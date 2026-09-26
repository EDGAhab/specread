#!/usr/bin/env python3
"""Score SpecRead v2.1 main eval responses.

Pre-registered scoring rule (EVAL_PROTOCOL.md):
- exact_value: correct iff normalized response == normalized gold
  (strip, collapse internal whitespace, case-insensitive). STRICT: no prefix
  stripping, no quote stripping, no token-substring leniency.
- multiple_choice: correct iff the chosen option letter matches gold.
- location+category: correct iff (a) category == gold SCREAMING label AND
  (b) cited location identifies the same contradiction as gold
  (same register/field/statement, judged by distinctive-token overlap:
  >=0.45 ok, <0.25 wrong, in-between -> GRAY ZONE, human-adjudicated in
  adjudications.json). A t3 NO_CONTRADICTION response on a real question is
  a miss -> WRONG.
- distractors (verdict+explanation): correct iff verdict == "consistent".

Outputs: scores_main.csv, ambiguous.jsonl (to be adjudicated),
adjudications.json (after review), scores_main_report input.
"""
import json, os, re, csv
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")
RECORDS = os.path.join(ROOT, "eval", "records")
RESP = {"gemini": os.path.join(RECORDS, "responses_main_gemini_v2.jsonl"),
        "mistral": os.path.join(RECORDS, "responses_main_mistral_v2.jsonl")}

T3_CATS = ["NUMERIC_MISMATCH", "RULE_INVERSION", "CROSSREF_CONFLICT", "MISSING_CONDITION"]
T4_CATS = ["NUMERIC_MISMATCH", "RULE_INVERSION", "CROSSREF_CONFLICT", "MISSING_CONDITION"]
ALL_CATS = T3_CATS

STOP = set("""the a an and or of to in on for with is are was were be been by as at from
that this these those it its into out over under not no vs via per than then so such
which who what when where how why while both each any all two section register bit
field value reset default spec excerpt rtl line lines statement statements rule
equation example note code theory operation configuration following below above
documented""".split())


def load_questions():
    qs = {}
    for fn in ["spec_read_v2_1.jsonl", "distractors_v2.jsonl"]:
        with open(os.path.join(DATA, fn)) as fh:
            for line in fh:
                q = json.loads(line)
                qs[q["id"]] = q
    return qs


def norm_exact(s):
    s = s.strip().lower()
    s = re.sub(r'\s+', ' ', s)
    return s


def score_exact(resp, gold):
    r, g = norm_exact(resp), norm_exact(gold)
    if not r:
        return False, "empty"
    if r == g:
        return True, "exact"
    return False, f"mismatch(resp={r[:60]!r} gold={g[:60]!r})"


def score_mc(resp, gold):
    m = re.search(r'\b([A-D])\b', resp.upper())
    if not m:
        return False, "no-letter"
    return (m.group(1) == gold.strip().upper()), f"letter={m.group(1)}"


def distinctive_tokens(text):
    toks = re.findall(r'[a-z0-9_]+', text.lower())
    return [t for t in toks if len(t) > 3 and t not in STOP]


def extract_json_loccat(resp):
    """Return (location_text, category) if response has a location+category JSON.

    Uses raw_decode from the first '{' so braces inside quoted strings don't
    truncate the parse (the old regex stopped at the first '}' anywhere).
    """
    start = resp.find('{')
    if start < 0:
        return None, None
    try:
        j, _ = json.JSONDecoder().raw_decode(resp[start:])
    except Exception:
        return None, None
    if not isinstance(j, dict):
        return None, None
    loc = j.get("location") or j.get("loc") or ""
    cat = (j.get("category") or j.get("cat") or "").upper()
    if isinstance(loc, list):
        loc = " ".join(str(x) for x in loc)
    elif isinstance(loc, dict):
        loc = " ".join(str(v) for v in loc.values())
    return str(loc), (cat or None)


def gold_str(gold):
    return gold if isinstance(gold, str) else json.dumps(gold, ensure_ascii=False)


