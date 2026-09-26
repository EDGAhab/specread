#!/usr/bin/env python3
"""Layered + decision-level metrics for the SpecRead main eval (mistral).

All numbers printed here are the single source of truth for the paper's
Failure Analysis, t4 decision-level, and gray-zone lower-bound numbers.

Layers (t3/t4, location+category items):
- strict: official score (auto + gray-zone adjudications from adjudications.json)
- loc_ok: distinctive-token overlap >= 0.45 on the cited location
           (adjudicated items use the adjudication verdict for the location too:
            OK verdict => loc_ok=True and cat_ok=True; WRONG => both False.
            Rationale: the adjudication judges the whole item.)
- cat_ok: predicted category == gold category
- both: loc_ok and cat_ok

Decision-level (t4, mutations + consistent-RTL controls combined):
- positive class = 98 mutated items (gold: violation)
- negative class = 41 control items (gold: NO_CONTRADICTION)
- pred_violation = response asserts a contradiction (parseable category and no
  NO_CONTRADICTION verdict); pred_compliant otherwise
- reports balanced accuracy, precision, recall, F1, MCC

Gray-zone lower bound: strict accuracy with every adjudicated item counted WRONG
(i.e. the 26 adjudicated-OK flipped to WRONG).
"""
import sys, os, json, re, math
from collections import Counter, defaultdict

EVAL = os.path.expanduser("~/workspace/specbench/build/eval")
sys.path.insert(0, EVAL)
import score_main as sm

CATS = ["NUMERIC_MISMATCH", "RULE_INVERSION", "CROSSREF_CONFLICT", "MISSING_CONDITION"]


def gold_cat(q):
    g = q["gold_answer"]
    g = json.loads(g) if isinstance(g, str) else g
    return g["category"].upper()


def predict_category(resp):
    """Predicted category: JSON-parsed valid label, else token-presence fallback
    (exactly one category token present). Matches the paper's layered analysis."""
    loc, cat = sm.extract_json_loccat(resp)
    if cat and cat in CATS:
        return cat
    ru = resp.upper()
    found = [c for c in CATS if c in ru]
    if len(found) == 1:
        return found[0]
    return None


def loc_frac(resp, q):
    g = q["gold_answer"]
    g = json.loads(g) if isinstance(g, str) else g
    loc_text = g.get("location") or (g.get("rule", "") + " " + g.get("rtl_location", ""))
    gtoks = sm.distinctive_tokens(loc_text)
    rtoks = set(sm.distinctive_tokens(resp))
    if not gtoks:
        return 1.0
    return sum(1 for t in gtoks if t in rtoks) / len(gtoks)


def t4_loc_frac(resp, q):
    """Mutation-aware t4 location check: fraction of the mutated snippet's
    distinctive tokens present in the response."""
    mut = (q.get("mutation") or {}).get("mutated", "")
    gtoks = sm.distinctive_tokens(mut)
    rtoks = set(sm.distinctive_tokens(resp))
    if not gtoks:
        return 1.0
    return sum(1 for t in gtoks if t in rtoks) / len(gtoks)


