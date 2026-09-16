module block3_stdp_learning (
    input  logic         CLK,
    input  logic         CLK_SLOW,
    input  logic         RST_N,
    input  logic         SE,
    input  logic         SI,
    input  logic [3:0]   PRE_SPIKE,
    input  logic [3:0]   POST_SPIKE,
    input  logic [3:0]   CAL_VEC,
    output logic         SO,
    output logic [127:0] WEIGHT_OUT,
    output logic         LEARNING_DONE
);
    // TODO: Implement the Team 3 microarchitecture.
    assign SO = SI;
endmodule
