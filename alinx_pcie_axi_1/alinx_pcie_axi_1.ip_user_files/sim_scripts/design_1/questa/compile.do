vlib questa_lib/work
vlib questa_lib/msim

vlib questa_lib/msim/xilinx_vip
vlib questa_lib/msim/xpm
vlib questa_lib/msim/xil_defaultlib
vlib questa_lib/msim/blk_mem_gen_v8_4_12
vlib questa_lib/msim/fifo_generator_v13_2_14
vlib questa_lib/msim/xdma_v4_2_2
vlib questa_lib/msim/axi_bram_ctrl_v4_1_13
vlib questa_lib/msim/xbip_utils_v3_0_15
vlib questa_lib/msim/c_reg_fd_v12_0_11
vlib questa_lib/msim/xbip_dsp48_wrapper_v3_0_7
vlib questa_lib/msim/xbip_pipe_v3_0_11
vlib questa_lib/msim/c_addsub_v12_0_21
vlib questa_lib/msim/c_counter_binary_v12_0_22
vlib questa_lib/msim/gigantic_mux
vlib questa_lib/msim/xlconcat_v2_1_7
vlib questa_lib/msim/axis_infrastructure_v1_1_1
vlib questa_lib/msim/axis_register_slice_v1_1_35
vlib questa_lib/msim/generic_baseblocks_v2_1_2
vlib questa_lib/msim/axi_data_fifo_v2_1_36
vlib questa_lib/msim/axi_infrastructure_v1_1_0
vlib questa_lib/msim/axi_register_slice_v2_1_36
vlib questa_lib/msim/axi_protocol_converter_v2_1_37

vmap xilinx_vip questa_lib/msim/xilinx_vip
vmap xpm questa_lib/msim/xpm
vmap xil_defaultlib questa_lib/msim/xil_defaultlib
vmap blk_mem_gen_v8_4_12 questa_lib/msim/blk_mem_gen_v8_4_12
vmap fifo_generator_v13_2_14 questa_lib/msim/fifo_generator_v13_2_14
vmap xdma_v4_2_2 questa_lib/msim/xdma_v4_2_2
vmap axi_bram_ctrl_v4_1_13 questa_lib/msim/axi_bram_ctrl_v4_1_13
vmap xbip_utils_v3_0_15 questa_lib/msim/xbip_utils_v3_0_15
vmap c_reg_fd_v12_0_11 questa_lib/msim/c_reg_fd_v12_0_11
vmap xbip_dsp48_wrapper_v3_0_7 questa_lib/msim/xbip_dsp48_wrapper_v3_0_7
vmap xbip_pipe_v3_0_11 questa_lib/msim/xbip_pipe_v3_0_11
vmap c_addsub_v12_0_21 questa_lib/msim/c_addsub_v12_0_21
vmap c_counter_binary_v12_0_22 questa_lib/msim/c_counter_binary_v12_0_22
vmap gigantic_mux questa_lib/msim/gigantic_mux
vmap xlconcat_v2_1_7 questa_lib/msim/xlconcat_v2_1_7
vmap axis_infrastructure_v1_1_1 questa_lib/msim/axis_infrastructure_v1_1_1
vmap axis_register_slice_v1_1_35 questa_lib/msim/axis_register_slice_v1_1_35
vmap generic_baseblocks_v2_1_2 questa_lib/msim/generic_baseblocks_v2_1_2
vmap axi_data_fifo_v2_1_36 questa_lib/msim/axi_data_fifo_v2_1_36
vmap axi_infrastructure_v1_1_0 questa_lib/msim/axi_infrastructure_v1_1_0
vmap axi_register_slice_v2_1_36 questa_lib/msim/axi_register_slice_v2_1_36
vmap axi_protocol_converter_v2_1_37 questa_lib/msim/axi_protocol_converter_v2_1_37

