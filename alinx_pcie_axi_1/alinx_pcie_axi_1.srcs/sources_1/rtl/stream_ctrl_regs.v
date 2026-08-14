`timescale 1ns / 1ps

// Reads stream control registers from BRAM port B (same memory the host writes
// via /dev/xdma0_user on port A).  Writes STATUS/BEAT_CNT back through port B.
//
// Register map (byte offsets):
//   0x00  CTRL     [0]=start (host sets, FPGA clears on accept)
//   0x04  LENGTH   total transfer length in bytes (used if REPEAT==0)
//   0x08  STATUS   [0]=busy [1]=done (written by FPGA)
//   0x0C  BEAT_CNT beats transferred (written by FPGA)
//   0x10  SEQ_LEN  sequence period in pattern BRAM (bytes, multiple of 8)
//   0x14  REPEAT   number of times to play the sequence (0 => use LENGTH)
module stream_ctrl_regs #(
    parameter integer DEFAULT_LEN_BYTES = 4096,
    parameter integer DEFAULT_SEQ_BYTES = 4096,
    parameter integer DEFAULT_REPEAT    = 1
) (
    input  wire        aclk,
    input  wire        aresetn,
    output reg         bram_enb,
    output reg  [3:0]  bram_web,
    output reg  [31:0] bram_addrb,
    output reg  [31:0] bram_dinb,
    input  wire [31:0] bram_doutb,
    output reg         start,
    output reg  [31:0] length_bytes,
    output reg  [31:0] seq_len_bytes,
    output reg  [31:0] repeat_count,
    input  wire        src_busy,
    input  wire        src_done,
    input  wire [31:0] src_beat_count,
    output wire [3:0]  dbg_state
);

    localparam [31:0] OFF_CTRL     = 32'h00;
    localparam [31:0] OFF_LENGTH   = 32'h04;
    localparam [31:0] OFF_STATUS   = 32'h08;
    localparam [31:0] OFF_BEAT_CNT = 32'h0C;
    localparam [31:0] OFF_SEQ_LEN  = 32'h10;
    localparam [31:0] OFF_REPEAT   = 32'h14;

    localparam [3:0] ST_READ_CTRL   = 4'd0;
    localparam [3:0] ST_WAIT_CTRL   = 4'd1;
    localparam [3:0] ST_READ_LEN    = 4'd2;
    localparam [3:0] ST_WAIT_LEN    = 4'd3;
    localparam [3:0] ST_READ_SEQ    = 4'd4;
    localparam [3:0] ST_WAIT_SEQ    = 4'd5;
    localparam [3:0] ST_READ_REP    = 4'd6;
    localparam [3:0] ST_CALC_LEN    = 4'd7;  // pending_mult_by_bram_doutb <= pending_seq * REPEAT
    localparam [3:0] ST_WAIT_REP    = 4'd8;  // length_bytes <= pending_mult_by_bram_doutb (or LENGTH)
    localparam [3:0] ST_CLEAR_START = 4'd9;
    localparam [3:0] ST_WRITE_STAT  = 4'd10;
    localparam [3:0] ST_WRITE_BEATS = 4'd11;

    reg [3:0]  state;
    reg [31:0] ctrl_reg;
    reg        ctrl_prev_start;
    reg [31:0] pending_len;
    reg [31:0] pending_seq;
    reg [31:0] pending_rep;
    reg [31:0] pending_mult_by_bram_doutb;  // SEQ_LEN * REPEAT product

    wire host_start = ctrl_reg[0];
    wire start_edge = host_start & ~ctrl_prev_start;

    always @(posedge aclk) begin
        if (!aresetn) begin
            state                       <= ST_READ_CTRL;
            bram_enb                    <= 1'b0;
            bram_web                    <= 4'h0;
            bram_addrb                  <= OFF_CTRL;
            bram_dinb                   <= 32'd0;
            ctrl_reg                    <= 32'd0;
            ctrl_prev_start             <= 1'b0;
            start                       <= 1'b0;
            length_bytes                <= DEFAULT_LEN_BYTES;
            seq_len_bytes               <= DEFAULT_SEQ_BYTES;
            repeat_count                <= DEFAULT_REPEAT;
            pending_len                 <= DEFAULT_LEN_BYTES;
            pending_seq                 <= DEFAULT_SEQ_BYTES;
            pending_rep                 <= DEFAULT_REPEAT;
            pending_mult_by_bram_doutb  <= 32'd0;
        end else begin
            start    <= 1'b0;
            bram_enb <= 1'b1;
            bram_web <= 4'h0;

            case (state)
                ST_READ_CTRL: begin
                    bram_addrb <= OFF_CTRL;
                    state      <= ST_WAIT_CTRL;
                end

                ST_WAIT_CTRL: begin
                    ctrl_reg        <= bram_doutb;
                    ctrl_prev_start <= host_start;
                    if (start_edge && !src_busy)
                        state <= ST_READ_LEN;
                    else
                        state <= ST_WRITE_STAT;
                end

                ST_READ_LEN: begin
                    bram_addrb <= OFF_LENGTH;
                    state      <= ST_WAIT_LEN;
                end

                ST_WAIT_LEN: begin
                    pending_len <= (bram_doutb < 32'd8) ? 32'd8 : bram_doutb;
                    state       <= ST_READ_SEQ;
                end

                ST_READ_SEQ: begin
                    bram_addrb <= OFF_SEQ_LEN;
                    state      <= ST_WAIT_SEQ;
                end

                ST_WAIT_SEQ: begin
                    pending_seq <= (bram_doutb < 32'd8) ? 32'd8 : bram_doutb;
                    state       <= ST_READ_REP;
                end

                ST_READ_REP: begin
                    bram_addrb <= OFF_REPEAT;
                    state      <= ST_CALC_LEN;
                end

                // BRAM REPEAT value is valid on dout; compute product
                ST_CALC_LEN: begin
                    pending_mult_by_bram_doutb <= pending_seq * bram_doutb;
                    pending_rep                <= bram_doutb;
                    state                      <= ST_WAIT_REP;
                end

                ST_WAIT_REP: begin
                    // REPEAT==0 => use LENGTH as total; else total = pending_mult_by_bram_doutb
                    if (pending_rep != 32'd0) begin
                        length_bytes <= pending_mult_by_bram_doutb;
                        repeat_count <= pending_rep;
                    end else begin
                        length_bytes <= pending_len;
                        repeat_count <= 32'd1;
                    end
                    seq_len_bytes <= pending_seq;
                    start         <= 1'b1;
                    state         <= ST_CLEAR_START;
                end

                ST_CLEAR_START: begin
                    bram_addrb <= OFF_CTRL;
                    bram_web   <= 4'hF;
                    bram_dinb  <= ctrl_reg & 32'hFFFFFFFE;
                    state      <= ST_WRITE_STAT;
                end

                ST_WRITE_STAT: begin
                    bram_addrb <= OFF_STATUS;
                    bram_web   <= 4'hF;
                    bram_dinb  <= {30'd0, src_done, src_busy};
                    state      <= ST_WRITE_BEATS;
                end

                ST_WRITE_BEATS: begin
                    bram_addrb <= OFF_BEAT_CNT;
                    bram_web   <= 4'hF;
                    bram_dinb  <= src_beat_count;
                    state      <= ST_READ_CTRL;
                end

                default: state <= ST_READ_CTRL;
            endcase
        end
    end

    assign dbg_state = state;

endmodule