def main():
    qs = sm.load_questions()
    adj = json.load(open(os.path.join(EVAL, "adjudications.json"))).get("mistral", {})
    resp_main, resp_ctrl = {}, {}
    with open(os.path.join(EVAL, "responses_main_mistral_v2.jsonl")) as fh:
        for line in fh:
            r = json.loads(line)
            resp_main[r["id"]] = r
    with open(os.path.join(EVAL, "responses_controls_mistral_v2.jsonl")) as fh:
        for line in fh:
            r = json.loads(line)
            resp_ctrl[r["id"]] = r

    # ---- layered t3/t4 ----
    layers = {3: Counter(), 4: Counter()}   # loc_ok, cat_ok, both, strict_ok, n
    conf = {3: Counter(), 4: Counter()}     # (gold_cat, pred_cat) -> n
    op = Counter()                          # t3 operator -> [ok, n]
    op_ok = Counter()
    strict_by_type = Counter()
    n_by_type = Counter()
    adj_ok_by_type = Counter()              # adjudicated OK per type (for lower bound)

    for qid, r in sorted(resp_main.items()):
        q = qs[qid]
        t = q["task_type"]
        af = q["answer_format"]
        if af == "verdict+explanation":
            continue  # distractors handled separately
        n_by_type[t] += 1
        resp = r.get("response", "")
        if af == "location+category":
            ok, amb, note = sm.score_loccat(resp, q["gold_answer"])
            a = adj.get(qid)
            if a:
                ok = (a["verdict"] == "OK")
                amb = False
            if amb:
                print(f"UNADJUDICATED AMBIGUOUS: {qid} -- {note}")
                continue
            strict_by_type[t] += ok
            if a and a["verdict"] == "OK":
                adj_ok_by_type[t] += 1
            # ---- layered components ----
            # location: "not wrong" boundary (overlap >= 0.25); the strict score
            # requires >= 0.45, which is why layered "both" can exceed strict.
            # category: JSON-parsed label else single-token-presence fallback.
            lf = loc_frac(resp, q) if t == 3 else t4_loc_frac(resp, q)
            gc = gold_cat(q)
            pc = predict_category(resp)
            # layers are pure auto-scorer outputs (no adjudication folding);
            # strict above applies the adjudication override. The location
            # bar for layers is the "not wrong" boundary (0.25), while strict
            # requires 0.45 -- hence layered "both" can exceed strict.
            loc_ok = lf >= 0.25
            cat_ok = (pc == gc)
            layers[t]["n"] += 1
            layers[t]["loc_ok"] += loc_ok
            layers[t]["cat_ok"] += cat_ok
            layers[t]["both"] += (loc_ok and cat_ok)
            layers[t]["strict_ok"] += ok
            conf[t][(gc, pc or "NONE")] += 1
            if t == 3:
                mop = (q.get("mutation") or {}).get("type", "?")
                op[mop] += 1
                op_ok[mop] += ok
        elif af in ("exact_value", "multiple_choice"):
            ok, _ = (sm.score_exact(resp, q["gold_answer"]) if af == "exact_value"
                     else sm.score_mc(resp, q["gold_answer"]))
            strict_by_type[t] += ok

    print("=== layered (t3/t4) ===")
    for t in (3, 4):
        L = layers[t]
        n = L["n"]
        print(f"t{t}: n={n} loc={L['loc_ok']}/{n}={L['loc_ok']/n:.3f} "
              f"cat={L['cat_ok']}/{n}={L['cat_ok']/n:.3f} "
              f"both={L['both']}/{n}={L['both']/n:.3f} "
              f"strict={L['strict_ok']}/{n}={L['strict_ok']/n:.3f}")
    print("=== t3 confusion (gold x pred) ===")
    for gc in CATS:
        row = " ".join(f"{conf[3][(gc, pc)]:3d}" for pc in CATS + ["NONE"])
        print(f"  {gc:17s} {row}")
    print("=== t4 confusion (gold x pred) ===")
    for gc in CATS:
        row = " ".join(f"{conf[4][(gc, pc)]:3d}" for pc in CATS + ["NONE"])
        print(f"  {gc:17s} {row}")
    print("=== t3 by operator (strict) ===")
    for mop in sorted(op):
        print(f"  {mop}: {op_ok[mop]}/{op[mop]}={op_ok[mop]/op[mop]:.3f}")

    # ---- t4 decision-level: mutations + controls ----
    def pred_violation(resp):
        ru = resp.upper()
        if "NO_CONTRADICTION" in ru:
            return False
        loc, cat = sm.extract_json_loccat(resp)
        if cat:
            return True
        # affirmative violation language without the compliant verdict
        if re.search(r"\b(contradiction|inconsistenc|violation|mismatch)\b", resp, re.I):
            return True
        return False

    TP = FN = FP = TN = 0
    for qid, r in sorted(resp_main.items()):
        q = qs[qid]
        if q["task_type"] == 4 and q["answer_format"] == "location+category":
            if pred_violation(r.get("response", "")):
                TP += 1
            else:
                FN += 1
    for qid, r in sorted(resp_ctrl.items()):
        if pred_violation(r.get("response", "")):
            FP += 1
        else:
            TN += 1
    tpr = TP / (TP + FN)
    tnr = TN / (TN + FP) if (TN + FP) else 0.0
    bal_acc = (tpr + tnr) / 2
    prec = TP / (TP + FP) if (TP + FP) else 0.0
    rec = tpr
    f1 = 2 * prec * rec / (prec + rec) if (prec + rec) else 0.0
    mcc_d = math.sqrt((TP + FP) * (TP + FN) * (TN + FP) * (TN + FN))
    mcc = (TP * TN - FP * FN) / mcc_d if mcc_d else 0.0
    print("=== t4 decision-level (98 mutations + 41 controls) ===")
    print(f"TP={TP} FN={FN} FP={FP} TN={TN}")
    print(f"TPR(recall)={rec:.3f} TNR={tnr:.3f} balanced_acc={bal_acc:.3f}")
    print(f"precision={prec:.3f} recall={rec:.3f} F1={f1:.3f} MCC={mcc:.3f}")

    # ---- gray-zone lower bound ----
    tot_ok = sum(strict_by_type[t] for t in (1, 2, 3, 4))
    tot_n = sum(n_by_type[t] for t in (1, 2, 3, 4))
    adj_ok_tot = sum(adj_ok_by_type.values())
    print("=== gray-zone lower bound (adjudicated-OK counted WRONG) ===")
    for t in (1, 2, 3, 4):
        lb = strict_by_type[t] - adj_ok_by_type[t]
        print(f"t{t}: strict {strict_by_type[t]}/{n_by_type[t]} -> lower bound {lb}/{n_by_type[t]}={lb/n_by_type[t]:.3f}")
    print(f"overall: strict {tot_ok}/{tot_n}={tot_ok/tot_n:.3f} -> "
          f"lower bound {tot_ok-adj_ok_tot}/{tot_n}={(tot_ok-adj_ok_tot)/tot_n:.3f}")


if __name__ == "__main__":
    main()