vlog -work xilinx_vip -64 -incr -mfcu  -sv -L xdma_v4_2_2 "+incdir+/opt/Xilinx_2/2025.2/data/xilinx_vip/include" \
"/opt/Xilinx_2/2025.2/data/xilinx_vip/hdl/axi4stream_vip_axi4streampc.sv" \
"/opt/Xilinx_2/2025.2/data/xilinx_vip/hdl/axi_vip_axi4pc.sv" \
"/opt/Xilinx_2/2025.2/data/xilinx_vip/hdl/xil_common_vip_pkg.sv" \
"/opt/Xilinx_2/2025.2/data/xilinx_vip/hdl/axi4stream_vip_pkg.sv" \
"/opt/Xilinx_2/2025.2/data/xilinx_vip/hdl/axi_vip_pkg.sv" \
"/opt/Xilinx_2/2025.2/data/xilinx_vip/hdl/axi4stream_vip_if.sv" \
"/opt/Xilinx_2/2025.2/data/xilinx_vip/hdl/axi_vip_if.sv" \
"/opt/Xilinx_2/2025.2/data/xilinx_vip/hdl/clk_vip_if.sv" \
"/opt/Xilinx_2/2025.2/data/xilinx_vip/hdl/rst_vip_if.sv" \

vlog -work xpm -64 -incr -mfcu  -sv -L xdma_v4_2_2 "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/d6c9/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/434f/hdl" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../../../../opt/Xilinx_2/2025.2/data/rsb/busdef" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/0568/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/3556/hdl/verilog" "+incdir+/opt/Xilinx_2/2025.2/data/xilinx_vip/include" \
"/opt/Xilinx_2/2025.2/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
"/opt/Xilinx_2/2025.2/data/ip/xpm/xpm_fifo/hdl/xpm_fifo.sv" \
"/opt/Xilinx_2/2025.2/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \

vcom -work xpm -64 -93  \
"/opt/Xilinx_2/2025.2/data/ip/xpm/xpm_VCOMP.vhd" \

vlog -work xil_defaultlib -64 -incr -mfcu  "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/d6c9/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/434f/hdl" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../../../../opt/Xilinx_2/2025.2/data/rsb/busdef" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/0568/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/3556/hdl/verilog" "+incdir+/opt/Xilinx_2/2025.2/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_0/source/design_1_xdma_0_0_pcie2_ip_pipe_clock.v" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_0/source/design_1_xdma_0_0_pcie2_ip_pipe_eq.v" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_0/source/design_1_xdma_0_0_pcie2_ip_pipe_drp.v" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_0/source/design_1_xdma_0_0_pcie2_ip_pipe_rate.v" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_0/source/design_1_xdma_0_0_pcie2_ip_pipe_reset.v" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_0/source/design_1_xdma_0_0_pcie2_ip_pipe_sync.v" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_0/source/design_1_xdma_0_0_pcie2_ip_gtp_pipe_rate.v" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_0/source/design_1_xdma_0_0_pcie2_ip_gtp_pipe_drp.v" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_0/source/design_1_xdma_0_0_pcie2_ip_gtp_pipe_reset.v" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_0/source/design_1_xdma_0_0_pcie2_ip_pipe_user.v" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_0/source/design_1_xdma_0_0_pcie2_ip_pipe_wrapper.v" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_0/source/design_1_xdma_0_0_pcie2_ip_qpll_drp.v" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_0/source/design_1_xdma_0_0_pcie2_ip_qpll_reset.v" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_0/source/design_1_xdma_0_0_pcie2_ip_qpll_wrapper.v" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_0/source/design_1_xdma_0_0_pcie2_ip_rxeq_scan.v" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_0/source/design_1_xdma_0_0_pcie2_ip_pcie_top.v" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_0/source/design_1_xdma_0_0_pcie2_ip_core_top.v" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_0/source/design_1_xdma_0_0_pcie2_ip_axi_basic_rx_null_gen.v" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_0/source/design_1_xdma_0_0_pcie2_ip_axi_basic_rx_pipeline.v" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_0/source/design_1_xdma_0_0_pcie2_ip_axi_basic_rx.v" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_0/source/design_1_xdma_0_0_pcie2_ip_axi_basic_top.v" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_0/source/design_1_xdma_0_0_pcie2_ip_axi_basic_tx_pipeline.v" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_0/source/design_1_xdma_0_0_pcie2_ip_axi_basic_tx_thrtl_ctl.v" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_0/source/design_1_xdma_0_0_pcie2_ip_axi_basic_tx.v" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_0/source/design_1_xdma_0_0_pcie2_ip_pcie_7x.v" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_0/source/design_1_xdma_0_0_pcie2_ip_pcie_bram_7x.v" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_0/source/design_1_xdma_0_0_pcie2_ip_pcie_bram_top_7x.v" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_0/source/design_1_xdma_0_0_pcie2_ip_pcie_brams_7x.v" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_0/source/design_1_xdma_0_0_pcie2_ip_pcie_pipe_lane.v" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_0/source/design_1_xdma_0_0_pcie2_ip_pcie_pipe_misc.v" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_0/source/design_1_xdma_0_0_pcie2_ip_pcie_pipe_pipeline.v" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_0/source/design_1_xdma_0_0_pcie2_ip_gt_top.v" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_0/source/design_1_xdma_0_0_pcie2_ip_gt_common.v" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_0/source/design_1_xdma_0_0_pcie2_ip_gtp_cpllpd_ovrd.v" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_0/source/design_1_xdma_0_0_pcie2_ip_gtx_cpllpd_ovrd.v" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_0/source/design_1_xdma_0_0_pcie2_ip_gt_rx_valid_filter_7x.v" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_0/source/design_1_xdma_0_0_pcie2_ip_gt_wrapper.v" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_0/source/design_1_xdma_0_0_pcie2_ip_pcie2_top.v" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_0/sim/design_1_xdma_0_0_pcie2_ip.v" \

