# Team 3: STDP Learning Engine

## Responsibilities

Implement spike-timing-dependent plasticity for 16 channels. Track timing on `CLK_SLOW`, calculate decay and signed weight updates on `CLK`, saturate weights to `[-128, 127]`, define the channel mapping, and generate `LEARNING_DONE`.

## Directories

- `rtl/`: synthesizable SystemVerilog
- `tb/`: self-checking unit tests and reference models
- `scripts/`: reproducible simulation and synthesis commands
- `docs/`: learning rule, lookup table, timing, and CDC decisions
- `constraints/`: clocks, I/O, and implementation constraints
- `reports/`: simulation, coverage, synthesis, and timing results

Start with `rtl/block3_stdp_learning.sv` and `tb/block3_stdp_learning_tb.sv`.