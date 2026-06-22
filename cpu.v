`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 18.06.2026 18:06:04
// Design Name: 
// Module Name: cpu
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

// Convention: wire named determined by outputName_inputName_use
// Exception: when one output is fed to multiple units: outputUnit_use
// system wide wires like clk, rst are only known by use

module cpu#(
    parameter WIDTH = 32
    )(
    input wire      clk,
    input wire      rst,
    
    // Wires connecting with external memory (single port)
    input  wire               mem_ready,
    input  wire [WIDTH*4-1:0] mem_rdata,
    output wire [WIDTH*4-1:0] mem_wdata,
    output wire               mem_we,
    output wire               mem_req,
    output wire [WIDTH-1:0]   mem_addr
    );
    
    
    wire flush_pipeline;
    wire hazard_stall;
    wire [1:0] forwardA;
    wire [1:0] forwardB;
    
    
    // stall/redirects
    wire icache_stall;
    wire mem_pipe_stall;
    wire pipeline_stall = icache_stall | mem_pipe_stall;
    wire branch_taken_ex;
    
    // IF/ID (decoder.v)
    wire [WIDTH-1:0] ifid_instruction;
    wire [WIDTH-1:0] ifid_pc_address;
    
    // ID/EX wires
    wire [WIDTH-1:0] idex_opa_mux;
    wire [WIDTH-1:0] idex_opb_mux;
    wire [WIDTH-1:0] idex_opb_data;
    wire [WIDTH-1:0] idex_pc_address;
    wire [WIDTH-1:0] idex_imm_data;
    wire [4:0]       idex_alu_control;
    wire             idex_reg_write;
    wire [1:0]       idex_mem_reg;
    wire             idex_load;
    wire             idex_store;
    wire [3:0]       idex_mask;
    wire [WIDTH-1:0] idex_instruction;
    wire             idex_branch_op;
    wire             idex_jal_op;
    wire             idex_jalr;
    wire [2:0]       idex_branch_funct3;
    
    
    // FETCH (PC) wire
    wire [WIDTH-1:0] pc_address;
    wire [WIDTH-1:0] pc_previous;
    wire [WIDTH-1:0] if_instruction;
    wire             fetch_icache_req;
    wire [WIDTH-1:0] fetch_icache_addr;
   
   
    // i cache wires (connecting i cache with memory
    wire [WIDTH*4-1:0] mem_icache_rdata;
    wire               mem_icache_valid;
    wire               icache_mem_req;
    wire [WIDTH-1:0]   icache_mem_addr;

    // i_cache (no i cache writing support in this implementation)
    i_cache #(
        .WIDTH(WIDTH)
    ) u_icache(
        .clk            (clk),
        .rst            (rst),
        // input from CPU
        .cpu_req        (fetch_icache_req),
        .cpu_addr       (fetch_icache_addr),
        // output to CPU
        .cpu_rdata      (icache_fetch_rdata),
        .cache_ready    (icache_ready),
        .icache_stall   (icache_stall),
        // input from main memory
        .mem_rdata      (icache_mem_rdata),
        .mem_ready      (icache_mem_valid),
        // output from main memory
        .mem_req        (icache_mem_req),
        .mem_addr       (icache_mem_addr)

    );                   
    

    // inconsistency in design, fetch supports write operation
        // but i cache does not, so we_re and mask hang lose
    fetch #(
        .WIDTH(WIDTH)
    ) u_fetch(
        .clk                   (clk),
        .rst                   (rst),       
        // input from EX
        .branch_taken          (ex_branch_taken),
        .branch_target         (ex_branch_target),       
        // input from i cache
        .instruction_fetch     (icache_fetch_rdata),
        .icache_stall          (icache_stall),
        // output to i cache 
        .request               (fetch_icache_req),
        .we_re                 (),
        .mask                  (),
        .address_out           (fetch_icache_addr),
        // output to IF/ID
        .instruction           (fetch_instruction),
        .pc_address            (fetch_pc_address)

    );
    
    // wires connected if_id to decoder.v
    wire [WIDTH-1:0] ifid_decoder_instruction;
    wire [WIDTH-1:0] ifid_decoder_pc_address;
    
    if_id #(
        .WIDTH(WIDTH)
    ) u_ifid(
        .clk                 (clk),
        .rst                 (rst),
        .stall               (),
        .flush               (),
        // input from fetch
        .instruction_in      (fetch_instruction),
        .pc_address_in       (fetch_pc_address),
        // output to ID
        .instruction_out     (ifid_decoder_instruction),
        .pc_address_out      (ifid_decoder_pc_address)
    );
    
    // Decoder
    wire              dec_idex_load;
    wire              dec_idex_store;
    wire              dec_idex_branch_op;
    wire              dec_idex_jal_op;
    wire              dec_idex_jalr_op;
    wire              dec_idex_next_sel_unused;
    wire [2:0]        dec_idex_branch_funct3;
    wire              dec_idex_reg_write_en_out;
    wire [4:0]        dec_idex_alu_control;
    wire [1:0]        dec_idex_mem_to_reg;
    wire [3:0]        dec_idex_mask;
    wire [2:0]        dec_idex_mem_funct3;
    wire [31:0]       dec_idex_opb_data;
    wire [31:0]       dec_idex_opa_mux_out;
    wire [31:0]       dec_idex_opb_mux_out;
    wire [31:0]       dec_idex_imm_data_out;
    wire [31:0]       dec_idex_pc_address_out;
    wire [4:0]        dec_idex_rs1;
    wire [4:0]        dec_idex_rs2;
    wire [4:0]        dec_idex_rd;
    
    wire [6:0] if_opcode = ifid_instruction[6:0];
    wire [2:0] if_funct3 = ifid_instruction[14:12];
    
    /*
    reg [3:0] store_mask_top;
    always @(*) begin
        store_mask_top = 4'b0000;
        if(if_opcode == 7'b0100011) begin
            case(if_funct3)
                3'b000:  store_mask_top = 4'b0001;
                3'b001:  store_mask_top = 4'b0011;
                3'b010:  store_mask_top = 4'b1111;
                default: store_mask_top = 4'b0000;
             endcase
        end
    end
    */
    
    // Write back-decoder wire
    wire [WIDTH-1:0] wb_dec_rd_data;
    wire [WIDTH-1:0] wb_dec_instruction;
    
    // ID + ID/EX both in this module
    decoder #(
        .WIDTH(WIDTH)
    )u_dec0(
       .clk                   (clk),
       .rst                   (rst),
       
       
       .valid                 (),
       .reg_write_en_in       (),
       .load_control_signal   (),
        
       // From IF/ID register
       .instruction           (ifid_decoder_instruction),
       .pc_address            (ifid_decoder_pc_address),
       // WB
       .rd_wb_data            (wb_dec_rd_data),
       .instruction_rd        (wb_dec_instruction),
       // output to EX
       .load                  (dec_idex_load),
       .store                 (dec_idex_store),
       .branch_op             (dec_idex_branch_op),
       .jal_op                (dec_idex_jal_op),
       .jalr                  (dec_idex_jalr_op),
       .branch_funct3         (dec_idex_branch_funct3),
       .reg_write_en_out      (dec_idex_reg_write_en_out),
       .alu_control           (dec_idex_alu_control),
       .mem_to_reg            (dec_idex_mem_to_reg),
       
       // passed via EX as EX/MEM is contained withing unit and require timing consistency
       .mask                  (dec_idex_mask),
       .mem_funct3            (dec_idex_mem_funct3),
                              
       .rs1                   (dec_idex_rs1),
       .rs2                   (dec_idex_rs2),
       .rd                    (dec_idex_rd),
       .opb_data              (dec_idex_opb_data),
       .opa_mux_out           (dec_idex_opa_mux_out),
       .opb_mux_out           (dec_idex_opb_mux_out),
       .imm_data_out          (dec_idex_imm_data_out),
       .pc_address_out        (dec_idex_pc_address_out)
    );                        
    
    
    // idex to ex wires
    wire              idex_ex_load;
    wire              idex_ex_store;
    wire              idex_ex_branch_op;
    wire              idex_ex_jal_op;
    wire              idex_ex_jalr_op;
    wire              idex_ex_next_sel_unused;
    wire [2:0]        idex_ex_branch_funct3;
    wire              idex_ex_reg_write_en_out;
    wire [4:0]        idex_ex_alu_control;
    wire [1:0]        idex_ex_mem_to_reg;
    wire [3:0]        idex_ex_mask;
    wire [2:0]        idex_ex_mem_funct3;
    wire [4:0]        idex_ex_rs1;
    wire [4:0]        idex_ex_rs2;
    wire [31:0]       idex_ex_opb_data;
    wire [31:0]       idex_ex_opa_mux_out;
    wire [31:0]       idex_ex_opb_mux_out;
    wire [31:0]       idex_ex_imm_data_out;
    wire [31:0]       idex_ex_pc_address_out;
    
    // idex to hazard unit
    wire [4:0]        idex_rs1;
    wire [4:0]        idex_rs2;
    wire [4:0]        idex_rd;
        
    id_ex #(
        .WIDTH(WIDTH)
    ) u_idex0 (
        .clk                    (clk),
        .rst                    (rst),
        
        .stall                  (pipeline_stall),
        .flush                  (branch_taken_ex),
        
        // rs1, rs2, rd passed to both EX and to hazard unit
        .rs1_in                 (dec_idex_rs1),
        .rs2_in                 (dec_idex_rs2),
        .rd_in                  (dec_idex_rd),   
                           
        .opa_mux_in             (dec_idex_opa_mux_out),
        .opb_mux_in             (dec_idex_opb_mux_out),
        .opb_data_in            (dec_idex_opb_data),
        .pc_address_in          (dec_idex_pc_address_out),
        .imm_data_in            (dec_idex_imm_data_out),
        .alu_control_in         (dec_idex_alu_control),
        .reg_write_in           (dec_idex_reg_write_en_out),
        .mem_reg_in             (dec_idex_mem_to_reg),
        .load_in                (dec_idex_load),
        .store_in               (dec_idex_store),
        .mask_in                (dec_idex_mask),
        .mem_funct3_in          (dec_idex_mem_funct3),
        .instruc_rd_in          (),
        .branch_op_in           (dec_idex_branch_op),
        .jal_op_in              (dec_idex_jal_op),
        .jalr_in                (dec_idex_jalr_op),
        .branch_funct3_in       (dec_idex_branch_funct3),
        
        .rs1_out                (idex_rs1),
        .rs2_out                (idex_rs2),
        .rd_out                 (idex_rd), 
               
        .opa_mux_out            (idex_ex_opa_mux_out),      
        .opb_mux_out            (idex_ex_opb_mux_out),      
        .opb_data_out           (idex_ex_opb_data),         
        .pc_address_out         (idex_ex_pc_address_out),   
        .imm_data_out           (idex_ex_imm_data_out),     
        .alu_control_out        (idex_ex_alu_control),      
        .reg_write_out          (idex_ex_reg_write_en_out), 
        .mem_reg_out            (idex_ex_mem_to_reg),       
        .load_out               (idex_ex_load),             
        .store_out              (idex_ex_store),            
        .mask_out               (idex_ex_mask),             
        .mem_funct3_out         (idex_ex_mem_funct3),       
        //.instruc_rd_out         (),        
        .branch_op_out          (idex_ex_branch_op),        
        .jal_op_out             (idex_ex_jal_op),           
        .jalr_out               (idex_ex_jalr_op),          
        .branch_funct3_out      (idex_ex_branch_funct3)    
    );
    
    // EX output
    wire [WIDTH-1:0] ex_alu_result;
    wire [WIDTH-1:0] ex_store_data;
    wire [WIDTH-1:0] ex_pc_address;
    wire             ex_branch_taken_out;
    //wire [WIDTH-1:0] ex_instruction;
    wire             ex_reg_write;
    wire [1:0]       ex_mem_reg;
    wire             ex_load;
    wire             ex_store;
    wire [3:0]       ex_mem_mask;
    wire [2:0]       ex_mem_funct3;
    wire [WIDTH-1:0] ex_next_sel_addr;
    
    wire [4:0]       ex_haz_rs1;
    wire [4:0]       ex_haz_rs2;
    wire [4:0]       ex_haz_rd;
    
    EX #
    (
        .WIDTH(WIDTH)
    ) u_ex0(
        .clk                  (clk),
        .rst                  (rst),
        .rs1_in               (idex_rs1),
        .rs2_in               (idex_rs2),
        .rd_in                (idex_rd),
        .opa_mux_in           (idex_ex_opa_mux_out),
        .opb_mux_in           (idex_ex_opb_mux_out),
        .opb_data_in          (idex_ex_opb_data),
        .pc_address_in        (idex_ex_pc_address_out),
        .imm_data_in          (idex_ex_imm_data_out),
        .alu_control_in       (idex_ex_alu_control),
                            
        .reg_write_in         (idex_ex_reg_write_en_out),
        .mem_reg_in           (idex_ex_mem_to_reg),
        .load_in              (idex_ex_load),
        .store_in             (idex_ex_store),
        .mask_in              (idex_ex_mask),
        .mem_funct3           (idex_ex_mem_funct3),
        //.instruc_rd_in        (),
                             
        .branch_op_in         (idex_ex_branch_op),
        .jal_op_in            (idex_ex_jal_op),
        .jalr_in              (idex_ex_jalr_op),
        .branch_funct3_in     (idex_ex_branch_funct3),
                       
        .alu_result_out       (ex_alu_result),
        .store_data_out       (ex_store_data),
        .branch_taken_out     (ex_pc_address),
        .branch_target_out    (ex_branch_taken_out),
        .reg_write_out        (ex_reg_write),
        .mem_reg_out          (ex_mem_reg),
        .load_out             (ex_load),
        .store_out            (ex_store),
        .mask_out             (ex_mem_mask),
        .mem_funct3_out       (ex_mem_funct3),
        //.instruc_rd_out       (),
        .pc_address_out       (ex_pc_address),
        .next_sel_addr_out    (ex_next_sel_addr),
        
        // connects to hazard
        .rs1_out              (ex_haz_rs1),
        .rs2_out              (ex_haz_rs2),
        .rd_out               (ex_haz_rd)
    );
    
    assign flush_pipeline = ex_branch_taken;
    
    
    
   // MEM output
   wire             mem_valid;
   wire             mem_dcache_req;
   wire             mem_dcache_rw;
   wire [3:0]       mem_dcache_mask;
   wire [WIDTH-1:0] mem_dcache_addr;
   wire [WIDTH-1:0] mem_dcache_wdata;
   wire [WIDTH-1:0] mem_wrap_load;
   wire [WIDTH-1:0] mem_alu_reg;
   wire [WIDTH-1:0] mem_next_sel_address;
   wire [WIDTH-1:0] mem_instruction;
   wire [WIDTH-1:0] mem_pre_address;
   wire             mem_reg_write;
   wire [1:0]       mem_mem_reg;
   
   
   // d-cache wires
    wire [WIDTH-1:0]        d_cache_rdata;
    wire                    d_cache_ready;
    wire                    d_cache_stall;
    wire                    d_mem_req;
    wire                    d_mem_we;
    wire [WIDTH-1:0]        d_mem_addr;
    wire [127:0]            d_mem_wdata;
    wire [127:0]            d_mem_rdata;
    wire                    d_mem_ready;
   
   
   MEM #(
        .WIDTH(WIDTH)
   ) u_mem0 (
        .clk                 (clk),
        .rst                 (rst),
                                
        .pipe_req            (ex_load | ex_store),
        .pipe_we             (ex_store),
        .pipe_mask           (ex_mem_mask),
        .pipe_addr           (),
        .pipe_wdata          (),
                            
        .valid               (mem_valid),
        .pipe_stall          (d_cache_rdata),
        
        // dcache input
        .cache_ready         (d_cache_ready),
        .cache_rdata         (),
        // dcache output          
        .cache_req           (mem_dcache_req),
        .cache_rw            (mem_dcache_rw),
        .cache_mask          (mem_dcache_mask),
        .cache_addr          (mem_dcache_addr),
        .cache_wdata         (mem_dcache_wdata),
                           
        // EX/MEM input             
        .reg_write_en        (ex_mem_reg),
        .mem_reg_in          (ex_mem_reg),
        .wrap_load_in        (),
        .alu_res             (ex_alu_result),
        .next_sel_addr       (ex_next_sel_addr),
        .instruction_in      (),
        .pre_address_in      (ex_pc_address),
        
        // MEM/WB output         
        .reg_write_out       (),
        .mem_reg_out         (),
        .wrap_load_out       (),
        .alu_res_out         (),
        .next_sel_address    (),
        .instruction_out     (),
        .pre_address_out     ()
   );
   

   
    d_cache #(
        .WIDTH(WIDTH)
    ) u_dcache0 (
        .clk                 (clk),
        .rst                 (rst),
        .cpu_req             (mem_dcache_req),
        .cpu_we              (mem_dcache_rw),
        .cpu_mask            (mem_dcache_mask),
        .cpu_addr            (mem_dcache_addr),
        .cpu_wdata           (mem_dcache_wdata),
        .cpu_rdata           (d_cache_rdata),
        .cache_ready         (d_cache_ready),
        .dcache_stall        (d_cache_stall),
        .mem_req             (d_mem_req),
        .mem_we              (d_mem_we),
        .mem_addr            (d_mem_addr),
        .mem_wdata           (d_mem_wdata),
        .mem_rdata           (d_mem_rdata),
        .mem_ready           (d_mem_ready)
    );
   
    // writeback data
   wire [WIDTH-1:0] wb_data;
   
   write_back #(
        .WIDTH(WIDTH)
   ) u_wb(
        .mem_to_reg         (mem_mem_reg),
        .alu_out            (mem_alu_res),
        .data_mem_out       (mem_wrap_load),
        .next_sel_address   (mem_next_sel_address),
        .rd_sel_mux_out     (wb_data)
   );
   
   
   mem_arbiter #(
        .WIDTH(WIDTH)
    ) u_arbiter (
        .clk           (clk),
        .rst           (rst),
        .i_req         (i_mem_req),
        .i_we          (i_mem_we),
        .i_addr        (i_mem_addr),
        .i_wdata       (i_mem_wdata),
        .i_ready       (i_mem_ready),
        .i_rdata       (i_mem_rdata),
        .d_req         (d_mem_req),
        .d_we          (d_mem_we),
        .d_addr        (d_mem_addr),
        .d_wdata       (d_mem_wdata),
        .d_ready       (d_mem_ready),
        .d_rdata       (d_mem_rdata),
        .mem_req       (mem_req),
        .mem_we        (mem_we),
        .mem_addr      (mem_addr),
        .mem_wdata     (mem_wdata),
        .mem_rdata     (mem_rdata),
        .mem_ready     (mem_ready)
    );
   
   hazard_unit u_hazunit0 (
       // from id
       .id_rs1           (idex_haz_rs1),      
       .id_rs2           (idex_haz_rs2),
       // from ex
       .ex_load          (ex_load),
       .ex_rd            (ex_haz_rd),            
       .ex_rs1           (ex_haz_rs1),
       .ex_rs2           (ex_haz_rs2),
       // from mem        
       .mem_regwrite     (),
       .mem_rd           (),
       // from wb         
       .wb_regwrite      (),
       .wb_rd            (),
                          
       .branch_taken     (),         
                          
       .icache_stall     (icache_stall),
       .dcache_stall     (),
                          
       .stall_pc         (),
       .stall_ifid       (),
                          
       .flush_ifid       (),
       .flush_idex       (),
                          
       .forwardA         (forwardA),
       .forwardB         (forwardB)
   );
    
endmodule