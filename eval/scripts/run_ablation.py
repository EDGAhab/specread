#!/usr/bin/env python3
"""Experiment 1 — Contamination ablation.

60 questions x {with-spec, without-spec} x {gemini, mistral} = 240 calls.
<=2 concurrent per model. Exponential backoff on 429.
Output: eval/records/responses_ablation.jsonl
"""
import sys, os, json, hashlib, threading
from concurrent.futures import ThreadPoolExecutor, as_completed

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from eval_common import (load_sample, build_standard_prompt, build_nospec_prompt,
                         call_gemini, call_mistral, call_with_backoff, now_iso,
                         EVALDIR)

OUT = os.path.join(EVALDIR, "responses_ablation.jsonl")

CONDITIONS = ["with_spec", "without_spec"]
MODELS = [("gemini", "gemini-flash-lite-latest", call_gemini),
          ("mistral", "ministral-3b-latest", call_mistral)]


def one_job(model_name, model_id, fn, q, condition):
    prompt = (build_standard_prompt(q) if condition == "with_spec"
              else build_nospec_prompt(q))
    label = f"{model_name}/{condition}/{q['id']}"
    resp, lat, attempts, err = call_with_backoff(fn, prompt, label,
                                                 model_name=model_name)
    return {
        "id": q["id"], "task_type": q["task_type"],
        "answer_format": q["answer_format"],
        "mutation_type": (q.get("mutation") or {}).get("type", "unknown"),
        "condition": condition, "model": model_name, "model_id": model_id,
        "prompt_sha256": hashlib.sha256(prompt.encode()).hexdigest(),
        "prompt_chars": len(prompt),
        "response": resp, "error": err, "attempts": attempts,
        "latency_s": lat, "timestamp": now_iso(),
    }


def main():
    items = load_sample()
    jobs = [(pname, mid, fn, q, cond)
            for (pname, mid, fn) in MODELS
            for q in items for cond in CONDITIONS]
    # resume: skip already-recorded (model, id, condition)
    done = set()
    if os.path.exists(OUT):
        with open(OUT) as fh:
            for line in fh:
                try:
                    r = json.loads(line)
                    done.add((r["model"], r["id"], r["condition"]))
                except Exception:
                    pass
    jobs = [j for j in jobs if (j[0], j[3]["id"], j[4]) not in done]
    print(f"{len(jobs)} calls queued ({len(done)} already done)", flush=True)

    # one single-threaded worker per model; records stream to disk with a
    # file lock as each call completes (no head-of-line blocking).
    import threading as _th
    flock = _th.Lock()
    fh = open(OUT, "a")

    def run_model(model_jobs):
        for j in model_jobs:
            r = one_job(*j)
            with flock:
                fh.write(json.dumps(r, ensure_ascii=False) + "\n")
                fh.flush()

    with ThreadPoolExecutor(max_workers=len(MODELS)) as ex:
        list(ex.map(run_model,
                    [[j for j in jobs if j[0] == pname] for (pname, _, _) in MODELS]))
    fh.close()
    print(f"wrote {OUT}")


if __name__ == "__main__":
    raise SystemExit(main())
