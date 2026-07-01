`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 21.06.2026 11:27:45
// Design Name: 
// Module Name: hazard_unit
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

// load use hazard detection (RAW)
// EX forwarding
// MEM forwarding
// branch hazard
// jump hazard
// dcache stall (freeze: IF, ID, EX, MEM)
// icache stall (freeze: IF, ID)
module hazard_unit(
    // from ID (RAW hazard)
    input  wire [4:0] id_rs1,               
    input  wire [4:0] id_rs2,               

    // from EX (instruction currently in EX)
    input  wire       ex_load,
    input  wire [4:0] ex_rd,
    // Needed for forwarding
    input  wire [4:0] ex_rs1,
    input  wire [4:0] ex_rs2,

    // from MEM (instruction currently in MEM)
    input  wire       mem_regwrite,
    input  wire [4:0] mem_rd,

    // from wb (instruction currently in WB)
    input  wire       wb_regwrite,
    input  wire [4:0] wb_rd,

    // CONTROL HAZARDS
    input  wire       branch_taken,

    // CACHE STALLS
    input  wire       icache_stall,
    input  wire       dcache_stall,

    // PIPELINE CONTROL OUTPUTS
    output wire       stall_pc,
    output wire       stall_ifid,

    output wire       flush_ifid,
    output wire       flush_idex,

    // FORWARDING
    output reg [1:0]  forwardA,
    output reg [1:0]  forwardB
);

    // LOAD-USE HAZARD
    wire load_use_hazard;

    assign load_use_hazard =
        ex_load &&
        (ex_rd != 5'd0) &&
        (
            (ex_rd == id_rs1) ||
            (ex_rd == id_rs2)
        );

    // GLOBAL STALLS
    assign stall_pc   = load_use_hazard | icache_stall   | dcache_stall;

    assign stall_ifid = load_use_hazard | icache_stall   | dcache_stall;

    // FLUSHES
    assign flush_ifid = branch_taken;

    assign flush_idex = branch_taken | load_use_hazard;

    // FORWARDING UNIT
    //
    // 00 = register file, 01 = MEM/WB, 10 = EX/MEM

    // EX/MEM gets priority

    always @(*) begin
        forwardA = 2'b00;
        forwardB = 2'b00;

        // Operand A

        if (
            mem_regwrite &&
            (mem_rd != 5'd0) &&
            (mem_rd == ex_rs1)
        ) begin
            forwardA = 2'b10;
        end
        else if (
            wb_regwrite &&
            (wb_rd != 5'd0) &&
            (wb_rd == ex_rs1)
        ) begin
            forwardA = 2'b01;
        end

        // Operand B

        if (
            mem_regwrite &&
            (mem_rd != 5'd0) &&
            (mem_rd == ex_rs2)
        ) begin
            forwardB = 2'b10;
        end
        else if (
            wb_regwrite &&
            (wb_rd != 5'd0) &&
            (wb_rd == ex_rs2)
        ) begin
            forwardB = 2'b01;
        end
    end
    
endmodule