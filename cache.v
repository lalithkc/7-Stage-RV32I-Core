`timescale 1ns / 1ps

module cache (
    input  wire        clk,
    input  wire        rst,

    // Core Interface
    input  wire        core_req,
    input  wire        core_we,
    input  wire [31:0] core_addr,
    input  wire [31:0] core_wdata,
    output reg  [31:0] core_rdata,
    output reg         core_stall,

    // Bus Interface
    output reg         bus_req,
    output reg         bus_we,
    output reg  [31:0] bus_addr,
    output reg  [31:0] bus_wdata,
    input  wire [31:0] bus_rdata,
    input  wire        bus_ack,

    // Snoop Interface
    input  wire        snoop_valid,
    input  wire        snoop_we,
    input  wire [31:0] snoop_addr
);

    localparam NUM_LINES = 64;
    localparam ADDR_BITS = $clog2(NUM_LINES);   // 6

    // Tag/valid stay as flip-flops: tiny (64 x 24b, 64 x 1b), and keeping
    // them as FFs is what lets hit/miss resolve combinationally, same
    // cycle, exactly as before the macro swap.
    reg [23:0] tag_array  [0:NUM_LINES-1];   // FIX: was [25:0], addr[31:8] is only 24 bits
    reg        valid_array[0:NUM_LINES-1];

    // Data storage: SPRAM_64x32 macro (exact depth/width match from PDK)
    wire [31:0] sram_rdata;
    reg  [ADDR_BITS-1:0] sram_addr;
    reg  [31:0]           sram_wdata;
    reg                   sram_web;   // 1 = read, 0 = write (active-low write enable, matches macro polarity)

    SPRAM_64x32 u_data_ram (
        .A   (sram_addr),
        .CE  (clk),        // CE is the macro's own clock pin (see ck_active_edge in behavioral model)
        .WEB (sram_web),
        .OEB (1'b0),        // output always enabled, no power gating in this design
        .CSB (1'b0),        // block always selected, dedicated macro
        .I   (sram_wdata),
        .O   (sram_rdata)
    );

    localparam IDLE      = 3'd0;
    localparam MISS_REQ  = 3'd1;
    localparam MISS_WAIT = 3'd2;
    localparam MISS_DATA = 3'd3;
    localparam BUS_WR    = 3'd4;
    localparam WR_DONE   = 3'd5;
    localparam RD_HIT    = 3'd6;   // NEW: capture registered SRAM read output

    reg [2:0] state, next_state;
    integer i;

    reg [31:0] req_addr_reg;
    reg [31:0] req_wdata_reg;

    wire [ADDR_BITS-1:0] core_index = core_addr[ADDR_BITS+1:2];
    wire [23:0]           core_tag   = core_addr[31:ADDR_BITS+2];

    wire [ADDR_BITS-1:0] snoop_index = snoop_addr[ADDR_BITS+1:2];
    wire [23:0]           snoop_tag   = snoop_addr[31:ADDR_BITS+2];

    wire cache_hit = valid_array[core_index] && (tag_array[core_index] == core_tag);

    // Does a same-cycle snoop invalidate collide with the line this state
    // is about to validate? Snoop wins if so. This is an explicit design
    // choice (coherence correctness > local write-through convenience) --
    // flag if you want the opposite priority.
    wire snoop_hits_core_write =
        snoop_valid && snoop_we && (snoop_index == core_index) &&
        valid_array[snoop_index] && (tag_array[snoop_index] == snoop_tag);

    wire snoop_hits_miss_fill =
        snoop_valid && snoop_we && (snoop_index == req_addr_reg[ADDR_BITS+1:2]) &&
        valid_array[snoop_index] && (tag_array[snoop_index] == snoop_tag);

    // Single sequential FSM. valid_array now has exactly one driving
    // always block (previously split across two blocks -- that was a
    // race: a core write-hit and a snoop invalidate to the same index in
    // the same cycle had simulator-dependent outcome, not RTL-defined
    // outcome. Snoop invalidation is now evaluated first, every cycle,
    // and takes priority over any same-cycle local valid-set.
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            req_addr_reg  <= 32'b0;
            req_wdata_reg <= 32'b0; // FIX: Added reset for req_wdata_reg to clear SpyGlass STARC05-1.3.1.3
	    core_rdata <= 32'b0;
            valid_array[0]  <= 1'b0;  tag_array[0]  <= 24'b0;
            valid_array[1]  <= 1'b0;  tag_array[1]  <= 24'b0;
            valid_array[2]  <= 1'b0;  tag_array[2]  <= 24'b0;
            valid_array[3]  <= 1'b0;  tag_array[3]  <= 24'b0;
            valid_array[4]  <= 1'b0;  tag_array[4]  <= 24'b0;
            valid_array[5]  <= 1'b0;  tag_array[5]  <= 24'b0;
            valid_array[6]  <= 1'b0;  tag_array[6]  <= 24'b0;
            valid_array[7]  <= 1'b0;  tag_array[7]  <= 24'b0;
            valid_array[8]  <= 1'b0;  tag_array[8]  <= 24'b0;
            valid_array[9]  <= 1'b0;  tag_array[9]  <= 24'b0;
            valid_array[10] <= 1'b0;  tag_array[10] <= 24'b0;
            valid_array[11] <= 1'b0;  tag_array[11] <= 24'b0;
            valid_array[12] <= 1'b0;  tag_array[12] <= 24'b0;
            valid_array[13] <= 1'b0;  tag_array[13] <= 24'b0;
            valid_array[14] <= 1'b0;  tag_array[14] <= 24'b0;
            valid_array[15] <= 1'b0;  tag_array[15] <= 24'b0;
            valid_array[16] <= 1'b0;  tag_array[16] <= 24'b0;
            valid_array[17] <= 1'b0;  tag_array[17] <= 24'b0;
            valid_array[18] <= 1'b0;  tag_array[18] <= 24'b0;
            valid_array[19] <= 1'b0;  tag_array[19] <= 24'b0;
            valid_array[20] <= 1'b0;  tag_array[20] <= 24'b0;
            valid_array[21] <= 1'b0;  tag_array[21] <= 24'b0;
            valid_array[22] <= 1'b0;  tag_array[22] <= 24'b0;
            valid_array[23] <= 1'b0;  tag_array[23] <= 24'b0;
            valid_array[24] <= 1'b0;  tag_array[24] <= 24'b0;
            valid_array[25] <= 1'b0;  tag_array[25] <= 24'b0;
            valid_array[26] <= 1'b0;  tag_array[26] <= 24'b0;
            valid_array[27] <= 1'b0;  tag_array[27] <= 24'b0;
            valid_array[28] <= 1'b0;  tag_array[28] <= 24'b0;
            valid_array[29] <= 1'b0;  tag_array[29] <= 24'b0;
            valid_array[30] <= 1'b0;  tag_array[30] <= 24'b0;
            valid_array[31] <= 1'b0;  tag_array[31] <= 24'b0;
            valid_array[32] <= 1'b0;  tag_array[32] <= 24'b0;
            valid_array[33] <= 1'b0;  tag_array[33] <= 24'b0;
            valid_array[34] <= 1'b0;  tag_array[34] <= 24'b0;
            valid_array[35] <= 1'b0;  tag_array[35] <= 24'b0;
            valid_array[36] <= 1'b0;  tag_array[36] <= 24'b0;
            valid_array[37] <= 1'b0;  tag_array[37] <= 24'b0;
            valid_array[38] <= 1'b0;  tag_array[38] <= 24'b0;
            valid_array[39] <= 1'b0;  tag_array[39] <= 24'b0;
            valid_array[40] <= 1'b0;  tag_array[40] <= 24'b0;
            valid_array[41] <= 1'b0;  tag_array[41] <= 24'b0;
            valid_array[42] <= 1'b0;  tag_array[42] <= 24'b0;
            valid_array[43] <= 1'b0;  tag_array[43] <= 24'b0;
            valid_array[44] <= 1'b0;  tag_array[44] <= 24'b0;
            valid_array[45] <= 1'b0;  tag_array[45] <= 24'b0;
            valid_array[46] <= 1'b0;  tag_array[46] <= 24'b0;
            valid_array[47] <= 1'b0;  tag_array[47] <= 24'b0;
            valid_array[48] <= 1'b0;  tag_array[48] <= 24'b0;
            valid_array[49] <= 1'b0;  tag_array[49] <= 24'b0;
            valid_array[50] <= 1'b0;  tag_array[50] <= 24'b0;
            valid_array[51] <= 1'b0;  tag_array[51] <= 24'b0;
            valid_array[52] <= 1'b0;  tag_array[52] <= 24'b0;
            valid_array[53] <= 1'b0;  tag_array[53] <= 24'b0;
            valid_array[54] <= 1'b0;  tag_array[54] <= 24'b0;
            valid_array[55] <= 1'b0;  tag_array[55] <= 24'b0;
            valid_array[56] <= 1'b0;  tag_array[56] <= 24'b0;
            valid_array[57] <= 1'b0;  tag_array[57] <= 24'b0;
            valid_array[58] <= 1'b0;  tag_array[58] <= 24'b0;
            valid_array[59] <= 1'b0;  tag_array[59] <= 24'b0;
            valid_array[60] <= 1'b0;  tag_array[60] <= 24'b0;
            valid_array[61] <= 1'b0;  tag_array[61] <= 24'b0;
            valid_array[62] <= 1'b0;  tag_array[62] <= 24'b0;
            valid_array[63] <= 1'b0;  tag_array[63] <= 24'b0;
        end else begin
            state <= next_state;

            // Snoop invalidation -- highest priority, checked every cycle
            if (snoop_valid && snoop_we && valid_array[snoop_index] &&
                (tag_array[snoop_index] == snoop_tag)) begin
                valid_array[snoop_index] <= 1'b0;
            end

            case (state)
                IDLE: begin
                    if (core_req && cache_hit) begin
                        if (core_we) begin
                            // Write-hit: data goes to SRAM combinationally
                            // (see mux below); tag/valid updated here.
                            // Already stalling for BUS_WR regardless (this
                            // is a write-through cache), so no extra
                            // latency from moving data into the macro.
                            tag_array[core_index] <= core_tag;
                            if (!snoop_hits_core_write)
                                valid_array[core_index] <= 1'b1;
                        end
                        // read-hit: nothing latched here now -- data is
                        // captured in RD_HIT once the SRAM's registered
                        // output is valid.
                    end

                    if (core_req && (!cache_hit || core_we)) begin
                        req_addr_reg  <= core_addr;
                        req_wdata_reg <= core_wdata;
                        // FIX: req_we_reg removed as it was unused (BUS_WR hardcodes bus_we=1)
                    end
                end

                RD_HIT: begin
                    core_rdata <= sram_rdata;
                end

                MISS_DATA: begin
                    // Data written to SRAM combinationally (see mux below).
                    tag_array[req_addr_reg[ADDR_BITS+1:2]] <= req_addr_reg[31:ADDR_BITS+2];
                    if (!snoop_hits_miss_fill)
                        valid_array[req_addr_reg[ADDR_BITS+1:2]] <= 1'b1;
                    core_rdata <= bus_rdata;
                end
            endcase
        end
    end

    // Combinational logic: next-state, bus control, SRAM control
    always @(*) begin
        next_state = state;
        core_stall = 1'b0;
        bus_req    = 1'b0;
        bus_we     = 1'b0;
        bus_addr   = 32'b0;
        bus_wdata  = 32'b0;

        // SRAM defaults: idle read, no side effect if nothing needs it
        sram_addr  = {ADDR_BITS{1'b0}};
        sram_wdata = 32'b0;
        sram_web   = 1'b1;

        case (state)
            IDLE: begin
                if (core_req) begin
                    if (core_we) begin
                        // Write-through: always forward to bus. Also
                        // write the SRAM now if it's a hit -- commits at
                        // the next clock edge, same timing the old
                        // FF-array version had.
                        next_state = BUS_WR;
                        core_stall = 1'b1;
                        if (cache_hit) begin
                            sram_addr  = core_index;
                            sram_wdata = core_wdata;
                            sram_web   = 1'b0;
                        end
                    end else begin
                        if (cache_hit) begin
                            // Issue the SRAM read this cycle; registered
                            // output isn't valid until next edge, so stall
                            // one extra cycle vs. the old FF-array version.
                            sram_addr  = core_index;
                            sram_web   = 1'b1;
                            next_state = RD_HIT;
                            core_stall = 1'b1;
                        end else begin
                            next_state = MISS_REQ;
                            core_stall = 1'b1;
                        end
                    end
                end
            end

            RD_HIT: begin
                // SRAM output is valid combinationally by now; captured
                // into core_rdata on this edge (see sequential block).
                core_stall = 1'b0;
                next_state = IDLE;
            end

            BUS_WR: begin
                bus_req   = 1'b1;
                bus_we    = 1'b1; // Hardcoded to 1, so req_we_reg was unused
                bus_addr  = req_addr_reg;
                bus_wdata = req_wdata_reg;
                core_stall = 1'b1;

                if (bus_ack) begin
                    next_state = WR_DONE;
                end
            end

            WR_DONE: begin
                core_stall = 1'b0;
                next_state = IDLE;
            end

            MISS_REQ: begin
                bus_req    = 1'b1;
                bus_addr   = req_addr_reg;
                core_stall = 1'b1;
                next_state = MISS_WAIT;
            end

            MISS_WAIT: begin
                bus_req    = 1'b1;
                bus_addr   = req_addr_reg;
                core_stall = 1'b1;

                if (bus_ack) begin
                    next_state = MISS_DATA;
                end
            end

            MISS_DATA: begin
                core_stall = 1'b1;
                sram_addr  = req_addr_reg[ADDR_BITS+1:2];
                sram_wdata = bus_rdata;
                sram_web   = 1'b0;
                next_state = IDLE;
            end
        endcase
    end

endmodule
