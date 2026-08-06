//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2025.2 (lin64) Build 6299465 Fri Nov 14 12:34:56 MST 2025
//Date        : Tue Aug  4 17:33:45 2026
//Host        : emerald running 64-bit Ubuntu 26.04 LTS
//Command     : generate_target design_1_wrapper.bd
//Design      : design_1_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module design_1_wrapper
   (LED,
    pcie_7x_mgt_rtl_0_rxn,
    pcie_7x_mgt_rtl_0_rxp,
    pcie_7x_mgt_rtl_0_txn,
    pcie_7x_mgt_rtl_0_txp,
    pcie_clk_clk_n,
    pcie_clk_clk_p,
    sys_rst_n,
    user_lnk_up,
    user_resetn);
  output [0:0]LED;
  input [1:0]pcie_7x_mgt_rtl_0_rxn;
  input [1:0]pcie_7x_mgt_rtl_0_rxp;
  output [1:0]pcie_7x_mgt_rtl_0_txn;
  output [1:0]pcie_7x_mgt_rtl_0_txp;
  input [0:0]pcie_clk_clk_n;
  input [0:0]pcie_clk_clk_p;
  input sys_rst_n;
  output user_lnk_up;
  output user_resetn;

  wire [0:0]LED;
  wire [1:0]pcie_7x_mgt_rtl_0_rxn;
  wire [1:0]pcie_7x_mgt_rtl_0_rxp;
  wire [1:0]pcie_7x_mgt_rtl_0_txn;
  wire [1:0]pcie_7x_mgt_rtl_0_txp;
  wire [0:0]pcie_clk_clk_n;
  wire [0:0]pcie_clk_clk_p;
  wire sys_rst_n;
  wire user_lnk_up;
  wire user_resetn;

  design_1 design_1_i
       (.LED(LED),
        .pcie_7x_mgt_rtl_0_rxn(pcie_7x_mgt_rtl_0_rxn),
        .pcie_7x_mgt_rtl_0_rxp(pcie_7x_mgt_rtl_0_rxp),
        .pcie_7x_mgt_rtl_0_txn(pcie_7x_mgt_rtl_0_txn),
        .pcie_7x_mgt_rtl_0_txp(pcie_7x_mgt_rtl_0_txp),
        .pcie_clk_clk_n(pcie_clk_clk_n),
        .pcie_clk_clk_p(pcie_clk_clk_p),
        .sys_rst_n(sys_rst_n),
        .user_lnk_up(user_lnk_up),
        .user_resetn(user_resetn));
endmodule
