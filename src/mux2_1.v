`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11.06.2026 16:28:13
// Design Name: 
// Module Name: mux2_1
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


module mux2_1(
    input wire [31:0] a,
    input wire [31:0] b,
    input wire        sel,
    
    output reg [31:0] out
    );
    
    always @(*) begin
        case(sel)
            1'b0: out = a;
            1'b1: out = b;
        endcase
    end
    
endmodule
