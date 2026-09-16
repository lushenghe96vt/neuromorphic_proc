module block5_soc_top_manager (
    input  logic       CLK_EXT,
    input  logic       RST_N_EXT,
    input  logic       SPI_SCLK,
    input  logic       SPI_CS_N,
    input  logic       SPI_MOSI,
    input  logic       SCAN_IN,
    input  logic       SO_FROM_TEAM4,
    input  logic       RO_SENSE_IN,
    output logic       SPI_MISO,
    output logic       SCAN_OUT,
    output logic       CLK_INT,
    output logic       CLK_SLOW_INT,
    output logic       RST_N_INT,
    output logic       GLOBAL_SE,
    output logic       SI_TO_TEAM1,
    output logic [3:0] CAL_VEC_1,
    output logic [3:0] CAL_VEC_3
);
    // TODO: Implement the Team 5 microarchitecture.
    assign CLK_INT = CLK_EXT;
    assign RST_N_INT = RST_N_EXT;
    assign SCAN_OUT = SO_FROM_TEAM4;
endmodule
