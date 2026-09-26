#!/usr/bin/env python3
"""Experiment 2 — Rule-table baseline.

60 questions x {gemini, mistral} = 120 question-model pairs; each pair is a
two-step prompt (step 1: extract excerpt into a numbered structured rule table;
step 2: answer using ONLY the rule table). Records both the table and the
final answer.
Output: eval/records/responses_ruletable.jsonl
"""
import sys, os, json, hashlib, threading
from concurrent.futures import ThreadPoolExecutor, as_completed

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from eval_common import (load_sample, build_rt_step1_prompt, build_rt_step2_prompt,
                         call_gemini, call_mistral, call_with_backoff, now_iso,
                         EVALDIR)

OUT = os.environ.get("RT_OUT") or os.path.join(EVALDIR, "responses_ruletable.jsonl")

MODELS = [("gemini", "gemini-flash-lite-latest", call_gemini),
          ("mistral", "ministral-3b-latest", call_mistral)]

# optional: MODELS_ONLY=gemini|mistral to run a single model
_only = os.environ.get("MODELS_ONLY")
if _only:
    MODELS = [m for m in MODELS if m[0] == _only]
    assert MODELS, f"unknown MODELS_ONLY={_only}"


def one_job(model_name, model_id, fn, q):
    # step 1: extract rule table
    p1 = build_rt_step1_prompt(q)
    table, lat1, att1, err1 = call_with_backoff(
        lambda pr: fn(pr, max_tokens=1024), p1,
        f"{model_name}/ruletable-step1/{q['id']}", model_name=model_name)
    rec = {
        "id": q["id"], "task_type": q["task_type"],
        "answer_format": q["answer_format"],
        "mutation_type": (q.get("mutation") or {}).get("type", "unknown"),
        "model": model_name, "model_id": model_id,
        "step1_prompt_sha256": hashlib.sha256(p1.encode()).hexdigest(),
        "rule_table": table, "step1_error": err1,
        "step1_attempts": att1, "step1_latency_s": lat1,
        "timestamp": now_iso(),
    }
    if not table:
        rec.update({"response": "", "error": "step1 failed", "attempts": att1,
                    "latency_s": 0.0})
        return rec
    # step 2: answer from the table only
    p2 = build_rt_step2_prompt(q, table)
    resp, lat2, att2, err2 = call_with_backoff(
        fn, p2, f"{model_name}/ruletable-step2/{q['id']}", model_name=model_name)
    rec.update({
        "step2_prompt_sha256": hashlib.sha256(p2.encode()).hexdigest(),
        "response": resp, "error": err2, "attempts": att1 + att2,
        "latency_s": round(lat1 + lat2, 1),
    })
    return rec


def main():
    items = load_sample()
    jobs = [(pname, mid, fn, q) for (pname, mid, fn) in MODELS for q in items]
    # resume: skip already-recorded (model, id)
    done = set()
    if os.path.exists(OUT):
        with open(OUT) as fh:
            for line in fh:
                try:
                    r = json.loads(line)
                    done.add((r["model"], r["id"]))
                except Exception:
                    pass
    jobs = [j for j in jobs if (j[0], j[3]["id"]) not in done]
    print(f"{len(jobs)} question-model pairs queued ({len(done)} already done; "
          f"= {2*len(jobs)} API calls)", flush=True)

    import threading as _th
    flock = _th.Lock()
    fh = open(OUT, "a")

    def run_model(model_jobs):
        for i, j in enumerate(model_jobs):
            r = one_job(*j)
            with flock:
                fh.write(json.dumps(r, ensure_ascii=False) + "\n")
                fh.flush()
            if (i + 1) % 10 == 0:
                print(f"  [{j[0]}] {i+1}/{len(model_jobs)} done", flush=True)

    with ThreadPoolExecutor(max_workers=len(MODELS)) as ex:
        list(ex.map(run_model,
                    [[j for j in jobs if j[0] == pname] for (pname, _, _) in MODELS]))
    fh.close()
    print(f"wrote {OUT}")


if __name__ == "__main__":
    raise SystemExit(main())
