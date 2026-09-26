# SpecRead Question Review Rubric (full build)

Every question must pass all 7 checks before it counts toward the total.
The reviewer re-reads the excerpt + question + gold answer independently and
must reach the same gold answer. Disagreements → rewrite or discard.

## The 7 checks

1. **Gold unambiguous.** Exactly one correct answer exists under the declared
   `answer_format`. No second defensible reading. For `multiple_choice`, all
   distractors are clearly wrong to someone who understood the excerpt.
2. **Excerpt self-contained.** t1/t2/t3 answerable from `spec_excerpt` alone;
   t4 from `spec_excerpt` + `rtl_excerpt`. No outside knowledge required
   (beyond basic digital-design literacy).
3. **Mutation realistic.** The injected defect must resemble a plausible real
   bug: a doc typo that could ship, a copy-paste error between similar
   registers, an RTL off-by-one a tired engineer could write. No cartoonish
   or self-announcing mutations; the mutated text must not contain meta-hints.
4. **Difficulty honest.**
   - easy: answer stated directly in one place in the excerpt.
   - medium: requires combining 2+ statements, or careful reading of a
     table / field description / conditional rule.
   - hard: multi-step inference, cross-referencing distant sections, or a
     subtle semantic distinction (e.g. level vs edge, "may" vs "shall").
5. **No leakage.** t3 mutated excerpts read naturally; t3 distractor items
   (unmutated) are genuinely self-consistent — verified by the reviewer, not
   assumed.
6. **Sim proof (t4 only).** `pilot/sim`-style directory with orig/mut/testbench
   and a log showing `RESULT: DIFFER`. Non-observable mutations are discarded,
   never faked.
7. **Schema valid.** All keys present; `source{repo,file,commit,license}` and
   `mutation{type,original,mutated,location}` filled; `verification` gives the
   exact sim commands for t4.

## Canonical conventions (resolved 2026-09-25, follow pilot)

- **t3/t4 gold category labels** are SCREAMING names: `NUMERIC_MISMATCH`,
  `RULE_INVERSION`, `CROSSREF_CONFLICT`, `MISSING_CONDITION`
  (deleted_condition maps to `MISSING_CONDITION`). These are the values used in
  `gold_answer` for `location+category` format, matching the pilot.
- **Distractor items** use `answer_format: "verdict+explanation"` with
  `gold_answer` a JSON object `{"verdict": "consistent", "explanation": "..."}`,
  matching `pilot/questions_t3_distractors.jsonl`. Distractors live in
  separate `distractors_<ip>.jsonl` files, never counted in quotas.

## Per-IP quotas (target ~40–60 questions per IP)

- t3 (mutated-spec contradiction): ~35%
- t4 (spec–RTL consistency): ~35%
- t1 (retrieval baseline): ~15%
- t2 (cross-section baseline): ~15%
- Plus ~5 t3 distractor items per IP (unmutated-but-suspicious; reported
  separately, not counted in the quota).

## Mutation-type balance (track per IP, keep roughly even)

- Spec: changed_number / rule_inversion / crossref_conflict / deleted_condition
- RTL: wrong_reset_value / off_by_one / inverted_enable /
  missing_fsm_transition / field_offset_error
