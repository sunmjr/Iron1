`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11.06.2026 18:10:35
// Design Name: 
// Module Name: program_counter
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

module program_counter #(
    parameter WIDTH = 32
)(
    input  wire             clk,
    input  wire             rst,            // Active-low reset

    // Pipeline control
    input  wire             stall,          // 1 = hold PC

    // Redirect from EX stage
    input  wire             branch_taken,   // BEQ/BNE/JAL/JALR taken
    input  wire [WIDTH-1:0] branch_target,  // Target address

    output reg  [WIDTH-1:0] address_out,
    output wire [WIDTH-1:0] pre_address_pc
);

    reg [WIDTH-1:0] previous_pc;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            address_out <= {WIDTH{1'b0}};
            previous_pc <= {WIDTH{1'b0}};
        end
        else begin
            previous_pc <= address_out;

            if (stall) begin
                address_out <= address_out;
            end
            else if (branch_taken) begin
                address_out <= branch_target;
            end
            else begin
                address_out <= address_out + 32'd4;
            end
        end
    end

    assign pre_address_pc = previous_pc;

endmodule