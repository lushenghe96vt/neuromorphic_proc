# Team 4: Asynchronous AER Router

## Responsibilities

Implement the clockless five-port AER router. Define packet routing, four-phase request/acknowledge behavior, output arbitration, fairness, buffering, malformed-packet behavior, and scan integration.

## Directories

- `rtl/`: synthesizable SystemVerilog and asynchronous primitives
- `tb/`: handshake, contention, and route tests
- `scripts/`: reproducible simulation and implementation commands
- `docs/`: packet format, route table, timing assumptions, and arbitration policy
- `constraints/`: implementation and asynchronous timing constraints
- `reports/`: simulation, coverage, synthesis, and timing results

Start with `rtl/block4_async_router.sv` and `tb/block4_async_router_tb.sv`.