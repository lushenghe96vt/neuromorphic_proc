# CORDIC Polar TX Block

An independent CORDIC accelerator for converting signed Cartesian input samples `(I, Q)` into polar output samples `(A, P)` for a polar transmitter.

## Block Contract

The starter interface accepts one sample when `in_valid` and `in_ready` are both high. It returns one result when `out_valid` is high. The result remains stable until the receiving block raises `out_ready`.

| Signal | Width | Meaning |
| --- | ---: | --- |
| `clk` | 1 | Synchronous clock |
| `rst_n` | 1 | Active-low reset |
| `in_valid` | 1 | Input sample is valid |
| `in_ready` | 1 | Block can accept an input sample |
| `i_in` | 16 | Signed in-phase sample |
| `q_in` | 16 | Signed quadrature sample |
| `out_valid` | 1 | Output result is valid |
| `out_ready` | 1 | Downstream block can accept the result |
| `amplitude_out` | 16 | Unsigned amplitude, saturated to 16 bits |
| `phase_out` | 16 | Signed phase in normalized turns |

### Numeric assumptions

These are the initial assumptions and must be confirmed in `docs/microarchitecture.md` before implementation:

- `i_in` and `q_in` are two's-complement signed 16-bit values.
- `amplitude_out` represents the magnitude `A = sqrt(I^2 + Q^2)`. The internal calculation may use guard bits; the final result saturates rather than wraps.
- `phase_out` represents `P = atan2(Q, I)` in normalized turns. `16'h0000` is 0 radians, `16'h4000` is +pi/2, `16'h8000` is -pi, and `16'hC000` represents -pi/2 when interpreted as signed two's complement.
- The phase range is `[-pi, +pi)`.
- Inputs of `(0, 0)` require a documented result. The recommended baseline is `amplitude_out = 0` and `phase_out = 0`.
- The design should use 16 iterations for 16-bit input precision unless an error/area study justifies another value.

## Required implementation

1. Register the input sample on an input handshake.
2. Move the vector into the CORDIC convergence range, including quadrant correction.
3. Perform vectoring-mode CORDIC iterations using an arctangent lookup table.
4. Apply or document the CORDIC gain correction for amplitude.
5. Saturate amplitude and preserve phase sign conventions.
6. Hold output data stable while `out_valid` is high and `out_ready` is low.
7. Provide a deterministic latency or document the variable-latency behavior.
8. Add assertions for handshake stability, reset behavior, and output protocol correctness.

A multi-cycle iterative implementation is the recommended starting point. A fully unrolled or pipelined implementation may be proposed if the latency, area, and power tradeoff is measured.

## Verification requirements

The testbench should compare the RTL against a software reference model for:

- all four quadrants;
- axes and signed-zero boundary cases;
- `(0, 0)`;
- maximum positive and negative I/Q values;
- small vectors near the origin;
- random vectors across the full input range;
- amplitude saturation and CORDIC gain correction;
- backpressure while `out_valid` is asserted;
- reset during idle and between transactions.

Recommended error metrics are amplitude absolute error and phase error in least-significant bits. The team must define acceptable tolerances before signoff.

## Directories

- `rtl/`: synthesizable SystemVerilog
- `tb/`: self-checking testbench and reference model
- `scripts/`: reproducible simulation, lint, synthesis, and implementation commands
- `docs/`: microarchitecture, numeric formats, convergence, and error budget
- `constraints/`: clock, I/O, and implementation constraints
- `reports/`: simulation, coverage, synthesis, timing, power, and area results

## First tasks

1. Confirm the amplitude scaling and phase encoding with the Polar TX interface owner.
2. Fill in the CORDIC arctangent table and gain-correction method.
3. Define latency, throughput, and reset values.
4. Implement the handshake shell in `rtl/cordic_polar_tx.sv`.
5. Build the reference-model scoreboard in `tb/cordic_polar_tx_tb.sv`.
