#!/usr/bin/env python3
"""SpecRead v1 MAIN eval — 385 questions + 42 distractors x 2 models = 854 calls.

Adapted from pilot/model_testing/run_pilot.py (the proven pipeline).
Pre-registered protocol: ~/workspace/specbench/EVAL_PROTOCOL.md

Changes from pilot:
- question files: build/spec_read_v1.jsonl + build/distractors_v1.jsonl
- models: gemini-flash-lite-latest, ministral-3b-latest only (free tier; NO Groq)
- prompt template is IP-generic (10 IPs, not UART-only)
- t3 verdict-commit tweak (EVAL_PROTOCOL.md): the t3 location+category prompt
  instructs the model to always commit to a verdict — either identify the
  contradiction (location + category) or reply exactly NO_CONTRADICTION.
- max_workers=2; longer exponential backoff on 429; never hammer.
- prompts built ONCE per question id and shared across models; prompt_sha256
  is stored per call to prove prompt identity across models.
- output: one responses file per model under build/eval/.
"""
import sys, os, json, time, hashlib, random, urllib.request, threading
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone

# per-provider pacing: minimum interval between the starts of two calls to the
# same provider. The gemini free-tier key is currently saturated by an external
# consumer (not on this box; all probes 429 for ~50 min), so gemini paces at
# 15s (~4 RPM, polite share) and relies on exponential backoff for gaps; the
# run automatically speeds up when the saturation ends. Mistral 2s (shared
# with the ruletable worker, uncongested).
PACE = {"gemini": 15.0, "mistral": 2.0, "mistral_small": 8.0}
_next_ok = {"gemini": 0.0, "mistral": 0.0, "mistral_small": 0.0}
_pace_lock = threading.Lock()


def pace(provider):
    with _pace_lock:
        now = time.time()
        wait = _next_ok[provider] - now
        _next_ok[provider] = max(now, _next_ok[provider]) + PACE[provider]
    if wait > 0:
        time.sleep(wait)

sys.path.insert(0, "/opt/hatch/skills/skill-creator/bin")
from dynamic_credentials import add_surrogate_to_request, read_json_response

BASE = os.path.expanduser("~/workspace/specbench")
BUILD = os.path.join(BASE, "build")
EVAL = os.path.join(BUILD, "eval")
os.makedirs(EVAL, exist_ok=True)

UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36")

T3_CATS = ["NUMERIC_MISMATCH", "RULE_INVERSION", "CROSSREF_CONFLICT", "MISSING_CONDITION"]
# T4 label set (canonical-only, v2 2026-09-25): all 98 t4 golds now use the
# canonical spec-side labels (NUMERIC_MISMATCH/RULE_INVERSION/CROSSREF_CONFLICT/
# MISSING_CONDITION). The 10 pilot-carryover uart-t4-001..010 golds were
# converted from legacy RTL-side labels to canonical per the dominant
# mutation-type mapping (see build/v2_change_log.json). The prompt therefore
# offers ONLY the four canonical labels.
T4_CATS = ["NUMERIC_MISMATCH", "RULE_INVERSION", "CROSSREF_CONFLICT", "MISSING_CONDITION"]

FORMAT_INSTRUCTIONS = {
    "exact_value": "Reply with ONLY the exact value asked for. No explanation, no extra text.",
    "multiple_choice": "Reply with ONLY the letter of the correct option (e.g. B). No explanation.",
}

PROMPT_TEMPLATE = """You are evaluating a hardware design specification (from the open-source OpenTitan project). Answer the question below using ONLY the provided excerpt(s). Do not use outside knowledge.

--- SPEC EXCERPT ---
{spec}
--- END SPEC EXCERPT ---
{rtl_block}
QUESTION: {question}

{fmt_instr}"""

RTL_BLOCK = """--- RTL EXCERPT ---
{rtl}
--- END RTL EXCERPT ---
"""


