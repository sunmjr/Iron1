`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 18.06.2026 15:13:11
// Design Name: 
// Module Name: registerfile
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


module registerfile #(
    parameter WIDTH = 32
)(
    input  wire             clk,
    input  wire             rst,
    input  wire             en,

    input  wire [4:0]       rs1,
    input  wire [4:0]       rs2,
    input  wire [4:0]       rd,

    input  wire [WIDTH-1:0] data,

    output wire [WIDTH-1:0] op_a,
    output wire [WIDTH-1:0] op_b
);

    reg [WIDTH-1:0] regs [0:31];

    integer i;

    always @(posedge clk or negedge rst) begin
        if(!rst) begin
            for(i = 0; i < 32; i = i + 1)
                regs[i] <= {WIDTH{1'b0}};
        end
        else begin
            if(en && (rd != 5'd0))
                regs[rd] <= data;
        end
    end

    assign op_a = (rs1 == 5'd0) ? {WIDTH{1'b0}} : regs[rs1];
    assign op_b = (rs2 == 5'd0) ? {WIDTH{1'b0}} : regs[rs2];

endmodule
