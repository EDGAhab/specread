# SpecRead

**Do LLMs understand hardware specifications, independently of their ability to write RTL?**

SpecRead is a 385-question benchmark that measures whether large language
models *comprehend* hardware design specifications. Existing hardware-AI
benchmarks (VerilogEval, RTLLM, AssertLLM, ...) score downstream artifacts:
generated RTL, assertions, testbenches. A model can fail those because it
never understood the spec, or because it understood it but cannot write
correct Verilog. SpecRead separates the two: every question is answerable
from a quoted spec excerpt alone, and every answer is auto-scorable.

## The four task types

| Type | Name | What it tests | n |
|---|---|---|---|
| 1 | Exact retrieval | Find a stated value in the spec | 58 |
| 2 | Cross-section reasoning | Combine statements from different sections | 58 |
| 3 | Mutated-spec contradiction | Detect an injected inconsistency inside the spec text | 171 |
| 4 | Spec-RTL consistency | Given a changed RTL diff, decide whether it violates the spec | 98 |

Types 3 and 4 are the scientific focus. Type-3 mutations are injected into
real spec text (changed numbers, inverted rules, conflicting cross-refs,
deleted conditions), plus 41 *distractor* items: suspicious-looking but
fully self-consistent excerpts that measure false-positive rate. Every
type-4 RTL mutation is **simulation-verified** with Icarus Verilog to change
observable behavior (`RESULT: DIFFER`); see `sim/SIM_README.md`.

## Dataset stats

- 385 questions across 10 OpenTitan IPs: uart 30, aes 50, aon_timer 25,
  hmac 35, i2c 55, kmac 45, pattgen 18, rv_timer 22, spi_device 50,
  spi_host 55
- Answer formats: `exact_value` x 94, `multiple_choice` x 22,
  `location+category` x 269 (all t3/t4)
- Difficulty mix: easy 66 / medium 246 / hard 73
- 98/98 type-4 mutations simulation-verified `DIFFER`
- 41 distractors (reported separately)
- 41 consistent-RTL controls for type-4 (`t4_controls_v2.jsonl`): unmutated RTL where the correct verdict is NO_CONTRADICTION

## Source attribution

All spec text and RTL are extracted from the open-source
[OpenTitan](https://github.com/lowRISC/opentitan) project at commit
`80b5b3213453156fe62683962664d1afd9695ec4` (Apache-2.0). Every question
records `source{repo, file, commit, license}`.

## Running the eval

```bash
export GEMINI_API_KEY=... MISTRAL_API_KEY=...
cd eval
python3 run_main.py     # full 385 + 41 distractors x model, temperature 0
python3 score_main.py   # auto-scoring per EVAL_PROTOCOL.md
```

See `eval/EVAL_PROTOCOL.md` for the full protocol (scoring rule, ablation
and rule-table experiments) and `eval/RUBRIC.md` for the question-review
rubric. `sim/` contains the 98 Icarus Verilog harnesses backing type 4.

## Results

Headline: **Ministral-3B (mistral) scores 40.0% overall** on the main set (v2.1, 154/385; t1 55.2%, t2 51.7%, t3 33.3%, t4 35.7%; 95% Wilson CI [0.352, 0.450]).

> Status: **v2.1 scores final.** The dataset was repaired (15 t2 prompts) and all model responses re-run; 88 gray-zone cases adjudicated, zero ambiguous items remain. Raw response records ship under `eval/records/` so anyone can reproduce scoring.

## Repository layout

```
specread/
  README.md            this file
  CITATION.cff         citation metadata
  LICENSE              Apache-2.0 (code: eval scripts, sim harnesses)
  data/
    spec_read_v2_1.jsonl     385 questions (released dataset)
    distractors_v2.jsonl     41 distractor items
    eval_sample_60.jsonl     60-question ablation sample
    v2_change_log.json       v2/v2.1 change history
    DATASET_LICENSE.md       dataset licensing (CC-BY-4.0)
  sim/
    SIM_README.md
    t4_cases/                98 iverilog harnesses (orig/mut/testbench/log)
    stubs/                   package stubs for standalone compilation
  eval/
    EVAL_PROTOCOL.md         evaluation protocol
    RUBRIC.md                question review rubric
    run_main.py              main eval runner (bring your own API keys)
    score_main.py            auto-scorer
    scripts/                 ablation / rule-table / analysis helpers
    records/                 raw model response records (v2.1 in progress)
```

## Licensing

- **Code** (eval scripts, sim harnesses): Apache-2.0 — see `LICENSE`.
- **Dataset** (the JSONL files): CC-BY-4.0 — see `data/DATASET_LICENSE.md`.
  You must give appropriate credit when using the data.
- Built on [OpenTitan](https://github.com/lowRISC/opentitan) (Apache-2.0);
  per-question source attribution is included in every record.

## Citation

See `CITATION.cff`. If you use SpecRead, please cite the dataset release.
