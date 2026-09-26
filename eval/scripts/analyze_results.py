#!/usr/bin/env python3
"""Phase-3 analysis: score ablation + rule-table responses, emit tables.

Stage 1 (this script): scores every record with score_common, applies
adjudications from adjudications_ablation.json when present, and dumps
gray-zone loccat cases to ambiguous_*.jsonl for human review.
Stage 2: after adjudications are written, re-run to get final tables.

Outputs (printed + returned as dicts):
- per model x condition x task_type accuracy
- ablation deltas (with_spec - without_spec)
- leaked questions (without_spec correct)
- rule-table vs with_spec delta
- failure table: model x task_type x mutation_type accuracy
"""
import sys, os, json, glob
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from score_common import load_questions, score_response, gold_obj

EVALDIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "records")
ABL = os.path.join(EVALDIR, "responses_ablation.jsonl")
RT_FILES = sorted(glob.glob(os.path.join(EVALDIR, "responses_ruletable*.jsonl")))
ADJ = os.path.join(EVALDIR, "adjudications_ablation.json")


def load_adjudications():
    if os.path.exists(ADJ):
        with open(ADJ) as fh:
            return json.load(fh)
    return {}


def score_files(paths, adj_key, adj):
    """Score multiple response files; returns (rows, ambiguous)."""
    qs = load_questions()
    rows, ambiguous = [], []
    for path in paths:
        with open(path) as fh:
            for line in fh:
                r = json.loads(line)
                q = qs[r["id"]]
                resp = r.get("response", "")
                if not resp or r.get("error"):
                    rows.append({**r, "result": "ERROR", "note": r.get("error", "")[:120]})
                    continue
                status, note = score_response(resp, q)
                if status == "AMBIGUOUS":
                    am = adj.get(adj_key, {}).get(r["model"], {}).get(r["id"])
                    if am:
                        status = "OK" if am["verdict"] == "OK" else "WRONG"
                        note += f" [manual:{am['verdict']}]"
                    else:
                        ambiguous.append({
                            "id": r["id"], "model": r["model"],
                            "condition": r.get("condition", "ruletable"),
                            "gold": gold_obj(q), "note": note,
                            "response": resp[:900]})
                        rows.append({**r, "result": "AMBIGUOUS", "note": note})
                        continue
                rows.append({**r, "result": status, "note": note})
    return rows, ambiguous


def accuracy_table(rows):
    """rows -> {group_key: {type: (ok, n)}} where group_key = model/condition."""
    per = defaultdict(lambda: defaultdict(lambda: [0, 0]))
    for r in rows:
        key = (r["model"], r.get("condition", "ruletable"))
        t = r["task_type"]
        if r["result"] == "AMBIGUOUS":
            continue
        per[key][t][1] += 1
        if r["result"] == "OK":
            per[key][t][0] += 1
    return per


def failure_table(rows):
    """rows -> {model: {(type, mutation): (ok, n)}}"""
    per = defaultdict(lambda: defaultdict(lambda: [0, 0]))
    for r in rows:
        if r["result"] == "AMBIGUOUS":
            continue
        per[r["model"]][(r["task_type"], r.get("mutation_type", "?"))][1] += 1
        if r["result"] == "OK":
            per[r["model"]][(r["task_type"], r.get("mutation_type", "?"))][0] += 1
    return per


def fmt(ok, n):
    return f"{ok}/{n}={ok/n:.3f}" if n else "0/0=n/a"


