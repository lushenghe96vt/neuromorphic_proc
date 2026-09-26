`timescale 1ns/1ps

// this tb is AI generated, I will include thel logs in this directroy

module block2_digital_snn_tb;
    // ================================================================
    // Verification-only parameter sets.
    // These values are chosen to exercise functionality; they are not
    // proposed final architectural constants.
    // ================================================================
    localparam logic [7:0] BETA_TEST = 8'd255;

    // Normal positive-weight DUT: convenient threshold crossing after
    // two updates of the same neuron.
    localparam logic signed [7:0]  POS_WEIGHT    = 8'sd1;
    localparam logic signed [11:0] POS_THRESHOLD = 12'sd500;
    localparam logic signed [11:0] POS_RESET     = 12'sd0;

    // Normal negative-weight DUT.
    localparam logic signed [7:0]  NEG_WEIGHT    = -8'sd1;
    localparam logic signed [11:0] NEG_THRESHOLD = 12'sd500;
    localparam logic signed [11:0] NEG_RESET     = 12'sd0;

    // Signed 8-bit maximum weight boundary.
    // A very large positive candidate must cross the largest possible
    // signed 12-bit threshold and therefore take the spike/reset path.
    localparam logic signed [7:0]  MAX_WEIGHT    = 8'sd127;
    localparam logic signed [11:0] MAX_THRESHOLD = 12'sd2047;
    localparam logic signed [11:0] MAX_RESET     = -12'sd123;

    // Signed 8-bit minimum weight boundary.
    // This produces a candidate below the signed 12-bit minimum and
    // therefore exercises the negative saturation clamp to -2048.
    localparam logic signed [7:0]  MIN_WEIGHT    = -8'sd128;
    localparam logic signed [11:0] MIN_THRESHOLD = 12'sd2047;
    localparam logic signed [11:0] MIN_RESET     = 12'sd0;

    // ================================================================
    // Common controls
    // ================================================================
    logic CLK;
    logic RST_N;
    logic SE;
    logic SI;

    // Positive DUT interface
    logic       pos_in_req;
    logic [7:0] pos_in_addr;
    logic       pos_out_ack;
    logic       pos_so;
    logic       pos_in_ack;
    logic       pos_out_req;
    logic [7:0] pos_out_addr;

    // Negative DUT interface
    logic       neg_in_req;
    logic [7:0] neg_in_addr;
    logic       neg_out_ack;
    logic       neg_so;
    logic       neg_in_ack;
    logic       neg_out_req;
    logic [7:0] neg_out_addr;

    // Maximum-value DUT interface
    logic       max_in_req;
    logic [7:0] max_in_addr;
    logic       max_out_ack;
    logic       max_so;
    logic       max_in_ack;
    logic       max_out_req;
    logic [7:0] max_out_addr;

    // Minimum-value DUT interface
    logic       min_in_req;
    logic [7:0] min_in_addr;
    logic       min_out_ack;
    logic       min_so;
    logic       min_in_ack;
    logic       min_out_req;
    logic [7:0] min_out_addr;

    int tests_run    = 0;
    int tests_failed = 0;

    // ================================================================
    // DUT instances
    // ================================================================
    block2_digital_snn #(
        .BETA_VALUE      (BETA_TEST),
        .WEIGHT_VALUE    (POS_WEIGHT),
        .THRESHOLD_VALUE (POS_THRESHOLD),
        .RESET_VALUE     (POS_RESET)
    ) dut_pos (
        .CLK          (CLK),
        .RST_N        (RST_N),
        .SE           (SE),
        .SI           (SI),
        .AER_IN_REQ   (pos_in_req),
        .AER_IN_ADDR  (pos_in_addr),
        .AER_OUT_ACK  (pos_out_ack),
        .SO           (pos_so),
        .AER_IN_ACK   (pos_in_ack),
        .AER_OUT_REQ  (pos_out_req),
        .AER_OUT_ADDR (pos_out_addr)
    );

    block2_digital_snn #(
        .BETA_VALUE      (BETA_TEST),
        .WEIGHT_VALUE    (NEG_WEIGHT),
        .THRESHOLD_VALUE (NEG_THRESHOLD),
        .RESET_VALUE     (NEG_RESET)
    ) dut_neg (
        .CLK          (CLK),
        .RST_N        (RST_N),
        .SE           (SE),
        .SI           (SI),
        .AER_IN_REQ   (neg_in_req),
        .AER_IN_ADDR  (neg_in_addr),
        .AER_OUT_ACK  (neg_out_ack),
        .SO           (neg_so),
        .AER_IN_ACK   (neg_in_ack),
        .AER_OUT_REQ  (neg_out_req),
        .AER_OUT_ADDR (neg_out_addr)
    );

    block2_digital_snn #(
        .BETA_VALUE      (BETA_TEST),
        .WEIGHT_VALUE    (MAX_WEIGHT),
        .THRESHOLD_VALUE (MAX_THRESHOLD),
        .RESET_VALUE     (MAX_RESET)
    ) dut_max (
        .CLK          (CLK),
        .RST_N        (RST_N),
        .SE           (SE),
        .SI           (SI),
        .AER_IN_REQ   (max_in_req),
        .AER_IN_ADDR  (max_in_addr),
        .AER_OUT_ACK  (max_out_ack),
        .SO           (max_so),
        .AER_IN_ACK   (max_in_ack),
        .AER_OUT_REQ  (max_out_req),
        .AER_OUT_ADDR (max_out_addr)
    );

    block2_digital_snn #(
        .BETA_VALUE      (BETA_TEST),
        .WEIGHT_VALUE    (MIN_WEIGHT),
        .THRESHOLD_VALUE (MIN_THRESHOLD),
        .RESET_VALUE     (MIN_RESET)
    ) dut_min (
        .CLK          (CLK),
        .RST_N        (RST_N),
        .SE           (SE),
        .SI           (SI),
        .AER_IN_REQ   (min_in_req),
        .AER_IN_ADDR  (min_in_addr),
        .AER_OUT_ACK  (min_out_ack),
        .SO           (min_so),
        .AER_IN_ACK   (min_in_ack),
        .AER_OUT_REQ  (min_out_req),
        .AER_OUT_ADDR (min_out_addr)
    );

    always #5 CLK = ~CLK;

    // ================================================================
    // Checking / timing helpers
    // ================================================================
    task automatic check(input bit condition, input string message);
        tests_run++;
        if (!condition) begin
            tests_failed++;
            $error("FAIL: %s", message);
        end
        else begin
            $display("PASS: %s", message);
        end
    endtask

    task automatic wait_clks(input int n);
        repeat (n) @(posedge CLK);
    endtask

    // Complete an input four-phase transaction.  This task waits through
    // WAIT_INPUT_REQ_LOW -> READ_NEURON -> WRITE_NEURON, so the state write
    // has occurred when it returns.  It is intended for non-spiking cases.
    task automatic send_event_nonspiking(
        ref logic       req,
        ref logic [7:0] addr_bus,
        ref logic       in_ack,
        input logic [7:0] addr,
        input string     tag
    );
        begin
            @(negedge CLK);
            addr_bus = addr;
            req      = 1'b1;

            @(posedge CLK);
            #1;
            check(in_ack === 1'b1,
                  $sformatf("%s: input address 0x%02h acknowledged", tag, addr));

            @(negedge CLK);
            req = 1'b0;

            // WAIT_INPUT_REQ_LOW, READ_NEURON, WRITE_NEURON
            wait_clks(3);
            #1;
            check(in_ack === 1'b0,
                  $sformatf("%s: input ACK returned low", tag));
        end
    endtask

    // Start an input transaction and wait through WRITE_NEURON.  A spiking
    // transaction will enter SEND_SPIKE; AER_OUT_REQ asserts one clock later.
    task automatic send_event_to_write(
        ref logic       req,
        ref logic [7:0] addr_bus,
        ref logic       in_ack,
        input logic [7:0] addr,
        input string     tag
    );
        begin
            @(negedge CLK);
            addr_bus = addr;
            req      = 1'b1;

            @(posedge CLK);
            #1;
            check(in_ack === 1'b1,
                  $sformatf("%s: input address 0x%02h acknowledged", tag, addr));

            @(negedge CLK);
            req = 1'b0;

            wait_clks(3);
            #1;
            check(in_ack === 1'b0,
                  $sformatf("%s: input ACK returned low", tag));
        end
    endtask

    // ================================================================
    // Main directed test sequence
    // ================================================================
    initial begin : test_sequence
        
	int n;
        logic signed [11:0] neuron1_before;

        CLK = 1'b0;
        RST_N = 1'b0;
        SE = 1'b0;
        SI = 1'b0;

        pos_in_req = 1'b0;
        pos_in_addr = 8'h00;
        pos_out_ack = 1'b0;

        neg_in_req = 1'b0;
        neg_in_addr = 8'h00;
        neg_out_ack = 1'b0;

        max_in_req = 1'b0;
        max_in_addr = 8'h00;
        max_out_ack = 1'b0;

        min_in_req = 1'b0;
        min_in_addr = 8'h00;
        min_out_ack = 1'b0;

	$dumpfile("simulation_output.vcd"); // for simulation
	$dumpvars;

        $display("\n============================================================");
        $display(" block2_digital_snn multi-configuration testbench");
        $display(" POS: W=%0d TH=%0d RESET=%0d", $signed(POS_WEIGHT), $signed(POS_THRESHOLD), $signed(POS_RESET));
        $display(" NEG: W=%0d TH=%0d RESET=%0d", $signed(NEG_WEIGHT), $signed(NEG_THRESHOLD), $signed(NEG_RESET));
        $display(" MAX: W=%0d TH=%0d RESET=%0d", $signed(MAX_WEIGHT), $signed(MAX_THRESHOLD), $signed(MAX_RESET));
        $display(" MIN: W=%0d TH=%0d RESET=%0d", $signed(MIN_WEIGHT), $signed(MIN_THRESHOLD), $signed(MIN_RESET));
        $display("============================================================\n");

        // ------------------------------------------------------------
        // TEST 1: Reset / idle behavior for every configuration
        // ------------------------------------------------------------
        $display("\n--- TEST 1: RESET / IDLE ---");
        wait_clks(3);
        @(negedge CLK);
        RST_N = 1'b1;
        @(posedge CLK);
        #1;

        check(pos_in_ack  === 1'b0 && pos_out_req === 1'b0,
              "positive DUT reset leaves AER interface idle");
        check(neg_in_ack  === 1'b0 && neg_out_req === 1'b0,
              "negative DUT reset leaves AER interface idle");
        check(max_in_ack  === 1'b0 && max_out_req === 1'b0,
              "maximum DUT reset leaves AER interface idle");
        check(min_in_ack  === 1'b0 && min_out_req === 1'b0,
              "minimum DUT reset leaves AER interface idle");

        for (n = 0; n < 32; n++) begin
            check(dut_pos.V_M[n] === 12'sd0,
                  $sformatf("positive DUT reset clears neuron %0d", n));
            check(dut_neg.V_M[n] === 12'sd0,
                  $sformatf("negative DUT reset clears neuron %0d", n));
            check(dut_max.V_M[n] === 12'sd0,
                  $sformatf("maximum DUT reset clears neuron %0d", n));
            check(dut_min.V_M[n] === 12'sd0,
                  $sformatf("minimum DUT reset clears neuron %0d", n));
        end

        // ------------------------------------------------------------
        // TEST 2: Positive weight + every neuron updateable
        // beta=255, W=+1: from zero the current RTL produces +255.
        // ------------------------------------------------------------
        $display("\n--- TEST 2: POSITIVE WEIGHT / ALL 32 NEURONS ---");
        for (n = 0; n < 32; n++) begin
            send_event_nonspiking(pos_in_req, pos_in_addr, pos_in_ack,
                                  n[7:0], "POS");

            check(dut_pos.V_M[n] === 12'sd255,
                  $sformatf("POS: neuron %0d updated from 0 to +255", n));
            check(pos_out_req === 1'b0,
                  $sformatf("POS: neuron %0d did not spike below threshold", n));
        end

        // Verify independent retention after all 32 were targeted.
        for (n = 0; n < 32; n++) begin
            check(dut_pos.V_M[n] === 12'sd255,
                  $sformatf("POS: neuron %0d retained independent state", n));
        end

        // ------------------------------------------------------------
        // TEST 3: Two different neurons are independently addressable
        // using the current temporary AER_IN_ADDR[4:0] mapping.
        // ------------------------------------------------------------
        $display("\n--- TEST 3: TWO DIFFERENT NEURONS ---");
        check(dut_pos.V_M[10] === 12'sd255 && dut_pos.V_M[11] === 12'sd255,
              "neurons 10 and 11 begin with the same known state");

        // A second event on neuron 10 crosses the chosen threshold and resets
        // neuron 10.  Neuron 11 must remain unchanged.
        send_event_to_write(pos_in_req, pos_in_addr, pos_in_ack, 8'd10, "POS-N10");
        check(dut_pos.V_M[10] === POS_RESET,
              "second event updates only neuron 10 and applies post-spike reset");
        check(dut_pos.V_M[11] === 12'sd255,
              "updating neuron 10 does not modify neuron 11");

        @(posedge CLK); // SEND_SPIKE asserts request
        #1;
        check(pos_out_req === 1'b1,
              "second event on neuron 10 produces an outgoing spike");
        check(pos_out_addr === 8'h2A,
              "spike address reflects Team-2 tile ID and source nibble A");

        // Finish this spike before continuing.
        pos_out_ack = 1'b1;
        @(posedge CLK);
        #1;
        check(pos_out_req === 1'b0,
              "POS: output request drops after downstream ACK");
        @(negedge CLK);
        pos_out_ack = 1'b0;
        @(posedge CLK);
        #1;

        // ------------------------------------------------------------
        // TEST 4: Negative weight datapath
        // beta=255, W=-1: from zero the current RTL produces -255.
        // ------------------------------------------------------------
        $display("\n--- TEST 4: NEGATIVE WEIGHT ---");
        send_event_nonspiking(neg_in_req, neg_in_addr, neg_in_ack, 8'd5, "NEG-N5");
        check(dut_neg.V_M[5] === -12'sd255,
              "negative weight decreases neuron 5 from 0 to -255");
        check(neg_out_req === 1'b0,
              "negative update below threshold does not produce a spike");

        send_event_nonspiking(neg_in_req, neg_in_addr, neg_in_ack, 8'd6, "NEG-N6");
        check(dut_neg.V_M[6] === -12'sd255,
              "negative weight independently updates neuron 6");
        check(dut_neg.V_M[5] === -12'sd255,
              "updating neuron 6 preserves neuron 5 state");

        // ------------------------------------------------------------
        // TEST 5: Input backpressure while shared datapath is busy
        // Use fresh POS neurons 20 and 21 (currently +255 after TEST 2).
        // ------------------------------------------------------------
        $display("\n--- TEST 5: INPUT WHILE DATAPATH BUSY ---");
        neuron1_before = dut_pos.V_M[21];

        @(negedge CLK);
        pos_in_addr = 8'd20;
        pos_in_req  = 1'b1;
        @(posedge CLK);
        #1;
        check(pos_in_ack === 1'b1,
              "busy test first request is accepted");

        @(negedge CLK);
        pos_in_req = 1'b0;
        @(posedge CLK); // WAIT_INPUT_REQ_LOW -> READ_NEURON
        #1;
        check(pos_in_ack === 1'b0,
              "busy test first handshake completes");

        // Present a second request during READ_NEURON.
        @(negedge CLK);
        pos_in_addr = 8'd21;
        pos_in_req  = 1'b1;
        @(posedge CLK); // READ_NEURON executes
        #1;
        check(pos_in_ack === 1'b0,
              "second input is not acknowledged while datapath is busy");
        check(dut_pos.V_M[21] === neuron1_before,
              "busy-time request does not modify second neuron");

        @(negedge CLK);
        pos_in_req = 1'b0;
        @(posedge CLK); // WRITE_NEURON for neuron 20
        #1;
        check(dut_pos.V_M[20] === POS_RESET,
              "first busy-test neuron completes its threshold/reset update");
        check(dut_pos.V_M[21] === neuron1_before,
              "unaccepted busy-time event leaves neuron 21 unchanged");

        // ------------------------------------------------------------
        // TEST 6: Threshold spike + blocked output + blocked new input
        // ------------------------------------------------------------
        $display("\n--- TEST 6: OUTPUT BACKPRESSURE ---");
        @(posedge CLK); // SEND_SPIKE raises AER_OUT_REQ
        #1;
        check(pos_out_req === 1'b1,
              "threshold crossing generates AER_OUT_REQ");
        check(pos_out_addr === 8'h24,
              "output spike address is stable for source nibble 4");

        repeat (3) begin
            @(posedge CLK);
            #1;
            check(pos_out_req === 1'b1,
                  "AER_OUT_REQ remains high while downstream ACK is low");
            check(pos_out_addr === 8'h24,
                  "AER_OUT_ADDR remains stable while output is blocked");
        end

        // Attempt another input while output request is blocked.
        @(negedge CLK);
        pos_in_addr = 8'd22;
        pos_in_req  = 1'b1;
        @(posedge CLK);
        #1;
        check(pos_in_ack === 1'b0,
              "new input is rejected while outgoing spike is blocked");
        check(dut_pos.V_M[22] === 12'sd255,
              "blocked input does not alter its target neuron");
        @(negedge CLK);
        pos_in_req = 1'b0;

        // Complete output handshake.
        pos_out_ack = 1'b1;
        @(posedge CLK);
        #1;
        check(pos_out_req === 1'b0,
              "AER_OUT_REQ drops after downstream ACK");

        // Still blocked until ACK returns low.
        @(negedge CLK);
        pos_in_addr = 8'd23;
        pos_in_req  = 1'b1;
        @(posedge CLK);
        #1;
        check(pos_in_ack === 1'b0,
              "input remains blocked until AER_OUT_ACK returns low");

        @(negedge CLK);
        pos_in_req  = 1'b0;
        pos_out_ack = 1'b0;
        @(posedge CLK);
        #1;

        // ------------------------------------------------------------
        // TEST 7: Maximum signed weight (+127)
        // With beta=255, the candidate from zero is far above +2047.
        // Because spike detection occurs BEFORE saturation in the RTL and
        // +2047 is the largest representable threshold, positive overflow
        // necessarily follows the spike/reset path.
        // ------------------------------------------------------------
        $display("\n--- TEST 7: MAXIMUM SIGNED WEIGHT (+127) ---");
        send_event_to_write(max_in_req, max_in_addr, max_in_ack, 8'd9, "MAX");

        check(dut_max.saved_spike === 1'b1,
              "maximum positive weight is detected as threshold crossing");
        check(dut_max.V_M[9] === MAX_RESET,
              $sformatf("maximum positive case writes configured reset value %0d",
                        $signed(MAX_RESET)));

        @(posedge CLK); // SEND_SPIKE
        #1;
        check(max_out_req === 1'b1,
              "maximum positive-weight case generates a spike");
        check(max_out_addr === 8'h29,
              "maximum positive-weight spike carries expected address");

        max_out_ack = 1'b1;
        @(posedge CLK);
        #1;
        check(max_out_req === 1'b0,
              "maximum-case spike request completes on ACK");
        @(negedge CLK);
        max_out_ack = 1'b0;
        @(posedge CLK);
        #1;

        // ------------------------------------------------------------
        // TEST 8: Minimum signed weight (-128) / negative saturation
        // From zero, beta=255 and W=-128 create a candidate below -2048,
        // so the datapath must clamp the stored membrane voltage to -2048.
        // ------------------------------------------------------------
        $display("\n--- TEST 8: MINIMUM SIGNED WEIGHT (-128) ---");
        send_event_nonspiking(min_in_req, min_in_addr, min_in_ack, 8'd12, "MIN");

        check(dut_min.V_M[12] === -12'sd2048,
              "minimum negative weight saturates membrane voltage at -2048");
        check(min_out_req === 1'b0,
              "negative saturation does not spuriously generate a spike");

        // Apply the minimum weight again.  The state must remain clamped,
        // proving that the lower boundary does not wrap around.
        send_event_nonspiking(min_in_req, min_in_addr, min_in_ack, 8'd12, "MIN-REPEAT");
        check(dut_min.V_M[12] === -12'sd2048,
              "repeated minimum update remains clamped at -2048 without wraparound");
        check(min_out_req === 1'b0,
              "repeated negative saturation still does not generate a spike");

        // ------------------------------------------------------------
        // TEST 9: Recovery after completed output handshake
        // Use NEG DUT because it is currently idle and produces no spike.
        // ------------------------------------------------------------
        $display("\n--- TEST 9: RECOVERY / CONTINUED OPERATION ---");
        send_event_nonspiking(neg_in_req, neg_in_addr, neg_in_ack, 8'd7, "NEG-RECOVERY");
        check(dut_neg.V_M[7] === -12'sd255,
              "DUT continues accepting new transactions after earlier tests");

        // ------------------------------------------------------------
        // Summary
        // ------------------------------------------------------------
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

    // Simulation watchdog.
    initial begin
        #200000;
        $fatal(1, "Simulation timeout");
    end

endmodule

