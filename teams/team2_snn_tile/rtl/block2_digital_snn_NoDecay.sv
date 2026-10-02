`timescale 1ns/1ps

// ----------------------------------------------------------------------------
// Team 2 contains 32 LOGICAL neurons but only one physical LIF arithmetic
// datapath.  The 32 neurons are organized as two layers of 16 channels:
//
//   neuron_id = 0_ssss  -> hidden neuron  s   (indices  0..15)
//   neuron_id = 1_ssss  -> output neuron  s   (indices 16..31)
//
// where s = AER_IN_ADDR[3:0].
//
// Per accepted AER input event on channel s:
//   1. Update hidden neuron s using WEIGHT_IN[s].
//   2. If hidden neuron s does NOT spike, the event is finished.
//   3. If hidden neuron s DOES spike, reuse the same physical LIF datapath to
//      update output neuron 16+s using the SAME WEIGHT_IN[s].
//   4. The hidden-layer spike is internal only; it does NOT generate AER.
//   5. If output neuron 16+s spikes, emit AER_OUT_ADDR = {4'b0010, s}.
//
// This is the intended meaning of time multiplexing here: the hidden and output
// logical neurons take turns using one datapath.  We never instantiate 32 LIF
// arithmetic units and we do not sweep all 32 neurons on each input event.
//
// LIF model
// ---------
// One mathematical LIF update is spread across multiple CLK cycles:
//
//   V_leak      = V_RESET + beta * (V_old - V_RESET)
//   V_candidate = V_leak + W_scaled
//
//   if V_candidate >= V_THRESHOLD:
//       spike  = 1
//       V_next = V_RESET
//   else:
//       spike  = 0
//       V_next = saturate_Q4.8(V_candidate)
//
// Default reference values:
//   beta        = 0.875 = 224/256 = 8'hE0 (unsigned Q0.8)
//   threshold   = 1.0   = 256/256          (signed Q4.8)
//   reset       = 0.0                         (signed Q4.8)
//
// WEIGHT INTERFACE
// ----------------
// Team 3 supplies sixteen signed 8-bit weights packed as WEIGHT_IN[127:0]:
//
//   channel s weight = WEIGHT_IN[8*s +: 8]
//
// The same captured channel weight is used for BOTH the hidden and output pass.
// The project currently specifies the weight width but not its binary point.
// Until that numerical convention is finalized, this RTL interprets each
// signed 8-bit weight as Q0.7.  Q0.7 -> Q4.8 is a one-bit left shift.
//
// STDP INTERFACE ASSUMPTION
// -------------------------
// STDP_PRE_SPIKE[s] pulses for one CLK when an external AER event on channel s
// is accepted.  STDP_POST_SPIKE[s] pulses for one CLK when output neuron 16+s
// fires.  This treats the externally observed source/output pair as the pre/post
// events supplied to Team 3.  If the integration contract defines different
// pulse semantics, only these pulse-generation points need to change.
//
// LEAK POLICY
// -----------
// This implementation uses event-driven leak only: a neuron is leaked when it
// is actually passed through the shared datapath.  Neurons that receive no
// events are not background-updated.  A lazy-leak or idle background sweep can
// be added later without changing the two-layer neuron mapping below.
// ============================================================================
module block2_digital_snn #(
    parameter logic [7:0]         BETA_VALUE       = 8'hE0,    // 0.875 Q0.8
    parameter logic signed [11:0] THRESHOLD_VALUE = 12'sd256,  // 1.0 Q4.8
    parameter logic signed [11:0] RESET_VALUE     = 12'sd0     // 0.0 Q4.8
) (
    input  logic         CLK,
    input  logic         RST_N,
    input  logic         SE,
    input  logic         SI,

    // Input AER, upper nibble = tile id, lower nibble = neuron id.
    input  logic         AER_IN_REQ,
    input  logic [7:0]   AER_IN_ADDR,

    // 16 signed 8-bit weights from Team 3.
    // Weight s occupies WEIGHT_IN[8*s +: 8].
    input  logic [127:0] WEIGHT_IN,

    // Output AER acknowledgement from the downstream block.
    input  logic         AER_OUT_ACK,

    output logic         SO,
    output logic         AER_IN_ACK,
    output logic         AER_OUT_REQ,
    output logic [7:0]   AER_OUT_ADDR,

    // Spike observations supplied to Team 3 for STDP.
    output logic [15:0]  STDP_PRE_SPIKE,
    output logic [15:0]  STDP_POST_SPIKE
);

    // ------------------------------------------------------------------------
    // Logical neuron state storage
    // ------------------------------------------------------------------------
    // 0 to 15: hidden layer
    // 16 to 31: output layer
    // Each membrane voltage is signed 12-bit Q4.8.
    logic signed [11:0] V_M [0:31];

    // Internal logical-neuron selector.
    //   bit 4: 0 = hidden layer, 1 = output layer
    //   bits3:0: channel s
    logic [4:0] neuron_id;

    // Captured channel identity from the accepted AER transaction.
    logic [3:0] source_id;

    // Capture exactly one 8-bit weight when the AER event is accepted.  The
    // same value is then reused for the hidden and (if needed) output pass.
    logic signed [7:0] captured_weight;

    // ------------------------------------------------------------------------
    // Multi-cycle LIF pipeline registers
    // ------------------------------------------------------------------------
    logic signed [11:0] current_voltage;     // Q4.8 V_old
    logic signed [12:0] voltage_from_reset;  // Q4.8, one guard bit
    logic signed [21:0] beta_product;        // product with 16 fractional bits
    logic signed [21:0] leaked_voltage;      // wide Q4.8 intermediate
    logic signed [21:0] candidate_voltage;   // wide Q4.8 intermediate
    logic signed [11:0] saved_next_voltage;  // final Q4.8 value to write
    logic               saved_spike;         // result of threshold decision

    // Current pass type.  This duplicates neuron_id[4] intentionally because
    // it makes the controller intent explicit and easy to inspect in waveforms.
    logic processing_output_layer;

    // ------------------------------------------------------------------------
    // Controller states
    // ------------------------------------------------------------------------
    // READ/APPLY_LEAK/ADD_WEIGHT/THRESHOLD/WRITE implement one mathematical
    // neuron update.  If a hidden neuron spikes, WRITE_NEURON changes the
    // selected logical neuron from 0_ssss to 1_ssss and runs those same states
    // using the same physical arithmetic hardware.
    typedef enum logic [3:0] {
        IDLE,
        WAIT_INPUT_REQ_LOW,
        READ_NEURON,
        APPLY_LEAK,
        ADD_WEIGHT,
        THRESHOLD_CHECK,
        WRITE_NEURON,
        SEND_SPIKE,
        WAIT_OUTPUT_ACK_LOW
    } state_t;

    state_t state;
    integer i;

    // ------------------------------------------------------------------------
    // Scan chain
    // ------------------------------------------------------------------------
    // SI -> V_M[0] -> ... -> V_M[31] -> SO.
    assign SO = V_M[31][11];

    // ------------------------------------------------------------------------
    // Sequential controller / shared datapath
    // ------------------------------------------------------------------------
    always_ff @(posedge CLK) begin
        if (!RST_N) begin
            state                   <= IDLE;
            neuron_id               <= '0;
            source_id               <= '0;
            captured_weight         <= '0;
            current_voltage         <= '0;
            voltage_from_reset      <= '0;
            beta_product            <= '0;
            leaked_voltage          <= '0;
            candidate_voltage       <= '0;
            saved_next_voltage      <= RESET_VALUE;
            saved_spike             <= 1'b0;
            processing_output_layer <= 1'b0;

            AER_IN_ACK              <= 1'b0;
            AER_OUT_REQ             <= 1'b0;
            AER_OUT_ADDR            <= '0;
            STDP_PRE_SPIKE          <= '0;
            STDP_POST_SPIKE         <= '0;

            for (i = 0; i < 32; i = i + 1)
                V_M[i] <= RESET_VALUE;
        end

        else if (SE) begin
            // Scan mode pauses normal neuron/AER processing and shifts the
            // membrane-state registers as one serial chain.
            STDP_PRE_SPIKE  <= '0;
            STDP_POST_SPIKE <= '0;

            V_M[0] <= {V_M[0][10:0], SI};
            for (i = 1; i < 32; i = i + 1)
                V_M[i] <= {V_M[i][10:0], V_M[i-1][11]};
        end

        else begin
            // STDP outputs are one-clock pulses.  Individual states below set
            // the appropriate bit after these defaults clear the prior pulse.
            STDP_PRE_SPIKE  <= '0;
            STDP_POST_SPIKE <= '0;

            case (state)

                // ------------------------------------------------------------
                // IDLE: accept one external event on source/channel s.
                // ------------------------------------------------------------
                IDLE: begin
                    if (AER_IN_REQ) begin
                        source_id <= AER_IN_ADDR[3:0];

                        // Extract weight channel s from Team 3's packed bus.
                        // Indexed part-select width is constant (8 bits), while
                        // the base changes with the incoming source ID.
                        captured_weight <= $signed(
                            WEIGHT_IN[(AER_IN_ADDR[3:0] * 8) +: 8]
                        );

                        // First pass always targets hidden neuron s: 0_ssss.
                        neuron_id               <= {1'b0, AER_IN_ADDR[3:0]};
                        processing_output_layer <= 1'b0;

                        // The accepted external AER event is the pre-synaptic
                        // event reported to Team 3 on this channel.
                        STDP_PRE_SPIKE[AER_IN_ADDR[3:0]] <= 1'b1;

                        // Four-phase input handshake: capture/accept the event,
                        // raise ACK, then wait for the sender to lower REQ.
                        AER_IN_ACK <= 1'b1;
                        state      <= WAIT_INPUT_REQ_LOW;
                    end
                end

                // ------------------------------------------------------------
                // WAIT_INPUT_REQ_LOW: finish the incoming four-phase handshake.
                // No new event can be accepted while the shared datapath is busy.
                // ------------------------------------------------------------
                WAIT_INPUT_REQ_LOW: begin
                    if (!AER_IN_REQ) begin
                        AER_IN_ACK <= 1'b0;
                        state      <= READ_NEURON;
                    end
                end

                // ------------------------------------------------------------
                // READ_NEURON: read whichever logical neuron currently owns the
                // shared datapath (hidden s first, output 16+s only if needed).
                // ------------------------------------------------------------
                READ_NEURON: begin
                    current_voltage <= V_M[neuron_id];
                    state           <= APPLY_LEAK;
                end

                // ------------------------------------------------------------
                // APPLY_LEAK:
                //   V_leak = V_RESET + beta * (V_old - V_RESET)
                //
                // beta is unsigned Q0.8; prepend a zero before signed multiply
                // so values above 0.5 are not interpreted as negative.
                // ------------------------------------------------------------
                APPLY_LEAK: begin
                    voltage_from_reset <=
                        $signed({current_voltage[11], current_voltage}) -
                        $signed({RESET_VALUE[11], RESET_VALUE});

                    beta_product <=
                        ($signed({current_voltage[11], current_voltage}) -
                         $signed({RESET_VALUE[11], RESET_VALUE})) *
                        $signed({1'b0, BETA_VALUE});

                    state <= ADD_WEIGHT;
                end

                // ------------------------------------------------------------
                // ADD_WEIGHT:
                //   V_candidate = V_leak + W_scaled
                //
                // Temporary numeric convention: captured_weight is signed Q0.7.
                // Q0.7 -> Q4.8 requires a one-bit left shift.  The same captured
                // weight is deliberately reused for both layer passes.
                // ------------------------------------------------------------
                ADD_WEIGHT: begin
                    leaked_voltage <=
                        $signed({{10{RESET_VALUE[11]}}, RESET_VALUE}) +
                        ($signed(beta_product) >>> 8);

                    candidate_voltage <=
                        $signed({{10{RESET_VALUE[11]}}, RESET_VALUE}) +
                        ($signed(beta_product) >>> 8) +
                        ($signed({{14{captured_weight[7]}}, captured_weight}) <<< 1);

                    state <= THRESHOLD_CHECK;
                end

                // ------------------------------------------------------------
                // THRESHOLD_CHECK: threshold first, otherwise signed saturation.
                // A crossing performs a hard reset to RESET_VALUE.
                // ------------------------------------------------------------
                THRESHOLD_CHECK: begin
                    if (candidate_voltage >=
                        $signed({{10{THRESHOLD_VALUE[11]}}, THRESHOLD_VALUE})) begin
                        saved_spike        <= 1'b1;
                        saved_next_voltage <= RESET_VALUE;
                    end
                    else begin
                        saved_spike <= 1'b0;

                        // Signed 12-bit Q4.8 storage range:
                        //   raw [-2048, 2047] = [-8.0, 7.99609375].
                        if (candidate_voltage > 22'sd2047)
                            saved_next_voltage <= 12'sd2047;
                        else if (candidate_voltage < -22'sd2048)
                            saved_next_voltage <= -12'sd2048;
                        else
                            saved_next_voltage <= candidate_voltage[11:0];
                    end

                    state <= WRITE_NEURON;
                end

                // ------------------------------------------------------------
                // WRITE_NEURON: commit the completed update and decide whether
                // this input event is finished or requires the second layer.
                // ------------------------------------------------------------
                WRITE_NEURON: begin
                    V_M[neuron_id] <= saved_next_voltage;

                    if (!processing_output_layer) begin
                        // Hidden layer pass (neuron 0_ssss).
                        if (saved_spike) begin
                            // Hidden neuron s fired.  This spike is INTERNAL:
                            // it selects output neuron 16+s and sends that neuron
                            // through the SAME shared datapath with SAME weight.
                            neuron_id               <= {1'b1, source_id};
                            processing_output_layer <= 1'b1;
                            state                   <= READ_NEURON;
                        end
                        else begin
                            // Hidden neuron did not fire; output layer is not
                            // touched and no external AER event is generated.
                            state <= IDLE;
                        end
                    end
                    else begin
                        // Output layer pass (neuron 1_ssss = 16+s).
                        if (saved_spike) begin
                            // Output neuron firing is the externally visible
                            // post-synaptic event for Team 3's STDP observation.
                            STDP_POST_SPIKE[source_id] <= 1'b1;
                            state <= SEND_SPIKE;
                        end
                        else begin
                            // Output neuron updated but stayed subthreshold.
                            state <= IDLE;
                        end
                    end
                end

                // ------------------------------------------------------------
                // SEND_SPIKE: only an OUTPUT-layer threshold crossing reaches
                // the external AER network.
                // ------------------------------------------------------------
                SEND_SPIKE: begin
                    if (!AER_OUT_REQ) begin
                        AER_OUT_ADDR <= {4'b0010, source_id};
                        AER_OUT_REQ  <= 1'b1;
                    end
                    else if (AER_OUT_ACK) begin
                        AER_OUT_REQ <= 1'b0;
                        state       <= WAIT_OUTPUT_ACK_LOW;
                    end
                end

                // ------------------------------------------------------------
                // WAIT_OUTPUT_ACK_LOW: complete four-phase output handshake.
                // ------------------------------------------------------------
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
