`timescale 1ns / 1ps

module main_memory (
    input  wire        clk,
    input  wire        rst,

    // ============================================================
    // Memory request from bus arbiter
    // ============================================================
    input  wire        mem_req,
    input  wire        mem_we,
    input  wire [31:0] mem_addr,
    input  wire [31:0] mem_wdata,

    // ============================================================
    // Memory response
    // ============================================================
    output wire [31:0] mem_rdata,
    output reg         mem_rvalid
);

`ifndef SYNTHESIS
initial begin
    $display("==================================================");
    $display(">>> main_memory.v : REGISTERED READ/WRITE VERSION <<<");
    $display(">>> (extended read latency: negedge-to-negedge SRAM");
    $display(">>>  access window instead of half-cycle)          <<<");
    $display("==================================================");
end
`endif

// ============================================================
// 1. SRAM OUTPUT
//
// IMPORTANT:
// Declare O before any always block references it.
// ============================================================

wire [51:0] O;


// ============================================================
// 2. SRAM INITIALIZATION
//
// Initialize:
//
//   CPU 0x00 -> SRAM A=0
//   CPU 0x04 -> SRAM A=1
//   CPU 0x08 -> SRAM A=2
//   CPU 0x0C -> SRAM A=3
//
// All initialized to zero.
// ============================================================

reg [2:0] init_count;
reg [2:0] init_count_next; // FIX: Split next-state logic for STARC05-2.11.3.1
reg       init_done;

wire init_active = !init_done;

// FIX: Combinational next-state logic
always @(*) begin
    init_count_next = init_count;
    if (!init_done) begin
        if (init_count == 3'd3) begin
            init_count_next = init_count; // Hold at 3
        end else begin
            init_count_next = init_count + 3'd1;
        end
    end
end

// FIX: Sequential state register only
always @(negedge clk or posedge rst) begin

    if (rst) begin

        init_count <= 3'd0;
        init_done  <= 1'b0;

    end
    else if (!init_done) begin

`ifndef SYNTHESIS
        $display(
            "[%0t] SRAM INIT: A=%0d DATA=00000000",
            $time,
            init_count
        );
`endif
        if (init_count == 3'd3) begin

            init_done <= 1'b1;

`ifndef SYNTHESIS
            $display(
                "[%0t] SRAM INIT COMPLETE",
                $time
            );
`endif

        end
        else begin

            init_count <= init_count_next;

        end
    end

end


// ============================================================
// 3. REGISTER REQUEST FROM ARBITER
//
// Arbiter:
//
//       mem_req
//          |
//          v
//       posedge
//          |
//          v
//      registered request
//          |
//          |
//       negedge
//          |
//          v
//       SRAM CE
//
// CE = ~clk, therefore SRAM active edge = negedge clk.
//
// This gives approximately half a clock period for the
// registered address/control/data to settle before the SRAM
// active edge.
// ============================================================

reg        mem_req_r;
reg        mem_we_r;
reg [31:0] mem_addr_r;
reg [31:0] mem_wdata_r;

always @(posedge clk or posedge rst) begin

    if (rst) begin

        mem_req_r   <= 1'b0;
        mem_we_r    <= 1'b0;
        mem_addr_r  <= 32'b0;
        mem_wdata_r <= 32'b0;

    end
    else begin

        mem_req_r   <= mem_req;
        mem_we_r    <= mem_we;
        mem_addr_r  <= mem_addr;
        mem_wdata_r <= mem_wdata;

    end

end


// ============================================================
// 4. SRAM CONTROL
// ============================================================

wire CE = ~clk;

// During initialization, force SRAM write cycles.
// During normal operation, use registered request.
wire sram_req =
    init_active ? 1'b1 : mem_req_r;

wire sram_we =
    init_active ? 1'b1 : mem_we_r;

// CSB active LOW
wire CSB =
    (sram_req == 1'b1) ? 1'b0 : 1'b1;

// WEB active LOW
wire WEB = ~sram_we;

// Output enable active LOW
wire OEB = 1'b0;


// ============================================================
// 5. SRAM ADDRESS
// ============================================================
//
// CPU byte address -> SRAM word address
//
// 0x00 -> 0
// 0x04 -> 1
// 0x08 -> 2
// 0x0C -> 3
// 0x40 -> 16
// ============================================================

wire [11:0] init_addr =
    {9'b0, init_count};

wire [11:0] A =
    init_active
    ? init_addr
    : ((mem_req_r == 1'b1)
       ? mem_addr_r[13:2]
       : 12'b0);


// ============================================================
// 6. SRAM WRITE DATA
// ============================================================

wire [31:0] sram_wdata =
    init_active
    ? 32'h00000000
    : mem_wdata_r;

// SRAM is 52 bits wide.
// Only lower 32 bits are used.
wire [51:0] I =
    {20'b0, sram_wdata};


// ============================================================
// 7. READ RESPONSE PIPELINE
// ============================================================
//
// Read sequence (UPDATED):
//
//   posedge N
//       |
//       | capture mem_req/mem_addr
//       v
//   negedge N
//       |
//       | SRAM active edge (CE rises), read_pending set
//       v
//   SRAM O settles (access time ~4.4ns for SPRAM_4096x52 SS
//   corner -- too slow to fit in the negedge N -> posedge N+1
//   half-cycle window this used to rely on)
//       |
//   posedge N+1
//       |
//       +--> read_pending_d <= read_pending  (extra pipeline
//       |    stage: DOES NOT capture O yet)
//       v
//   posedge N+2
//       |
//       +--> capture O[31:0] into mem_rdata_r
//       +--> mem_rvalid = 1
//
// This gives the SRAM a full clock period (negedge N to
// posedge N+2 = 1.5x period) to respond instead of half a
// period, matching real access time at any reasonable target
// frequency. Read latency is now 3 cycles from request
// (posedge N) instead of 2. mem_rvalid remains a ONE-CYCLE
// pulse -- consumers (bus_arbiter) must tolerate the added
// cycle of latency; verify wait-state handling there.
// ============================================================

reg        read_pending;
reg        read_pending_d;   // NEW: extra pipeline stage
reg [31:0] mem_rdata_r;


// ------------------------------------------------------------
// Detect read at SRAM active edge
// ------------------------------------------------------------

always @(negedge clk or posedge rst) begin

    if (rst) begin

        read_pending <= 1'b0;

    end
    else begin

        if (!init_active &&
            mem_req_r &&
            !mem_we_r) begin

            read_pending <= 1'b1;

`ifndef SYNTHESIS
            $display(
                "[%0t] SRAM READ ACCEPTED: addr=%08h A=%03h",
                $time,
                mem_addr_r,
                mem_addr_r[13:2]
            );
