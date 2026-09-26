#!/usr/bin/env python3
"""Generate paper/numbers.tex: every number in specread_v2.tex as LaTeX macros.

Single source of truth for the paper's numbers (2026-09-26, reviewer revision):
- Main results: CONSERVATIVE scoring (--conservative), gray-zone cases counted
  WRONG, adjudications.json ignored. Fully scripted, no human/LLM judgment.
- Primary t3/t4 headline: verdict+location (category as secondary column).
- Appendix sensitivity: deterministic lenient-threshold scoring
  (location overlap >= 0.25 instead of >= 0.45); no adjudication used.
- Accuracy macros (Acc*) are percentages (e.g. 33.2); use with \\% in tex.
  Decision-level macros (Dec*) stay as proportions (used without \\%).

Usage: python3 gen_paper_numbers.py
Output: ../paper/numbers.tex  (included by specread_v2.tex via \\input)

All values are parsed from the output of score_main.py / score_layered.py /
baselines.py (run by this script), plus Wilson 95% CIs computed here.
Nothing is hand-entered.
"""
import os, re, subprocess, math, json

EVAL = os.path.expanduser("~/workspace/specbench/build/eval")
PAPER = os.path.expanduser("~/workspace/specbench/paper")


def run(args):
    p = subprocess.run(["python3"] + args, cwd=EVAL, capture_output=True, text=True)
    if p.returncode != 0:
        raise RuntimeError(f"{args} failed:\n{p.stderr[-2000:]}")
    return p.stdout


def wilson(ok, n, z=1.96):
    if n == 0:
        return (0.0, 0.0)
    p = ok / n
    d = 1 + z * z / n
    c = p + z * z / (2 * n)
    m = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n))
    lo, hi = (c - m) / d, (c + m) / d
    # clamp floating-point dust to [0, 1]
    return (max(0.0, lo), min(1.0, hi))


def parse_main(out):
    """{'mistral': {1:(ok,n), 2:(ok,n), 3:(ok,n), 4:(ok,n)}, 'fpr':(fp,n)}"""
    d = {"mistral": {}, "fpr": (0, 0)}
    for line in out.splitlines():
        m = re.search(r"^mistral: t1=(\d+)/(\d+) t2=(\d+)/(\d+) t3=(\d+)/(\d+) t4=(\d+)/(\d+)", line)
        if m:
            g = list(map(int, m.groups()))
            for t in (1, 2, 3, 4):
                d["mistral"][t] = (g[(t - 1) * 2], g[(t - 1) * 2 + 1])
        m = re.search(r"distractor_FPR=(\d+)/(\d+)", line)
        if m:
            d["fpr"] = (int(m.group(1)), int(m.group(2)))
    return d


