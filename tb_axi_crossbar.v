`timescale 1ns / 1ps

module tb_axi_crossbar;
    reg clk;
    reg rst_n;
    
    // M0 Signals
    reg  [31:0] m0_awaddr; reg         m0_awvalid; wire        m0_awready;
    reg  [31:0] m0_wdata;  reg  [3:0]  m0_wstrb;   reg         m0_wvalid; wire        m0_wready;
    wire [1:0]  m0_bresp;  wire        m0_bvalid;  reg         m0_bready;
    reg  [31:0] m0_araddr; reg         m0_arvalid; wire        m0_arready;
    wire [31:0] m0_rdata;  wire [1:0]  m0_rresp;   wire        m0_rvalid; reg         m0_rready;

    // M1 Signals
    reg  [31:0] m1_awaddr; reg         m1_awvalid; wire        m1_awready;
    reg  [31:0] m1_wdata;  reg  [3:0]  m1_wstrb;   reg         m1_wvalid; wire        m1_wready;
    wire [1:0]  m1_bresp;  wire        m1_bvalid;  reg         m1_bready;
    reg  [31:0] m1_araddr; reg         m1_arvalid; wire        m1_arready;
    wire [31:0] m1_rdata;  wire [1:0]  m1_rresp;   wire        m1_rvalid; reg         m1_rready;

    // S0 Signals (Dummy Memory Slave)
    // FIXED: These must be 'reg' because they are driven by the always block below
    wire [31:0] s0_awaddr; wire        s0_awvalid; reg         s0_awready;
    wire [31:0] s0_wdata;  wire [3:0]  s0_wstrb;   wire        s0_wvalid; reg         s0_wready;
    reg  [1:0]  s0_bresp;  reg         s0_bvalid;  wire        s0_bready;
    wire [31:0] s0_araddr; wire        s0_arvalid; reg         s0_arready;
    reg  [31:0] s0_rdata;  reg  [1:0]  s0_rresp;   reg         s0_rvalid; wire        s0_rready;

    // S1 Signals (Connected to Accelerator)
    wire [31:0] s1_awaddr; wire        s1_awvalid; wire        s1_awready;
    wire [31:0] s1_wdata;  wire [3:0]  s1_wstrb;   wire        s1_wvalid; wire        s1_wready;
    wire [1:0]  s1_bresp;  wire        s1_bvalid;  wire        s1_bready;
    wire [31:0] s1_araddr; wire        s1_arvalid; wire        s1_arready;
    wire [31:0] s1_rdata;  wire [1:0]  s1_rresp;   wire        s1_rvalid; wire        s1_rready;

    integer i;

    // ---------------------------------------------------------
    // Instantiate Crossbar
    // ---------------------------------------------------------
    axi_crossbar_2x2 uut (
        .clk(clk), .rst_n(rst_n),
        // M0
        .m0_awaddr(m0_awaddr), .m0_awvalid(m0_awvalid), .m0_awready(m0_awready),
        .m0_wdata(m0_wdata), .m0_wstrb(m0_wstrb), .m0_wvalid(m0_wvalid), .m0_wready(m0_wready),
        .m0_bresp(m0_bresp), .m0_bvalid(m0_bvalid), .m0_bready(m0_bready),
        .m0_araddr(m0_araddr), .m0_arvalid(m0_arvalid), .m0_arready(m0_arready),
        .m0_rdata(m0_rdata), .m0_rresp(m0_rresp), .m0_rvalid(m0_rvalid), .m0_rready(m0_rready),
        // M1
        .m1_awaddr(m1_awaddr), .m1_awvalid(m1_awvalid), .m1_awready(m1_awready),
        .m1_wdata(m1_wdata), .m1_wstrb(m1_wstrb), .m1_wvalid(m1_wvalid), .m1_wready(m1_wready),
        .m1_bresp(m1_bresp), .m1_bvalid(m1_bvalid), .m1_bready(m1_bready),
        .m1_araddr(m1_araddr), .m1_arvalid(m1_arvalid), .m1_arready(m1_arready),
        .m1_rdata(m1_rdata), .m1_rresp(m1_rresp), .m1_rvalid(m1_rvalid), .m1_rready(m1_rready),
        // S0
        .s0_awaddr(s0_awaddr), .s0_awvalid(s0_awvalid), .s0_awready(s0_awready),
        .s0_wdata(s0_wdata), .s0_wstrb(s0_wstrb), .s0_wvalid(s0_wvalid), .s0_wready(s0_wready),
        .s0_bresp(s0_bresp), .s0_bvalid(s0_bvalid), .s0_bready(s0_bready),
        .s0_araddr(s0_araddr), .s0_arvalid(s0_arvalid), .s0_arready(s0_arready),
        .s0_rdata(s0_rdata), .s0_rresp(s0_rresp), .s0_rvalid(s0_rvalid), .s0_rready(s0_rready),
        // S1
        .s1_awaddr(s1_awaddr), .s1_awvalid(s1_awvalid), .s1_awready(s1_awready),
        .s1_wdata(s1_wdata), .s1_wstrb(s1_wstrb), .s1_wvalid(s1_wvalid), .s1_wready(s1_wready),
        .s1_bresp(s1_bresp), .s1_bvalid(s1_bvalid), .s1_bready(s1_bready),
        .s1_araddr(s1_araddr), .s1_arvalid(s1_arvalid), .s1_arready(s1_arready),
        .s1_rdata(s1_rdata), .s1_rresp(s1_rresp), .s1_rvalid(s1_rvalid), .s1_rready(s1_rready)
    );

    // ---------------------------------------------------------
    // Instantiate Accelerator at S1
    // ---------------------------------------------------------
    axi4_lite_accel u_accel (
        .clk(clk), .rst_n(rst_n),
        .awaddr(s1_awaddr), .awvalid(s1_awvalid), .awready(s1_awready),
        .wdata(s1_wdata), .wstrb(s1_wstrb), .wvalid(s1_wvalid), .wready(s1_wready),
        .bresp(s1_bresp), .bvalid(s1_bvalid), .bready(s1_bready),
        .araddr(s1_araddr), .arvalid(s1_arvalid), .arready(s1_arready),
        .rdata(s1_rdata), .rresp(s1_rresp), .rvalid(s1_rvalid), .rready(s1_rready)
    );

    // ---------------------------------------------------------
    // Dummy S0 Slave (Simple 1-cycle response SRAM model)
    // ---------------------------------------------------------
    reg [31:0] s0_mem;
    always @(posedge clk) begin
        if (!rst_n) begin
            s0_awready <= 0; s0_wready <= 0; s0_bvalid <= 0;
            s0_arready <= 0; s0_rvalid <= 0;
            s0_bresp   <= 0; s0_rresp  <= 0; s0_rdata  <= 0;
        end else begin
            s0_awready <= s0_awvalid;
            s0_wready  <= s0_wvalid;
            if (s0_awvalid && s0_awready && s0_wvalid && s0_wready) begin
                s0_mem <= s0_wdata;
                s0_bvalid <= 1;
                s0_bresp <= 2'b00;
            end
            if (s0_bvalid && s0_bready) s0_bvalid <= 0;

            s0_arready <= s0_arvalid;
            if (s0_arvalid && s0_arready) begin
                s0_rvalid <= 1;
                s0_rdata  <= s0_mem;
                s0_rresp  <= 2'b00;
            end
            if (s0_rvalid && s0_rready) s0_rvalid <= 0;
        end
    end

    // Clock generation
    always #5 clk = ~clk;

    // ---------------------------------------------------------
    // AXI Master Write Task (Independent AW/W Handshakes)
    // ---------------------------------------------------------
    task axi_write;
        input integer master_id;
        input [31:0]  addr;
        input [31:0]  data;
        begin
            @(posedge clk); #1;
            if (master_id == 0) begin
                m0_awaddr = addr; m0_awvalid = 1;
                m0_wdata  = data; m0_wstrb = 4'hF; m0_wvalid = 1;
            end else begin
                m1_awaddr = addr; m1_awvalid = 1;
                m1_wdata  = data; m1_wstrb = 4'hF; m1_wvalid = 1;
            end
            
            if (master_id == 0) begin
                while (!m0_awready) @(posedge clk);
                @(posedge clk); #1;
                m0_awvalid = 0;
                
                while (!m0_wready) @(posedge clk);
                @(posedge clk); #1;
                m0_wvalid = 0;
                
                m0_bready = 1;
                while (!m0_bvalid) @(posedge clk);
                @(posedge clk); #1; m0_bready = 0;
            end else begin
                while (!m1_awready) @(posedge clk);
                @(posedge clk); #1;
                m1_awvalid = 0;
                
                while (!m1_wready) @(posedge clk);
                @(posedge clk); #1;
                m1_wvalid = 0;
                
                m1_bready = 1;
                while (!m1_bvalid) @(posedge clk);
                @(posedge clk); #1; m1_bready = 0;
            end
        end
    endtask

    // ---------------------------------------------------------
    // AXI Master Read Task (Parameterized for M0/M1)
    // ---------------------------------------------------------
    task axi_read;
        input  integer master_id;
        input  [31:0]  addr;
        output [31:0]  data;
        begin
            @(posedge clk); #1;
            if (master_id == 0) begin
                m0_araddr = addr; m0_arvalid = 1;
            end else begin
                m1_araddr = addr; m1_arvalid = 1;
            end
            
            if (master_id == 0) begin
                while (!m0_arready) @(posedge clk);
                @(posedge clk); #1; m0_arvalid = 0;
                m0_rready = 1;
                while (!m0_rvalid) @(posedge clk);
                #1; data = m0_rdata;
                @(posedge clk); #1; m0_rready = 0;
            end else begin
                while (!m1_arready) @(posedge clk);
                @(posedge clk); #1; m1_arvalid = 0;
                m1_rready = 1;
                while (!m1_rvalid) @(posedge clk);
                #1; data = m1_rdata;
                @(posedge clk); #1; m1_rready = 0;
            end
        end
    endtask

    reg [31:0] read_val0, read_val1;

    initial begin
        // Initialize
        clk = 0; rst_n = 0;
        m0_awaddr=0; m0_awvalid=0; m0_wdata=0; m0_wstrb=0; m0_wvalid=0; m0_bready=0;
        m1_awaddr=0; m1_awvalid=0; m1_wdata=0; m1_wstrb=0; m1_wvalid=0; m1_bready=0;
        m0_araddr=0; m0_arvalid=0; m0_rready=0;
        m1_araddr=0; m1_arvalid=0; m1_rready=0;

        #20 rst_n = 1;

        $display("==================================================");
        $display("Starting Concurrent 2x2 Crossbar Verification...");
        $display("==================================================");

        // 1. M0 initializes the Accelerator (S1)
        $display("M0: Clearing Acc and Loading Weights...");
        axi_write(0, 32'h8000_0000, 32'h0000_0001); // Clear Acc
        axi_write(0, 32'h8000_0004, 32'h04040404);
        axi_write(0, 32'h8000_0004, 32'h03030303);
        axi_write(0, 32'h8000_0004, 32'h02020202);
        axi_write(0, 32'h8000_0004, 32'h01010101);

        // 2. CONCURRENT TRAFFIC TEST
        // M0 streams activations to S1
        // M1 writes to S0 (Memory)
        $display("M0 and M1 Concurrent Write Test...");
        fork
            axi_write(0, 32'h8000_0014, 32'h02020202); // M0 -> S1
            axi_write(1, 32'h0000_0000, 32'hDEAD_BEEF); // M1 -> S0
        join

        // 3. Wait for systolic ripple
        for (i = 0; i < 4; i = i + 1) @(posedge clk);

        // 4. Concurrent Read Test
        $display("M0 and M1 Concurrent Read Test...");
        fork
            axi_read(0, 32'h8000_0024, read_val0); // M0 reads S1
            axi_read(1, 32'h0000_0000, read_val1); // M1 reads S0
        join

        #10 $display("--------------------------------------------------");
        if (read_val0 === 32'd32 && read_val1 === 32'hDEAD_BEEF) begin
            $display("TEST PASSED: Crossbar successfully routed concurrent traffic!");
            $display("  M0 read from S1 (Accel): %d", read_val0);
            $display("  M1 read from S0 (Mem):   %h", read_val1);
        end else begin
            $display("TEST FAILED!");
            $display("  M0 expected 32, got: %d", read_val0);
            $display("  M1 expected DEAD_BEEF, got: %h", read_val1);
        end
        $display("==================================================");

        #10 $finish;
    end
endmodule
