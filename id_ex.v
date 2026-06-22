`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 19.06.2026 18:08:21
// Design Name: 
// Module Name: id_ex
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


module id_ex #(
    parameter WIDTH = 32
)(
    input  wire             clk,
    input  wire             rst,
    input  wire             stall,
    input  wire             flush,
    
    input  wire [4:0]       rs1_in,
    input  wire [4:0]       rs2_in,
    input  wire [4:0]       rd_in,
    
    input  wire [WIDTH-1:0] opa_mux_in,
    input  wire [WIDTH-1:0] opb_mux_in,
    input  wire [WIDTH-1:0] opb_data_in,
    input  wire [WIDTH-1:0] pc_address_in,
    input  wire [WIDTH-1:0] imm_data_in,
    input  wire [4:0]       alu_control_in,
    input  wire             reg_write_in,
    input  wire [1:0]       mem_reg_in,
    input  wire             load_in,
    input  wire             store_in,
    input  wire [3:0]       mask_in,
    input  wire [2:0]       mem_funct3_in,
    //input  wire [WIDTH-1:0] instruction_in,
    input  wire             branch_op_in,
    input  wire             jal_op_in,
    input  wire             jalr_in,
    input  wire [2:0]       branch_funct3_in,
    
    output reg  [4:0]       rs1_out,
    output reg  [4:0]       rs2_out,
    output reg  [4:0]       rd_out,
    
    output reg  [WIDTH-1:0] opa_mux_out,
    output reg  [WIDTH-1:0] opb_mux_out,
    output reg  [WIDTH-1:0] opb_data_out,
    output reg  [WIDTH-1:0] pc_address_out,
    output reg  [WIDTH-1:0] imm_data_out,
    output reg  [4:0]       alu_control_out,
    output reg              reg_write_out,
    output reg  [1:0]       mem_reg_out,
    output reg              load_out,
    output reg              store_out,
    output reg  [3:0]       mask_out,
    output reg  [2:0]       mem_funct3_out,
    //output reg  [WIDTH-1:0] instruction_out,
    output reg              branch_op_out,
    output reg              jal_op_out,
    output reg              jalr_out,
    output reg  [2:0]       branch_funct3_out
);


    always @(posedge clk or negedge rst) begin
        if (!rst || flush) begin
            opa_mux_out       <= {WIDTH{1'b0}};
            opb_mux_out       <= {WIDTH{1'b0}};
            opb_data_out      <= {WIDTH{1'b0}};
            pc_address_out    <= {WIDTH{1'b0}};
            imm_data_out      <= {WIDTH{1'b0}};
            alu_control_out   <= 5'b00000;
            reg_write_out     <= 1'b0;
            mem_reg_out       <= 2'b00;
            load_out          <= 1'b0;
            store_out         <= 1'b0;
            mask_out          <= 4'b0000;
            mem_funct3_out    <= 3'b000;
            //instruction_out   <= {WIDTH{1'b0}};
            branch_op_out     <= 1'b0;
            jal_op_out        <= 1'b0;
            jalr_out          <= 1'b0;
            branch_funct3_out <= 3'b000; 
            
            rs1_out           <= 4'b0000;
            rs2_out           <= 4'b0000;
            //rd_out            <= 4'b0000;    
        end 
        else if (!stall) begin
            opa_mux_out       <= opa_mux_in;
            opb_mux_out       <= opb_mux_in;
            opb_data_out      <= opb_data_in;
            pc_address_out    <= pc_address_in;
            imm_data_out      <= imm_data_in;
            alu_control_out   <= alu_control_in;
            reg_write_out     <= reg_write_in;
            mem_reg_out       <= mem_reg_in;
            load_out          <= load_in;
            store_out         <= store_in;
            mask_out          <= mask_in;
            mem_funct3_out    <= mem_funct3_in;
            //instruction_out   <= instruction_in;
            branch_op_out     <= branch_op_in;
            jal_op_out        <= jal_op_in;
            jalr_out          <= jalr_in;
            branch_funct3_out <= branch_funct3_in;
            
            rs1_out           <= rs1_in;
            rs2_out           <= rs2_in;
            //rd_out            <= rd_in; 
        end
    end
endmodule