vlog -work blk_mem_gen_v8_4_12 -64 -incr -mfcu  "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/d6c9/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/434f/hdl" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../../../../opt/Xilinx_2/2025.2/data/rsb/busdef" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/0568/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/3556/hdl/verilog" "+incdir+/opt/Xilinx_2/2025.2/data/xilinx_vip/include" \
"../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/42f3/simulation/blk_mem_gen_v8_4.v" \

vlog -work xil_defaultlib -64 -incr -mfcu  "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/d6c9/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/434f/hdl" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../../../../opt/Xilinx_2/2025.2/data/rsb/busdef" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/0568/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/3556/hdl/verilog" "+incdir+/opt/Xilinx_2/2025.2/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_1/sim/xdma_v4_2_2_blk_mem_64_reg_be.v" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_2/sim/xdma_v4_2_2_blk_mem_64_noreg_be.v" \

vlog -work fifo_generator_v13_2_14 -64 -incr -mfcu  "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/d6c9/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/434f/hdl" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../../../../opt/Xilinx_2/2025.2/data/rsb/busdef" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/0568/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/3556/hdl/verilog" "+incdir+/opt/Xilinx_2/2025.2/data/xilinx_vip/include" \
"../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/d654/simulation/fifo_generator_vlog_beh.v" \

vcom -work fifo_generator_v13_2_14 -64 -93  \
"../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/d654/hdl/fifo_generator_v13_2_rfs.vhd" \

vlog -work fifo_generator_v13_2_14 -64 -incr -mfcu  "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/d6c9/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/434f/hdl" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../../../../opt/Xilinx_2/2025.2/data/rsb/busdef" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/0568/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/3556/hdl/verilog" "+incdir+/opt/Xilinx_2/2025.2/data/xilinx_vip/include" \
"../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/d654/hdl/fifo_generator_v13_2_rfs.v" \

vlog -work xil_defaultlib -64 -incr -mfcu  "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/d6c9/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/434f/hdl" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../../../../opt/Xilinx_2/2025.2/data/rsb/busdef" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/0568/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/3556/hdl/verilog" "+incdir+/opt/Xilinx_2/2025.2/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_3/sim/pcie2_fifo_generator_dma_cpl.v" \
"../../../bd/design_1/ip/design_1_xdma_0_0/ip_4/sim/pcie2_fifo_generator_tgt_brdg.v" \

vlog -work xdma_v4_2_2 -64 -incr -mfcu  -sv -L xdma_v4_2_2 "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/d6c9/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/434f/hdl" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../../../../opt/Xilinx_2/2025.2/data/rsb/busdef" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/0568/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/3556/hdl/verilog" "+incdir+/opt/Xilinx_2/2025.2/data/xilinx_vip/include" \
"../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/d6c9/hdl/xdma_v4_2_vl_rfs.sv" \

