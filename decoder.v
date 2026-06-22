`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11.06.2026 23:01:46
// Design Name: 
// Module Name: decoder
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

// ID stage
// The entire Reg bank is here
// TODO: feels off design as reg bank should be in MEM or WB
// but this is more convenient to send data to ALU
// Hence, TODO: review overall design

module decoder #(
    parameter WIDTH = 32
)(
    input wire             clk,
    input wire             rst,

    // Pipeline / stall control
    input wire             valid,               // 1 = instruction in IF/ID is valid at the moment, 0 = bubble
    input wire             reg_write_en_in,     // WB stage write enable
    input wire             load_control_signal, // 1 = bubble / stall decode

    // Current instruction stream
    input wire [WIDTH-1:0] instruction,         // actual instruction from fetch->IF/ID
    input wire [WIDTH-1:0] pc_address,          // PC value corresponding to this instruction
    input wire [WIDTH-1:0] rd_wb_data,          // data from write back
    input wire [WIDTH-1:0] instruction_rd,      // delayed instruction containing WB destination register

    // Decoded control outputs (ID/EX inbuilt)
    output reg              load,               // 1 for LB, LH, LW, LBU, LHU instructions (for MEM)
    output reg              store,              // 1 for SB, SH, SW (for MEM)
    output reg              branch_op,          // 1 for BEW, BNE, BLT, BGE, BLTU, BGEU (for EX)
    output reg              jal_op,             // 1 for JAL
    output reg              jalr_op,            // 1 for JALR 
    //output reg            next_sel,           // for JAL/JALR only
    output reg [2:0]        branch_funct3,      // to EX for branch compare (BEQ:000;BNE:001;BLT:100;BGE:101;)
    output reg              reg_write_en_out,   // should WB write a register
    output reg [4:0]        alu_control,        
    output reg [1:0]        mem_to_reg,         // controls WB mux (00:ALU result; 01:load data; 10:PC+4)
    
    // mask, mem_funct3 will be used by MEM, but passed via EX for consistency/timing
    output reg [3:0]        mask,               // decode->EX->MEM->D_cache (to identify which bits to modify)
                                                     // uses 1 hot encoding
    output reg [2:0]        mem_funct3,         // (LB and LBU both use same mask, LH vs LHU, SB vs SH vs SW)

    // Register / operand metadata
    output wire [4:0]       rs1,                // source register 1
    output wire [4:0]       rs2,                // source register 2
    output wire [4:0]       rd,                 // destination register
    output wire [WIDTH-1:0] opb_data,           // raw rs2 data for stores
    output wire [WIDTH-1:0] opa_mux_out,        // final operand A (to EX)
    output wire [WIDTH-1:0] opb_mux_out,        // final operand B (to EX)
    output wire [WIDTH-1:0] imm_data_out,       // immediate value (for instructions of 3 operands like BEQ)
    output wire [WIDTH-1:0] pc_address_out      // forwards PC to EX
);

    wire [WIDTH-1:0] op_a;
    wire [WIDTH-1:0] op_b;
    wire [WIDTH-1:0] imm_mux_out;

    wire [WIDTH-1:0] i_immo;
    wire [WIDTH-1:0] s_immo;
    wire [WIDTH-1:0] sb_immo;
    wire [WIDTH-1:0] uj_immo;
    wire [WIDTH-1:0] u_immo;

    reg              operand_a;
    reg              operand_b;
    reg [2:0]        imm_sel;

    wire decode_enable = valid && !load_control_signal;

    wire [6:0] opcode  = instruction[6:0];
    wire [2:0] funct3  = instruction[14:12];
    wire [6:0] funct7  = instruction[31:25];

    assign rs1 = instruction[19:15];
    assign rs2 = instruction[24:20];
    assign rd  = instruction[11:7];

    assign pc_address_out = decode_enable ? pc_address : {WIDTH{1'b0}};
    assign imm_data_out   = decode_enable ? imm_mux_out : {WIDTH{1'b0}};
    assign opb_data       = decode_enable ? op_b : {WIDTH{1'b0}};

    assign opa_mux_out = decode_enable ? (operand_a ? pc_address : op_a) : {WIDTH{1'b0}};
    assign opb_mux_out = decode_enable ? (operand_b ? imm_mux_out : op_b) : {WIDTH{1'b0}};

    always @(*) begin
        // default to prevent latch
        load             = 1'b0;
        store            = 1'b0;
        branch_op        = 1'b0;
        jal_op           = 1'b0;
        jalr_op          = 1'b0;
        // next_sel         = 1'b0;     EX is managing branches. 
        branch_funct3    = 3'b000;
        reg_write_en_out = 1'b0;
        alu_control      = 5'b00000;
        mem_to_reg       = 2'b00;
        operand_a        = 1'b0;
        operand_b        = 1'b0;
        imm_sel          = 3'b000;
        mask             = 4'b0000;
        mem_funct3       = funct3;

        if (decode_enable) begin
            case (opcode)
                // R-type and M-extension
                7'b0110011: begin
                    reg_write_en_out = 1'b1;
                    operand_a        = 1'b0;
                    operand_b        = 1'b0;
                    mem_to_reg       = 2'b00;

                    if (funct7 == 7'b0000001) begin
                        case (funct3)
                            3'b000: alu_control = 5'b10000; // MUL
                            3'b001: alu_control = 5'b10001; // MULH
                            3'b010: alu_control = 5'b10010; // MULHSU
                            3'b011: alu_control = 5'b10011; // MULHU
                            3'b100: alu_control = 5'b10100; // DIV
                            3'b101: alu_control = 5'b10101; // DIVU
                            3'b110: alu_control = 5'b10110; // REM
                            3'b111: alu_control = 5'b10111; // REMU
                            default: alu_control = 5'b00000;
                        endcase
                    end else begin
                        case (funct3)
                            3'b000:  alu_control = funct7[5] ? 5'b00001 : 5'b00000; // SUB : ADD
                            3'b111:  alu_control = 5'b00010; // AND
                            3'b110:  alu_control = 5'b00011; // OR
                            3'b100:  alu_control = 5'b00100; // XOR
                            3'b001:  alu_control = funct7[5] ? 5'b01000 : 5'b00101; // SLA : SLL
                            3'b101:  alu_control = funct7[5] ? 5'b00111 : 5'b00110; // SRA : SRL
                            3'b010:  alu_control = 5'b01001; // SLT
                            3'b011:  alu_control = 5'b01010; // SLTU
                            default: alu_control = 5'b00000;
                        endcase
                    end
                end

                // I-type arithmetic
                7'b0010011: begin
                    reg_write_en_out = 1'b1;
                    operand_b        = 1'b1;
                    imm_sel          = 3'b000;

                    case (funct3)
                        3'b000: alu_control = 5'b00000; // ADDI
                        3'b111: alu_control = 5'b00010; // ANDI
                        3'b110: alu_control = 5'b00011; // ORI
                        3'b100: alu_control = 5'b00100; // XORI
                        3'b010: alu_control = 5'b01001; // SLTI
                        3'b011: alu_control = 5'b01010; // SLTIU
                        3'b001: alu_control = funct7[5] ? 5'b01000 : 5'b00101; // SLAI : SLLI
                        3'b101: alu_control = funct7[5] ? 5'b00111 : 5'b00110; // SRAI : SRLI
                        default: alu_control = 5'b00000;
                    endcase
                end

                // Loads
                7'b0000011: begin
                    reg_write_en_out = 1'b1;
                    load             = 1'b1;
                    operand_b        = 1'b1;
                    imm_sel          = 3'b000;
                    mem_to_reg       = 2'b01;
                    alu_control      = 5'b00000; // address = rs1 + imm
                    
                    case(funct3)
                        3'b000: mask = 4'b0001; // LB
                        3'b001: mask = 4'b0011; // LH
                        3'b010: mask = 4'b1111; // LW
                        3'b100: mask = 4'b0001; // LBU
                        3'b101: mask = 4'b0011; // LHU
                    endcase
                end

                // Stores
                7'b0100011: begin
                    store            = 1'b1;
                    operand_b        = 1'b1;
                    imm_sel          = 3'b001;
                    alu_control      = 5'b00000; // address = rs1 + imm
                    case (funct3)
                        3'b000:  mask = 4'b0001; // SB
                        3'b001:  mask = 4'b0011; // SH
                        3'b010:  mask = 4'b1111; // SW
                        default: mask = 4'b0000;
                    endcase
                end

                // Conditional branches
                7'b1100011: begin
                    branch_op        = 1'b1;
                    branch_funct3    = funct3;
                    imm_sel          = 3'b010;
                    alu_control      = 5'b00000;
                end

                // JAL
                7'b1101111: begin
                    reg_write_en_out = 1'b1;
                    jal_op           = 1'b1;
                    imm_sel          = 3'b011;
                    mem_to_reg       = 2'b10;
                    operand_a        = 1'b1;
                    operand_b        = 1'b1;
                    alu_control      = 5'b00000;
                end

                // JALR
                7'b1100111: begin
                    reg_write_en_out = 1'b1;
                    jalr_op           = 1'b1;
                    imm_sel          = 3'b000;
                    mem_to_reg       = 2'b10;
                    operand_a        = 1'b0;
                    operand_b        = 1'b1;
                    alu_control      = 5'b00000;
                end

                // LUI
                7'b0110111: begin
                    reg_write_en_out = 1'b1;
                    operand_b        = 1'b1;
                    imm_sel          = 3'b100;
                    alu_control      = 5'b01011; // PASS B
                end

                // AUIPC
                7'b0010111: begin
                    reg_write_en_out = 1'b1;
                    operand_a        = 1'b1;     // PC
                    operand_b        = 1'b1;     // U-immediate
                    imm_sel          = 3'b100;
                    alu_control      = 5'b00000; // PC + imm
                    mem_to_reg       = 2'b00;
                end

                default: begin
                    // bubble / unsupported opcode => all defaults
                end
            endcase
        end
    end

    // Immediate generator
    immediategen u_imm_gen0 (
        .instr(instruction),
        .i_imme(i_immo),
        .sb_imme(sb_immo),
        .s_imme(s_immo),
        .uj_imme(uj_immo),
        .u_imme(u_immo)
    );

    // Immediate selector
    mux8_3 u_mux0 (
        .a(i_immo),
        .b(s_immo),
        .c(sb_immo),
        .d(uj_immo),
        .e(u_immo),
        .sel(imm_sel),
        .out(imm_mux_out)
    );

    // Register file
    registerfile u_regfile0 (
        .clk(clk),
        .rst(rst),
        .en(reg_write_en_in),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .data(rd_wb_data),
        .op_a(op_a),
        .op_b(op_b)
    );

endmodule
