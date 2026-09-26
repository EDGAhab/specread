# SpecRead v2.1 — Evaluation Protocol

## Eval sets
- `data/spec_read_v2_1.jsonl` — 385 questions
  (t1 x 58, t2 x 58, t3 x 171, t4 x 98; 10 OpenTitan IPs)
- `data/distractors_v2.jsonl` — 41 distractor items (t3 false-positive control;
  reported separately, never counted in accuracy)
- `data/eval_sample_60.jsonl` — stratified ablation sample
  (t3 x 20, t4 x 20, t1 x 10, t2 x 10)

## Prompting (identical across models, temperature 0)
- One question per call. Format: spec excerpt (+ rtl excerpt for t4)
  + question + required answer format.
- **t3 verdict-commit tweak:** the t3 prompt instructs the model to always
  commit to a verdict — either identify the contradiction (location +
  category) or state `NO_CONTRADICTION`. It must not refuse the premise
  or ask for clarification.

## Scoring rule
- `exact_value`: correct iff normalized response == normalized gold
  (strip, collapse internal whitespace, case-insensitive). Strict: no
  prefix stripping, no quote stripping, no token-substring leniency.
- `multiple_choice`: correct iff the chosen option letter matches gold.
- `location+category`: correct iff (a) category equals the gold SCREAMING
  label (`NUMERIC_MISMATCH`, `RULE_INVERSION`, `CROSSREF_CONFLICT`,
  `MISSING_CONDITION`) AND (b) the cited location identifies the same
  contradiction as gold (same register/field/statement, judged by
  distinctive-token overlap: >= 0.45 correct, < 0.25 wrong, in-between ->
  GRAY ZONE). Gray-zone cases go to logged human adjudication
  (`eval/records/adjudications.json`), never silent guessing.
- Distractors: correct iff verdict == "consistent".

## Experiments
1. **Main eval** (`eval/run_main.py`): full 385 questions + 41 distractors,
   one call per question per model, temperature 0. Prompts are built once per
   question id and shared across models; `prompt_sha256` is stored per call
   to prove prompt identity. Score with `eval/score_main.py`.
2. **Contamination ablation** (`eval/scripts/run_ablation.py`): 60-question
   sample x {with-spec, without-spec}. Without-spec = question + answer
   format only, no excerpt. A correct without-spec answer implies
   memorization or a leaky question (flagged for rewrite).
3. **Rule-table baseline** (`eval/scripts/run_ruletable.py`): 60-question
   sample, two-step prompt: first extract the excerpt into a numbered
   structured rule table, then answer using only the table.
4. **Failure analysis** (`eval/scripts/analyze_results.py`): by task type x
   mutation type; characteristic failure modes quoted.

## Running

Set your API keys (bring your own keys; nothing is stored in this repo):

```bash
export GEMINI_API_KEY=...    # for call_gemini (generativelanguage.googleapis.com)
export MISTRAL_API_KEY=...   # for call_mistral (api.mistral.ai)
cd eval
python3 run_main.py          # writes eval/records/responses_main_<model>_v2.jsonl
python3 score_main.py        # writes scores_main.csv, ambiguous.jsonl, agg.json
```

Environment knobs in `run_main.py`: `MODELS_ONLY=gemini|mistral`,
`TASK_TYPES=4`, `ITEM_IDS=aes-t2-001`, `APPEND=1` (targeted re-runs).

Be polite on free tiers: the scripts pace calls (gemini ~15s, mistral ~2s)
with exponential backoff on 429. Never hammer shared endpoints.

## v2.1 dataset notes
- v2 cleaned v1: all 98 t4 `rtl_excerpt` fields regenerated from the actually
  simulated mutants and re-verified `RESULT: DIFFER`; one duplicate distractor
  removed; 10 pilot t4 gold labels converted to canonical spec-side categories.
  See `data/v2_change_log.json`.
- v2.1 repaired 15 t2 multiple-choice prompts that omitted their option lists
  while asking for a letter answer (options A-D appended, gold set to the
  letter). The v2 file is untouched; v2.1 is the released dataset.

## Design decisions (disclosed)
- **t4 marked-diff framing:** t4 `rtl_excerpt` fields carry literal
  `// <-- MUTATED` markers on changed lines. This is intentional: t4 is
  framed as diff review ("here is a change — does it violate the spec?"),
  not unmarked audit. Unmarked audit is future work.
- **t4 contains only violations, no consistent unmutated-RTL controls.**
  A verdict-only "always violation" strategy would therefore succeed on the
  verdict dimension; full scoring also requires category + overlapping
  location, which that strategy cannot fake.
- **No complete candidate/discard ledger exists for t4** (hand-built; 98
  retained, all `DIFFER`-verified). Per-IP review notes record 26 discarded
  candidates, but that is not a complete denominator.