vlog -work xil_defaultlib -64 -incr -mfcu  -sv -L xdma_v4_2_2 "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/d6c9/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/434f/hdl" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../../../../opt/Xilinx_2/2025.2/data/rsb/busdef" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/0568/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/3556/hdl/verilog" "+incdir+/opt/Xilinx_2/2025.2/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_xdma_0_0/xdma_v4_2/hdl/verilog/design_1_xdma_0_0_dma_cpl.sv" \
"../../../bd/design_1/ip/design_1_xdma_0_0/xdma_v4_2/hdl/verilog/design_1_xdma_0_0_dma_req.sv" \
"../../../bd/design_1/ip/design_1_xdma_0_0/xdma_v4_2/hdl/verilog/design_1_xdma_0_0_rx_destraddler.sv" \
"../../../bd/design_1/ip/design_1_xdma_0_0/xdma_v4_2/hdl/verilog/design_1_xdma_0_0_rx_demux.sv" \
"../../../bd/design_1/ip/design_1_xdma_0_0/xdma_v4_2/hdl/verilog/design_1_xdma_0_0_tgt_cpl.sv" \
"../../../bd/design_1/ip/design_1_xdma_0_0/xdma_v4_2/hdl/verilog/design_1_xdma_0_0_tgt_req.sv" \
"../../../bd/design_1/ip/design_1_xdma_0_0/xdma_v4_2/hdl/verilog/design_1_xdma_0_0_tx_mux.sv" \
"../../../bd/design_1/ip/design_1_xdma_0_0/xdma_v4_2/hdl/verilog/design_1_xdma_0_0_axi_stream_intf.sv" \
"../../../bd/design_1/ip/design_1_xdma_0_0/xdma_v4_2/hdl/verilog/design_1_xdma_0_0_cfg_sideband.sv" \
"../../../bd/design_1/ip/design_1_xdma_0_0/xdma_v4_2/hdl/verilog/design_1_xdma_0_0_pcie2_to_pcie3_wrapper.sv" \
"../../../bd/design_1/ip/design_1_xdma_0_0/xdma_v4_2/hdl/verilog/design_1_xdma_0_0_dma_bram_wrap.sv" \
"../../../bd/design_1/ip/design_1_xdma_0_0/xdma_v4_2/hdl/verilog/design_1_xdma_0_0_dma_bram_wrap_1024.sv" \
"../../../bd/design_1/ip/design_1_xdma_0_0/xdma_v4_2/hdl/verilog/design_1_xdma_0_0_dma_bram_wrap_2048.sv" \
"../../../bd/design_1/ip/design_1_xdma_0_0/xdma_v4_2/hdl/verilog/design_1_xdma_0_0_core_top.sv" \
"../../../bd/design_1/ip/design_1_xdma_0_0/sim/design_1_xdma_0_0.sv" \

vcom -work xil_defaultlib -64 -93  \
"../../../bd/design_1/ip/design_1_util_ds_buf_0/util_ds_buf.vhd" \
"../../../bd/design_1/ip/design_1_util_ds_buf_0/sim/design_1_util_ds_buf_0.vhd" \

vcom -work axi_bram_ctrl_v4_1_13 -64 -93  \
"../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/2f03/hdl/axi_bram_ctrl_v4_1_rfs.vhd" \

vcom -work xil_defaultlib -64 -93  \
"../../../bd/design_1/ip/design_1_axi_bram_ctrl_1_0/sim/design_1_axi_bram_ctrl_1_0.vhd" \

vlog -work xil_defaultlib -64 -incr -mfcu  "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/d6c9/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/434f/hdl" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../../../../opt/Xilinx_2/2025.2/data/rsb/busdef" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/0568/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/3556/hdl/verilog" "+incdir+/opt/Xilinx_2/2025.2/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_blk_mem_gen_1_0/sim/design_1_blk_mem_gen_1_0.v" \

vcom -work xbip_utils_v3_0_15 -64 -93  \
"../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/fb6f/hdl/xbip_utils_v3_0_vh_rfs.vhd" \

vcom -work c_reg_fd_v12_0_11 -64 -93  \
"../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/0ff7/hdl/c_reg_fd_v12_0_vh_rfs.vhd" \