def build_prompt(q):
    af = q["answer_format"]
    if af in FORMAT_INSTRUCTIONS:
        fmt_instr = FORMAT_INSTRUCTIONS[af]
    elif af == "location+category":
        cats = T3_CATS if q["task_type"] == 3 else T4_CATS
        fmt_instr = ('Reply in JSON with exactly two keys: "location" (quote the two '
                     'conflicting statements, or give their locations) and "category" '
                     f'(exactly one of: {", ".join(cats)}). No text outside the JSON.')
        if q["task_type"] == 3:
            # t3 verdict-commit tweak (pre-registered in EVAL_PROTOCOL.md)
            fmt_instr += (' You must commit to a verdict: if you find NO contradiction '
                          'in the excerpts, do not refuse the premise, explain, or ask '
                          'for clarification — instead reply with exactly NO_CONTRADICTION '
                          'and nothing else.')
        else:
            # t4 (v2.1b): give the model an explicit compliant-answer option so
            # consistent-RTL controls are answerable without forced guessing
            fmt_instr += (' If the RTL complies with the spec excerpt, reply with '
                          'exactly {"verdict": "NO_CONTRADICTION"} and no other text.')
    elif af == "verdict+explanation":
        fmt_instr = ('Reply in JSON with exactly two keys: "verdict" (either "consistent" '
                     'or "contradiction") and "explanation" (one or two sentences). '
                     "No text outside the JSON.")
    else:
        raise ValueError(f"unknown answer_format {af}")
    rtl_block = RTL_BLOCK.format(rtl=q["rtl_excerpt"]) if q.get("rtl_excerpt") else ""
    return PROMPT_TEMPLATE.format(spec=q["spec_excerpt"], rtl_block=rtl_block,
                                  question=q["question"], fmt_instr=fmt_instr)


def post_json(url, payload, cred, allowed_hosts, timeout=150):
    data = json.dumps(payload).encode()
    req = urllib.request.Request(url, data=data,
                                 headers={"Content-Type": "application/json",
                                          "User-Agent": UA})
    add_surrogate_to_request(req, cred, entry_name="access_token",
                             allowed_hosts=allowed_hosts)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return read_json_response(resp)


def call_gemini(prompt):
    out = post_json(
        "https://generativelanguage.googleapis.com/v1beta/models/"
        "gemini-flash-lite-latest:generateContent",
        {"contents": [{"parts": [{"text": prompt}]}],
         "generationConfig": {"temperature": 0, "maxOutputTokens": 512}},
        "custom.gemini2", ("generativelanguage.googleapis.com",))
    cands = out.get("candidates", [])
    return "".join(p.get("text", "") for p in cands[0].get("content", {}).get("parts", [])) if cands else ""


def call_mistral(prompt):
    out = post_json(
        "https://api.mistral.ai/v1/chat/completions",
        {"model": "ministral-3b-latest", "temperature": 0, "max_tokens": 512,
         "messages": [{"role": "user", "content": prompt}]},
        "custom.mistral", ("api.mistral.ai",))
    ch = out.get("choices", [])
    return ch[0].get("message", {}).get("content", "") if ch else ""


MODELS = [("gemini", "gemini-flash-lite-latest", call_gemini),
          ("mistral", "ministral-3b-latest", call_mistral)]

MODEL_OUT = {"gemini": os.path.join(EVAL, "responses_main_gemini_v2.jsonl"),
             "mistral": os.path.join(EVAL, "responses_main_mistral_v2.jsonl")}


def load_items():
    items, distractors = [], []
    with open(os.path.join(BUILD, "spec_read_v2_1.jsonl")) as fh:
        for line in fh:
            items.append(json.loads(line))
    with open(os.path.join(BUILD, "distractors_v2.jsonl")) as fh:
        for line in fh:
            distractors.append(json.loads(line))
    return items, distractors


def is_429(e):
    return "429" in str(e) or "rate" in str(e).lower() or "quota" in str(e).lower()


def one_call(provider_name, model_id, fn, q, prompt):
    last_err = None
    for attempt in range(6):
        pace(provider_name)  # respect per-provider minimum interval
        t0 = time.time()
        try:
            resp = fn(prompt)
            lat = time.time() - t0
            if not resp.strip():
                raise RuntimeError("empty response")
            return {"id": q["id"], "task_type": q["task_type"],
                    "answer_format": q["answer_format"],
                    "model": provider_name, "model_id": model_id,
                    "prompt_sha256": hashlib.sha256(prompt.encode()).hexdigest(),
                    "prompt_chars": len(prompt),
                    "response": resp, "latency_s": round(lat, 1),
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                    "attempt": attempt + 1}
        except Exception as e:
            last_err = e
            base = 15 if is_429(e) else 5
            wait = min(base * (2 ** attempt), 180)
            print(f"  [{provider_name}/{q['id']}] attempt {attempt+1} failed: "
                  f"{str(e)[:120]} — retry in {wait}s", flush=True)
            time.sleep(wait)
    return {"id": q["id"], "task_type": q["task_type"],
            "answer_format": q["answer_format"],
            "model": provider_name, "model_id": model_id,
            "prompt_sha256": hashlib.sha256(prompt.encode()).hexdigest(),
            "prompt_chars": len(prompt),
            "response": "", "error": str(last_err)[:300],
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "attempt": 6}


