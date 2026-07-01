`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04.06.2026 12:28:31
// Design Name: 
// Module Name: alu
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


module alu #(
    parameter WIDTH = 32
    )(
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    input  wire [4:0]       alu_ctrl,
    output reg  [WIDTH-1:0] y,
    output wire             flag
    );
    reg [4:0]               shift_amt;
    reg [(2*WIDTH)-1:0]     mul_reg;
    always @(*) begin
        shift_amt   = b[4:0];
        
        // check amount of optimization
        case(alu_ctrl) 
            5'b00000: y = a + b;                             // add
            5'b00001: y = a - b;                             // sub
            5'b00010: y = a & b;                             // and
            5'b00011: y = a | b;                             // or
            5'b00100: y = a ^ b;                             // xor
            5'b00101: y = a << shift_amt;                    // shift left logical
            5'b00110: y = a >> shift_amt;                    // shift right logical
            5'b00111: y = $signed(a) >>> shift_amt;          // shift right arithmatic
            5'b01000: y = a <<< shift_amt;                   // shift left arithmatic
            5'b01001: y = ($signed(a) < $signed(b)) ? 1 : 0; // set less than signed
            5'b01010: y = (a < b) ? 1 : 0;                   // shift less than unsigned
            5'b01011: y = b;                                 // pass B
            
            // M Extension
            5'b10000: begin // MUL (Returns lower 32-bits)
                mul_reg = a * b;
                y       = mul_reg[WIDTH-1:0];
            end
            
            5'b10001: begin // MULH (Signed x Signed, returns upper 32-bits)
                mul_reg = $signed(a) * $signed(b);
                y       = mul_reg[(2*WIDTH)-1:WIDTH];
            end
            
            5'b10010: begin // MULHSU (Signed x Unsigned, upper bits) **FIXED VERILOG BUG**
                mul_reg = $signed(a) * $signed({1'b0, b});
                y       = mul_reg[(2*WIDTH)-1:WIDTH];
            end
            
            5'b10011: begin // MULHU (Unsigned x Unsigned, upper bits)
                mul_reg = a * b;
                y       = mul_reg[(2*WIDTH)-1:WIDTH];
            end
            
            5'b10100: begin // DIV (Signed Division with overflow/zero guards)
                if (b == 0) 
                    y = {WIDTH{1'b1}}; // RISC-V spec: Divide by zero returns -1
                else if (a == (1 << (WIDTH-1)) && b == {WIDTH{1'b1}})
                    y = a;             // RISC-V spec: Overflow (Min Negative / -1) returns Min Negative
                else 
                    y = $signed(a) / $signed(b);
            end
            
            5'b10101: begin // DIVU (Unsigned Division)
                if (b == 0) 
                    y = {WIDTH{1'b1}}; // unsigned divide by zero returns all 1s
                else 
                    y = a / b;
            end
            
            5'b10110: begin // REM (Signed Remainder / Modulo)
                if (b == 0) 
                    y = a;             // remainder by zero returns the dividend
                else if (a == (1 << (WIDTH-1)) && b == {WIDTH{1'b1}})
                    y = 0;             // overflow remainder returns 0
                else 
                    y = $signed(a) % $signed(b);
            end
            
            5'b10111: begin // REMU (Unsigned Remainder / Modulo)
                if (b == 0) 
                    y = a;             // unsigned remainder by zero returns dividend
                else 
                    y = a % b;
            end

            default: y = {WIDTH{1'b0}}; // default
        endcase
    end

    assign flag = (y == 32'b0);

endmodule
