`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.06.2026 15:18:07
// Design Name: 
// Module Name: write_back
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


module write_back #(parameter WIDTH=32)
    (
    input wire [1:0]       mem_to_reg,
    input wire [WIDTH-1:0] alu_out,
    input wire [WIDTH-1:0] data_mem_out,
    input wire [WIDTH-1:0] next_sel_address,
    
    output reg [WIDTH-1:0] rd_sel_mux_out
    );
    
    always @(*) begin
        case(mem_to_reg)
            2'b00: rd_sel_mux_out = alu_out;
            2'b01: rd_sel_mux_out = data_mem_out;
            2'b10: rd_sel_mux_out = next_sel_address;
        endcase
    end
    
endmodule