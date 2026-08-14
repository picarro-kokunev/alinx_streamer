`timescale 1ns / 1ps

// AXI-Stream C2H source that plays a sequence from pattern BRAM and wraps
// (repeats) until length_bytes have been transferred.
// Pattern BRAM port: 64-bit read, byte-addressed, READ_LATENCY=1.
module c2h_mem_source #(
    parameter integer TDATA_WIDTH       = 64,
    parameter integer DEFAULT_LEN_BYTES = 4096,
    parameter integer DEFAULT_SEQ_BYTES = 4096,
    parameter         ARM_ON_C2H        = 1
) (
    input  wire                     aclk,
    input  wire                     aresetn,
    input  wire                     start,
    input  wire [31:0]              length_bytes,
    input  wire [31:0]              seq_len_bytes,
    output reg                      busy,
    output reg                      done,
    output reg  [31:0]              beat_count,
    // Pattern BRAM (read-only, 64-bit, latency 1)
    output reg                      pat_en,
    output wire [7:0]               pat_we,
    output reg  [31:0]              pat_addr,
    output wire [TDATA_WIDTH-1:0]   pat_din,
    input  wire [TDATA_WIDTH-1:0]   pat_dout,
    // AXI-Stream master
    output reg  [TDATA_WIDTH-1:0]   m_axis_tdata,
    output reg  [TDATA_WIDTH/8-1:0] m_axis_tkeep,
    output reg                      m_axis_tlast,
    output reg                      m_axis_tvalid,
    input  wire                     m_axis_tready,
    output wire [1:0]               dbg_state
);

    localparam integer BEAT_BYTES = TDATA_WIDTH / 8;

    localparam [1:0] ST_IDLE = 2'd0;
    localparam [1:0] ST_LOAD = 2'd1;
    localparam [1:0] ST_RUN  = 2'd2;

    reg [1:0]  state;
    reg [31:0] bytes_rem;
    reg [31:0] seq_len;
    reg [31:0] next_off;
    reg        start_d;

    wire start_pulse  = start & ~start_d;
    wire arm_on_ready = ARM_ON_C2H && m_axis_tready && (state == ST_IDLE) && !busy;

    wire [31:0] xfer_len = (length_bytes < BEAT_BYTES) ? BEAT_BYTES[31:0] : length_bytes;
    wire [31:0] period   = (seq_len_bytes < BEAT_BYTES) ? BEAT_BYTES[31:0] : seq_len_bytes;
    wire        last_beat = (bytes_rem <= BEAT_BYTES);

    // Next offset within the sequence (wrap)
    function [31:0] wrap_next;
        input [31:0] off;
        input [31:0] len;
        reg   [31:0] n;
        begin
            n = off + BEAT_BYTES;
            if (n >= len)
                wrap_next = 32'd0;
            else
                wrap_next = n;
        end
    endfunction

    assign pat_we  = {BEAT_BYTES{1'b0}};
    assign pat_din = {TDATA_WIDTH{1'b0}};

    always @(posedge aclk) begin
        if (!aresetn)
            start_d <= 1'b0;
        else
            start_d <= start;
    end

    always @(posedge aclk) begin
        if (!aresetn) begin
            state         <= ST_IDLE;
            busy          <= 1'b0;
            done          <= 1'b0;
            beat_count    <= 32'd0;
            bytes_rem     <= 32'd0;
            seq_len       <= DEFAULT_SEQ_BYTES;
            next_off      <= 32'd0;
            pat_en        <= 1'b0;
            pat_addr      <= 32'd0;
            m_axis_tvalid <= 1'b0;
            m_axis_tlast  <= 1'b0;
            m_axis_tkeep  <= {BEAT_BYTES{1'b1}};
            m_axis_tdata  <= {TDATA_WIDTH{1'b0}};
        end else begin
            done <= 1'b0;
            // Keep EN high while a read is in flight or data may be used.
            // Output-register BRAM (READ_LATENCY=1) gates the dout register with EN.
            if (state == ST_IDLE)
                pat_en <= 1'b0;

            case (state)
                ST_IDLE: begin
                    m_axis_tvalid <= 1'b0;
                    if (start_pulse || arm_on_ready) begin
                        busy       <= 1'b1;
                        bytes_rem  <= xfer_len;
                        seq_len    <= period;
                        next_off   <= wrap_next(32'd0, period);
                        beat_count <= 32'd0;
                        // Issue first BRAM read (addr 0)
                        pat_en     <= 1'b1;
                        pat_addr   <= 32'd0;
                        state      <= ST_LOAD;
                    end
                end

                // Wait one cycle for READ_LATENCY=1 (EN stays high)
                ST_LOAD: begin
                    pat_en <= 1'b1;
                    state  <= ST_RUN;
                end

                ST_RUN: begin
                    pat_en <= 1'b1;
                    if (!m_axis_tvalid) begin
                        m_axis_tdata  <= pat_dout;
                        m_axis_tkeep  <= {BEAT_BYTES{1'b1}};
                        m_axis_tlast  <= last_beat;
                        m_axis_tvalid <= 1'b1;
                        // Prefetch next beat unless this is the last
                        if (!last_beat) begin
                            pat_addr <= next_off;
                            next_off <= wrap_next(next_off, seq_len);
                        end
                    end else if (m_axis_tready) begin
                        beat_count <= beat_count + 32'd1;
                        if (last_beat) begin
                            m_axis_tvalid <= 1'b0;
                            busy          <= 1'b0;
                            done          <= 1'b1;
                            pat_en        <= 1'b0;
                            state         <= ST_IDLE;
                        end else begin
                            bytes_rem     <= bytes_rem - BEAT_BYTES;
                            m_axis_tdata  <= pat_dout;
                            m_axis_tlast  <= (bytes_rem <= 2 * BEAT_BYTES);
                            // Prefetch following beat if more than one remain after this handshake
                            if (bytes_rem > 2 * BEAT_BYTES) begin
                                pat_addr <= next_off;
                                next_off <= wrap_next(next_off, seq_len);
                            end
                        end
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

    assign dbg_state = state;

endmodule