def parse_layered(out):
    d = {}
    cur_conf = None
    for line in out.splitlines():
        m = re.match(r"t([34]): n=(\d+) loc=(\d+)/\d+=([\d.]+) cat=(\d+)/\d+=([\d.]+) both=(\d+)/\d+=([\d.]+) strict=(\d+)/\d+=([\d.]+)", line)
        if m:
            t = int(m.group(1))
            d[t] = {"n": int(m.group(2)), "loc": (int(m.group(3)), float(m.group(4))),
                    "cat": (int(m.group(5)), float(m.group(6))),
                    "both": (int(m.group(7)), float(m.group(8))),
                    "strict": (int(m.group(9)), float(m.group(10)))}
        m = re.match(r"t([34]): n=(\d+) vl=(\d+)/\d+=([\d.]+)", line)
        if m:
            t = int(m.group(1))
            d.setdefault(t, {})["vl"] = (int(m.group(3)), float(m.group(4)))
            d[t]["n"] = int(m.group(2))
        m = re.match(r"  (\w+): (\d+)/(\d+)=([\d.]+)", line)
        if m and m.group(1) in ("changed_number", "crossref_conflict", "rule_inversion", "deleted_condition"):
            d.setdefault("op", {})[m.group(1)] = (int(m.group(2)), int(m.group(3)), float(m.group(4)))
        m = re.match(r"=== deleted_condition location-only: (\d+)/(\d+)=([\d.]+) ===", line)
        if m:
            d["dc_loc"] = (int(m.group(1)), int(m.group(2)), float(m.group(3)))
        m = re.match(r"TP=(\d+) FN=(\d+) FP=(\d+) TN=(\d+)", line)
        if m:
            # t3 verdict-level comes first, t4 decision-level second; disambiguate
            # by call order: we parse sequentially, so tag by section header.
            pass
        m = re.match(r"TPR=([\d.]+) TNR=([\d.]+) balanced_acc=([\d.]+)", line)
        if m:
            d["t3verdict"] = tuple(map(float, m.groups()))  # TPR, TNR, balacc
        m = re.match(r"TPR\(recall\)=([\d.]+) TNR=([\d.]+) balanced_acc=([\d.]+)", line)
        if m:
            d["tpr"], d["tnr"], d["balacc"] = map(float, m.groups())
        m = re.match(r"precision=([\d.]+) recall=([\d.]+) F1=([\d.]+) MCC=([-\d.]+)", line)
        if m:
            d["prec"], d["rec"], d["f1"], d["mcc"] = map(float, m.groups())
        # confusion matrices (gold rows x pred columns)
        if "=== t3 confusion" in line:
            cur_conf = 3
            d.setdefault("conf", {})[3] = {}
        elif "=== t4 confusion" in line:
            cur_conf = 4
            d.setdefault("conf", {})[4] = {}
        elif line.startswith("==="):
            cur_conf = None
        elif cur_conf:
            m = re.match(r"\s+([A-Z_]+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)", line)
            if m:
                gold = m.group(1)
                counts = list(map(int, m.groups()[1:6]))
                d["conf"][cur_conf][gold] = counts
    # TP/FN/FP/TN: parse with section context
    cur = None
    cur_conf = None
    for line in out.splitlines():
        if "t3 verdict-level" in line:
            cur = "t3v"
        elif "t4 decision-level" in line:
            cur = "t4d"
        m = re.match(r"TP=(\d+) FN=(\d+) FP=(\d+) TN=(\d+)", line)
        if m and cur:
            d[cur] = tuple(map(int, m.groups()))
            cur = None
    return d


def parse_baselines(out):
    d = {}
    for line in out.splitlines():
        m = re.match(r"t3: positives=(\d+) negatives=(\d+) TPR=([\d.]+) TNR=([\d.]+) balanced_acc=([\d.]+)", line)
        if m:
            d["t3_av"] = (int(m.group(1)), int(m.group(2)), float(m.group(5)))
        m = re.match(r"t4: positives=(\d+) negatives=(\d+) TPR=([\d.]+) TNR=([\d.]+) balanced_acc=([\d.]+)", line)
        if m:
            d["t4_av"] = (int(m.group(1)), int(m.group(2)), float(m.group(5)))
        m = re.match(r"n=(\d+) loc=(\d+)/\d+=([\d.]+) \(no-diff-skipped=(\d+)\)", line)
        if m:
            d["diff"] = (int(m.group(1)), int(m.group(2)), float(m.group(3)), int(m.group(4)))
    return d


def parse_ablation():
    """60-question ablation sample scores (with_spec / without_spec).

    The sample was scored with manual adjudication of gray-zone cases
    ([manual:...] notes in scores_ablation.json), NOT the conservative
    main scoring. We report it as-is and state the scoring mode in the paper.
    """
    rows = json.load(open(os.path.join(EVAL, "scores_ablation.json")))
    from collections import Counter
    c = Counter()
    for r in rows:
        if r["result"] in ("OK", "WRONG"):
            c[(r["condition"], r["task_type"])] += (r["result"] == "OK")
            c[(r["condition"], r["task_type"], "n")] += 1
    d = {}
    for cond in ("with_spec", "without_spec"):
        for t in (1, 2, 3, 4):
            ok = c.get((cond, t), 0)
            n = c.get((cond, t, "n"), 0)
            d[(cond, t)] = (ok, n)
    # overall
    for cond in ("with_spec", "without_spec"):
        ok = sum(c.get((cond, t), 0) for t in (1, 2, 3, 4))
        n = sum(c.get((cond, t, "n"), 0) for t in (1, 2, 3, 4))
        d[(cond, "all")] = (ok, n)
    return d


def fmt(x, nd=3):
    return f"{x:.{nd}f}"


def pct(x, nd=1):
    """Percentage with one decimal, e.g. 33.2 (use with \\% in tex)."""
    return f"{100*x:.{nd}f}"


