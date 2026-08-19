`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Samples generator: reads N x 16-bit samples from BRAM port B and streams them
// on a 64-bit AXI-Stream master (C2H channel 1) in an infinite loop while enabled.
//
// BRAM byte map (host writes via AXI-Lite / port A):
//   0x00  CTRL      bit0 = run (1=stream, 0=stop)
//   0x04  N_SAMPLES number of 16-bit samples (1 .. MAX_SAMPLES)
//   0x08  STATUS    (reserved)
//   0x10  samples   packed int16 LE, two samples per 32-bit word
//////////////////////////////////////////////////////////////////////////////////

module samples_generator #(
    parameter integer BRAM_ADDR_WIDTH = 32,
    parameter integer SAMPLE_BASE_BYTE = 16,
    parameter integer MAX_SAMPLES = 2040
) (
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF M_AXIS:BRAM_PORTB, ASSOCIATED_RESET aresetn, FREQ_HZ 125000000" *)
    input  wire                       aclk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input  wire                       aresetn,

    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB CLK" *)
    output wire                       bram_portb_clk,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB RST" *)
    (* X_INTERFACE_MODE = "master" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME BRAM_PORTB, MASTER_TYPE BRAM_CTRL, MEM_SIZE 4096, MEM_WIDTH 32, MEM_ECC NONE, READ_WRITE_MODE READ_ONLY, READ_LATENCY 1" *)
    output wire                       bram_portb_rst,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB EN" *)
    output wire                       bram_portb_en,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB WE" *)
    output wire [3:0]                 bram_portb_we,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB ADDR" *)
    output wire [BRAM_ADDR_WIDTH-1:0] bram_portb_addr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB DIN" *)
    output wire [31:0]                bram_portb_din,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB DOUT" *)
    input  wire [31:0]                bram_portb_dout,

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TDATA" *)
    output reg  [63:0]                  m_axis_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TKEEP" *)
    output reg  [7:0]                 m_axis_tkeep,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TLAST" *)
    output reg                        m_axis_tlast,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TVALID" *)
    (* X_INTERFACE_MODE = "master" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME M_AXIS, TDATA_NUM_BYTES 8, TDEST_WIDTH 0, TID_WIDTH 0, TUSER_WIDTH 0, HAS_TREADY 1, HAS_TSTRB 0, HAS_TKEEP 1, HAS_TLAST 1" *)
    output reg                        m_axis_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TREADY" *)
    input  wire                       m_axis_tready
);

localparam [BRAM_ADDR_WIDTH-1:0] REG_CTRL_BYTE = 32'h0;
localparam [BRAM_ADDR_WIDTH-1:0] REG_N_BYTE    = 32'h4;

localparam [2:0] S_POLL   = 3'd0;
localparam [2:0] S_LOAD_N = 3'd1;
localparam [2:0] S_WAIT   = 3'd2;
localparam [2:0] S_ACCUM  = 3'd3;
localparam [2:0] S_SEND   = 3'd4;

reg [2:0] state;
reg [15:0] sample_count;
reg [15:0] sample_idx;
reg [BRAM_ADDR_WIDTH-1:0] pending_addr;
reg [63:0] beat_data;
reg [2:0] samples_in_beat;
reg bram_en_r;
reg [BRAM_ADDR_WIDTH-1:0] bram_addr_r;
reg [15:0] samples_added;
reg [2:0] total_in_beat;

assign bram_portb_clk  = aclk;
assign bram_portb_rst  = ~aresetn;
assign bram_portb_en   = bram_en_r;
assign bram_portb_we   = 4'b0000;
assign bram_portb_addr = bram_addr_r;
assign bram_portb_din  = 32'd0;

function automatic [BRAM_ADDR_WIDTH-1:0] sample_word_addr;
    input [15:0] idx;
    begin
        sample_word_addr = SAMPLE_BASE_BYTE + {20'b0, idx[15:1], 2'b00};
    end
endfunction

function automatic [7:0] keep_for_count;
    input [2:0] count;
    begin
        keep_for_count = (8'd1 << (count << 1)) - 8'd1;
    end
endfunction

task issue_read;
    input [BRAM_ADDR_WIDTH-1:0] addr;
    begin
        bram_addr_r  <= addr;
        bram_en_r    <= 1'b1;
        pending_addr <= addr;
    end
endtask

always @(posedge aclk) begin
    if (!aresetn) begin
        state           <= S_POLL;
        sample_count    <= 16'd0;
        sample_idx      <= 16'd0;
        bram_addr_r     <= REG_CTRL_BYTE;
        bram_en_r       <= 1'b0;
        beat_data       <= 64'd0;
        samples_in_beat <= 3'd0;
        m_axis_tdata    <= 64'd0;
        m_axis_tkeep    <= 8'h00;
        m_axis_tlast    <= 1'b0;
        m_axis_tvalid   <= 1'b0;
    end else begin
        bram_en_r <= 1'b0;

        if (m_axis_tvalid && m_axis_tready)
            m_axis_tvalid <= 1'b0;

        case (state)
            S_POLL: begin
                issue_read(REG_CTRL_BYTE);
                state <= S_WAIT;
            end

            S_LOAD_N: begin
                issue_read(REG_N_BYTE);
                state <= S_WAIT;
            end

            S_WAIT: begin
                if (pending_addr == REG_CTRL_BYTE) begin
                    if (bram_portb_dout[0]) begin
                        if (sample_count == 16'd0)
                            state <= S_LOAD_N;
                        else begin
                            sample_idx      <= 16'd0;
                            beat_data       <= 64'd0;
                            samples_in_beat <= 3'd0;
                            issue_read(sample_word_addr(16'd0));
                            state <= S_WAIT;
                        end
                    end else begin
                        state <= S_POLL;
                    end
                end else if (pending_addr == REG_N_BYTE) begin
                    if (bram_portb_dout[15:0] == 16'd0)
                        sample_count <= 16'd1;
                    else if (bram_portb_dout[15:0] > MAX_SAMPLES[15:0])
                        sample_count <= MAX_SAMPLES[15:0];
                    else
                        sample_count <= bram_portb_dout[15:0];
                    sample_idx      <= 16'd0;
                    beat_data       <= 64'd0;
                    samples_in_beat <= 3'd0;
                    issue_read(sample_word_addr(16'd0));
                    state <= S_WAIT;
                end else begin
                    state <= S_ACCUM;
                end
            end

            S_ACCUM: begin
                if (samples_in_beat == 3'd0) begin
                    beat_data[15:0]  <= bram_portb_dout[15:0];
                    beat_data[31:16] <= bram_portb_dout[31:16];
                end else begin
                    beat_data[47:32] <= bram_portb_dout[15:0];
                    beat_data[63:48] <= bram_portb_dout[31:16];
                end

                samples_added = (sample_idx + 16'd2 >= sample_count)
                    ? (sample_count - sample_idx)
                    : 16'd2;
                total_in_beat = samples_in_beat + samples_added[2:0];

                if ((sample_idx + 16'd2 >= sample_count) ||
                    (samples_in_beat + 3'd2 >= 3'd4)) begin
                    m_axis_tlast <= (sample_idx + 16'd2 >= sample_count);
                    m_axis_tkeep <= keep_for_count(total_in_beat);
                    state <= S_SEND;
                end else begin
                    sample_idx      <= sample_idx + 16'd2;
                    samples_in_beat <= samples_in_beat + 3'd2;
                    issue_read(sample_word_addr(sample_idx + 16'd2));
                    state <= S_WAIT;
                end
            end

            S_SEND: begin
                m_axis_tdata  <= beat_data;
                m_axis_tvalid <= 1'b1;

                if (m_axis_tvalid && m_axis_tready) begin
                    if (m_axis_tlast) begin
                        sample_idx      <= 16'd0;
                        beat_data       <= 64'd0;
                        samples_in_beat <= 3'd0;
                        m_axis_tlast    <= 1'b0;
                        state           <= S_POLL;
                    end else begin
                        sample_idx      <= sample_idx + 16'd4;
                        beat_data       <= 64'd0;
                        samples_in_beat <= 3'd0;
                        issue_read(sample_word_addr(sample_idx + 16'd4));
                        state           <= S_WAIT;
                    end
                end
            end

            default: state <= S_POLL;
        endcase
    end
end

endmodule