def main():
    models_only = os.environ.get("MODELS_ONLY", "").strip().lower()
    sel = [m for m in MODELS if (not models_only or m[0] == models_only)]
    assert sel, f"MODELS_ONLY={models_only!r} matches no model"
    # targeted re-runs: TASK_TYPES="4" and/or ITEM_IDS="aes-t2-001" (comma-sep);
    # APPEND=1 keeps the existing output file, dropping any records whose id
    # is in the re-run set (avoids duplicates).
    task_types = {t.strip() for t in os.environ.get("TASK_TYPES", "").split(",") if t.strip()}
    item_ids = {i.strip() for i in os.environ.get("ITEM_IDS", "").split(",") if i.strip()}
    append = os.environ.get("APPEND", "") == "1"
    items, distractors = load_items()
    order = items + distractors  # (shuffled + filtered below)
    assert len(items) == 385 and len(distractors) == 41, (len(items), len(distractors))
    rng = random.Random(20260925)
    order = items + distractors
    rng.shuffle(order)
    if task_types or item_ids:
        # targeted re-run: keep the shuffled relative order, filter to the set
        order = [q for q in order
                 if str(q["task_type"]) in task_types or q["id"] in item_ids]
        print(f"filtered to {len(order)} items (TASK_TYPES={task_types} ITEM_IDS={item_ids})",
              flush=True)
    else:
        with open(os.path.join(EVAL, "call_order.json"), "w") as fh:
            json.dump({"seed": 20260925, "order": [q["id"] for q in order]}, fh)
    print(f"call order (seed 20260925): {[q['id'] for q in order][:10]} ... "
          f"total {len(order)}", flush=True)

    # prompts built ONCE per question, shared across models (prompt identity)
    prompts = {q["id"]: build_prompt(q) for q in order}
    sha = {}
    for q in order:
        assert prompts[q["id"]], q["id"]
        sha[q["id"]] = hashlib.sha256(prompts[q["id"]].encode()).hexdigest()
    # sanity: distinct prompts per question. v2 has no duplicate prompts
    # (the single verified duplicate pair uart-t3d-001/uart-t3d-003 was
    # deduped; SCORES_v1's "7 pairs" claim was not reproducible on audit).
    ndup = len(order) - len(set(sha.values()))
    if ndup:
        print(f"NOTE: {ndup} questions share a prompt with another id "
              f"(dataset duplicates, kept as-is)", flush=True)

    # reset outputs for the selected models only (fresh run per model),
    # unless APPEND=1 (targeted re-run: drop stale records for re-run ids)
    rerun_ids = {q["id"] for q in order}
    for pname, _, _ in sel:
        if append:
            kept = []
            if os.path.exists(MODEL_OUT[pname]):
                with open(MODEL_OUT[pname]) as fh:
                    for line in fh:
                        if not line.strip():
                            continue
                        r = json.loads(line)
                        if r["id"] not in rerun_ids:
                            kept.append(r)
            with open(MODEL_OUT[pname], "w") as fh:
                for r in kept:
                    fh.write(json.dumps(r, ensure_ascii=False) + "\n")
            print(f"[{pname}] APPEND mode: kept {len(kept)} records, "
                  f"re-running {len(rerun_ids)} ids", flush=True)
        else:
            open(MODEL_OUT[pname], "w").close()

    # Interleave providers: [gemini_q1, mistral_q1, gemini_q2, mistral_q2, ...]
    # so the 2 workers alternate providers instead of both hammering one.
    # MODELS_ONLY env var restricts to one model (e.g. run mistral while
    # gemini is saturated).
    jobs = []
    for q in order:
        for (pname, mid, fn) in sel:
            jobs.append((pname, mid, fn, q, prompts[q["id"]]))
    print(f"{len(jobs)} calls queued (models={[m[0] for m in sel]}, max_workers=2)",
          flush=True)

    done = 0
    handles = {p: open(MODEL_OUT[p], "a") for p in MODEL_OUT}
    try:
        with ThreadPoolExecutor(max_workers=2) as ex:
            futs = [ex.submit(one_call, *j) for j in jobs]
            for f in futs:
                rec = f.result()
                handles[rec["model"]].write(json.dumps(rec, ensure_ascii=False) + "\n")
                handles[rec["model"]].flush()
                done += 1
                if done % 20 == 0:
                    print(f"  ...{done}/{len(jobs)} done", flush=True)
    finally:
        for h in handles.values():
            h.close()
    print("wrote responses files", flush=True)


if __name__ == "__main__":
    raise SystemExit(main())
