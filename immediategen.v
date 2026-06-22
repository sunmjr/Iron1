`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 18.06.2026 15:14:19
// Design Name: 
// Module Name: immediategen
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


`timescale 1ns / 1ps

module immediategen(
    input  wire [31:0] instr,

    output wire [31:0] i_imme,
    output wire [31:0] sb_imme,
    output wire [31:0] s_imme,
    output wire [31:0] uj_imme,
    output wire [31:0] u_imme
);

    // I-Type
    assign i_imme =
    {
        {20{instr[31]}},
        instr[31:20]
    };

    // S-Type
    assign s_imme =
    {
        {20{instr[31]}},
        instr[31:25],
        instr[11:7]
    };

    // SB-Type (Branch)
    assign sb_imme =
    {
        {19{instr[31]}},
        instr[31],
        instr[7],
        instr[30:25],
        instr[11:8],
        1'b0
    };

    // UJ-Type (JAL)
    assign uj_imme =
    {
        {11{instr[31]}},
        instr[31],
        instr[19:12],
        instr[20],
        instr[30:21],
        1'b0
    };

    // U-Type (LUI/AUIPC)
    assign u_imme =
    {
        instr[31:12],
        12'b0
    };

endmodule
