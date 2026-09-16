# Team 2: Digital SNN Tile

## Responsibilities

Implement the 32-neuron time-multiplexed LIF tile. Define the fixed-point update equation, store neuron state, sequence the shared datapath, handle AER backpressure, generate output spikes, and connect the scan path.

## Directories

- `rtl/`: synthesizable SystemVerilog
- `tb/`: self-checking unit tests and reference models
- `scripts/`: reproducible simulation and synthesis commands
- `docs/`: microarchitecture, timing, and fixed-point decisions
- `constraints/`: clocks, I/O, and implementation constraints
- `reports/`: simulation, coverage, synthesis, and timing results

Start with `rtl/block2_digital_snn.sv` and `tb/block2_digital_snn_tb.sv`.