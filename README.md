# Dual-Core RV32I RISC-V SoC — RTL through GDSII

A dual-core RV32I RISC-V system written in Verilog and taken through the full physical design flow on the **SCL 180nm** process.

## Highlights

- **Core:** 2-wide, 7-stage dual-issue RV32I pipeline with out-of-order issue, in-order commit and full forwarding
- **Branch prediction:** 64-entry branch target buffer
- **Memory system:** two cores with write-through L1 caches kept coherent by a MESI-lite snooping protocol and a priority bus arbiter
- **Accelerator:** 4x4 INT8 systolic array behind an AXI4-Lite slave, connected through a 2x2 crossbar
- **Physical design:** Synopsys IC Compiler II on SCL180nm — timing closed at **143 MHz with zero WNS**, **100% routed nets**, clean GDSII after ECO fixes
- **Sign-off:** RTL-to-netlist equivalence checked with Synopsys Formality; gate-level simulation in Cadence Xcelium

## Files

| File | Purpose |
|---|---|
| `system_top.v` | Top level: two cores, arbiter, memory, scan ports |
| `core_top.v` | Dual-issue RV32I pipeline |
| `control_unit.v`, `alu.v`, `alu_decoder.v`, `imm_gen.v`, `reg_file.v` | Decode and execute |
| `forwarding_unit.v`, `scoreboard.v` | Hazard handling and issue control |
| `btb.v` | 64-entry branch target buffer |
| `cache.v` | Write-through L1 cache with snoop support |
| `bus_arbiter.v` | Shared-bus arbiter that generates snoop traffic |
| `main_memory.v`, `SPRAM_*.v` | Main memory and SRAM macro models |
| `axi4_lite_accel.v`, `axi_crossbar_2x2.v` | AXI4-Lite accelerator wrapper and 2x2 crossbar |
| `systolic_array_4x4.v`, `pe_mac.v`, `simd_unit.v` | INT8 systolic array |
| `tb_*.v` | Testbenches: core, system, crossbar, systolic array, gate-level |

## Tools

Verilog · Synopsys Design Compiler · IC Compiler II · Formality · Cadence Xcelium
