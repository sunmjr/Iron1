`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.06.2026 16:16:47
// Design Name: 
// Module Name: MEM
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

module MEM #(
    parameter WIDTH = 32
)(
    input  wire             clk,
    input  wire             rst,

    // EX -> MEM Memory Request Interface
    input  wire             pipe_req,
    input  wire             pipe_we,          // 0=read, 1=write
    input  wire [3:0]       pipe_mask,
    input  wire [WIDTH-1:0] pipe_addr,
    input  wire [WIDTH-1:0] pipe_wdata,

    output wire             valid,
    output wire             pipe_stall,

    // MEM -> DCache Interface
    output wire             cache_req,
    output wire             cache_rw,
    output wire [3:0]       cache_mask,
    output wire [WIDTH-1:0] cache_addr,
    output wire [WIDTH-1:0] cache_wdata,

    input  wire             cache_ready,
    input  wire [WIDTH-1:0] cache_rdata,

    // EX/MEM input
    input  wire             reg_write_en,
    input  wire [1:0]       mem_reg_in,
    input  wire [WIDTH-1:0] wrap_load_in,
    input  wire [WIDTH-1:0] alu_res,
    input  wire [WIDTH-1:0] next_sel_addr,
    //input  wire [WIDTH-1:0] instruction_in,
    input  wire [WIDTH-1:0] pre_address_in,

    // MEM/WB Pipeline Outputs
    output wire             reg_write_out,
    output wire [1:0]       mem_reg_out,
    output wire [WIDTH-1:0] wrap_load_out,
    output wire [WIDTH-1:0] alu_res_out,
    output wire [WIDTH-1:0] next_sel_address,
    //output wire [WIDTH-1:0] instruction_out,
    output wire [WIDTH-1:0] pre_address_out
);

    // D-Cache Request Forwarding
    assign cache_req   = pipe_req;
    assign cache_rw    = pipe_we;
    assign cache_mask  = pipe_mask;
    assign cache_addr  = pipe_addr;
    assign cache_wdata = pipe_wdata;

    // Handshake / Stall Logic
    assign pipe_stall = pipe_req && !cache_ready;

    assign valid = pipe_req && cache_ready;

    // MEM/WB Pipeline Registers
    reg             reg_write_reg;
    reg [1:0]       mem_reg_reg;
    reg [WIDTH-1:0] wrap_load_reg;
    reg [WIDTH-1:0] alu_res_reg;
    reg [WIDTH-1:0] next_sel_addr_reg;
    reg [WIDTH-1:0] instruction_reg;
    reg [WIDTH-1:0] pre_address_reg;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            reg_write_reg     <= 1'b0;
            mem_reg_reg       <= 2'b00;
            wrap_load_reg     <= {WIDTH{1'b0}};
            alu_res_reg       <= {WIDTH{1'b0}};
            next_sel_addr_reg <= {WIDTH{1'b0}};
            instruction_reg   <= {WIDTH{1'b0}};
            pre_address_reg   <= {WIDTH{1'b0}};
        end
        else if (!pipe_stall) begin
            reg_write_reg     <= reg_write_en;
            mem_reg_reg       <= mem_reg_in;

            // For loads, WB will eventually select cache data.
            // For ALU ops/JAL/JALR these fields simply pass through.
            wrap_load_reg     <= wrap_load_in;

            alu_res_reg       <= alu_res;
            next_sel_addr_reg <= next_sel_addr;
            //instruction_reg   <= instruction_in;
            pre_address_reg   <= pre_address_in;
        end
    end

    // MEM/WB Outputs
    assign reg_write_out    = reg_write_reg;
    assign mem_reg_out      = mem_reg_reg;
    assign wrap_load_out    = wrap_load_reg;
    assign alu_res_out      = alu_res_reg;
    assign next_sel_address = next_sel_addr_reg;
    //assign instruction_out  = instruction_reg;
    assign pre_address_out  = pre_address_reg;

endmodule