#!/usr/bin/env python3
"""Shared prompting + API call helpers for SpecRead v1 phase-3 experiments.

Follows ~/workspace/specbench/EVAL_PROTOCOL.md exactly:
- standard prompt = spec excerpt (+ rtl for t4) + question + format instruction,
  incl. the t3 verdict-commit tweak (DECISION.md caveat 4).
- temperature 0, one question per call, identical prompts across models.
"""
import sys, os, json, time, hashlib, random, urllib.request
from datetime import datetime, timezone

sys.path.insert(0, "/opt/hatch/skills/skill-creator/bin")
from dynamic_credentials import add_surrogate_to_request, read_json_response

BASE = os.path.expanduser("~/workspace/specbench/build")
EVALDIR = os.path.join(BASE, "eval")
os.makedirs(EVALDIR, exist_ok=True)

UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36")

T3_CATS = ["NUMERIC_MISMATCH", "RULE_INVERSION", "CROSSREF_CONFLICT", "MISSING_CONDITION"]
T4_CATS = ["NUMERIC_MISMATCH", "RULE_INVERSION", "CROSSREF_CONFLICT",
           "MISSING_CONDITION"]  # canonical spec-side labels, same as t3 golds
# (2026-09-25 fix: t4 golds use spec-side contradiction categories, not the
# RTL mutation-type names; the prompt must offer the gold labels.)

FORMAT_INSTRUCTIONS = {
    "exact_value": "Reply with ONLY the exact value asked for. No explanation, no extra text.",
    "multiple_choice": "Reply with ONLY the letter of the correct option (e.g. B). No explanation.",
}

# ---- standard (with-spec) prompt ----
STD_TEMPLATE = """You are evaluating a hardware design specification (from the open-source OpenTitan project). Answer the question below using ONLY the provided excerpt(s). Do not use outside knowledge.

--- SPEC EXCERPT ---
{spec}
--- END SPEC EXCERPT ---
{rtl_block}
QUESTION: {question}

{fmt_instr}"""

# ---- without-spec (contamination ablation condition b) ----
NOSPEC_TEMPLATE = """No spec excerpt is provided. Answer the question below as best you can.

QUESTION: {question}

{fmt_instr}"""

# ---- rule-table baseline ----
RT_STEP1_TEMPLATE = """Extract the spec excerpt below into a numbered structured rule table. Write one rule per line in the form "R1: ...", "R2: ...". Include every factual statement, number, register name, field, and condition stated in the excerpt. Do not add outside knowledge and do not omit statements.

--- SPEC EXCERPT ---
{spec}
--- END SPEC EXCERPT ---
{rtl_block}
Reply with ONLY the numbered rule table, one rule per line."""

RT_STEP2_TEMPLATE = """You have extracted the rule table below from a hardware spec excerpt. Answer the question using ONLY your rule table. Do not consult the original excerpt and do not use outside knowledge.

--- RULE TABLE ---
{table}
--- END RULE TABLE ---
QUESTION: {question}

{fmt_instr}"""

RTL_BLOCK = """--- RTL EXCERPT ---
{rtl}
--- END RTL EXCERPT ---
"""


def t3_verdict_tweak():
    return (' Always commit to a verdict: either identify the contradiction '
            '(location + category) or state NO_CONTRADICTION. Do not question '
            'the premise or ask for clarification.')


def fmt_instruction(q):
    af = q["answer_format"]
    if af in FORMAT_INSTRUCTIONS:
        return FORMAT_INSTRUCTIONS[af]
    if af == "location+category":
        cats = T3_CATS if q["task_type"] == 3 else T4_CATS
        instr = ('Reply in JSON with exactly two keys: "location" (quote the two '
                 'conflicting statements, or give their locations) and "category" '
                 f'(exactly one of: {", ".join(cats)}). No text outside the JSON.')
        if q["task_type"] == 3:
            instr += t3_verdict_tweak()
        else:
            instr += (' If the RTL complies with the spec excerpt, reply with '
                      'exactly {"verdict": "NO_CONTRADICTION"} and no other text.')
        return instr
    raise ValueError(f"unknown answer_format {af}")


