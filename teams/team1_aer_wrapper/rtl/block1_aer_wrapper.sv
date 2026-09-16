module block1_aer_wrapper (
    input  logic        CLK,
    input  logic        RST_N,
    input  logic        SE,
    input  logic        SI,
    input  logic [15:0] SPIKE_OUT,
    input  logic        AER_ACK,
    input  logic        CFG_WE,
    input  logic [63:0] CFG_DATA,
    output logic        SO,
    output logic        AER_REQ,
    output logic [7:0]  AER_ADDR,
    output logic [63:0] WEIGHT_DAC
);
    // TODO: Implement the Team 1 microarchitecture.
    assign SO = SI;
endmodule
