module cordic_polar_tx #(
    parameter int INPUT_WIDTH = 16,
    parameter int OUTPUT_WIDTH = 16,
    parameter int ITERATIONS = 16
) (
    input  logic                         clk,
    input  logic                         rst_n,
    input  logic                         in_valid,
    output logic                         in_ready,
    input  logic signed [INPUT_WIDTH-1:0] i_in,
    input  logic signed [INPUT_WIDTH-1:0] q_in,
    output logic                         out_valid,
    input  logic                         out_ready,
    output logic        [OUTPUT_WIDTH-1:0] amplitude_out,
    output logic signed [OUTPUT_WIDTH-1:0] phase_out
);
    // TODO: Implement quadrant correction, vectoring iterations, gain correction,
    // amplitude saturation, and the output handshake.
    assign in_ready = 1'b0;
endmodule
