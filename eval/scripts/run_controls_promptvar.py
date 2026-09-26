#!/usr/bin/env python3
"""Prompt-sensitivity check for t4 controls (reviewer suggestion).

Runs the 41 t4 control items (unmutated RTL, gold: NO_CONTRADICTION) through
Ministral-3B with a deterministically varied prompt, to test whether the 100%
false-positive rate is robust to prompt phrasing.

VARIATION (documented before any API call):
  Original instruction (run_controls.py):
    'You must commit to a verdict: if you find NO violation of the '
    'spec in the RTL excerpt, do not refuse the premise, explain, or '
    'ask for clarification -- instead reply with exactly '
    'NO_CONTRADICTION and nothing else.'

  Variant instruction (this script):
    'The RTL excerpt may be fully compliant with the specification. '
    'If you find NO violation of the spec in the RTL excerpt, reply '
    'with exactly NO_CONTRADICTION and nothing else. Do not refuse '
    'the premise, explain, or ask for clarification.'

The variant makes the compliant outcome salient up front instead of framing
it as an exception to a "must commit to a verdict" directive. Everything else
(spec excerpt, RTL excerpt, question, JSON format instruction, category list)
is byte-identical to the original.

Rate limiting: max 1 concurrent call, 3s gap between calls, to avoid
interfering with SIGMETRICS probe traffic on the shared Mistral key.
No retries on 429/5xx (probe priority).
"""

import json, os, sys, time, hashlib, random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run_controls import PROMPT_TEMPLATE, RTL_BLOCK, T4_CATS, MODEL_FNS

BUILD = os.path.expanduser("~/workspace/specbench/build")
OUT = os.path.expanduser("~/workspace/specbench/build/eval/responses_controls_mistral_promptvar.jsonl")

VARIANT_INSTR = (
    'Reply in JSON with exactly two keys: "location" (quote the two '
    'conflicting statements, or give their locations) and "category" '
    f'(exactly one of: {", ".join(T4_CATS)}). No text outside the JSON. '
    'The RTL excerpt may be fully compliant with the specification. '
    'If you find NO violation of the spec in the RTL excerpt, reply '
    'with exactly NO_CONTRADICTION and nothing else. Do not refuse '
    'the premise, explain, or ask for clarification.'
)

def build_variant_prompt(q):
    rtl_block = RTL_BLOCK.format(rtl=q["rtl_excerpt"]) if q.get("rtl_excerpt") else ""
    return PROMPT_TEMPLATE.format(spec=q["spec_excerpt"], rtl_block=rtl_block,
                                  question=q["question"], fmt_instr=VARIANT_INSTR)

def one_call(pname, mid, fn, q, prompt):
    import time as _t
    t0 = _t.time()
    try:
        resp = fn(prompt)
        rec = {"id": q["id"], "task_type": 4, "answer_format": "json_or_nocontradiction",
               "model": pname, "model_id": mid,
               "prompt_sha256": hashlib.sha256(prompt.encode()).hexdigest(),
               "prompt_chars": len(prompt), "prompt_variant": "compliant_salient_v1",
               "response": resp, "latency_s": round(_t.time() - t0, 2),
               "timestamp": _t.strftime("%Y-%m-%dT%H:%M:%S%z"),
               "attempt": 1}
    except Exception as e:
        rec = {"id": q["id"], "task_type": 4, "model": pname, "model_id": mid,
               "prompt_variant": "compliant_salient_v1",
               "error": f"{type(e).__name__}: {e}",
               "timestamp": _t.strftime("%Y-%m-%dT%H:%M:%S%z")}
    return rec

def main():
    items = [json.loads(l) for l in open(os.path.join(BUILD, "t4_controls_v3.jsonl"))]
    assert len(items) == 41, len(items)
    # deterministic order (same seed as original)
    rng = random.Random(20260926)
    rng.shuffle(items)
    pname, mid, fn = MODEL_FNS["mistral"]
    print(f"41 control prompt-variant calls queued (model={pname})", flush=True)
    print(f"Variant instruction documented in script header.", flush=True)
    with open(OUT, "w") as out:
        for i, q in enumerate(items):
            prompt = build_variant_prompt(q)
            rec = one_call(pname, mid, fn, q, prompt)
            out.write(json.dumps(rec, ensure_ascii=False) + "\n")
            out.flush()
            status = "OK" if "response" in rec else f"ERR:{rec.get('error','?')[:40]}"
            print(f"[{i+1}/41] {q['id']}: {status}", flush=True)
            if i < len(items) - 1:
                time.sleep(3)  # rate-limit gap
    print(f"done -> {OUT}", flush=True)

if __name__ == "__main__":
    main()