def score_loccat(resp, gold):
    # gold may be a JSON string or an already-parsed dict (37 t4 golds)
    g = json.loads(gold) if isinstance(gold, str) else gold
    gold_cat = g["category"].upper()
    ru = resp.upper()
    loc, cat = extract_json_loccat(resp)
    if cat and cat not in ALL_CATS:
        cat = None  # not a real category token
    if cat is None and "NO_CONTRADICTION" in ru:
        return False, False, "miss: NO_CONTRADICTION"
    has_gold = gold_cat in ru
    others = [c for c in ALL_CATS if c != gold_cat and c in ru]
    cat_ok = bool(cat == gold_cat) and not others
    if cat is None:
        # fall back to raw token presence (pilot-compatible)
        cat_ok = has_gold and not others
    cat_note = f"cat={cat} cat_gold={has_gold} others={others}"
    loc_text = g.get("location") or (g.get("rule", "") + " " + g.get("rtl_location", ""))
    gtoks = distinctive_tokens(loc_text)
    rtoks = set(distinctive_tokens(resp))
    if not gtoks:
        loc_frac, loc_note = 1.0, "no-gold-tokens"
    else:
        hit = sum(1 for t in gtoks if t in rtoks)
        loc_frac = hit / len(gtoks)
        loc_note = f"tok_overlap={hit}/{len(gtoks)}"
    if loc_frac >= 0.45:
        loc_ok, amb = True, False
    elif loc_frac < 0.25:
        loc_ok, amb = False, False
    else:
        loc_ok, amb = False, True
    correct = bool(cat_ok and loc_ok and not amb)
    note = cat_note + " " + loc_note
    return correct, amb, note


NEG = re.compile(r'\b(no|not|without|isn\'t|aren\'t|doesn\'t|don\'t|lack of|free of)\b.{0,25}\b(contradiction|inconsistenc|violation|error|bug|mismatch)\b',
                 re.I)


def score_distractor(resp):
    ru = resp.upper()
    m = re.search(r'"verdict"\s*:\s*"([^"]+)"', resp, re.I)
    verdict = m.group(1).lower() if m else None
    cats_found = [c for c in T3_CATS if c in ru]
    if verdict == "consistent" or ("consistent" in resp.lower() and not cats_found
                                   and not re.search(r'\bcontradiction\b', resp, re.I)):
        return "TN", "verdict=consistent"
    if cats_found:
        return "FP", f"named category {cats_found}"
    if re.search(r'\bcontradiction\b', resp, re.I) and not NEG.search(resp):
        return "FP", "affirmative contradiction claim"
    if re.search(r'\b(violation|inconsistenc|does not match|mismatch)\b', resp, re.I) and not NEG.search(resp):
        return "FP", "affirmative inconsistency claim"
    return "AMBIGUOUS", "could not classify"


