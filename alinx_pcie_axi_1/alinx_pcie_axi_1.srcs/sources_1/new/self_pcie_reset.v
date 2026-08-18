`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/16/2026 11:11:10 AM
// Design Name: 
// Module Name: self_pcie_reset
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

// assert pcie_reset_n ( drive low ) upon FPGA is configured
module self_pcie_reset #(parameter RESET_CNT_W = 19)
(
    input clk,
    output pcie_reset_n
);

localparam ST_IDLE = 0;
localparam ST_SAVE = 1;
localparam ST_START = 2;
localparam ST_DONE = 3;

reg [1:0] state;
reg [RESET_CNT_W-1:0] reset_len_cnt;
reg pcie_reset_reg;  

initial
begin
    reset_len_cnt = 0;
    pcie_reset_reg = 0;
    state = ST_IDLE;
end

assign pcie_reset_n = pcie_reset_reg; 

// pcie_reset_n reset cycle
always@(posedge clk)
begin
    state <= state;
    case (state)
        ST_IDLE:
        begin
            begin
                state <= ST_SAVE;   
            end
        end
        ST_SAVE : 
        begin
            reset_len_cnt <= 1'b1;            
            state <= ST_START;            
        end
        ST_START : 
        begin
            if( reset_len_cnt != 0 )
            begin
                reset_len_cnt <= reset_len_cnt + 1'b1;            
            end
            else
            begin    
                state <= ST_DONE;
                pcie_reset_reg <= 1'b1;            
            end
        end    
        ST_DONE:
        begin
        // no action 
        end        
        default:
        begin
        // no action 
        end           
    endcase    
end

endmodule
