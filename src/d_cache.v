`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.06.2026 17:44:35
// Design Name: 
// Module Name: d_cache
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


module d_cache #(
    parameter WIDTH = 32
)(
    input wire             clk,
    input wire             rst,          // active-low reset

    // CPU interface
    input wire             cpu_req,      // 1 = request active
    input wire             cpu_we,       // 0 = load, 1 = store
    input wire [3:0]       cpu_mask,     // big-endian byte lanes:
                                         // [3]=addr+0 (MSB byte of word)
                                         // [2]=addr+1
                                         // [1]=addr+2
                                         // [0]=addr+3 (LSB byte of word)
                                         
    input wire [WIDTH-1:0] cpu_addr,     // byte address
    input wire [WIDTH-1:0] cpu_wdata,    // store data
    output reg [WIDTH-1:0] cpu_rdata,    // load data (raw 32-bit word)
    output wire            cache_ready,  // hit / transaction completed
    output wire            dcache_stall, // cache busy / miss in progress

    // main memory interface
    output reg              mem_req,     // one-cycle transaction pulse
    output reg              mem_we,      // 0 = read refill, 1 = writeback
    output reg  [WIDTH-1:0] mem_addr,    // 64-byte aligned line base
    output reg  [127:0]     mem_wdata,   // big-endian 128-bit beat to memory
    input wire [127:0]      mem_rdata,   // big-endian 128-bit beat from memory
    input wire              mem_ready    // one pulse per beat
);

    // cache (TODO: section added later, parts of code does not align with these), TODO: do these values even make sense
    localparam SETS      = 16;
    localparam WAYS      = 4;
    localparam LINE_SIZE = 64;          // bytes

    // TODO: make the values a function of localparam
    wire [21:0] cpu_tag   = cpu_addr[31:10];
    wire [3:0]  cpu_index = cpu_addr[9:6];
    wire [3:0]  word_sel  = cpu_addr[5:2];

    // storage
    reg [511:0] data_mem  [0:SETS-1][0:WAYS-1];
    reg [21:0]  tag_mem   [0:SETS-1][0:WAYS-1];
    reg         valid_mem [0:SETS-1][0:WAYS-1];
    reg         dirty_mem [0:SETS-1][0:WAYS-1];

    // 3-bit tree PLRU per set
    // bit0: 0 = ways 0/1 are MRU-side, 1 = ways 2/3 are MRU-side
    // bit1: 0 = way0 MRU over way1, 1 = way1 MRU over way0
    // bit2: 0 = way2 MRU over way3, 1 = way3 MRU over way2
    reg [2:0] lru_mem [0:SETS-1];

    // We keep one 128-bit buffer for writeback/fill sequencing.
    reg [511:0] line_buffer;

    // Dirty writeback requires one extra pulse after eviction finishes.
    reg fetch_req_pending;

    // Burst counter: 0,1,2,3 for the four 128-bit beats.
    reg [1:0] burst_counter;

    // FSM
    localparam STATE_IDLE  = 2'b00;
    localparam STATE_EVICT = 2'b01;
    localparam STATE_FETCH = 2'b10;

    reg [1:0] current_state, next_state;

    // =========================================================================
    // HELPER FUNCTIONS
    // =========================================================================

    // Big-endian byte in a 512-bit cache line:
    // byte offset 0 is the most significant byte of the line.
    function [7:0] get_line_byte;
        input [511:0] line;
        input [5:0]   byte_off;
        begin
            get_line_byte = line[511 - (byte_off * 8) -: 8];
        end
    endfunction

    function [31:0] get_line_word;
        input [511:0] line;
        input [3:0]   word_index;
        reg   [5:0]   base;
        begin
            base = {word_index, 2'b00};
            get_line_word = {
                get_line_byte(line, base + 6'd0),
                get_line_byte(line, base + 6'd1),
                get_line_byte(line, base + 6'd2),
                get_line_byte(line, base + 6'd3)
            };
        end
    endfunction

    function [511:0] apply_store_to_line;
        input [511:0] line;
        input [3:0]   word_index;
        input [3:0]   mask;
        input [31:0]  wdata;
        reg   [511:0] tmp;
        reg   [5:0]   base;
        begin
            tmp  = line;
            base = {word_index, 2'b00};

            // Big-endian byte lanes:
            // mask[3] -> address+0, wdata[31:24]
            // mask[2] -> address+1, wdata[23:16]
            // mask[1] -> address+2, wdata[15:8]
            // mask[0] -> address+3, wdata[7:0]
            if (mask[3]) tmp[511 - ((base + 6'd0) * 8) -: 8] = wdata[31:24];
            if (mask[2]) tmp[511 - ((base + 6'd1) * 8) -: 8] = wdata[23:16];
            if (mask[1]) tmp[511 - ((base + 6'd2) * 8) -: 8] = wdata[15:8];
            if (mask[0]) tmp[511 - ((base + 6'd3) * 8) -: 8] = wdata[7:0];

            apply_store_to_line = tmp;
        end
    endfunction

    task update_plru;
        input [3:0] set_idx;
        input [1:0] way;
        begin
            case (way)
                2'd0: begin
                    lru_mem[set_idx][0] = 1'b0;
                    lru_mem[set_idx][1] = 1'b0;
                end
                2'd1: begin
                    lru_mem[set_idx][0] = 1'b0;
                    lru_mem[set_idx][1] = 1'b1;
                end
                2'd2: begin
                    lru_mem[set_idx][0] = 1'b1;
                    lru_mem[set_idx][2] = 1'b0;
                end
                2'd3: begin
                    lru_mem[set_idx][0] = 1'b1;
                    lru_mem[set_idx][2] = 1'b1;
                end
            endcase
        end
    endtask

    // hit logic
    wire hit_way0 = valid_mem[cpu_index][0] && (tag_mem[cpu_index][0] == cpu_tag);
    wire hit_way1 = valid_mem[cpu_index][1] && (tag_mem[cpu_index][1] == cpu_tag);
    wire hit_way2 = valid_mem[cpu_index][2] && (tag_mem[cpu_index][2] == cpu_tag);
    wire hit_way3 = valid_mem[cpu_index][3] && (tag_mem[cpu_index][3] == cpu_tag);

    wire cache_hit = cpu_req && (hit_way0 || hit_way1 || hit_way2 || hit_way3);

    // ready means the current request hits and data is available immediately.
    assign cache_ready  = cache_hit;

    // busy/stall means a miss is being serviced, or the current request missed.
    assign dcache_stall = (current_state != STATE_IDLE) || (cpu_req && !cache_hit);

    // victim selection. TODO: i have a feeling this will be resource intensive, check gate level
    reg [1:0] victim_way;

    always @(*) begin
        if (!valid_mem[cpu_index][0]) begin
            victim_way = 2'd0;
        end else if (!valid_mem[cpu_index][1]) begin
            victim_way = 2'd1;
        end else if (!valid_mem[cpu_index][2]) begin
            victim_way = 2'd2;
        end else if (!valid_mem[cpu_index][3]) begin
            victim_way = 2'd3;
        end else begin
            if (lru_mem[cpu_index][0] == 1'b0) begin
                // ways 2/3 are least-recently-used side
                victim_way = (lru_mem[cpu_index][2] == 1'b0) ? 2'd3 : 2'd2;
            end else begin
                // ways 0/1 are least-recently-used side
                victim_way = (lru_mem[cpu_index][1] == 1'b0) ? 2'd1 : 2'd0;
            end
        end
    end

    wire victim_is_dirty = valid_mem[cpu_index][victim_way] &&
                           dirty_mem[cpu_index][victim_way];

    // next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            STATE_IDLE: begin
                if (cpu_req && !cache_hit) begin
                    next_state = victim_is_dirty ? STATE_EVICT : STATE_FETCH;
                end
            end

            STATE_EVICT: begin
                if (mem_ready && (burst_counter == 2'd3)) begin
                    next_state = STATE_FETCH;
                end
            end

            STATE_FETCH: begin
                if (mem_ready && (burst_counter == 2'd3)) begin
                    next_state = STATE_IDLE;
                end
            end

            default: begin
                next_state = STATE_IDLE;
            end
        endcase
    end

    // STATE REGISTER
    always @(posedge clk) begin
        if (!rst) begin
            current_state <= STATE_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    integer s, w;

    always @(posedge clk) begin
        if (!rst) begin
            burst_counter     <= 2'b00;
            mem_req           <= 1'b0;
            mem_we            <= 1'b0;
            mem_addr          <= {WIDTH{1'b0}};
            mem_wdata         <= 128'b0;
            line_buffer       <= 512'b0;
            fetch_req_pending <= 1'b0;
            cpu_rdata         <= {WIDTH{1'b0}};

            for (s = 0; s < SETS; s = s + 1) begin
                lru_mem[s] <= 3'b000;
                for (w = 0; w < WAYS; w = w + 1) begin
                    data_mem[s][w]  <= 512'b0;
                    tag_mem[s][w]   <= 22'b0;
                    valid_mem[s][w] <= 1'b0;
                    dirty_mem[s][w] <= 1'b0;
                end
            end
        end else begin
            case (current_state)
                STATE_IDLE: begin
                    mem_req <= 1'b0;

                    if (cache_hit) begin
                        // Update PLRU on hit.
                        if (hit_way0) begin
                            update_plru(cpu_index, 2'd0);
                        end else if (hit_way1) begin
                            update_plru(cpu_index, 2'd1);
                        end else if (hit_way2) begin
                            update_plru(cpu_index, 2'd2);
                        end else if (hit_way3) begin
                            update_plru(cpu_index, 2'd3);
                        end

                        // Write hits update the cache line immediately.
                        if (cpu_we) begin
                            if (hit_way0) begin
                                data_mem[cpu_index][0] <= apply_store_to_line(
                                    data_mem[cpu_index][0], word_sel, cpu_mask, cpu_wdata
                                );
                                dirty_mem[cpu_index][0] <= 1'b1;
                            end else if (hit_way1) begin
                                data_mem[cpu_index][1] <= apply_store_to_line(
                                    data_mem[cpu_index][1], word_sel, cpu_mask, cpu_wdata
                                );
                                dirty_mem[cpu_index][1] <= 1'b1;
                            end else if (hit_way2) begin
                                data_mem[cpu_index][2] <= apply_store_to_line(
                                    data_mem[cpu_index][2], word_sel, cpu_mask, cpu_wdata
                                );
                                dirty_mem[cpu_index][2] <= 1'b1;
                            end else if (hit_way3) begin
                                data_mem[cpu_index][3] <= apply_store_to_line(
                                    data_mem[cpu_index][3], word_sel, cpu_mask, cpu_wdata
                                );
                                dirty_mem[cpu_index][3] <= 1'b1;
                            end
                        end
                    end
                    else if (cpu_req && !cache_hit) begin
                        burst_counter <= 2'b00;
                        if (victim_is_dirty) begin
                            // Start dirty writeback burst immediately.
                            mem_req   <= 1'b1;
                            mem_we    <= 1'b1;
                            mem_addr  <= {tag_mem[cpu_index][victim_way], cpu_index, 6'b000000};
                            mem_wdata <= data_mem[cpu_index][victim_way][511:384];
                            line_buffer <= data_mem[cpu_index][victim_way];
                            fetch_req_pending <= 1'b0;
                        end else begin
                            // Start clean fetch burst immediately.
                            mem_req   <= 1'b1;
                            mem_we    <= 1'b0;
                            mem_addr  <= {cpu_addr[31:6], 6'b000000};
                            fetch_req_pending <= 1'b0;
                        end
                    end
                end

                STATE_EVICT: begin
                    mem_req <= 1'b0;
                    mem_we  <= 1'b1;

                    if (mem_ready) begin
                        case (burst_counter)
                            2'd0: mem_wdata <= line_buffer[383:256];
                            2'd1: mem_wdata <= line_buffer[255:128];
                            2'd2: mem_wdata <= line_buffer[127:0];
                            2'd3: begin
                                // Writeback is finished; request the fetch burst next.
                                mem_we            <= 1'b0;
                                fetch_req_pending  <= 1'b1;
                                burst_counter      <= 2'b00;
                            end
                        endcase

                        if (burst_counter != 2'd3) begin
                            burst_counter <= burst_counter + 1'b1;
                        end
                    end
                end

                STATE_FETCH: begin
                    mem_we <= 1'b0;

                    // If we just finished writeback, issue a one-cycle fetch pulse now.
                    if (fetch_req_pending) begin
                        mem_req <= 1'b1;
                        mem_addr <= {cpu_addr[31:6], 6'b000000};
                        fetch_req_pending <= 1'b0;
                    end else begin
                        mem_req <= 1'b0;
                    end

                    if (mem_ready) begin
                        case (burst_counter)
                            2'd0: line_buffer[511:384] <= mem_rdata;
                            2'd1: line_buffer[383:256] <= mem_rdata;
                            2'd2: line_buffer[255:128] <= mem_rdata;
                            2'd3: line_buffer[127:0]   <= mem_rdata;
                        endcase

                        if (burst_counter == 2'd3) begin
                            // assemble final fetched line and install it.
                            // for a store miss, apply the store immediately after fill.
                            if (cpu_we) begin
                                data_mem[cpu_index][victim_way] <= apply_store_to_line(
                                    {line_buffer[511:128], mem_rdata},
                                    word_sel, cpu_mask, cpu_wdata
                                );
                                dirty_mem[cpu_index][victim_way] <= 1'b1;
                            end else begin
                                data_mem[cpu_index][victim_way] <= {line_buffer[511:128], mem_rdata};
                                dirty_mem[cpu_index][victim_way] <= 1'b0;
                            end

                            tag_mem[cpu_index][victim_way]   <= cpu_tag;
                            valid_mem[cpu_index][victim_way] <= 1'b1;
                            update_plru(cpu_index, victim_way);

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

    // output data mux
    reg [511:0] selected_line;

    always @(*) begin
        selected_line = 512'b0;

        if (hit_way0) begin
            if (cpu_we) selected_line = apply_store_to_line(data_mem[cpu_index][0], word_sel, cpu_mask, cpu_wdata);
            else        selected_line = data_mem[cpu_index][0];
        end else if (hit_way1) begin
            if (cpu_we) selected_line = apply_store_to_line(data_mem[cpu_index][1], word_sel, cpu_mask, cpu_wdata);
            else        selected_line = data_mem[cpu_index][1];
        end else if (hit_way2) begin
            if (cpu_we) selected_line = apply_store_to_line(data_mem[cpu_index][2], word_sel, cpu_mask, cpu_wdata);
            else        selected_line = data_mem[cpu_index][2];
        end else if (hit_way3) begin
            if (cpu_we) selected_line = apply_store_to_line(data_mem[cpu_index][3], word_sel, cpu_mask, cpu_wdata);
            else        selected_line = data_mem[cpu_index][3];
        end

        cpu_rdata = get_line_word(selected_line, word_sel);
    end

endmodule