def main():
    adj = load_adjudications()
    all_rows = {}
    all_amb = []
    if os.path.exists(ABL):
        rows, amb = score_files([ABL], "ablation", adj)
        all_rows["ablation"] = rows
        all_amb += [("ambiguous_ablation.jsonl", a) for a in amb]
        print(f"ablation: {len(rows)} scored, {len(amb)} ambiguous pending")
    if RT_FILES:
        rows, amb = score_files(RT_FILES, "ruletable", adj)
        all_rows["ruletable"] = rows
        all_amb += [("ambiguous_ruletable.jsonl", a) for a in amb]
        print(f"ruletable ({len(RT_FILES)} files): {len(rows)} scored, "
              f"{len(amb)} ambiguous pending")

    # dump ambiguous candidates grouped by file
    by_file = defaultdict(list)
    for fn, a in all_amb:
        by_file[fn].append(a)
    for fn, items in by_file.items():
        with open(os.path.join(EVALDIR, fn), "w") as fh:
            for a in items:
                fh.write(json.dumps(a, ensure_ascii=False) + "\n")
        print(f"  wrote {fn} ({len(items)})")

    # ---- accuracy tables ----
    for exp, rows in all_rows.items():
        per = accuracy_table(rows)
        print(f"\n=== {exp} accuracy (model/condition x type) ===")
        for key in sorted(per):
            tot_ok = tot_n = 0
            line = f"{key[0]}/{key[1]}: "
            for t in [1, 2, 3, 4]:
                ok, n = per[key][t]
                tot_ok += ok
                tot_n += n
                line += f"t{t}={fmt(ok,n)} "
            line += f"overall={fmt(tot_ok,tot_n)}"
            print(line)

    # ---- ablation deltas ----
    if "ablation" in all_rows:
        per = accuracy_table(all_rows["ablation"])
        print("\n=== ablation deltas: with_spec minus without_spec ===")
        for model in ["gemini", "mistral"]:
            line = f"{model}: "
            for t in [1, 2, 3, 4]:
                w_ok, w_n = per[(model, "with_spec")][t]
                b_ok, b_n = per[(model, "without_spec")][t]
                d = (w_ok / w_n - b_ok / b_n) if w_n and b_n else float("nan")
                line += f"t{t}={d:+.3f} "
            print(line)
        # leaked questions
        print("\n=== leaked questions (without_spec correct) ===")
        qs = load_questions()
        for r in all_rows["ablation"]:
            if r.get("condition") == "without_spec" and r["result"] == "OK":
                q = qs[r["id"]]
                g = gold_obj(q)
                print(f"  {r['model']} {r['id']} t{r['task_type']} "
                      f"gold={str(g)[:90]!r} resp={r['response'][:90]!r}")

    # ---- rule-table vs standard ----
    if "ruletable" in all_rows and "ablation" in all_rows:
        per_rt = accuracy_table(all_rows["ruletable"])
        per_ab = accuracy_table(all_rows["ablation"])
        print("\n=== rule-table vs with_spec (standard prompt) deltas ===")
        for model in ["gemini", "mistral"]:
            line = f"{model}: "
            for t in [1, 2, 3, 4]:
                rt_ok, rt_n = per_rt[(model, "ruletable")][t]
                w_ok, w_n = per_ab[(model, "with_spec")][t]
                d = (rt_ok / rt_n - w_ok / w_n) if rt_n and w_n else float("nan")
                line += f"t{t}={d:+.3f} "
            print(line)

    # ---- failure tables ----
    for exp, rows in all_rows.items():
        if exp == "ablation":
            # only with_spec rows for failure analysis
            rows = [r for r in rows if r.get("condition") == "with_spec"]
        ft = failure_table(rows)
        print(f"\n=== {exp} failure table: model -> (type,mutation) ok/n ===")
        for model in sorted(ft):
            for key in sorted(ft[model]):
                ok, n = ft[model][key]
                print(f"  {model} t{key[0]}/{key[1]}: {fmt(ok,n)}")

    # save rows for report writers
    for exp, rows in all_rows.items():
        with open(os.path.join(EVALDIR, f"scores_{exp}.json"), "w") as fh:
            json.dump([{"id": r["id"], "model": r["model"],
                        "condition": r.get("condition", "ruletable"),
                        "task_type": r["task_type"],
                        "mutation_type": r.get("mutation_type"),
                        "result": r["result"], "note": r["note"]}
                       for r in rows], fh, ensure_ascii=False, indent=1)
    print("\nwrote scores_*.json")


if __name__ == "__main__":
    raise SystemExit(main())
