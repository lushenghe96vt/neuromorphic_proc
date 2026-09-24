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

    // each voltage is signed 12-bit Q4.8. ???
    logic signed [11:0] V_M [0:31];

    // to remember which neuron is being updated
    logic [4:0] neuron_id;

    // use shared arithmetic datapath
    // TODO: declare datapath registers after defining the LIF equation and the width of each intermediate result

    // beta is unsigned (Q0.8)
    logic [7:0] beta;
    // weight is signed 8 bit
    logc signed [7:0] W;

    /*
    The exact LIF update equation, threshold, reset voltage, and post-spike reset must be written in the team microarchitecture document. 
    A useful baseline sequence is: capture event, read neuron state, add the signed weight, apply leak, compare against threshold, write the next state, 
    and emit a spike if the threshold was crossed.
    */
    // threshold voltage (Q4.8) and reset voltage
    logic signed [11:0] THRESHOLD_V;
    logic signed [11:0] RESET_V;

    // FSM states
    typedef enum logic [2:0] {
        IDLE,
        CAPTURE_EVENT,
        READ_NEURON,
        ADD_WEIGHT,
        APPLY_LEAK,
        CHECK_THRESHOLD,
        WRITE_NEURON,
        SEND_SPIKE
    } state_t;
    state_t state;

    always_ff @(posedge CLK) begin
        if (!RST_N) begin // init
            state        <= IDLE;

            AER_IN_ACK   <= 1'b0;
            AER_OUT_REQ  <= 1'b0;
            AER_OUT_ADDR <= '0;

            for (i = 0; i < 32; i = i + 1) // idk if we need this
                neuron_v[i] <= '0;
        end 

        else if (SE) begin 
            // Shift membrane voltage registers instead of updating neurons
        end 

        else begin // start fsm
            case (state)

                IDLE: begin
                    // wait for an incoming AER request
                    // accept only when the it can be processed
                end

                CAPTURE_EVENT: begin
                    // save the information needed for the update
                    // complete input ACK
                end

                READ_NEURON: begin
                    // choose the neuron and read voltage
                end

                ADD_WEIGHT: begin
                    // get weight
                    // apply it to the voltage
                end

                APPLY_LEAK: begin
                    // apply leak coefficient
                end

                CHECK_THRESHOLD: begin
                    // compare the updated voltage with the threshold
                    // decide whether or not to spike
                end

                WRITE_NEURON: begin
                    // store the saturated updated voltage
                    // If spiked, store the post spike reset voltage
                end

                SEND_SPIKE: begin
                    // put the spike address on AER_OUT_ADDR
                    // hold AER_OUT_REQ and address stable until acknowledged
                    // Complete the output handshake and go to IDLE
                end

                default: begin
                end

            endcase

        end

endmodule