vcom -work xbip_dsp48_wrapper_v3_0_7 -64 -93  \
"../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/9bc6/hdl/xbip_dsp48_wrapper_v3_0_vh_rfs.vhd" \

vcom -work xbip_pipe_v3_0_11 -64 -93  \
"../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/6a79/hdl/xbip_pipe_v3_0_vh_rfs.vhd" \

vcom -work c_addsub_v12_0_21 -64 -93  \
"../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/ed70/hdl/c_addsub_v12_0_vh_rfs.vhd" \

vcom -work c_counter_binary_v12_0_22 -64 -93  \
"../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/782b/hdl/c_counter_binary_v12_0_vh_rfs.vhd" \

vcom -work xil_defaultlib -64 -93  \
"../../../bd/design_1/ip/design_1_c_counter_binary_0_0/sim/design_1_c_counter_binary_0_0.vhd" \

vlog -work xil_defaultlib -64 -incr -mfcu  "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/d6c9/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/434f/hdl" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../../../../opt/Xilinx_2/2025.2/data/rsb/busdef" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/0568/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/3556/hdl/verilog" "+incdir+/opt/Xilinx_2/2025.2/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_c2h_streamer_0_0/sim/design_1_c2h_streamer_0_0.v" \
"../../../bd/design_1/ip/design_1_system_ila_1_0/bd_0/sim/bd_365d.v" \
"../../../bd/design_1/ip/design_1_system_ila_1_0/bd_0/ip/ip_0/sim/bd_365d_ila_lib_0.v" \

vlog -work gigantic_mux -64 -incr -mfcu  "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/d6c9/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/434f/hdl" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../../../../opt/Xilinx_2/2025.2/data/rsb/busdef" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/0568/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/3556/hdl/verilog" "+incdir+/opt/Xilinx_2/2025.2/data/xilinx_vip/include" \
"../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/b2b0/hdl/gigantic_mux_v1_0_cntr.v" \

vlog -work xil_defaultlib -64 -incr -mfcu  "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/d6c9/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/434f/hdl" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../../../../opt/Xilinx_2/2025.2/data/rsb/busdef" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/0568/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/3556/hdl/verilog" "+incdir+/opt/Xilinx_2/2025.2/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_system_ila_1_0/bd_0/ip/ip_1/bd_365d_g_inst_0_gigantic_mux.v" \
"../../../bd/design_1/ip/design_1_system_ila_1_0/bd_0/ip/ip_1/sim/bd_365d_g_inst_0.v" \

vlog -work xlconcat_v2_1_7 -64 -incr -mfcu  "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/d6c9/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/434f/hdl" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../../../../opt/Xilinx_2/2025.2/data/rsb/busdef" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/0568/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/3556/hdl/verilog" "+incdir+/opt/Xilinx_2/2025.2/data/xilinx_vip/include" \
"../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/9c1a/hdl/xlconcat_v2_1_vl_rfs.v" \

vlog -work xil_defaultlib -64 -incr -mfcu  "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/d6c9/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/434f/hdl" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../../../../opt/Xilinx_2/2025.2/data/rsb/busdef" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/0568/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/3556/hdl/verilog" "+incdir+/opt/Xilinx_2/2025.2/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_system_ila_1_0/bd_0/ip/ip_2/sim/bd_365d_slot_0_aw_0.v" \
"../../../bd/design_1/ip/design_1_system_ila_1_0/bd_0/ip/ip_3/sim/bd_365d_slot_0_w_0.v" \
"../../../bd/design_1/ip/design_1_system_ila_1_0/bd_0/ip/ip_4/sim/bd_365d_slot_0_b_0.v" \
"../../../bd/design_1/ip/design_1_system_ila_1_0/bd_0/ip/ip_5/sim/bd_365d_slot_0_ar_0.v" \
"../../../bd/design_1/ip/design_1_system_ila_1_0/bd_0/ip/ip_6/sim/bd_365d_slot_0_r_0.v" \
"../../../bd/design_1/ip/design_1_system_ila_1_0/sim/design_1_system_ila_1_0.v" \

