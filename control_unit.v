`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04.06.2026 16:41:28
// Design Name: 
// Module Name: control_unit
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

// Pipeline = Instruction Fetch (IF) -> Instruction Decode (ID) -> Execute Instruction (EX) -> 
// Memory Access (Mem) -> Write back (Wb)
module control_unit #(
    parameter WIDTH = 32
    )(
    
    input wire      clk,
    input wire      rst,
    
    // Instruction memory side (I-cache)
    input  wire [127:0]     imem_rdata,
    input  wire             imem_ready,
    output wire             imem_req,
    output wire [WIDTH-1:0] imem_addr,
    
    // Data memory side (D-cache)
    input  wire [127:0]    dmem_rdata,
    input  wire            dmem_ready,
    output wire            dmem_req,
    output wire            dmem_we,
    output wire [WIDTH-1:0]
    
    );
    
endmodule
