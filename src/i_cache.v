`timescale 1ns / 1ps

module i_cache #(
    parameter WIDTH = 32
)(
    input wire              clk,
    input wire              rst,          // active-low reset

    // CPU PIPELINE INTERFACE
    input wire              cpu_req,      // 1 = CPU wants an instruction
    input wire [WIDTH-1:0]  cpu_addr,     // instruction address (PC)
    output reg  [WIDTH-1:0] cpu_rdata,    // instruction returned to CPU
    output wire             cache_ready,  // 1 = hit / data valid
    output wire             icache_stall, // 1 = cache is busy on a miss

    // MAIN MEMORY INTERFACE
    output reg                mem_req,      // one-cycle request pulse
    output reg  [WIDTH-1:0]   mem_addr,     // aligned to 64 bytes
    input  wire [WIDTH*4-1:0] mem_rdata,    // 128-bit beat
    input  wire               mem_ready     // valid for each beat
);

    // Cache configuration
    localparam SETS      = 32;
    localparam WAYS      = 2;
    localparam LINE_SIZE = 64; // bytes

    // Address slicing
    wire [20:0] cpu_tag   = cpu_addr[31:11];
    wire [4:0]  cpu_index = cpu_addr[10:6];
    wire [3:0]  word_sel  = cpu_addr[5:2];

    // =========================================================================
    // STORAGE
    // =========================================================================
    reg [511:0] data_mem [0:SETS-1][0:WAYS-1];
    reg [20:0]  tag_mem  [0:SETS-1][0:WAYS-1];
    reg         valid_mem[0:SETS-1][0:WAYS-1];

    // lru_mem stores the MRU way:
    // 0 => way0 was used most recently
    // 1 => way1 was used most recently
    reg lru_mem [0:SETS-1];

    // =========================================================================
    // HIT LOGIC
    // =========================================================================
    wire hit_way0 = valid_mem[cpu_index][0] && (tag_mem[cpu_index][0] == cpu_tag);
    wire hit_way1 = valid_mem[cpu_index][1] && (tag_mem[cpu_index][1] == cpu_tag);
    wire cache_hit = cpu_req && (hit_way0 || hit_way1);

    assign cache_ready  = cache_hit;
    assign icache_stall = (current_state == STATE_ALLOCATE) || (cpu_req && !cache_hit);

    // =========================================================================
    // FSM
    // =========================================================================
    localparam STATE_IDLE     = 2'b00;
    localparam STATE_ALLOCATE = 2'b01;

    reg [1:0] current_state, next_state;

    // 4 beats * 128 bits = 512-bit line
    reg [1:0]  burst_counter;
    reg [511:0] line_buffer;

    // Victim selection:
    // 1) use invalid way if one exists
    // 2) otherwise use the opposite of MRU
    reg victim_way;

    always @(*) begin
        if (!valid_mem[cpu_index][0]) begin
            victim_way = 1'b0;
        end else if (!valid_mem[cpu_index][1]) begin
            victim_way = 1'b1;
        end else begin
            victim_way = ~lru_mem[cpu_index];
        end
    end

    always @(*) begin
        next_state = current_state;
        case (current_state)
            STATE_IDLE: begin
                if (cpu_req && !cache_hit) begin
                    next_state = STATE_ALLOCATE;
                end
            end

            STATE_ALLOCATE: begin
                if (mem_ready && (burst_counter == 2'd3)) begin
                    next_state = STATE_IDLE;
                end
            end

            default: begin
                next_state = STATE_IDLE;
            end
        endcase
    end

    always @(posedge clk) begin
        if (!rst) begin
            current_state <= STATE_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // =========================================================================
    // SEQUENTIAL REFILL / UPDATE LOGIC
    // =========================================================================
    integer s, w;

    always @(posedge clk) begin
        if (!rst) begin
            burst_counter <= 2'b00;
            mem_req       <= 1'b0;
            mem_addr      <= {WIDTH{1'b0}};
            line_buffer   <= 512'b0;
            cpu_rdata     <= {WIDTH{1'b0}};

            for (s = 0; s < SETS; s = s + 1) begin
                lru_mem[s] <= 1'b0;
                for (w = 0; w < WAYS; w = w + 1) begin
                    valid_mem[s][w] <= 1'b0;
                    tag_mem[s][w]   <= 21'b0;
                    data_mem[s][w]  <= 512'b0;
                end
            end
        end else begin
            case (current_state)
                STATE_IDLE: begin
                    mem_req <= 1'b0;

                    if (cache_hit) begin
                        // Update MRU bit on a hit
                        if (hit_way0) begin
                            lru_mem[cpu_index] <= 1'b0;
                        end else begin
                            lru_mem[cpu_index] <= 1'b1;
                        end
                    end else if (cpu_req && !cache_hit) begin
                        // Start refill request
                        mem_req       <= 1'b1;
                        mem_addr      <= {cpu_addr[31:6], 6'b000000}; // 64-byte aligned
                        burst_counter <= 2'b00;
                    end
                end

                STATE_ALLOCATE: begin
                    mem_req <= 1'b0;

                    if (mem_ready) begin
                        // Assemble the 512-bit cache line from 4 beats
                        case (burst_counter)
                            2'b00: line_buffer[127:0]   <= mem_rdata;
                            2'b01: line_buffer[255:128]  <= mem_rdata;
                            2'b10: line_buffer[383:256]  <= mem_rdata;
                            2'b11: line_buffer[511:384]  <= mem_rdata;
                        endcase

                        if (burst_counter == 2'd3) begin
                            // Final beat: write the line into the chosen victim way
                            if (victim_way == 1'b0) begin
                                data_mem[cpu_index][0]  <= {mem_rdata, line_buffer[383:0]};
                                tag_mem[cpu_index][0]   <= cpu_tag;
                                valid_mem[cpu_index][0] <= 1'b1;
                                lru_mem[cpu_index]      <= 1'b0; // way0 becomes MRU
                            end else begin
                                data_mem[cpu_index][1]  <= {mem_rdata, line_buffer[383:0]};
                                tag_mem[cpu_index][1]   <= cpu_tag;
                                valid_mem[cpu_index][1] <= 1'b1;
                                lru_mem[cpu_index]      <= 1'b1; // way1 becomes MRU
                            end

                            burst_counter <= 2'b00;
                        end else begin
                            burst_counter <= burst_counter + 1'b1;
                        end
                    end
                end

                default: begin
                    mem_req <= 1'b0;
                end
            endcase
        end
    end

    // =========================================================================
    // WORD MUX
    // =========================================================================
    reg [511:0] selected_line;

    always @(*) begin
        selected_line = 512'b0;
        cpu_rdata     = {WIDTH{1'b0}};

        if (hit_way0) begin
            selected_line = data_mem[cpu_index][0];
        end else if (hit_way1) begin
            selected_line = data_mem[cpu_index][1];
        end

        case (word_sel)
            4'h0: cpu_rdata = selected_line[31:0];
            4'h1: cpu_rdata = selected_line[63:32];
            4'h2: cpu_rdata = selected_line[95:64];
            4'h3: cpu_rdata = selected_line[127:96];
            4'h4: cpu_rdata = selected_line[159:128];
            4'h5: cpu_rdata = selected_line[191:160];
            4'h6: cpu_rdata = selected_line[223:192];
            4'h7: cpu_rdata = selected_line[255:224];
            4'h8: cpu_rdata = selected_line[287:256];
            4'h9: cpu_rdata = selected_line[319:288];
            4'hA: cpu_rdata = selected_line[351:320];
            4'hB: cpu_rdata = selected_line[383:352];
            4'hC: cpu_rdata = selected_line[415:384];
            4'hD: cpu_rdata = selected_line[447:416];
            4'hE: cpu_rdata = selected_line[479:448];
            4'hF: cpu_rdata = selected_line[511:480];
            default: cpu_rdata = {WIDTH{1'b0}};
        endcase
    end

endmodule