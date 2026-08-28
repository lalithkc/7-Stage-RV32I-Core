`timescale 1ns / 1ps

module system_top (
    input  wire        clk,
    input  wire        rst,

    input  wire        scan_enable,
    input  wire [3:0]  scan_in,
    output wire [3:0]  scan_out,

    // ============================================================
    // Instruction Memory Interfaces
    // ============================================================

    input  wire [31:0] instr_in1_c0,
    input  wire [31:0] instr_in2_c0,
    output wire [31:0] pc_out_c0,

    input  wire [31:0] instr_in1_c1,
    input  wire [31:0] instr_in2_c1,
    output wire [31:0] pc_out_c1
);

    // ============================================================
    // Core 0 Bus Wires
    // ============================================================

    wire        c0_bus_req;
    wire        c0_bus_we;
    wire        c0_bus_ack;

    wire [31:0] c0_bus_addr;
    wire [31:0] c0_bus_wdata;
    wire [31:0] c0_bus_rdata;

    wire        c0_snoop_valid;
    wire        c0_snoop_we;
    wire [31:0] c0_snoop_addr;


    // ============================================================
    // Core 1 Bus Wires
    // ============================================================

    wire        c1_bus_req;
    wire        c1_bus_we;
    wire        c1_bus_ack;

    wire [31:0] c1_bus_addr;
    wire [31:0] c1_bus_wdata;
    wire [31:0] c1_bus_rdata;

    wire        c1_snoop_valid;
    wire        c1_snoop_we;
    wire [31:0] c1_snoop_addr;


    // ============================================================
    // Shared Main Memory Wires
    // ============================================================

    wire        mem_req;
    wire        mem_we;

    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [31:0] mem_rdata;

    // IMPORTANT: this was missing
    wire        mem_rvalid;


    // ============================================================
    // CORE 0
    // ============================================================

    core_top core0 (
        .clk        (clk),
        .rst        (rst),

        .instr_in1  (instr_in1_c0),
        .instr_in2  (instr_in2_c0),
        .pc_out     (pc_out_c0),

        .bus_req    (c0_bus_req),
        .bus_we     (c0_bus_we),
        .bus_addr   (c0_bus_addr),
        .bus_wdata  (c0_bus_wdata),

        .bus_rdata  (c0_bus_rdata),
        .bus_ack    (c0_bus_ack),

        .snoop_valid(c0_snoop_valid),
        .snoop_we   (c0_snoop_we),
        .snoop_addr (c0_snoop_addr)
    );


    // ============================================================
    // CORE 1
    // ============================================================

    core_top core1 (
        .clk        (clk),
        .rst        (rst),

        .instr_in1  (instr_in1_c1),
        .instr_in2  (instr_in2_c1),
        .pc_out     (pc_out_c1),

        .bus_req    (c1_bus_req),
        .bus_we     (c1_bus_we),
        .bus_addr   (c1_bus_addr),
        .bus_wdata  (c1_bus_wdata),

        .bus_rdata  (c1_bus_rdata),
        .bus_ack    (c1_bus_ack),

        .snoop_valid(c1_snoop_valid),
        .snoop_we   (c1_snoop_we),
        .snoop_addr (c1_snoop_addr)
    );


    // ============================================================
    // BUS ARBITER
    // ============================================================

    bus_arbiter arb (
        .clk        (clk),
        .rst        (rst),

        // --------------------------------------------------------
        // Core 0
        // --------------------------------------------------------

        .req0       (c0_bus_req),
        .we0        (c0_bus_we),
        .addr0      (c0_bus_addr),
        .wdata0     (c0_bus_wdata),

        .ack0       (c0_bus_ack),
        .rdata0     (c0_bus_rdata),

        // --------------------------------------------------------
        // Core 1
        // --------------------------------------------------------

        .req1       (c1_bus_req),
        .we1        (c1_bus_we),
        .addr1      (c1_bus_addr),
        .wdata1     (c1_bus_wdata),

        .ack1       (c1_bus_ack),
        .rdata1     (c1_bus_rdata),

        // --------------------------------------------------------
        // Snoop
        // --------------------------------------------------------

        .snoop_valid0(c0_snoop_valid),
        .snoop_we0   (c0_snoop_we),
        .snoop_addr0 (c0_snoop_addr),

        .snoop_valid1(c1_snoop_valid),
        .snoop_we1   (c1_snoop_we),
        .snoop_addr1 (c1_snoop_addr),

        // --------------------------------------------------------
        // Main memory
        // --------------------------------------------------------

        .mem_req    (mem_req),
        .mem_we     (mem_we),
        .mem_addr   (mem_addr),
        .mem_wdata  (mem_wdata),

        .mem_rdata  (mem_rdata),
        .mem_rvalid (mem_rvalid)
    );


    // ============================================================
    // MAIN MEMORY
    // ============================================================

    main_memory u_main_mem (
        .clk       (clk),
        .rst       (rst),

        .mem_req   (mem_req),
        .mem_we    (mem_we),
        .mem_addr  (mem_addr),
        .mem_wdata (mem_wdata),

        .mem_rdata (mem_rdata),
        .mem_rvalid(mem_rvalid)
    );

endmodule
