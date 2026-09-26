# Sim harnesses — how the 98 type-4 RTL mutations were verified

Every type-4 question in SpecRead is backed by a simulation harness in
`t4_cases/`. The dataset only retains mutations that were proven, by actual
Icarus Verilog simulation, to change the module's observable behavior
(`RESULT: DIFFER`). Mutations that simulated identically were discarded.

## Layout

```
sim/
  SIM_README.md
  stubs/            # minimal OpenTitan package stubs needed to compile the
                    # extracted submodules (e.g. aes_pkg_min.sv). These stand in
                    # for the real OpenTitan packages so each case compiles standalone.
  t4_cases/
    <ip>-<nnn>/     # e.g. aes-001 ... uart-010  (98 dirs, one per t4 question)
      orig.sv       # the original OpenTitan submodule (behavioral model)
      mut.sv        # the same module with the injected mutation
      tb.sv         # testbench: instantiates both, compares outputs,
                    # prints RESULT: DIFFER or RESULT: NO DIFFERENCE
      <ip>-<nnn>.log# captured output of the original verification run
```

Directory name `<ip>-<nnn>` maps to question id `<ip>-t4-<nnn>`
(e.g. `aes-001` <-> `aes-t4-001`, `uart-010` <-> `uart-t4-010`).

## Re-running a case

You need [Icarus Verilog](https://github.com/steveicarus/iverilog) (any recent
version; the original runs used iverilog 12).

```bash
cd t4_cases/aes-001
iverilog -g2012 -o sim.vvp ../../stubs/aes_pkg_min.sv orig.sv mut.sv tb.sv
vvp sim.vvp
```

Expected output (tail): `RESULT: DIFFER (...)`.

Which stub(s) each case needs is shown in the first line of its `.log`
(the original logs record absolute workspace paths; substitute
`../../stubs/<file>` for them). Cases that need no stub compile with just
`orig.sv mut.sv tb.sv`.

## What DIFFER means (and does not mean)

- `RESULT: DIFFER` proves the injected RTL mutation changes observable
  behavior under the testbench stimuli. It is a *filter*, not a finding:
  it guarantees the question's premise ("the RTL differs from the spec")
  is real, so a model that answers "violation" is answering a genuine
  defect rather than a no-op change.
- It does **not** by itself prove a spec violation. The spec-violation
  judgment is the model's task; each question's `gold_answer` cites the
  specific spec rule and explains the link between the RTL change and the rule.

## Provenance

- Original RTL extracted from OpenTitan at commit
  `80b5b3213453156fe62683962664d1afd9695ec4` (Apache-2.0).
  The `verification` field of each t4 question records the exact sim commands.
- Mutations are intentionally small and realistic (off-by-one, wrong reset
  value, inverted enable, missing FSM transition, field offset error):
  the kind of defect a tired engineer could ship.
