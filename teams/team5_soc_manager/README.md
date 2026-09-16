# Team 5: SoC Manager and Top Integration

## Responsibilities

Implement SPI configuration, clock and reset distribution, scan-chain integration, ring-oscillator calibration, calibration-vector generation, top-level connectivity, and integration constraints.

## Directories

- `rtl/`: synthesizable SystemVerilog and top-level wrappers
- `tb/`: SPI, reset, scan, calibration, and integration tests
- `scripts/`: reproducible simulation, synthesis, and integration commands
- `docs/`: register map, CDC, clock/reset, scan, and calibration decisions
- `constraints/`: clocks, I/O, power domains, and implementation constraints
- `reports/`: simulation, coverage, synthesis, and timing results

Start with `rtl/block5_soc_top_manager.sv` and `tb/block5_soc_top_manager_tb.sv`.