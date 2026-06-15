# 🧭 Fully Associative Cache Memory Architecture

A parameterized, synthesizable **Fully Associative Cache Controller** implemented in Verilog. Unlike direct-mapped configurations, a fully associative architecture allows any block of main memory to reside in **any** available cache line slot. This maximizes storage flexibility, drastically eliminates conflict misses, and implements an automated empty-slot allocation policy alongside a fallback replacement routine.

---

## 🚀 Architectural Overview

In this fully associative configuration, there are no index bits. Every single lookup request forces a parallel check across all existing cache lines simultaneously to find a matching tag identification.

### 🔍 Concurrent Tag Matching & Hardware Lookup

Because a fully associative cache does not use fixed index bits to narrow down a search to a single line, the hardware must evaluate every single cache slot at the same time.

* **Parallel Comparator Array:** In actual synthesized hardware, your behavioral `for` loop (`for (i = 0; i < CACHE_LINES; i = i + 1)`) maps directly to an array of physical hardware comparators operating concurrently.
* **Simultaneous Evaluation:** When the CPU places an address on the bus, the 5-bit `block_address` is fed to all 4 cache line tag registers simultaneously.
* **Hit Routing:** If any comparator detects an exact match AND the corresponding `valid` bit is active, the internal multiplexer instantly paths that specific line's data payload to the output bus, pulling the `hit` flag high within the same execution window.

## 📂 Repository File Structure

```text
fullyassociative_cache_mapping/
├── .gitignore                 # Specifies untracked compilation & simulation artifacts
├── README.md                  # Main overview, toolchain guide, and simulation instructions
├── fullyAssociative_mapping.v   # Synthesizable RTL implementation of Fully Associative cache
├── fullyAssociative_mapping.md  # Auto-generated detailed hardware module specifications
├── fullyAssociative_mapping.svg # Top-level schematic block diagram of the module boundary
├── testbench.v                # Testbench simulation suite validating reads, writes, & hits
├── external_storage.mem       # Hexadecimal main memory initialization image file
├── simulation_2.png           # Waveform capturing specific cache transaction state (Hit/Miss)
├── simulation_3.png           # Waveform analysis showing automated slot allocation updates
├── simulation_4.png           # Waveform verification documenting fallback block eviction
└── simulation_waveform.png    # Comprehensive behavioral timeline showing end-to-end execution

## 📐 Address Space Partitioning

In a fully associative cache, there are no fixed index bits. The address bus is partitioned directly into two fields:

```text
 Bit Position:   [6]       [5]       [4]       [3]       [2]   |   [1]       [0]
 Field Mapping:  <-------------- Tag (5 bits) -------------->  |  <- Offset (2 bits) ->
 ```

## 🛠️ Design Features

This cache architecture provides high-performance data matching and robust consistency using the following hardware design characteristics:

* **Flexible Zero-Conflict Mapping:** By completely eliminating fixed index routing, any main memory block can go into **any** vacant cache line slot. This entirely prevents structural cache thrashing and conflict misses caused by bad address alignment.
* **Parallel Search Engine Lookups:** Realized via a concurrent behavioral loop that synthesizes directly into an array of parallel hardware comparators. When lookups occur, every active tag directory slot is validated simultaneously within the same clock evaluation window.
* **Immediate Write-Through Protocol:** Guarantees absolute data integrity and visibility between memory levels by instantly forwarding all processor write operations (`write_enable`) down to the background main memory array block concurrently with local cache data register modifications.
* **Dynamic Slot Allocation & Fallback Eviction:** Features a dual-stage miss resolution strategy. On a cache miss, the controller sweeps the lines to discover unallocated slots (`!valid[i]`). If an unallocated slot is found, it updates it dynamically. If the cache is completely full, it drops back safely to a fallback replacement routine targeting line 0.

## 📋 Module Specifications

The core architecture is fully parameterized to easily allow scaling of data widths, block sizing, and cache depth.  

> 🔍 **Detailed Pinout & Signal Directory:** For the complete, auto-generated hardware port mappings, bit-slice signals, and synthesis constants, please refer to the full [fullyAssociative_mapping.md](./fullyAssociative_mapping.md) architectural specification file.

### ⚙️ Core Configuration Quick-View

| Parameter | Default Value | Description |
| :--- | :---: | :--- |
| `WORD_SIZE` | `1` | Width of an individual data word (in bytes) |
| `BLOCK_SIZE` | `4` | Number of data words packed inside a single line |
| `CACHE_LINES` | `4` | Total storage slots available inside the cache |
| `RAM_BLOCKS` | `32` | Total block depth of background main memory |

## 🛠️ Toolchain & EDA Tools

This project was developed, simulated, and documented using the following industrial and open-source hardware engineering tool suite:

* **Design & IDE:** [VS Code](https://code.visualstudio.com/) — Integrated development environment used for writing synthesizable RTL code.
* **Documentation Engine:** [TerosHDL](https://teroshdl.github.io/teroSHDL/) — Used for real-time code parsing, block diagram schematic generation, and automated markdown documentation formatting.
* **Simulation & Synthesis Compiler:** [Icarus Verilog (iVerilog)](http://iverilog.icarus.com/) — Open-source Verilog simulation and synthesis tool used to compile the RTL design and testbench.
* **Waveform Viewer:** [GTKWave](https://gtkwave.sourceforge.net/) — Fully featured wave viewer used to open and analyze the compiled `.vcd` (Value Change Dump) simulation files to verify the controller's state machine transitions.

## 🚀 Compilation and Simulation Guide

This workspace is fully optimized for VS Code utilizing the Icarus Verilog (iverilog) compiler toolchain and GTKWave for visual waveform debugging.

**Prerequisites**
Ensure you have the simulation binaries installed on your system terminal:

```text  
    # Verify installations
    iverilog -v
    vvp -v
```

## 💻Execution Steps

1. **Open your Terminal at the root project directory**  
2. **Compile the Design Modules Together**
3. **Execute the Compiled Binary**
4. **Analyze the Output Waveform**

```text
    # bash cmd
    iverilog -o sim_out.vvp rtl_design/direct_mapping.v testbench/testbench.v
    vvp sim_out.vvp
    gtkwave waveform/testbench.vcd
```  