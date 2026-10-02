`timescale 1ns/1ps

// ============================================================================
// Testbench for the Team 2 two-layer, time-multiplexed LIF tile.
//
// Architectural behavior checked here:
//   * incoming source nibble s selects hidden neuron s (0..15)
//   * WEIGHT_IN contains 16 packed 8-bit channel weights
//   * hidden non-spike ends the transaction
//   * hidden spike triggers a second pass through the SAME LIF datapath for
//     output neuron 16+s
//   * the SAME captured weight is reused on both passes
//   * hidden spikes do not generate external AER output
//   * output spikes generate AER_OUT_ADDR = {4'b0010, s}
//   * STDP_PRE_SPIKE pulses on accepted input event
//   * STDP_POST_SPIKE pulses when the output neuron fires
//
// Weight numerical convention remains the temporary RTL convention:
// signed Q0.7.  Therefore raw +32 represents +0.25 membrane units.
// ============================================================================
module block2_digital_snn_tb;

    logic         CLK;
    logic         RST_N;
    logic         SE;
    logic         SI;
    logic         AER_IN_REQ;
    logic [7:0]   AER_IN_ADDR;
    logic [127:0] WEIGHT_IN;
    logic         AER_OUT_ACK;

    logic         SO;
    logic         AER_IN_ACK;
    logic         AER_OUT_REQ;
    logic [7:0]   AER_OUT_ADDR;
    logic [15:0]  STDP_PRE_SPIKE;
    logic [15:0]  STDP_POST_SPIKE;

    int tests_run;
    int tests_failed;

    block2_digital_snn dut (
        .CLK(CLK),
        .RST_N(RST_N),
        .SE(SE),
        .SI(SI),
        .AER_IN_REQ(AER_IN_REQ),
        .AER_IN_ADDR(AER_IN_ADDR),
        .WEIGHT_IN(WEIGHT_IN),
        .AER_OUT_ACK(AER_OUT_ACK),
        .SO(SO),
        .AER_IN_ACK(AER_IN_ACK),
        .AER_OUT_REQ(AER_OUT_REQ),
        .AER_OUT_ADDR(AER_OUT_ADDR),
        .STDP_PRE_SPIKE(STDP_PRE_SPIKE),
        .STDP_POST_SPIKE(STDP_POST_SPIKE)
    );

    always #5 CLK = ~CLK;

    task automatic check(input logic condition, input string message);
        begin
            tests_run++;
            if (!condition) begin
                tests_failed++;
                $error("FAIL: %s", message);
            end
            else begin
                $display("PASS: %s", message);
            end
        end
    endtask

    task automatic wait_clks(input int count);
        repeat (count) @(posedge CLK);
    endtask

    // Set one of the sixteen packed Team 3 weight channels.
    task automatic set_weight(
        input logic [3:0]        channel,
        input logic signed [7:0] weight
    );
        WEIGHT_IN[(channel * 8) +: 8] = weight;
    endtask

    // Send one legal Team-1-style AER packet.  Upper nibble is 0001 and lower
    // nibble is source/channel s.  The task completes only the input handshake;
    // neuron processing continues afterward in the DUT.
    task automatic send_event(
        input logic [3:0] source,
        input string      tag
    );
        begin
            @(negedge CLK);
            AER_IN_ADDR = {4'b0001, source};
            AER_IN_REQ  = 1'b1;

            @(posedge CLK);
            #1;
            check(AER_IN_ACK === 1'b1,
                  $sformatf("%s: input event acknowledged", tag));
            check(STDP_PRE_SPIKE[source] === 1'b1,
                  $sformatf("%s: STDP pre-spike pulse generated", tag));

            @(negedge CLK);
            AER_IN_REQ = 1'b0;

            @(posedge CLK);
            #1;
            check(AER_IN_ACK === 1'b0,
                  $sformatf("%s: input ACK returned low", tag));
        end
    endtask

    // Wait long enough for one hidden-only pass to finish.
    task automatic wait_hidden_only;
        begin
            // After WAIT_INPUT_REQ_LOW -> READ, the hidden pass executes:
            // READ, APPLY_LEAK, ADD_WEIGHT, THRESHOLD_CHECK, WRITE.
            wait_clks(5);
            #1;
        end
    endtask

    // Wait long enough for a hidden-spike + output pass to finish its output
    // WRITE state.  Caller can then inspect whether AER transmit follows.
    task automatic wait_hidden_and_output;
        begin
            // hidden READ/LEAK/ADD/THRESHOLD/WRITE = 5 clocks
            // output READ/LEAK/ADD/THRESHOLD/WRITE = 5 clocks
            wait_clks(10);
            #1;
        end
    endtask

    // Drive six +0.25-style events on one channel so the hidden neuron reaches
    // threshold once.  The first five events are hidden-only updates; the sixth
    // causes the hidden spike and therefore performs the output-layer pass.
    // The caller must configure the channel weight before calling this task.
    task automatic drive_one_hidden_spike(
        input logic [3:0] source,
        input string      tag
    );
        int k;
        begin
            for (k = 0; k < 5; k++) begin
                send_event(source, $sformatf("%s-H%0d", tag, k+1));
                wait_hidden_only();
            end
            send_event(source, $sformatf("%s-H6", tag));
            wait_hidden_and_output();
        end
    endtask

    task automatic complete_output_handshake(input string tag);
        begin
            // SEND_SPIKE raises REQ on the clock after output WRITE_NEURON.
            @(posedge CLK);
            #1;
            check(AER_OUT_REQ === 1'b1,
                  $sformatf("%s: outgoing AER request asserted", tag));

            @(negedge CLK);
            AER_OUT_ACK = 1'b1;
            @(posedge CLK);
            #1;
            check(AER_OUT_REQ === 1'b0,
                  $sformatf("%s: AER request dropped after ACK", tag));

            @(negedge CLK);
            AER_OUT_ACK = 1'b0;
            @(posedge CLK);
            #1;
        end
    endtask

    initial begin : test_sequence
        int n;

        CLK            = 1'b0;
        RST_N          = 1'b0;
        SE             = 1'b0;
        SI             = 1'b0;
        AER_IN_REQ     = 1'b0;
        AER_IN_ADDR    = 8'h00;
        WEIGHT_IN      = '0;
        AER_OUT_ACK    = 1'b0;
        tests_run      = 0;
        tests_failed   = 0;

        $dumpfile("simulation_output.vcd");
        $dumpvars(0, block2_digital_snn_tb);

        $display("\n============================================================");
        $display(" Team 2 two-layer time-multiplexed LIF testbench");
        $display(" hidden indices = 0..15, output indices = 16..31");
        $display(" beta      = 0.875 (Q0.8 raw 224)");
        $display(" threshold = 1.0   (Q4.8 raw 256)");
        $display(" reset     = 0.0   (Q4.8 raw 0)");
        $display(" weights   = temporary signed Q0.7 convention");
        $display("============================================================\n");

        // --------------------------------------------------------------------
        // TEST 1: reset initializes all 32 logical neurons.
        // --------------------------------------------------------------------
        wait_clks(3);
        @(negedge CLK);
        RST_N = 1'b1;
        @(posedge CLK);
        #1;

        check(AER_IN_ACK === 1'b0 && AER_OUT_REQ === 1'b0,
              "AER interfaces idle after reset");
        check(STDP_PRE_SPIKE === 16'h0000 && STDP_POST_SPIKE === 16'h0000,
              "STDP outputs idle after reset");

        for (n = 0; n < 32; n++)
            check(dut.V_M[n] === 12'sd0,
                  $sformatf("reset initializes neuron %0d", n));

        // --------------------------------------------------------------------
        // TEST 2: source s=3 updates hidden neuron 3 only if subthreshold.
        // W3 = +0.25 => hidden V3 becomes raw 64.  Output neuron 19 remains 0.
        // --------------------------------------------------------------------
        $display("\n--- TEST 2: HIDDEN-ONLY SUBTHRESHOLD UPDATE ---");
        set_weight(4'd3, 8'sd32);
        send_event(4'd3, "HIDDEN-SUB");
        wait_hidden_only();

        check(dut.V_M[3] === 12'sd64,
              "source 3 updates hidden neuron index 3");
        check(dut.V_M[19] === 12'sd0,
              "output neuron 16+3 is untouched when hidden neuron does not fire");
        check(AER_OUT_REQ === 1'b0,
              "hidden subthreshold update produces no external AER event");

        // --------------------------------------------------------------------
        // TEST 3: other channels are independent and select their own weights.
        // W4 = -0.25.  Hidden neuron 4 should become raw -64 while neuron 3
        // keeps its previous state.
        // --------------------------------------------------------------------
        $display("\n--- TEST 3: PACKED WEIGHT CHANNEL SELECTION ---");
        set_weight(4'd4, -8'sd32);
        send_event(4'd4, "WEIGHT-SEL");
        wait_hidden_only();
        check(dut.V_M[4] === -12'sd64,
              "source 4 consumes WEIGHT_IN channel 4");
        check(dut.V_M[3] === 12'sd64,
              "updating source 4 leaves hidden neuron 3 unchanged");

        // --------------------------------------------------------------------
        // TEST 4: hidden neuron 5 fires after six +0.25 events.
        // The resulting internal hidden spike causes exactly one output-layer
        // update of neuron 21 with the SAME channel-5 weight.
        // --------------------------------------------------------------------
        $display("\n--- TEST 4: HIDDEN SPIKE TRIGGERS OUTPUT PASS ---");
        set_weight(4'd5, 8'sd32);
        drive_one_hidden_spike(4'd5, "H5-FIRST");

        check(dut.V_M[5] === 12'sd0,
              "hidden neuron 5 hard-resets when it fires");
        check(dut.V_M[21] === 12'sd64,
              "hidden spike causes output neuron 21 to update with same W5");
        check(AER_OUT_REQ === 1'b0,
              "first hidden spike leaves output neuron subthreshold, so no AER output");

        // --------------------------------------------------------------------
        // TEST 5: repeat hidden-5 firing enough times for output neuron 21 to
        // accumulate six output-layer updates.  On the sixth output update it
        // crosses threshold, resets, pulses STDP_POST_SPIKE[5], and emits 0x25.
        //
        // This deliberately reaches the output threshold only through legal
        // AER traffic rather than writing V_M directly from the testbench.
        // --------------------------------------------------------------------
        $display("\n--- TEST 5: OUTPUT SPIKE / AER EMISSION ---");

        // One output update already happened in TEST 4.  Four more produce
        // output raw values 120, 169, 211, 248.
        for (n = 0; n < 4; n++) begin
            drive_one_hidden_spike(4'd5, $sformatf("H5-OUT-%0d", n+2));
            check(AER_OUT_REQ === 1'b0,
                  "output neuron remains subthreshold before sixth output update");
        end

        check(dut.V_M[21] === 12'sd248,
              "output neuron 21 reaches raw 248 before its firing update");

        // Sixth output update: output 21 crosses threshold.
        drive_one_hidden_spike(4'd5, "H5-OUT-6");
        check(dut.V_M[21] === 12'sd0,
              "output neuron 21 hard-resets after threshold crossing");
        check(STDP_POST_SPIKE[5] === 1'b1,
              "output firing pulses STDP_POST_SPIKE[5]");

        complete_output_handshake("OUT-FIRE");
        check(AER_OUT_ADDR === 8'h25,
              "output neuron 16+5 emits Team-2 AER address {0010,0101}");

        // --------------------------------------------------------------------
        // TEST 6: the channel weight is captured when the AER event is accepted
        // and the SAME captured value is reused for the hidden and output pass.
        // Build hidden neuron 6 to raw 248 with five ordinary events, then make
        // its sixth event the capture-stability test.
        // --------------------------------------------------------------------
        $display("\n--- TEST 6: SAME CAPTURED WEIGHT USED FOR BOTH LAYERS ---");
        set_weight(4'd6, 8'sd32);

        for (n = 0; n < 5; n++) begin
            send_event(4'd6, $sformatf("H6-PREP-%0d", n+1));
            wait_hidden_only();
        end
        check(dut.V_M[6] === 12'sd248,
              "hidden neuron 6 prepared to fire on next +0.25 event");
        check(dut.V_M[22] === 12'sd0,
              "output neuron 22 is still untouched before hidden 6 fires");

        @(negedge CLK);
        AER_IN_ADDR = {4'b0001, 4'd6};
        AER_IN_REQ  = 1'b1;
        @(posedge CLK);
        #1;
        check(AER_IN_ACK === 1'b1, "capture/reuse event acknowledged");
        check(STDP_PRE_SPIKE[6] === 1'b1,
              "capture/reuse event produces pre-spike pulse");

        @(negedge CLK);
        AER_IN_REQ = 1'b0;

        // Change Team 3's live bus after acceptance.  Both hidden and output
        // passes must still use the previously captured +0.25 value.
        set_weight(4'd6, -8'sd64);
        @(posedge CLK);
        #1;
        wait_hidden_and_output();

        check(dut.V_M[6] === 12'sd0,
              "hidden 6 fired using captured positive weight");
        check(dut.V_M[22] === 12'sd64,
              "output 22 reused the same captured +0.25 weight");

        // --------------------------------------------------------------------
        // Summary
        // --------------------------------------------------------------------
        $display("\n============================================================");
        $display(" TESTS RUN    : %0d", tests_run);
        $display(" TESTS FAILED : %0d", tests_failed);
        if (tests_failed == 0)
            $display(" RESULT       : PASS");
        else
            $display(" RESULT       : FAIL");
        $display("============================================================\n");

        if (tests_failed != 0)
            $fatal(1, "block2_digital_snn testbench failed");

        $finish;
    end

endmodule
