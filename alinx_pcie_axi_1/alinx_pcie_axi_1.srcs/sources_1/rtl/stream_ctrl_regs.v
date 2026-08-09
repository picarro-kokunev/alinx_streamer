`timescale 1ns / 1ps

// Reads stream control registers from BRAM port B (same memory the host writes
// via /dev/xdma0_user on port A).  Writes STATUS/BEAT_CNT back through port B.
//
// Register map (32-bit word offsets):
//   0x00  CTRL    [0]=start (host sets, FPGA clears on accept)
//   0x04  LENGTH  transfer length in bytes (multiple of 8)
//   0x08  STATUS  [0]=busy [1]=done (written by FPGA)
//   0x0C  BEAT_CNT
//   0x10  SEED_LO
//   0x14  SEED_HI
module stream_ctrl_regs #(
    parameter integer DEFAULT_LEN_BYTES = 4096
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
    output reg  [63:0] seed,
    input  wire        src_busy,
    input  wire        src_done,
    input  wire [31:0] src_beat_count,
    output wire [2:0] dbg_state   // assign dbg_state = state;    
);

    localparam [31:0] OFF_CTRL     = 32'h00;
    localparam [31:0] OFF_LENGTH   = 32'h04;
    localparam [31:0] OFF_STATUS   = 32'h08;
    localparam [31:0] OFF_BEAT_CNT = 32'h0C;
    localparam [31:0] OFF_SEED_LO  = 32'h10;
    localparam [31:0] OFF_SEED_HI  = 32'h14;

    localparam [2:0] ST_READ_CTRL    = 3'd0;
    localparam [2:0] ST_WAIT_CTRL    = 3'd1;
    localparam [2:0] ST_READ_LEN     = 3'd2;
    localparam [2:0] ST_WAIT_LEN     = 3'd3;
    localparam [2:0] ST_READ_SEED_L  = 3'd4;
    localparam [2:0] ST_WAIT_SEED_L  = 3'd5;
    localparam [2:0] ST_READ_SEED_H  = 3'd6;
    localparam [2:0] ST_WAIT_SEED_H  = 3'd7;
    localparam [2:0] ST_CLEAR_START  = 3'd8;
    localparam [2:0] ST_WRITE_STAT   = 3'd9;
    localparam [2:0] ST_WRITE_BEATS  = 3'd10;

    reg [2:0]  state;
    reg [31:0] ctrl_reg;
    reg        ctrl_prev_start;
    reg [31:0] seed_lo;
    reg [31:0] pending_len;
    reg [31:0] pending_seed_hi;

    wire host_start  = ctrl_reg[0];
    wire start_edge  = host_start & ~ctrl_prev_start;

    always @(posedge aclk) begin
        if (!aresetn) begin
            state           <= ST_READ_CTRL;
            bram_enb        <= 1'b0;
            bram_web        <= 4'h0;
            bram_addrb      <= OFF_CTRL;
            bram_dinb       <= 32'd0;
            ctrl_reg        <= 32'd0;
            ctrl_prev_start <= 1'b0;
            start           <= 1'b0;
            length_bytes    <= DEFAULT_LEN_BYTES;
            seed            <= 64'd0;
            seed_lo         <= 32'd0;
            pending_len     <= DEFAULT_LEN_BYTES;
            pending_seed_hi <= 32'd0;
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
                    if (start_edge && !src_busy) begin
                        state <= ST_READ_LEN;
                    end else begin
                        state <= ST_WRITE_STAT;
                    end
                end

                ST_READ_LEN: begin
                    bram_addrb <= OFF_LENGTH;
                    state      <= ST_WAIT_LEN;
                end

                ST_WAIT_LEN: begin
                    pending_len <= (bram_doutb < 32'd8) ? 32'd8 : bram_doutb;
                    state       <= ST_READ_SEED_L;
                end

                ST_READ_SEED_L: begin
                    bram_addrb <= OFF_SEED_LO;
                    state      <= ST_WAIT_SEED_L;
                end

                ST_WAIT_SEED_L: begin
                    seed_lo <= bram_doutb;
                    state   <= ST_READ_SEED_H;
                end

                ST_READ_SEED_H: begin
                    bram_addrb <= OFF_SEED_HI;
                    state      <= ST_WAIT_SEED_H;
                end

                ST_WAIT_SEED_H: begin
                    pending_seed_hi <= bram_doutb;
                    length_bytes    <= pending_len;
                    seed            <= {bram_doutb, seed_lo};
                    start           <= 1'b1;
                    state           <= ST_CLEAR_START;
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
