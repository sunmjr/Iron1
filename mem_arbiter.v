`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 20.06.2026 18:36:44
// Design Name: 
// Module Name: mem_arbiter
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

module mem_arbiter #(
    parameter WIDTH = 32
)(
    input  wire             clk,
    input  wire             rst,

    // I-cache client
    input  wire             i_req,
    input  wire             i_we,
    input  wire [WIDTH-1:0] i_addr,
    input  wire [127:0]     i_wdata,
    output wire             i_ready,
    output wire [127:0]     i_rdata,

    // D-cache client
    input  wire             d_req,
    input  wire             d_we,
    input  wire [WIDTH-1:0] d_addr,
    input  wire [127:0]     d_wdata,
    output wire             d_ready,
    output wire [127:0]     d_rdata,

    // Shared external memory
    output reg              mem_req,
    output reg              mem_we,
    output reg  [WIDTH-1:0] mem_addr,
    output reg  [127:0]     mem_wdata,
    input  wire [127:0]     mem_rdata,
    input  wire             mem_ready
);

    localparam SEL_NONE = 2'b00;
    localparam SEL_I    = 2'b01;
    localparam SEL_D    = 2'b10;

    reg [1:0] active_sel;
    reg [1:0] beat_count;
    reg       busy;

    wire choose_d = d_req;
    wire choose_i = i_req && !d_req;

    assign i_ready = (busy && active_sel == SEL_I) ? mem_ready : 1'b0;
    assign d_ready = (busy && active_sel == SEL_D) ? mem_ready : 1'b0;

    assign i_rdata = (busy && active_sel == SEL_I) ? mem_rdata : 128'b0;
    assign d_rdata = (busy && active_sel == SEL_D) ? mem_rdata : 128'b0;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            busy       <= 1'b0;
            active_sel <= SEL_NONE;
            beat_count <= 2'b00;
            mem_req    <= 1'b0;
            mem_we     <= 1'b0;
            mem_addr   <= {WIDTH{1'b0}};
            mem_wdata  <= 128'b0;
        end else begin
            mem_req <= 1'b0;

            if (!busy) begin
                if (choose_d) begin
                    busy       <= 1'b1;
                    active_sel <= SEL_D;
                    beat_count <= 2'b00;
                    mem_req    <= 1'b1;
                    mem_we     <= d_we;
                    mem_addr   <= d_addr;
                    mem_wdata  <= d_wdata;
                end else if (choose_i) begin
                    busy       <= 1'b1;
                    active_sel <= SEL_I;
                    beat_count <= 2'b00;
                    mem_req    <= 1'b1;
                    mem_we     <= i_we;
                    mem_addr   <= i_addr;
                    mem_wdata  <= i_wdata;
                end
            end else begin
                if (mem_ready) begin
                    if (beat_count == 2'd3) begin
                        busy       <= 1'b0;
                        active_sel <= SEL_NONE;
                        beat_count <= 2'b00;
                    end else begin
                        beat_count <= beat_count + 1'b1;
                    end
                end
            end
        end
    end
endmodule