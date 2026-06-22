`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11.06.2026 16:18:49
// Design Name: 
// Module Name: mux3_8
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


module mux8_3(
    input wire [31:0] a,
    input wire [31:0] b,
    input wire [31:0] c,
    input wire [31:0] d,
    input wire [31:0] e,
    input wire [31:0] f,
    input wire [31:0] g,
    input wire [31:0] h,
    input wire [2:0]  sel,
    
    output reg [31:0] out
    );
    
    always @(*) begin
        case(sel)
            3'b000: out = a;
            3'b001: out = b;
            3'b010: out = c;
            3'b011: out = d;
            3'b100: out = e;
            3'b101: out = f;
            3'b110: out = g;
            3'b111: out = h;
        endcase
    end
    
endmodule
