# Team 1: AER Wrapper

## Responsibilities

Implement the digital adapter between the analog macro and the AER network. Preserve `AER_ADDR` and `AER_REQ` until `AER_ACK`, implement the 64-bit `WEIGHT_DAC` configuration register, define a deterministic multi-spike policy, and connect the scan path.

## Directories

- `rtl/`: synthesizable SystemVerilog
- `tb/`: self-checking unit tests and models
- `scripts/`: reproducible simulation and synthesis commands
- `docs/`: microarchitecture, timing, and interface decisions
- `constraints/`: clocks, I/O, and implementation constraints
- `reports/`: simulation, coverage, synthesis, and timing results

Start with `rtl/block1_aer_wrapper.sv` and `tb/block1_aer_wrapper_tb.sv`.