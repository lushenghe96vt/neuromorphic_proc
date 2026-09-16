module block4_async_router (
    input  logic        SE,
    input  logic        SI,
    input  logic        REQ_IN_LOCAL,
    input  logic [9:0]  DATA_IN_LOCAL,
    input  logic        ACK_OUT_LOCAL,
    output logic        ACK_IN_LOCAL,
    output logic        REQ_OUT_LOCAL,
    output logic [9:0]  DATA_OUT_LOCAL,
    input  logic [3:0]  REQ_IN_NSEW,
    input  logic [9:0]  DATA_IN_NSEW [3:0],
    input  logic [3:0]  ACK_OUT_NSEW,
    output logic [3:0]  ACK_IN_NSEW,
    output logic [3:0]  REQ_OUT_NSEW,
    output logic [9:0]  DATA_OUT_NSEW [3:0],
    output logic        SO
);
    // TODO: Implement the Team 4 asynchronous microarchitecture.
    assign SO = SI;
endmodule
