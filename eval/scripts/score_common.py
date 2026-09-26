#!/usr/bin/env python3
"""Protocol-exact scoring for SpecRead v1 phase-3 experiments.

EVAL_PROTOCOL.md scoring rule:
- exact_value: correct iff normalized(response) == normalized(gold);
  normalize = strip + collapse internal whitespace + case-insensitive.
  Near-miss policy: qualifier-dropping is WRONG (strict).
- multiple_choice: correct iff chosen option letter/label matches gold.
- location+category: correct iff (a) category == gold SCREAMING label AND
  (b) cited location identifies the same contradiction (quote/token overlap).
  Gray zone (overlap 0.25-0.45) -> adjudications file, never silent guessing.
"""
import json, os, re
from collections import defaultdict

T3_CATS = ["NUMERIC_MISMATCH", "RULE_INVERSION", "CROSSREF_CONFLICT", "MISSING_CONDITION"]
T4_CATS = ["NUMERIC_MISMATCH", "RULE_INVERSION", "CROSSREF_CONFLICT", "MISSING_CONDITION"]
ALL_CATS = T3_CATS

STOP = set("""the a an and or of to in on for with is are was were be been by as at from
that this these those it its into out over under not no vs via per than then so such
which who what when where how why while both each any all two section register bit
field value reset default spec excerpt rtl line lines statement statements rule
equation example note code theory operation configuration following below above
documented contradict contradiction inconsistent inconsistency""".split())


def gold_obj(q):
    g = q["gold_answer"]
    if isinstance(g, str) and g.strip().startswith("{"):
        return json.loads(g)
    return g


def norm_exact(s):
    return re.sub(r"\s+", " ", s.strip()).lower()


def score_exact(resp, gold):
    r, g = norm_exact(resp), norm_exact(gold)
    if not r:
        return False, "empty"
    return (r == g), ("exact" if r == g else f"mismatch(resp={r[:70]!r},gold={g[:70]!r})")


def score_exact_lenient(resp, gold):
    """Sensitivity variant (NOT the official score): strips code formatting and
    accepts the gold as a standalone token inside a short response."""
    r = norm_exact(resp).strip("`\"'").rstrip(".").strip()
    r = re.sub(r"^(the\s+answer\s+is|answer\s*:|answer\s+is)\s*", "", r)
    g = norm_exact(gold).strip("`\"'")
    if not r:
        return False, "empty"
    if r == g:
        return True, "exact"
    if re.search(r"(?<![\w])" + re.escape(g) + r"(?![\w])", r) and len(r) <= len(g) + 12:
        return True, "token-substring"
    return False, f"mismatch(resp={r[:70]!r},gold={g[:70]!r})"


def score_mc(resp, gold):
    m = re.search(r"\b([A-D])\b", resp.upper())
    gm = re.search(r"\b([A-D])\b", str(gold).upper())
    if not m:
        return False, "no-letter"
    if not gm:
        return False, f"no-letter-in-gold({str(gold)[:30]!r})"
    return (m.group(1) == gm.group(1)), f"letter={m.group(1)} gold={gm.group(1)}"


def distinctive_tokens(text):
    toks = re.findall(r"[a-z0-9_]+", text.lower())
    return [t for t in toks if len(t) > 3 and t not in STOP]


def score_loccat(resp, q):
    g = gold_obj(q)
    gold_cat = str(g["category"]).upper()
    ru = resp.upper()
    has_gold = gold_cat in ru
    others = [c for c in ALL_CATS if c != gold_cat and c in ru]
    cat_ok = has_gold and not others
    cat_note = f"cat_gold={has_gold} others={others}"
    loc_text = g.get("location") or (g.get("rule", "") + " " + g.get("rtl_location", ""))
    gtoks = distinctive_tokens(loc_text)
    rtoks = set(distinctive_tokens(resp))
    if not gtoks:
        loc_frac = 1.0
        loc_note = "no-gold-tokens"
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
    return correct, amb, f"{cat_note} {loc_note}"


def score_response(resp, q):
    """Returns (status, note): status in OK/WRONG/AMBIGUOUS/ERROR."""
    if not resp or not resp.strip():
        return "ERROR", "empty/missing response"
    af = q["answer_format"]
    if af == "exact_value":
        ok, note = score_exact(resp, gold_obj(q))
        return ("OK" if ok else "WRONG"), note
    if af == "multiple_choice":
        ok, note = score_mc(resp, gold_obj(q))
        return ("OK" if ok else "WRONG"), note
    if af == "location+category":
        ok, amb, note = score_loccat(resp, q)
        return ("AMBIGUOUS" if amb else ("OK" if ok else "WRONG")), note
    raise ValueError(f"unknown answer_format {af}")


def load_questions():
    qs = {}
    base = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "data")
    # SAMPLE_FILE env override for v2 re-runs (eval_sample_60_v2.jsonl)
    sample_fn = os.environ.get("SAMPLE_FILE", "eval_sample_60.jsonl")
    for fn in [sample_fn]:
        with open(os.path.join(base, fn)) as fh:
            for line in fh:
                q = json.loads(line)
                qs[q["id"]] = q
    return qs