def rtl_block(q):
    return RTL_BLOCK.format(rtl=q["rtl_excerpt"]) if q.get("rtl_excerpt") else ""


def build_standard_prompt(q):
    return STD_TEMPLATE.format(spec=q["spec_excerpt"], rtl_block=rtl_block(q),
                               question=q["question"], fmt_instr=fmt_instruction(q))


def build_nospec_prompt(q):
    return NOSPEC_TEMPLATE.format(question=q["question"], fmt_instr=fmt_instruction(q))


def build_rt_step1_prompt(q):
    return RT_STEP1_TEMPLATE.format(spec=q["spec_excerpt"], rtl_block=rtl_block(q))


def build_rt_step2_prompt(q, table):
    return RT_STEP2_TEMPLATE.format(table=table.strip(), question=q["question"],
                                    fmt_instr=fmt_instruction(q))


def load_sample():
    items = []
    with open(os.path.join(BASE, "eval_sample_60.jsonl")) as fh:
        for line in fh:
            items.append(json.loads(line))
    assert len(items) == 60, len(items)
    return items


def post_json(url, payload, cred, allowed_hosts, timeout=150):
    data = json.dumps(payload).encode()
    req = urllib.request.Request(url, data=data,
                                 headers={"Content-Type": "application/json",
                                          "User-Agent": UA})
    add_surrogate_to_request(req, cred, entry_name="access_token",
                             allowed_hosts=allowed_hosts)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return read_json_response(resp)


def call_gemini(prompt, max_tokens=512):
    out = post_json(
        "https://generativelanguage.googleapis.com/v1beta/models/"
        "gemini-flash-lite-latest:generateContent",
        {"contents": [{"parts": [{"text": prompt}]}],
         "generationConfig": {"temperature": 0, "maxOutputTokens": max_tokens}},
        "custom.gemini2", ("generativelanguage.googleapis.com",))
    cands = out.get("candidates", [])
    if not cands:
        return ""
    return "".join(p.get("text", "") for p in cands[0].get("content", {}).get("parts", []))


def call_mistral(prompt, max_tokens=512):
    out = post_json(
        "https://api.mistral.ai/v1/chat/completions",
        {"model": "ministral-3b-latest", "temperature": 0, "max_tokens": max_tokens,
         "messages": [{"role": "user", "content": prompt}]},
        "custom.mistral", ("api.mistral.ai",))
    ch = out.get("choices", [])
    return ch[0].get("message", {}).get("content", "") if ch else ""


def is_rate_limit(exc):
    s = str(exc)
    return "429" in s or "rate" in s.lower() or "RESOURCE_EXHAUSTED" in s


_last_call = {}
_last_call_lock = __import__("threading").Lock()
# minimum gap between call starts, per model (polite pacing on free tier)
MIN_GAP_S = {"gemini": 12.0, "mistral": 1.0}


def pace(model_name):
    import threading as _t
    gap = MIN_GAP_S.get(model_name, 5.0)
    with _last_call_lock:
        prev = _last_call.get(model_name, 0.0)
        wait = prev + gap - time.time()
        if wait > 0:
            time.sleep(wait)
        _last_call[model_name] = time.time()


def now_iso():
    return datetime.now(timezone.utc).isoformat()


def call_with_backoff(fn, prompt, label, max_attempts=6, base_wait=15,
                      model_name=None):
    """Call fn(prompt) with exponential backoff on 429/rate-limit errors."""
    last_err = None
    for attempt in range(max_attempts):
        if model_name:
            pace(model_name)
        t0 = time.time()
        try:
            resp = fn(prompt)
            lat = time.time() - t0
            if not resp.strip():
                raise RuntimeError("empty response")
            return resp, round(lat, 1), attempt + 1, None
        except Exception as e:
            last_err = e
            if is_rate_limit(e) or attempt < max_attempts - 1:
                wait = min(base_wait * (2 ** attempt) + random.uniform(0, 5),
                           600 if is_rate_limit(e) else 120)
                print(f"  [{label}] attempt {attempt+1} failed ({str(e)[:90]}) — "
                      f"retry in {wait:.0f}s", flush=True)
                time.sleep(wait)
            else:
                break
    return "", 0.0, max_attempts, str(last_err)[:300]
