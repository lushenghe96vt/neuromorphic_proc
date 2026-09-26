`timescale 1ns/1ps // for simulation timing
module block2_digital_snn #(
    // Supply these values from the testbench for now.
    // Unknown defaults expose a missing test configuration in simulation.
    parameter logic [7:0]         BETA_VALUE      = 8'hxx,
    parameter logic signed [7:0]  WEIGHT_VALUE    = 8'shx,
    parameter logic signed [11:0] THRESHOLD_VALUE = 12'shx,
    parameter logic signed [11:0] RESET_VALUE     = 12'shx
) (
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

    // Each membrane voltage is signed 12-bit Q4.8.
    logic signed [11:0] V_M [0:31];

    // The neuron currently being updated.
    logic [4:0] neuron_id;

    // Configuration used by the datapath.
    logic [7:0] beta;
    logic signed [7:0] W;
    logic signed [11:0] THRESHOLD_V;
    logic signed [11:0] RESET_V;

    assign beta        = BETA_VALUE;
    assign W           = WEIGHT_VALUE;
    assign THRESHOLD_V = THRESHOLD_VALUE;
    assign RESET_V     = RESET_VALUE;

    // Datapath for V_candidate = beta * (V_M + W).
    // Existing temporary interpretation: W represents whole voltage units.
    logic signed [20:0] weight_q8;
    logic signed [20:0] voltage_plus_weight;
    logic signed [29:0] leaked_product;
    logic signed [20:0] candidate_voltage;
    logic spike_detected;
    logic signed [11:0] next_voltage;

    always_comb begin
        weight_q8 = $signed({{13{W[7]}}, W}) <<< 8;

        voltage_plus_weight =
            $signed(V_M[neuron_id]) + weight_q8;

        leaked_product =
            voltage_plus_weight * $signed({1'b0, beta});

        // Return from 16 fractional bits to eight.
        candidate_voltage = leaked_product >>> 8;

        spike_detected =
            candidate_voltage >= $signed(THRESHOLD_V);

        if (spike_detected) begin
            next_voltage = RESET_V;
        end
        else if (candidate_voltage > 21'sd2047) begin
            next_voltage = 12'sd2047;
        end
        else if (candidate_voltage < -21'sd2048) begin
            next_voltage = -12'sd2048;
        end
        else begin
            next_voltage = candidate_voltage[11:0];
        end
    end

    typedef enum logic [2:0] {
        IDLE,
        WAIT_INPUT_REQ_LOW,
        READ_NEURON,
        WRITE_NEURON,
        SEND_SPIKE,
        WAIT_OUTPUT_ACK_LOW
    } state_t;

    state_t state;

    logic [7:0] captured_addr;
    logic signed [11:0] saved_next_voltage;
    logic saved_spike;

    integer i;

    // Membrane-voltage scan chain:
    // SI -> V_M[0] -> ... -> V_M[31] -> SO.
    assign SO = V_M[31][11];

    always_ff @(posedge CLK) begin
        if (!RST_N) begin
            state              <= IDLE;
            captured_addr      <= '0;
            neuron_id          <= '0;
            saved_next_voltage <= '0;
            saved_spike        <= 1'b0;

            AER_IN_ACK         <= 1'b0;
            AER_OUT_REQ        <= 1'b0;
            AER_OUT_ADDR       <= '0;

            for (i = 0; i < 32; i = i + 1)
                V_M[i] <= '0;
        end

        else if (SE) begin
            // Shift the membrane registers; pause normal FSM operation.
            V_M[0] <= {V_M[0][10:0], SI};

            for (i = 1; i < 32; i = i + 1)
                V_M[i] <= {V_M[i][10:0], V_M[i-1][11]};
        end

        else begin
            case (state)

                IDLE: begin
                    if (AER_IN_REQ) begin
                        captured_addr <= AER_IN_ADDR;

                        // TEMPORARY mapping retained from your code.
                        // Replace when the input-address meaning is known.
                        neuron_id <= AER_IN_ADDR[4:0];

                        AER_IN_ACK <= 1'b1;
                        state      <= WAIT_INPUT_REQ_LOW;
                    end
                end

                WAIT_INPUT_REQ_LOW: begin
                    // Keep ACK asserted until the sender lowers REQ.
                    if (!AER_IN_REQ) begin
                        AER_IN_ACK <= 1'b0;
                        state      <= READ_NEURON;
                    end
                end

                READ_NEURON: begin
                    // Save the current combinational datapath result.
                    saved_next_voltage <= next_voltage;
                    saved_spike        <= spike_detected;
                    state              <= WRITE_NEURON;
                end

                WRITE_NEURON: begin
                    V_M[neuron_id] <= saved_next_voltage;

                    if (saved_spike)
                        state <= SEND_SPIKE;
                    else
                        state <= IDLE;
                end

                SEND_SPIKE: begin
                    if (!AER_OUT_REQ) begin
                        // Team 2 tile ID plus incoming event-source ID.
                        // This does not uniquely identify a Team 2 neuron.
                        AER_OUT_ADDR <= {4'b0010, captured_addr[3:0]};
                        AER_OUT_REQ  <= 1'b1;
                    end
                    else if (AER_OUT_ACK) begin
                        AER_OUT_REQ <= 1'b0;
                        state       <= WAIT_OUTPUT_ACK_LOW;
                    end
                end

                WAIT_OUTPUT_ACK_LOW: begin
                    if (!AER_OUT_ACK)
                        state <= IDLE;
                end

                default: begin
                    AER_IN_ACK  <= 1'b0;
                    AER_OUT_REQ <= 1'b0;
                    state       <= IDLE;
                end

            endcase
        end
    end

endmodule