`endif

        end
        else begin

            read_pending <= 1'b0;

        end

    end

end


// ------------------------------------------------------------
// Capture SRAM output
//
// NEW: read_pending is delayed one additional cycle
// (read_pending_d) before triggering the O capture, giving the
// SRAM output a full clock period to settle instead of half.
// ------------------------------------------------------------

always @(posedge clk or posedge rst) begin

    if (rst) begin

        read_pending_d <= 1'b0;
        mem_rdata_r    <= 32'b0;
        mem_rvalid     <= 1'b0;

    end
    else begin

        // Shift read_pending into the extra pipeline stage
        read_pending_d <= read_pending;

        // Default: no response this cycle
        mem_rvalid <= 1'b0;

        if (read_pending_d) begin

            mem_rdata_r <= O[31:0];
            mem_rvalid  <= 1'b1;

`ifndef SYNTHESIS
            $display(
                "[%0t] SRAM READ RESPONSE: data=%08h",
                $time,
                O[31:0]
            );
`endif

        end

    end

end

assign mem_rdata = mem_rdata_r;


// ============================================================
// 8. FOUNDRY SRAM
//
// DO NOT MODIFY THE FOUNDRY SRAM MODEL.
// ============================================================

SPRAM_4096x52 sram_inst (
    .A   (A),
    .CE  (CE),
    .WEB (WEB),
    .OEB (OEB),
    .CSB (CSB),
    .I   (I),
    .O   (O)
);


`ifndef SYNTHESIS
// ============================================================
// 9. INITIALIZATION DEBUG
// ============================================================

always @(negedge clk) begin

    if (init_active) begin

        #1;

        $display(
            "[%0t] SRAM INIT DEBUG:",
            $time
        );

        $display(
            "        A=%03h CE=%b CSB=%b WEB=%b OEB=%b I=%013h O=%013h",
            A,
            CE,
            CSB,
            WEB,
            OEB,
            I,
            O
        );

    end

end


// ============================================================
// 10. NORMAL MEMORY DEBUG
// ============================================================

always @(negedge clk) begin

    if (!init_active && mem_req_r) begin

        #1;

        if (mem_we_r) begin

            $display(
                "[%0t] SRAM WRITE DEBUG: addr=%08h A=%03h data=%08h CE=%b CSB=%b WEB=%b I=%013h",
                $time,
                mem_addr_r,
                A,
                mem_wdata_r,
                CE,
                CSB,
                WEB,
                I
            );

        end
        else begin

            $display(
                "[%0t] SRAM READ DEBUG: addr=%08h A=%03h CE=%b CSB=%b WEB=%b O=%013h rdata=%08h",
                $time,
                mem_addr_r,
                A,
                CE,
                CSB,
                WEB,
                O,
                mem_rdata
            );

        end

    end

end
`endif

endmodule
