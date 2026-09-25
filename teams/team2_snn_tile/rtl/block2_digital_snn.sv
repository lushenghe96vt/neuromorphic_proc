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
    //sheng_branch

    // TODO: Implement the Team 2 microarchitecture.

    // each voltage is signed 12-bit Q4.8
    // 0 to 2047 represents a positive voltage, while 2048 to 4095 represents a negative voltage
    // real ranges from -8 to 8 V
    logic signed [11:0] V_M [0:31];

    // remember which neuron is being updated
    // on team 1 readme it states: The upper nibble of AER_ADDR is the fixed tile ID (4'b0001). The lower nibble is the selected neuron ID (0 through 15)
    // TODO: decide how we get neuron_id
    logic [4:0] neuron_id; // just a placeholder needs to be 5 bits to choose for 32

    // beta is unsigned Q0.8 meaning 0 - 255
    logic [7:0] beta;

    // weight is signed 8-bis
    // Team 3 produces weights
    logic signed [7:0] W;

    // threshold voltage and reset voltage use signed 12-bit Q4.8
    // TODO: decide these values
    logic signed [11:0] THRESHOLD_V;
    logic signed [11:0] RESET_V;

    /*
    The exact LIF update equation, threshold, reset voltage, and post-spike
    reset must be written in the team microarchitecture document.

    The README suggests: capture event, read neuron state, add the signed
    weight, apply leak, compare against threshold, write the next state,
    and emit a spike if the threshold was crossed.
    */

    // datapath for V_candidate = beta * (V_M + W)
    // assuming W represents whole voltage units, so shift it by 8 to convert it to the Q4.8 format used by V_M
    logic signed [20:0] weight_q8;
    logic signed [20:0] voltage_plus_weight;
    logic signed [29:0] leaked_product;
    logic signed [20:0] candidate_voltage;
    // result of comparing the candidate voltage with the threshold
    logic spike_detected;
    // voltage that WRITE_NEURON will eventually store
    logic signed [11:0] next_voltage;

    always_comb begin
        // sign extend W before shifting so negative weights stay negative
        weight_q8 = $signed({{13{W[7]}}, W}) <<< 8;

        // V_M is in Q4.8 so extend it before adding the weight
        voltage_plus_weight =
            $signed(V_M[neuron_id]) + weight_q8;

        // Q4.8 multiplied by Q0.8 produces 16 fractional bits
        // beta is extended with a leading zero so it remains positive
        leaked_product =
            voltage_plus_weight * $signed({1'b0, beta});

        // shift back to 8 fractional bits
        // TODO: decide whether to round instead of truncating
        candidate_voltage = leaked_product >>> 8;

        // assuming as it reaches the threshold, causess a spike
        spike_detected = candidate_voltage >= $signed(THRESHOLD_V);

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


    // FSM states
    typedef enum logic [2:0] {
        IDLE,
        WAIT_INPUT_REQ_LOW,
        READ_NEURON,
        WRITE_NEURON,
        SEND_SPIKE,
        WAIT_OUTPUT_ACK_LOW
    } state_t;

    state_t state;

    // saved values for the current event
    logic [7:0] captured_addr;
    logic signed [11:0] saved_next_voltage;
    logic saved_spike;

    integer i;
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
            // TODO: implement scan shifting
        end

        else begin
            case (state)

                IDLE: begin
                    // accept an incoming event and save its address
                    if (AER_IN_REQ) begin
                        captured_addr <= AER_IN_ADDR;

                        // placeholder mapping ensure definition later
                        neuron_id <= AER_IN_ADDR[4:0];

                        AER_IN_ACK <= 1'b1;
                        state <= WAIT_INPUT_REQ_LOW;
                    end
                end

                WAIT_INPUT_REQ_LOW: begin
                    // hold ACK high until the sender lowers REQ
                    if (!AER_IN_REQ) begin
                        AER_IN_ACK <= 1'b0;
                        state <= READ_NEURON;
                    end
                end

                READ_NEURON: begin
                    // The always_comb block uses V_M[neuron_id] to calculate the result. Save that result here so
                    // it stays unchanged during WRITE_NEURON
                    saved_next_voltage <= next_voltage;
                    saved_spike <= spike_detected;
                    state <= WRITE_NEURON;
                end

                WRITE_NEURON: begin
                    // store the result saved on the preceding clock
                    V_M[neuron_id] <= saved_next_voltage;

                    if (saved_spike)
                        state <= SEND_SPIKE;
                    else
                        state <= IDLE;
                end

                SEND_SPIKE: begin
                    if (!AER_OUT_REQ) begin
                        // Start an output transaction.
                        // decide how to identify neuron
                        AER_OUT_ADDR <= {};
                        AER_OUT_REQ  <= 1'b1;
                    end
                    else if (AER_OUT_ACK) begin
                        // receiver has acknowledged the spike so lower REQ,
                        // then wait for the receiver to lower ACK
                        AER_OUT_REQ <= 1'b0;
                        state <= WAIT_OUTPUT_ACK_LOW;
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