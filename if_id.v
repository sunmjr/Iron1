`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 19.06.2026 15:33:45
// Design Name: 
// Module Name: if_id
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

module if_id #(
    parameter WIDTH = 32
)(
    input  wire             clk,
    input  wire             rst,
    input  wire             stall,
    input  wire             flush,

    input  wire [WIDTH-1:0] instruction_in,
    input  wire [WIDTH-1:0] pc_address_in,

    output reg  [WIDTH-1:0] instruction_out,
    output reg  [WIDTH-1:0] pc_address_out
);

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            instruction_out <= {WIDTH{1'b0}};
            pc_address_out  <= {WIDTH{1'b0}};
        end else if (flush) begin
            instruction_out <= {WIDTH{1'b0}};
            pc_address_out  <= {WIDTH{1'b0}};
        end else if (!stall) begin
            instruction_out <= instruction_in;
            pc_address_out  <= pc_address_in;
        end
    end

endmodule
