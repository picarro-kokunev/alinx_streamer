`timescale 1ns / 1ps

// Self-checking TB for stream_ctrl_regs ST_CALC_LEN / ST_WAIT_REP length path.
module tb_stream_ctrl_regs;
    reg         aclk = 0;
    reg         aresetn = 0;
    wire        bram_enb;
    wire [3:0]  bram_web;
    wire [31:0] bram_addrb;
    wire [31:0] bram_dinb;
    reg  [31:0] bram_doutb = 0;
    wire        start;
    wire [31:0] length_bytes;
    wire [31:0] seq_len_bytes;
    wire [31:0] repeat_count;
    reg         src_busy = 0;
    reg         src_done = 0;
    reg  [31:0] src_beat_count = 0;
    wire [3:0]  dbg_state;

    // Word-addressed register file (byte_offset >> 2)
    reg [31:0] mem [0:15];

    integer errors;
    integer starts_seen;
    integer i;

    localparam [3:0] ST_CALC_LEN = 4'd7;
    localparam [3:0] ST_WAIT_REP = 4'd8;

    stream_ctrl_regs #(
        .DEFAULT_LEN_BYTES(4096),
        .DEFAULT_SEQ_BYTES(4096),
        .DEFAULT_REPEAT(1)
    ) dut (
        .aclk(aclk),
        .aresetn(aresetn),
        .bram_enb(bram_enb),
        .bram_web(bram_web),
        .bram_addrb(bram_addrb),
        .bram_dinb(bram_dinb),
        .bram_doutb(bram_doutb),
        .start(start),
        .length_bytes(length_bytes),
        .seq_len_bytes(seq_len_bytes),
        .repeat_count(repeat_count),
        .src_busy(src_busy),
        .src_done(src_done),
        .src_beat_count(src_beat_count),
        .dbg_state(dbg_state)
    );

    always #5 aclk = ~aclk;

    // BRAM with READ_LATENCY=1 matching the FSM READ->WAIT pairs:
    // after address is updated (post-NBA), data is ready on the next FSM state.
    always @(posedge aclk) begin
        if (!aresetn) begin
            bram_doutb <= 32'd0;
        end else if (bram_enb) begin
            if (|bram_web)
                mem[bram_addrb[5:2]] = bram_dinb; // visible to subsequent read
            #1;
            bram_doutb <= mem[bram_addrb[5:2]];
        end
    end

    task automatic arm_and_check;
        input [31:0] length_w;
        input [31:0] seq_len_w;
        input [31:0] repeat_w;
        input [31:0] exp_length;
        input [31:0] exp_seq;
        input [31:0] exp_repeat;
        integer guard;
        reg saw_calc;
        reg [31:0] a_at_calc;
        begin
            mem[0] = 32'd0;       // CTRL
            mem[1] = length_w;    // LENGTH
            mem[2] = 32'd0;       // STATUS
            mem[3] = 32'd0;       // BEAT_CNT
            mem[4] = seq_len_w;   // SEQ_LEN
            mem[5] = repeat_w;    // REPEAT

            // Let the FSM poll idle with CTRL=0
            repeat (16) @(posedge aclk);

            // Pulse host start
            mem[0] = 32'd1;

            starts_seen = 0;
            saw_calc = 0;
            guard = 0;
            while (starts_seen == 0 && guard < 400) begin
                @(posedge aclk);
                guard = guard + 1;

                if (dbg_state == ST_CALC_LEN) begin
                    saw_calc = 1;
                    a_at_calc = dut.pending_mult_by_bram_doutb;
                end

                if (start) begin
                    starts_seen = 1;

                    if (!saw_calc) begin
                        $display("FAIL: start without visiting ST_CALC_LEN");
                        errors = errors + 1;
                    end

                    if (length_bytes !== exp_length) begin
                        $display("FAIL length_bytes got=%0d exp=%0d (seq=%0d rep=%0d prod=%0d)",
                                 length_bytes, exp_length, seq_len_w, repeat_w,
                                 dut.pending_mult_by_bram_doutb);
                        errors = errors + 1;
                    end
                    if (seq_len_bytes !== exp_seq) begin
                        $display("FAIL seq_len_bytes got=%0d exp=%0d",
                                 seq_len_bytes, exp_seq);
                        errors = errors + 1;
                    end
                    if (repeat_count !== exp_repeat) begin
                        $display("FAIL repeat_count got=%0d exp=%0d",
                                 repeat_count, exp_repeat);
                        errors = errors + 1;
                    end

                    // When REPEAT!=0, length must come from registered product
                    if (repeat_w != 0 && dut.pending_mult_by_bram_doutb !== exp_length) begin
                        $display("FAIL pending_mult_by_bram_doutb got=%0d exp=%0d",
                                 dut.pending_mult_by_bram_doutb, exp_length);
                        errors = errors + 1;
                    end

                    if (length_bytes === exp_length &&
                        seq_len_bytes === exp_seq &&
                        repeat_count === exp_repeat) begin
                        $display("PASS length=%0d seq=%0d repeat=%0d (via pending_mult_by_bram_doutb)",
                                 length_bytes, seq_len_bytes, repeat_count);
                    end
                end
            end

            if (starts_seen == 0) begin
                $display("FAIL: start never asserted (seq=%0d rep=%0d) last_state=%0d CTRL_mem=%0d",
                         seq_len_w, repeat_w, dbg_state, mem[0]);
                errors = errors + 1;
            end

            // Ensure CTRL stays clear for next case
            mem[0] = 32'd0;
            repeat (24) @(posedge aclk);
        end
    endtask

    initial begin
        errors = 0;
        for (i = 0; i < 16; i = i + 1)
            mem[i] = 32'd0;

        repeat (2) @(posedge aclk);
        aresetn = 1;
        repeat (4) @(posedge aclk);

        // SEQ*REP via pending_mult_by_bram_doutb
        arm_and_check(32'd9999, 32'd512, 32'd10, 32'd5120, 32'd512, 32'd10);
        // REPEAT==0 falls back to LENGTH
        arm_and_check(32'd2048, 32'd256, 32'd0,  32'd2048, 32'd256, 32'd1);
        // small values
        arm_and_check(32'd100,  32'd8,   32'd3,  32'd24,   32'd8,   32'd3);
        // SEQ_LEN < 8 clamps to 8 before multiply
        arm_and_check(32'd100,  32'd4,   32'd4,  32'd32,   32'd8,   32'd4);

        if (errors == 0) begin
            $display("ALL TESTS PASSED");
            $finish(0);
        end else begin
            $display("FAILED with %0d error(s)", errors);
            $finish(1);
        end
    end

    initial begin
        #200000;
        $display("FAIL: timeout");
        $finish(1);
    end
endmodule