def main():
    qs = load_questions()
    adj_path = os.path.join(RECORDS, "adjudications.json")
    adjud = {}
    if os.path.exists(adj_path):
        with open(adj_path) as fh:
            adjud = json.load(fh)

    rows, ambiguous = [], []
    per = defaultdict(lambda: defaultdict(lambda: [0, 0]))   # model -> type -> [ok, n]
    perip = defaultdict(lambda: defaultdict(lambda: [0, 0]))  # model -> ip -> [ok, n]
    fp = defaultdict(lambda: [0, 0])
    sha_check = defaultdict(set)  # qid -> set of prompt sha

    for model, path in RESP.items():
        if not os.path.exists(path):
            print(f"note: {path} not found, skipping model {model!r}")
            continue
        adj_m = adjud.get(model, {})
        with open(path) as fh:
            for line in fh:
                r = json.loads(line)
                q = qs[r["id"]]
                sha_check[r["id"]].add(r["prompt_sha256"])
                af = q["answer_format"]
                resp = r.get("response", "")
                ip = "?"
                m = re.search(r'hw/ip/([^/]+)/', q["source"].get("file", ""))
                if m:
                    ip = m.group(1)
                if not resp:
                    rows.append((r["id"], model, ip, af, "ERROR", r.get("error", "")[:80]))
                    per[model][q["task_type"]][1] += 1
                    perip[model][ip][1] += 1
                    continue
                if af == "exact_value":
                    ok, note = score_exact(resp, q["gold_answer"])
                    status = "OK" if ok else "WRONG"
                    per[model][q["task_type"]][1] += 1
                    per[model][q["task_type"]][0] += ok
                    perip[model][ip][1] += 1
                    perip[model][ip][0] += ok
                    rows.append((r["id"], model, ip, af, status, note))
                elif af == "multiple_choice":
                    ok, note = score_mc(resp, q["gold_answer"])
                    status = "OK" if ok else "WRONG"
                    per[model][q["task_type"]][1] += 1
                    per[model][q["task_type"]][0] += ok
                    perip[model][ip][1] += 1
                    perip[model][ip][0] += ok
                    rows.append((r["id"], model, ip, af, status, note))
                elif af == "location+category":
                    ok, amb, note = score_loccat(resp, q["gold_answer"])
                    adj = adj_m.get(r["id"])
                    if adj:
                        ok = (adj["verdict"] == "OK")
                        note += f" [adjudicated:{adj['verdict']}]"
                        amb = False
                    if amb:
                        ambiguous.append({"id": r["id"], "model": model, "ip": ip,
                                          "task_type": q["task_type"],
                                          "note": note, "gold": gold_str(q["gold_answer"])[:800],
                                          "question": q["question"][:300],
                                          "response": resp[:1500]})
                        rows.append((r["id"], model, ip, af, "AMBIGUOUS", note))
                    else:
                        per[model][q["task_type"]][1] += 1
                        per[model][q["task_type"]][0] += ok
                        perip[model][ip][1] += 1
                        perip[model][ip][0] += ok
                        rows.append((r["id"], model, ip, af, "OK" if ok else "WRONG", note))
                elif af == "verdict+explanation":
                    cls, note = score_distractor(resp)
                    rows.append((r["id"], model, ip, af, cls, note))
                    if cls == "AMBIGUOUS":
                        ambiguous.append({"id": r["id"], "model": model, "ip": ip,
                                          "task_type": q["task_type"],
                                          "note": note, "gold": gold_str(q["gold_answer"])[:800],
                                          "question": q["question"][:300],
                                          "response": resp[:1500]})
                    else:
                        fp[model][1] += 1
                        fp[model][0] += (cls == "FP")
                else:
                    raise ValueError(af)

    with open(os.path.join(RECORDS, "scores_main.csv"), "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["question_id", "model", "ip", "answer_format", "result", "note"])
        w.writerows(rows)
    with open(os.path.join(RECORDS, "ambiguous.jsonl"), "w") as fh:
        for a in ambiguous:
            fh.write(json.dumps(a, ensure_ascii=False) + "\n")

    # prompt-identity check across models
    multi = {k: v for k, v in sha_check.items() if len(v) != 1}
    print(f"prompt sha check: {len(sha_check)} questions, "
          f"{len(multi)} with !=1 distinct sha across models")
    if multi:
        print("  BAD:", list(multi)[:5])

    print("=== per-type accuracy (OK/n) ===")
    for model in ["gemini", "mistral"]:
        tot_ok = tot_n = 0
        line = f"{model}: "
        for t in [1, 2, 3, 4]:
            ok, n = per[model][t]
            tot_ok += ok
            tot_n += n
            line += f"t{t}={ok}/{n} "
        acc = tot_ok / tot_n if tot_n else 0
        fpn, fpd = fp[model]
        fpr = fpn / fpd if fpd else 0
        print(f"{line} overall={tot_ok}/{tot_n}={acc:.3f} distractor_FPR={fpn}/{fpd}={fpr:.3f}")
    print(f"ambiguous (needs adjudication): {len(ambiguous)} -> ambiguous.jsonl")

    # stash aggregate stats for the report builder
    with open(os.path.join(RECORDS, "agg.json"), "w") as fh:
        json.dump({"per": {m: {str(t): per[m][t] for t in per[m]} for m in per},
                 "perip": {m: {ip: perip[m][ip] for ip in perip[m]} for m in perip},
                 "fp": {m: fp[m] for m in fp},
                 "rows_n": len(rows)}, fh)


if __name__ == "__main__":
    raise SystemExit(main())
