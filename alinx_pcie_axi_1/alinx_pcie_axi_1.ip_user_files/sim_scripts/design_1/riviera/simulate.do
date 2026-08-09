transcript off
onbreak {quit -force}
onerror {quit -force}
transcript on

asim +access +r +m+design_1  -L xil_defaultlib -L xilinx_vip -L xpm -L blk_mem_gen_v8_4_12 -L fifo_generator_v13_2_14 -L xdma_v4_2_2 -L axi_bram_ctrl_v4_1_13 -L xbip_utils_v3_0_15 -L c_reg_fd_v12_0_11 -L xbip_dsp48_wrapper_v3_0_7 -L xbip_pipe_v3_0_11 -L c_addsub_v12_0_21 -L c_counter_binary_v12_0_22 -L gigantic_mux -L xlconcat_v2_1_7 -L axis_infrastructure_v1_1_1 -L axis_register_slice_v1_1_35 -L generic_baseblocks_v2_1_2 -L axi_data_fifo_v2_1_36 -L axi_infrastructure_v1_1_0 -L axi_register_slice_v2_1_36 -L axi_protocol_converter_v2_1_37 -L unisims_ver -L unimacro_ver -L secureip -O5 xil_defaultlib.design_1 xil_defaultlib.glbl

do {design_1.udo}

run 1000ns

endsim

quit -force
