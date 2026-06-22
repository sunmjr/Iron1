`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.06.2026 17:12:52
// Design Name: 
// Module Name: EX
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

module EX #(
    parameter WIDTH = 32
)(
    input wire clk,
    input wire rst,

    // INTERFACE A: INPUTS FROM ID/EX REGISTER
    input wire [WIDTH-1:0] opa_mux_in,          
    input wire [WIDTH-1:0] opb_mux_in,          
    input wire [WIDTH-1:0] opb_data_in,         
    input wire [WIDTH-1:0] pc_address_in,       
    input wire [WIDTH-1:0] imm_data_in,         
    input wire [4:0]       alu_control_in,      
                                               
    input wire             reg_write_in,        
    input wire [1:0]       mem_reg_in,          
    input wire             load_in,             
    input wire             store_in,            
    input wire [3:0]       mask_in,             
    input wire [2:0]       mem_funct3,          
    //input wire [WIDTH-1:0] instruction_in,    
                                               
    // Branch / jump control from decoder       
    input wire             branch_op_in,        
    input wire             jal_op_in,           
    input wire             jalr_in,             
    input wire [2:0]       branch_funct3_in,    
    
    input wire [4:0]       rs1_in,
    input wire [4:0]       rs2_in,
    input wire [4:0]       rd_in,     
                                          
    // OUTPUTS TO EX/MEM REGISTER  
    output wire [WIDTH-1:0] alu_result_out,     
    output wire [WIDTH-1:0] store_data_out,     
    output wire             branch_taken_out,   
    output wire [WIDTH-1:0] branch_target_out,  
                                               
    output wire             reg_write_out,      
    output wire [1:0]       mem_reg_out,        
    output wire             load_out,           
    output wire             store_out,          
    output wire [3:0]       mask_out,           
    //output wire [WIDTH-1:0] instruction_out,  
    output wire [WIDTH-1:0] pc_address_out,     
    output wire [WIDTH-1:0] next_sel_addr_out,  
    
    output wire [4:0]       rs1_out,
    output wire [4:0]       rs2_out,
    output wire [4:0]       rd_out
);

    // ALU
    wire [WIDTH-1:0] alu_result_wire;
    wire             alu_flag_unused;

    alu #(
        .WIDTH(WIDTH)
    ) u_alu (
        .a(opa_mux_in),
        .b(opb_mux_in),
        .alu_ctrl(alu_control_in),
        .y(alu_result_wire),
        .flag(alu_flag_unused)
    );

    // BRANCH / JUMP RESOLUTION
    reg branch_taken_reg;
    reg [WIDTH-1:0] branch_target_reg;

    always @(*) begin
        branch_taken_reg  = 1'b0;
        branch_target_reg = pc_address_in + imm_data_in;

        if (jalr_in) begin
            branch_taken_reg  = 1'b1;
            branch_target_reg = (opa_mux_in + imm_data_in) & 32'hFFFF_FFFE;
        end else if (jal_op_in) begin
            branch_taken_reg = 1'b1;
        end else if (branch_op_in) begin
            case (branch_funct3_in)
                3'b000: branch_taken_reg = (opa_mux_in == opb_mux_in);                      // BEQ
                3'b001: branch_taken_reg = (opa_mux_in != opb_mux_in);                      // BNE
                3'b100: branch_taken_reg = ($signed(opa_mux_in) <  $signed(opb_mux_in));    // BLT
                3'b101: branch_taken_reg = ($signed(opa_mux_in) >= $signed(opb_mux_in));    // BGE
                3'b110: branch_taken_reg = (opa_mux_in < opb_mux_in);                       // BLTU
                3'b111: branch_taken_reg = (opa_mux_in >= opb_mux_in);                      // BGEU
                default: branch_taken_reg = 1'b0;
            endcase
        end
    end

    assign branch_taken_out  = branch_taken_reg;
    assign branch_target_out = branch_target_reg;

    // EX/MEM PIPELINE REGISTERS
    reg [WIDTH-1:0] alu_result_reg;
    reg [WIDTH-1:0] store_data_reg;
    reg [WIDTH-1:0] pc_address_reg;
    reg [WIDTH-1:0] next_sel_addr_reg;
    //reg [WIDTH-1:0] instruction_reg;

    reg             reg_write_reg;
    reg [1:0]       mem_reg_reg;
    reg             load_reg;
    reg             store_reg;
    reg [3:0]       mask_reg;
    
    reg [4:0]       rs1_reg;
    reg [4:0]       rs2_reg;
    reg [4:0]       rd_reg;

    always @(posedge clk, negedge rst) begin
        if (!rst) begin
            alu_result_reg    <= {WIDTH{1'b0}};
            store_data_reg    <= {WIDTH{1'b0}};
            pc_address_reg    <= {WIDTH{1'b0}};
            next_sel_addr_reg <= {WIDTH{1'b0}};
            //instruction_reg   <= {WIDTH{1'b0}};
            reg_write_reg     <= 1'b0;
            mem_reg_reg       <= 2'b00;
            load_reg          <= 1'b0;
            store_reg         <= 1'b0;
            mask_reg          <= 4'b0000;
            rs1_reg           <= 4'b0000;
            rs2_reg           <= 4'b0000;
            rd_reg            <= 4'b0000;
        end else begin
            alu_result_reg    <= alu_result_wire;
            store_data_reg    <= opb_data_in;
            pc_address_reg    <= pc_address_in;
            next_sel_addr_reg <= pc_address_in + 32'd4;
            //instruction_reg   <= instruction_in;
            reg_write_reg     <= reg_write_in;
            mem_reg_reg       <= mem_reg_in;
            load_reg          <= load_in;
            store_reg         <= store_in;
            mask_reg          <= mask_in;
            rs1_reg           <= rs1_in;
            rs2_reg           <= rs2_in;
            rd_reg            <= rd_in;
        end
    end

    assign alu_result_out    = alu_result_reg;
    assign store_data_out    = store_data_reg;
    assign reg_write_out     = reg_write_reg;
    assign mem_reg_out       = mem_reg_reg;
    assign load_out          = load_reg;
    assign store_out         = store_reg;
    assign mask_out          = mask_reg;
    //assign instruction_out   = instruction_reg;
    assign pc_address_out    = pc_address_reg;
    assign next_sel_addr_out = next_sel_addr_reg;
    
    assign rs1_out           = rs1_reg;
    assign rs2_out           = rs2_reg;
    assign rd_out            = rd_reg;

endmodule
