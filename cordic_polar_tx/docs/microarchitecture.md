# CORDIC Polar TX Microarchitecture

## Decisions to finalize

- Input and output fixed-point scaling
- Phase encoding and wrap convention
- CORDIC iteration count
- Arctangent table representation
- Gain correction method
- Input/output latency and throughput
- `(0, 0)` behavior
- Amplitude overflow and saturation policy
- Reset behavior

## Proposed datapath

1. Capture signed I/Q input.
2. Correct the input quadrant so the vectoring iterations converge.
3. Iterate `x`, `y`, and `z` using a signed shift-add CORDIC datapath.
4. Convert the final `x` value to amplitude and apply gain correction.
5. Normalize and register amplitude and phase outputs.

Add timing diagrams, state transitions, bit-growth analysis, and an error budget before RTL freeze.