vlog -work axis_infrastructure_v1_1_1 -64 -incr -mfcu  "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/d6c9/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/434f/hdl" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../../../../opt/Xilinx_2/2025.2/data/rsb/busdef" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/0568/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/3556/hdl/verilog" "+incdir+/opt/Xilinx_2/2025.2/data/xilinx_vip/include" \
"../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/434f/hdl/axis_infrastructure_v1_1_vl_rfs.v" \

vlog -work axis_register_slice_v1_1_35 -64 -incr -mfcu  "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/d6c9/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/434f/hdl" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../../../../opt/Xilinx_2/2025.2/data/rsb/busdef" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/0568/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/3556/hdl/verilog" "+incdir+/opt/Xilinx_2/2025.2/data/xilinx_vip/include" \
"../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/be12/hdl/axis_register_slice_v1_1_vl_rfs.v" \

vlog -work xil_defaultlib -64 -incr -mfcu  "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/d6c9/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/434f/hdl" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../../../../opt/Xilinx_2/2025.2/data/rsb/busdef" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/0568/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/3556/hdl/verilog" "+incdir+/opt/Xilinx_2/2025.2/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_axis_register_slice_0_0/sim/design_1_axis_register_slice_0_0.v" \
"../../../bd/design_1/sim/design_1.v" \
"../../../bd/design_1/ip/design_1_xlconcat_0_0/sim/design_1_xlconcat_0_0.v" \

vlog -work generic_baseblocks_v2_1_2 -64 -incr -mfcu  "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/d6c9/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/434f/hdl" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../../../../opt/Xilinx_2/2025.2/data/rsb/busdef" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/0568/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/3556/hdl/verilog" "+incdir+/opt/Xilinx_2/2025.2/data/xilinx_vip/include" \
"../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/0c28/hdl/generic_baseblocks_v2_1_vl_rfs.v" \

vlog -work axi_data_fifo_v2_1_36 -64 -incr -mfcu  "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/d6c9/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/434f/hdl" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../../../../opt/Xilinx_2/2025.2/data/rsb/busdef" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/0568/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/3556/hdl/verilog" "+incdir+/opt/Xilinx_2/2025.2/data/xilinx_vip/include" \
"../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/fb46/hdl/axi_data_fifo_v2_1_vl_rfs.v" \

vlog -work axi_infrastructure_v1_1_0 -64 -incr -mfcu  "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/d6c9/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/434f/hdl" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../../../../opt/Xilinx_2/2025.2/data/rsb/busdef" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/0568/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/3556/hdl/verilog" "+incdir+/opt/Xilinx_2/2025.2/data/xilinx_vip/include" \
"../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/ec67/hdl/axi_infrastructure_v1_1_vl_rfs.v" \

vlog -work axi_register_slice_v2_1_36 -64 -incr -mfcu  "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/d6c9/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/434f/hdl" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../../../../opt/Xilinx_2/2025.2/data/rsb/busdef" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/0568/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/3556/hdl/verilog" "+incdir+/opt/Xilinx_2/2025.2/data/xilinx_vip/include" \
"../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/bc4b/hdl/axi_register_slice_v2_1_vl_rfs.v" \

vlog -work axi_protocol_converter_v2_1_37 -64 -incr -mfcu  "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/d6c9/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/434f/hdl" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../../../../opt/Xilinx_2/2025.2/data/rsb/busdef" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/0568/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/3556/hdl/verilog" "+incdir+/opt/Xilinx_2/2025.2/data/xilinx_vip/include" \
"../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/d98a/hdl/axi_protocol_converter_v2_1_vl_rfs.v" \

vlog -work xil_defaultlib -64 -incr -mfcu  "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/d6c9/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/434f/hdl" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../../../../opt/Xilinx_2/2025.2/data/rsb/busdef" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/5431/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/4e08/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/0568/hdl/verilog" "+incdir+../../../../alinx_pcie_axi_1.gen/sources_1/bd/design_1/ipshared/3556/hdl/verilog" "+incdir+/opt/Xilinx_2/2025.2/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_axi_interconnect_0_imp_auto_pc_0/sim/design_1_axi_interconnect_0_imp_auto_pc_0.v" \

vlog -work xil_defaultlib \
"glbl.v"

