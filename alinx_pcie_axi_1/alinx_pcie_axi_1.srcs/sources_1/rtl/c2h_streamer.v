`timescale 1ns / 1ps

// Top-level streamer: control BRAM port-B + pattern BRAM + AXI-Stream source.
// Plays a host-loaded sequence from pattern BRAM and repeats it N times.
module c2h_streamer #(
    parameter integer TDATA_WIDTH       = 64,
    parameter integer DEFAULT_LEN_BYTES = 4096,
    parameter integer DEFAULT_SEQ_BYTES = 4096,
    parameter integer DEFAULT_REPEAT    = 1,
    parameter         ARM_ON_C2H        = 1,
    parameter         EXPORT_DEBUG      = 1
) (
    input  wire                     aclk,
    input  wire                     aresetn,

    // Control BRAM port B (32-bit; host writes via port A /dev/xdma0_user @ 0x0)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME BRAM_PORTB, MASTER_TYPE BRAM_CTRL, MEM_ADDRESS_MODE BYTE_ADDRESS, MEM_SIZE 4096, MEM_WIDTH 32, MEM_ECC NONE, READ_WRITE_MODE READ_WRITE, READ_LATENCY 1" *)
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB CLK" *)
    output wire                     bram_clkb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB RST" *)
    output wire                     bram_rstb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB EN" *)
    output wire                     bram_enb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB WE" *)
    output wire [3:0]               bram_web,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB ADDR" *)
    output wire [31:0]              bram_addrb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB DIN" *)
    output wire [31:0]              bram_dinb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB DOUT" *)
    input  wire [31:0]              bram_doutb,

    // Pattern BRAM port (64-bit read; host loads via axi_bram_ctrl @ 0x1000)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME PATTERN_BRAM, MASTER_TYPE BRAM_CTRL, MEM_ADDRESS_MODE BYTE_ADDRESS, MEM_SIZE 4096, MEM_WIDTH 64, MEM_ECC NONE, READ_WRITE_MODE READ_ONLY, READ_LATENCY 1" *)
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 PATTERN_BRAM CLK" *)
    output wire                     pat_clkb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 PATTERN_BRAM RST" *)
    output wire                     pat_rstb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 PATTERN_BRAM EN" *)
    output wire                     pat_enb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 PATTERN_BRAM WE" *)
    output wire [7:0]               pat_web,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 PATTERN_BRAM ADDR" *)
    output wire [31:0]              pat_addrb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 PATTERN_BRAM DIN" *)
    output wire [TDATA_WIDTH-1:0]   pat_dinb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 PATTERN_BRAM DOUT" *)
    input  wire [TDATA_WIDTH-1:0]   pat_doutb,

    // AXI-Stream master to XDMA S_AXIS_C2H
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TDATA" *)
    output wire [TDATA_WIDTH-1:0]   m_axis_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TKEEP" *)
    output wire [TDATA_WIDTH/8-1:0] m_axis_tkeep,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TLAST" *)
    output wire                     m_axis_tlast,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TVALID" *)
    output wire                     m_axis_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TREADY" *)
    input  wire                     m_axis_tready,

    // ILA debug (present when EXPORT_DEBUG=1)
    output wire        dbg_start,
    output wire        dbg_busy,
    output wire        dbg_done,
    output wire [31:0] dbg_beat_count,
    output wire [31:0] dbg_length_bytes,
    // Packed {repeat_count[31:0], seq_len_bytes[31:0]} (keeps old 64-bit dbg_seed width)
    output wire [63:0] dbg_seed,
    output wire [3:0]  dbg_ctrl_state,
    output wire [1:0]  dbg_src_state
);

    wire        src_start;
    wire [31:0] src_length;
    wire [31:0] src_seq_len;
    wire [31:0] src_repeat;
    wire        src_busy;
    wire        src_done;
    wire [31:0] src_beat_count;

    wire [3:0] ctrl_state;
    wire [1:0] src_state;

    assign bram_clkb = aclk;
    assign bram_rstb = ~aresetn;
    assign pat_clkb  = aclk;
    assign pat_rstb  = ~aresetn;

    stream_ctrl_regs #(
        .DEFAULT_LEN_BYTES (DEFAULT_LEN_BYTES),
        .DEFAULT_SEQ_BYTES (DEFAULT_SEQ_BYTES),
        .DEFAULT_REPEAT    (DEFAULT_REPEAT)
    ) u_ctrl (
        .aclk          (aclk),
        .aresetn       (aresetn),
        .bram_enb      (bram_enb),
        .bram_web      (bram_web),
        .bram_addrb    (bram_addrb),
        .bram_dinb     (bram_dinb),
        .bram_doutb    (bram_doutb),
        .start         (src_start),
        .length_bytes  (src_length),
        .seq_len_bytes (src_seq_len),
        .repeat_count  (src_repeat),
        .src_busy      (src_busy),
        .src_done      (src_done),
        .src_beat_count(src_beat_count),
        .dbg_state     (ctrl_state)
    );

    c2h_mem_source #(
        .TDATA_WIDTH       (TDATA_WIDTH),
        .DEFAULT_LEN_BYTES (DEFAULT_LEN_BYTES),
        .DEFAULT_SEQ_BYTES (DEFAULT_SEQ_BYTES),
        .ARM_ON_C2H        (ARM_ON_C2H)
    ) u_source (
        .aclk           (aclk),
        .aresetn        (aresetn),
        .start          (src_start),
        .length_bytes   (src_length),
        .seq_len_bytes  (src_seq_len),
        .busy           (src_busy),
        .done           (src_done),
        .beat_count     (src_beat_count),
        .pat_en         (pat_enb),
        .pat_we         (pat_web),
        .pat_addr       (pat_addrb),
        .pat_din        (pat_dinb),
        .pat_dout       (pat_doutb),
        .m_axis_tdata   (m_axis_tdata),
        .m_axis_tkeep   (m_axis_tkeep),
        .m_axis_tlast   (m_axis_tlast),
        .m_axis_tvalid  (m_axis_tvalid),
        .m_axis_tready  (m_axis_tready),
        .dbg_state      (src_state)
    );

    generate
        if (EXPORT_DEBUG) begin : gen_dbg
            assign dbg_start        = src_start;
            assign dbg_busy         = src_busy;
            assign dbg_done         = src_done;
            assign dbg_beat_count   = src_beat_count;
            assign dbg_length_bytes = src_length;
            assign dbg_seed         = {src_repeat, src_seq_len};
            assign dbg_ctrl_state   = ctrl_state;
            assign dbg_src_state    = src_state;
        end else begin : gen_no_dbg
            assign dbg_start        = 1'b0;
            assign dbg_busy         = 1'b0;
            assign dbg_done         = 1'b0;
            assign dbg_beat_count   = 32'd0;
            assign dbg_length_bytes = 32'd0;
            assign dbg_seed         = 64'd0;
            assign dbg_ctrl_state   = 4'd0;
            assign dbg_src_state    = 2'd0;
        end
    endgenerate
endmodule
