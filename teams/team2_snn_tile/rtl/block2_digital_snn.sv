module block2_digital_snn (
    input  logic       CLK,
    input  logic       RST_N,
    input  logic       SE,
    input  logic       SI,
    input  logic       AER_IN_REQ,
    input  logic [7:0] AER_IN_ADDR,
    input  logic       AER_OUT_ACK,
    output logic       SO,
    output logic       AER_IN_ACK,
    output logic       AER_OUT_REQ,
    output logic [7:0] AER_OUT_ADDR
);
    // TODO: Implement the Team 2 microarchitecture.
    assign SO = SI;
endmodule