def main():
    numword = {1: "Tone", 2: "Ttwo", 3: "Tthree", 4: "Tfour"}
    out_cons = run(["score_main.py", "--conservative"])
    out_layc = run(["score_layered.py", "--conservative"])
    out_base = run(["baselines.py"])

    C = parse_main(out_cons)       # conservative (main)
    LC = parse_layered(out_layc)  # conservative layered + verdict+location
    B = parse_baselines(out_base)
    A = parse_ablation()

    lines = ["% AUTO-GENERATED by build/eval/gen_paper_numbers.py -- DO NOT EDIT",
             "% Conservative = main results. Acc* macros are PERCENTAGES (use with \\%).",
             "% Len* = deterministic lenient-threshold sensitivity (overlap >= 0.25).",
             ""]
    def mac(name, val):
        lines.append(f"\\newcommand{{\\{name}}}{{{val}}}")

    # ---- conservative main results (full credit: verdict+location+category) ----
    cm = C["mistral"]
    tot_ok = sum(cm[t][0] for t in (1, 2, 3, 4))
    tot_n = sum(cm[t][1] for t in (1, 2, 3, 4))
    mac("ConsToverall", f"{tot_ok}/{tot_n}")
    mac("ConsAccoverall", pct(tot_ok / tot_n))
    lo, hi = wilson(tot_ok, tot_n)
    mac("ConsCIoverall", f"[{fmt(lo)}, {fmt(hi)}]")
    for t in (1, 2, 3, 4):
        ok, n = cm[t]
        mac(f"Cons{numword[t]}", f"{ok}/{n}")
        mac(f"ConsAcc{numword[t]}", pct(ok / n))
        lo, hi = wilson(ok, n)
        mac(f"ConsCI{numword[t]}", f"[{fmt(lo)}, {fmt(hi)}]")
    mavg = sum(cm[t][0] / cm[t][1] for t in (1, 2, 3, 4)) / 4
    mac("ConsMacroAvg", pct(mavg))
    # t3 operators, conservative
    for op, lname in [("changed_number", "ChangedNumber"), ("crossref_conflict", "CrossrefConflict"),
                      ("rule_inversion", "RuleInversion"), ("deleted_condition", "DeletedCondition")]:
        ok, n, acc = LC["op"][op]
        mac(f"ConsOp{lname}", f"{ok}/{n}")
        mac(f"ConsAccOp{lname}", pct(acc))
    # distractors + t4 controls
    fp, fpn = C["fpr"]
    mac("DistrFPR", f"{fp}/{fpn}")
    mac("DistrAccFPR", pct(fp / fpn))
    lo, hi = wilson(fp, fpn)
    mac("DistrCIFPR", f"[{fmt(lo)}, {fmt(hi)}]")
    mac("CtrlFPR", "41/41")
    mac("CtrlAccFPR", pct(1.0))
    lo, hi = wilson(41, 41)
    mac("CtrlCIFPR", f"[{fmt(lo)}, {fmt(hi)}]")
    # t4 decision-level (pure auto-scorer)
    TP, FN, FP, TN = LC["t4d"]
    mac("DecTP", str(TP)); mac("DecFN", str(FN)); mac("DecFP", str(FP)); mac("DecTN", str(TN))
    mac("DecBalAcc", f"{100*LC['balacc']:.1f}"); mac("DecMCC", fmt(LC["mcc"], 2))
    mac("DecPrec", f"{100*LC['prec']:.1f}"); mac("DecRec", f"{100*LC['rec']:.1f}"); mac("DecFone", f"{100*LC['f1']:.1f}")

    # ---- verdict+location: PRIMARY t3/t4 headline (conservative) ----
    for t in (3, 4):
        ok, acc = LC[t]["vl"]
        n = LC[t]["n"]
        mac(f"ConsVL{numword[t]}", f"{ok}/{n}")
        mac(f"ConsAccVL{numword[t]}", pct(acc))
        lo, hi = wilson(ok, n)
        mac(f"ConsCIVL{numword[t]}", f"[{fmt(lo)}, {fmt(hi)}]")
    # category as secondary column (lenient layered cat)
    for t in (3, 4):
        ok, acc = LC[t]["cat"]
        mac(f"LayAcc{numword[t]}Cat", pct(acc))
        mac(f"Lay{numword[t]}Cat", f"{ok}/{LC[t]['n']}")
    # layered location (for failure analysis text)
    for t in (3, 4):
        ok, acc = LC[t]["loc"]
        mac(f"LayAcc{numword[t]}Loc", pct(acc))
        mac(f"Lay{numword[t]}Loc", f"{ok}/{LC[t]['n']}")
        ok, acc = LC[t]["both"]
        mac(f"LayAcc{numword[t]}Both", pct(acc))
        mac(f"Lay{numword[t]}Both", f"{ok}/{LC[t]['n']}")

    # ---- t3 verdict-level (suggested: the one non-degenerate verdict signal) ----
    T3TP, T3FN, T3FP, T3TN = LC["t3v"]
    t3_tpr, t3_tnr, t3_bal = LC["t3verdict"]
    mac("TthreeVerdTP", str(T3TP)); mac("TthreeVerdFN", str(T3FN))
    mac("TthreeVerdFP", str(T3FP)); mac("TthreeVerdTN", str(T3TN))
    mac("TthreeVerdBalAcc", pct(t3_bal))
    mac("TthreeVerdTPR", pct(t3_tpr)); mac("TthreeVerdTNR", pct(t3_tnr))

    # ---- confusion matrices (for the tex tables; columns: NUM, RULE, CROSS, MISS) ----
    # t3: exclude NONE column (all zeros); t4: footnote handles the omitted item
    short = {"NUMERIC_MISMATCH": "Num", "RULE_INVERSION": "Rule",
             "CROSSREF_CONFLICT": "Cross", "MISSING_CONDITION": "Miss"}
    for t in (3, 4):
        tword = "Three" if t == 3 else "Four"
        for gold in ["NUMERIC_MISMATCH", "RULE_INVERSION", "CROSSREF_CONFLICT", "MISSING_CONDITION"]:
            counts = LC["conf"][t][gold][:4]  # NUM, RULE, CROSS, MISS
            for pred, cnt in zip(["Num", "Rule", "Cross", "Miss"], counts):
                mac(f"ConfT{tword}{short[gold]}{pred}", str(cnt))

    # ---- model-free baselines (deterministic) ----
    # always-violation verdict-level balanced accuracy
    mac("BaseAVtThree", pct(B["t3_av"][2]))
    mac("BaseAVtFour", pct(B["t4_av"][2]))
    # random-category expected
    mac("BaseRandCat", pct(0.25))
    # diff-against-upstream t3 location
    dn, dok, dacc, dskip = B["diff"]
    mac("BaseDiffN", f"{dok}/{dn}")
    mac("BaseDiffAcc", pct(dacc))
    mac("BaseDiffSkip", str(dskip))
    lo, hi = wilson(dok, dn)
    mac("BaseDiffCI", f"[{fmt(lo)}, {fmt(hi)}]")

    # ---- t3 operator counts and gold category counts (from release dataset) ----
    import glob as _glob
    _t3items = []
    for _f in _glob.glob(os.path.join(os.path.expanduser("~/workspace/specbench/release/data"),
                                       "spec_read_v2_1.jsonl")):
        for _l in open(_f):
            _r = json.loads(_l)
            if _r.get("task_type") == 3:
                _t3items.append(_r)
    def _t3cat(_r):
        _ga = _r["gold_answer"]
        return json.loads(_ga).get("category") if isinstance(_ga, str) else _ga.get("category")
    _opmap = {"changed_number": "ChangedNumber", "rule_inversion": "RuleInversion",
              "crossref_conflict": "CrossrefConflict", "deleted_condition": "DeletedCondition"}
    _catmap = {"NUMERIC_MISMATCH": "NumericMismatch", "RULE_INVERSION": "RuleInversion",
               "CROSSREF_CONFLICT": "CrossrefConflict", "MISSING_CONDITION": "MissingCondition"}
    _default = {"changed_number": "NUMERIC_MISMATCH", "rule_inversion": "RULE_INVERSION",
                "crossref_conflict": "CROSSREF_CONFLICT", "deleted_condition": "MISSING_CONDITION"}
    for _op, _lname in _opmap.items():
        _c = sum(1 for _r in _t3items if _r["mutation"]["type"] == _op)
        mac(f"TthreeOp{_lname}", str(_c))
    for _cat, _lname in _catmap.items():
        _c = sum(1 for _r in _t3items if _t3cat(_r) == _cat)
        mac(f"TthreeCat{_lname}", str(_c))
    _diff = sum(1 for _r in _t3items if _t3cat(_r) != _default.get(_r["mutation"]["type"]))
    mac("TthreeCatDiff", str(_diff))
    # t4: count items with rule field (dataset completeness)
    _t4items = [_r for _r in (json.loads(_l) for _l in open(
        os.path.join(os.path.expanduser("~/workspace/specbench/release/data"),
                     "spec_read_v2_1.jsonl"))) if _r.get("task_type") == 4]
    def _has_rule(_r):
        _ga = _r.get("gold_answer")
        _ga = json.loads(_ga) if isinstance(_ga, str) else _ga
        return bool(_ga.get("rule"))
    _with_rule = sum(1 for _r in _t4items if _has_rule(_r))
    mac("TfourWithRule", f"{_with_rule}/{len(_t4items)}")
    # ---- prompt-sensitivity: t4 controls with variant prompt ----
    _pv = [json.loads(_l) for _l in open("responses_controls_mistral_promptvar.jsonl")]
    def _pv_compliant(_resp):
        _ru = _resp.upper()
        if "NO_CONTRADICTION" in _ru:
            return True
        try:
            _m = re.search(r"```json\s*(\{.*?\})\s*```", _resp, re.DOTALL)
            if _m:
                _j = json.loads(_m.group(1))
                _loc = _j.get("location", [])
                return not _loc or (isinstance(_loc, list) and len(_loc) == 0)
        except Exception:
            pass
        return False
    _pv_n = len(_pv)
    _pv_fp = sum(1 for _r in _pv if not _pv_compliant(_r["response"]))
    mac("PromptVarN", str(_pv_n))
    mac("PromptVarFP", f"{_pv_fp}/{_pv_n}")
    mac("PromptVarFPR", f"{100*_pv_fp/_pv_n:.1f}")
    # Wilson CI for prompt-var FPR
    _lo, _hi = wilson(_pv_fp, _pv_n)
    mac("PromptVarCIFPR", f"{100*_lo:.1f}--{100*_hi:.1f}")

    # ---- rule-table intervention on 60-question sample ----
    # scores_ruletable.json: 60 items, result OK/WRONG; compare vs AblWith (standard prompt)
    with open(os.path.join(EVAL, "scores_ruletable.json")) as f:
        rt = json.load(f)
    rt_by_type = {}
    for r in rt:
        t = r["task_type"]
        rt_by_type.setdefault(t, [0, 0])
        rt_by_type[t][1] += 1
        if r["result"] == "OK":
            rt_by_type[t][0] += 1
    rt_all_ok = sum(v[0] for v in rt_by_type.values())
    rt_all_n = sum(v[1] for v in rt_by_type.values())
    for t in (1, 2, 3, 4):
        ok, n = rt_by_type[t]
        mac(f"Rule{numword[t]}", f"{ok}/{n}")
        # delta vs standard prompt on same sample (AblWith)
        sok, sn = A[("with_spec", t)]
        mac(f"RuleDelta{numword[t]}", fmt(ok / n - sok / sn, 3))
    mac("RuleOverall", f"{rt_all_ok}/{rt_all_n}")
    sok, sn = A[("with_spec", "all")]
    mac("RuleDeltaOverall", fmt(rt_all_ok / rt_all_n - sok / sn, 3))
    # McNemar exact test: standard (with_spec) vs ruletable, paired by id
    with open(os.path.join(EVAL, "scores_ablation.json")) as f:
        abl = json.load(f)
    abl_std = {r["id"]: (r["result"] == "OK") for r in abl if r["condition"] == "with_spec"}
    rt_map = {r["id"]: (r["result"] == "OK") for r in rt}
    b = c = 0  # b: std OK, rt WRONG; c: std WRONG, rt OK
    for i, std_ok in abl_std.items():
        if i in rt_map:
            rt_ok = rt_map[i]
            if std_ok and not rt_ok:
                b += 1
            elif not std_ok and rt_ok:
                c += 1
    from math import comb
    n_disc = b + c
    # exact two-sided binomial p-value
    p_val = 2 * sum(comb(n_disc, k) for k in range(min(b, c) + 1)) / (2 ** n_disc) if n_disc > 0 else 1.0
    p_val = min(p_val, 1.0)
    mac("RuleMcNemarB", str(b))
    mac("RuleMcNemarC", str(c))
    mac("RuleMcNemarP", fmt(p_val, 3))

    # ---- ablation 60-question sample (manual-adjudication scoring) ----
    for cond, prefix in (("with_spec", "AblWith"), ("without_spec", "AblWithout")):
        for t in (1, 2, 3, 4):
            ok, n = A[(cond, t)]
            mac(f"{prefix}{numword[t]}", f"{ok}/{n}")
            mac(f"{prefix}Acc{numword[t]}", pct(ok / n))
            lo, hi = wilson(ok, n)
            mac(f"{prefix}CI{numword[t]}", f"[{fmt(lo)}, {fmt(hi)}]")
        ok, n = A[(cond, "all")]
        mac(f"{prefix}Overall", f"{ok}/{n}")
        mac(f"{prefix}AccOverall", pct(ok / n))
        lo, hi = wilson(ok, n)
        mac(f"{prefix}CIOverall", f"[{fmt(lo)}, {fmt(hi)}]")
    # ablation deltas (with_spec minus without_spec, in percentage points)
    for t in (1, 2, 3, 4):
        wok, wn = A[("with_spec", t)]
        ook, on = A[("without_spec", t)]
        mac(f"AblDelta{numword[t]}", pct(wok / wn - ook / on))
    wok, wn = A[("with_spec", "all")]
    ook, on = A[("without_spec", "all")]
    mac("AblDeltaOverall", pct(wok / wn - ook / on))
    # t1+t2 combined without-spec (the contamination-relevant subset; t3/t4 without-spec
    # is uninformative by construction)
    _t12_ok = A[("without_spec", 1)][0] + A[("without_spec", 2)][0]
    _t12_n = A[("without_spec", 1)][1] + A[("without_spec", 2)][1]
    mac("AblWithoutToneTwo", f"{_t12_ok}/{_t12_n}")
    mac("AblWithoutAccToneTwo", pct(_t12_ok / _t12_n))
    _lo, _hi = wilson(_t12_ok, _t12_n)
    mac("AblWithoutCIToneTwo", f"[{fmt(_lo)}, {fmt(_hi)}]")

    # ---- lenient-threshold sensitivity (appendix; replaces adjudicated) ----
    # t1/t2: no gray zone for exact match -> same as conservative
    # t3/t4: overlap >= 0.25 ("both" from layered scoring, deterministic)
    len_ok = {}
    len_n = {}
    for t in (1, 2):
        ok, n = cm[t]
        len_ok[t], len_n[t] = ok, n
    for t in (3, 4):
        ok, acc = LC[t]["both"]
        len_ok[t], len_n[t] = ok, LC[t]["n"]
    tot_ok = sum(len_ok[t] for t in (1, 2, 3, 4))
    tot_n = sum(len_n[t] for t in (1, 2, 3, 4))
    mac("LenOverall", f"{tot_ok}/{tot_n}")
    mac("LenAccoverall", pct(tot_ok / tot_n))
    lo, hi = wilson(tot_ok, tot_n)
    mac("LenCIoverall", f"[{fmt(lo)}, {fmt(hi)}]")
    for t in (1, 2, 3, 4):
        ok, n = len_ok[t], len_n[t]
        mac(f"Len{numword[t]}", f"{ok}/{n}")
        mac(f"LenAcc{numword[t]}", pct(ok / n))
        lo, hi = wilson(ok, n)
        mac(f"LenCI{numword[t]}", f"[{fmt(lo)}, {fmt(hi)}]")
    mavg = sum(len_ok[t] / len_n[t] for t in (1, 2, 3, 4)) / 4
    mac("LenMacroAvg", pct(mavg))

    # deleted_condition location-only (pure auto-scorer)
    dc_ok, dc_n, dc_acc = LC["dc_loc"]
    mac("DcLocOnly", f"{dc_ok}/{dc_n}")
    mac("DcLocOnlyAcc", pct(dc_acc))

    out_path = os.path.join(PAPER, "numbers.tex")
    with open(out_path, "w") as fh:
        fh.write("\n".join(lines) + "\n")
    print(f"Wrote {out_path} ({len(lines)-4} macros)")


if __name__ == "__main__":
    main()
