`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11.06.2026 18:05:57
// Design Name: 
// Module Name: fetch
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

module fetch #(
    parameter WIDTH = 32
)(
    input wire clk,
    input wire rst,

    // Redirects from EX stage
    input wire             branch_taken,
    input wire [31:0]      branch_target,

    // I-Cache Interface
    input wire [31:0]      instruction_fetch,
    input wire             icache_stall,

    output reg             request,
    output reg [3:0]       we_re,
    output reg [3:0]       mask,
    output wire [31:0]     address_out,

    // IF/ID Pipeline Outputs
    output wire [31:0]     instruction,
    output wire [31:0]     pc_address
);

    // Program Counter
    program_counter #(
        .WIDTH(WIDTH)
    ) u_pc0 (
        .clk(clk),
        .rst(rst),

        .stall(icache_stall),

        .branch_taken(branch_taken),
        .branch_target(branch_target),

        .address_out(address_out),
        .pre_address_pc(pc_address)
    );

    // Instruction Memory Request
    always @(*) begin
        request = 1'b1;
        // Read-only instruction cache
        we_re   = 4'b0000;
        // Full instruction fetch
        mask    = 4'b1111;
    end

    // IF/ID Data Path
    assign instruction = instruction_fetch;

endmodule