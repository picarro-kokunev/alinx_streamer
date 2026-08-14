`timescale 1ns / 1ps

// AXI-Stream pattern source for XDMA C2H channel 0.
// Emits ascending 64-bit counter beats; asserts TLAST on the final beat.
//
// NOTE: Superseded by c2h_mem_source.v (memory-backed repeating sequence).
// Kept for reference / fallback; c2h_streamer instantiates c2h_mem_source.
module c2h_pattern_source #(
    parameter integer TDATA_WIDTH        = 64,
    parameter integer DEFAULT_LEN_BYTES  = 4096,
    parameter         ARM_ON_C2H         = 1
) (
    input  wire                     aclk,
    input  wire                     aresetn,
    input  wire                     start,
    input  wire [31:0]              length_bytes,
    input  wire [63:0]              seed,
    output reg                      busy,
    output reg                      done,
    output reg  [31:0]              beat_count,
    output reg  [TDATA_WIDTH-1:0]   m_axis_tdata,
    output reg  [TDATA_WIDTH/8-1:0] m_axis_tkeep,
    output reg                      m_axis_tlast,
    output reg                      m_axis_tvalid,
    input  wire                     m_axis_tready,
    output wire [1:0]               dbg_state
);

    localparam integer BEAT_BYTES = TDATA_WIDTH / 8;

    localparam [1:0] ST_IDLE = 2'd0;
    localparam [1:0] ST_RUN  = 2'd1;

    reg [1:0]       state;
    reg [31:0]      bytes_rem;
    reg [63:0]      counter;
    reg             start_d;
    wire            start_pulse = start & ~start_d;
    wire            arm_on_ready = ARM_ON_C2H && m_axis_tready && (state == ST_IDLE) && !busy;

    wire [31:0]     xfer_len = (length_bytes < BEAT_BYTES) ? 32'd8 : length_bytes;
    wire            last_beat = (bytes_rem <= BEAT_BYTES);

    always @(posedge aclk) 
    begin
        if (!aresetn) begin
            start_d <= 1'b0;
        end else begin
            start_d <= start;
        end
    end

    always @(posedge aclk) begin
        if (!aresetn) begin
            state          <= ST_IDLE;
            busy           <= 1'b0;
            done           <= 1'b0;
            beat_count     <= 32'd0;
            bytes_rem      <= 32'd0;
            counter        <= 64'd0;
            m_axis_tvalid  <= 1'b0;
            m_axis_tlast   <= 1'b0;
            m_axis_tkeep   <= {BEAT_BYTES{1'b1}};
            m_axis_tdata   <= {TDATA_WIDTH{1'b0}};
        end else 
        begin
            done <= 1'b0;

            case (state)
                ST_IDLE: 
                begin
                    m_axis_tvalid <= 1'b0;
                    if (start_pulse || arm_on_ready) 
                    begin
                        busy      <= 1'b1;
                        bytes_rem <= xfer_len;
                        counter   <= seed;
                        beat_count<= 32'd0;
                        state     <= ST_RUN;
                    end
                end

                ST_RUN: 
                begin
                    if (!m_axis_tvalid) 
                    begin
                        m_axis_tdata  <= counter;
                        m_axis_tkeep  <= {BEAT_BYTES{1'b1}};
                        m_axis_tlast  <= last_beat;
                        m_axis_tvalid <= 1'b1;
                    end 
                    else if (m_axis_tready) 
                    begin
                        beat_count <= beat_count + 32'd1;
                        if (last_beat) 
                        begin
                            m_axis_tvalid <= 1'b0;
                            busy          <= 1'b0;
                            done          <= 1'b1;
                            state         <= ST_IDLE;
                        end 
                        else 
                        begin
                            bytes_rem     <= bytes_rem - BEAT_BYTES;
                            counter       <= counter + 64'd1;
                            m_axis_tdata  <= counter + 64'd1;
                            m_axis_tlast  <= (bytes_rem <= 2 * BEAT_BYTES);
                        end
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end
    assign dbg_state = state;    

endmodule
