# 📋 Module Specifications: fullyAssociative_mapping

- **Source File:** `fullyAssociative_mapping.v`

---

## 📐 Block Diagram

Below is the structural block diagram showing the top-level interface ports and parameter connections for the fully associative architecture:

![Diagram](fullyAssociative_mapping.svg "Architectural Module Diagram")

---

## ⚙️ Generics / Parameters

These parameters control the bit widths and structural capacities of the memory levels, allowing the module to scale dynamically:

| Generic name  | Type        | Value | Description |
| ------------- | ----------- | ----- | ----------- |
| `WORD_SIZE`   | `parameter` | `1`     | Width of a single data word inside the memory subsystem, evaluated in bytes. |
| `BLOCK_SIZE`  | `parameter` | `4`     | Total depth configuration specifying the number of data words bundled into a single memory block. |
| `CACHE_LINES` | `parameter` | `4`     | Total storage line capacity (slots) available within the high-speed cache register array. |
| `RAM_BLOCKS`  | `parameter` | `32`    | Total block capacity configuration of the simulated background main memory array. |

---

## 🔌 Interface Ports

Top-level interface boundaries connecting the processor master controller to the cache storage and memory subsystems:

| Port name      | Direction | Type                       | Description |
| -------------- | --------- | -------------------------- | ----------- |
| `clk`          | input     | `wire`                       | Master system clock line driving internal state registers on its rising edge. |
| `rst`          | input     | `wire`                       | Global active-high synchronous system reset signal used to flush and invalidate cache entries. |
| `address`      | input     | `wire [address_bites-1:0]` | Incoming physical memory address target bus supplied by the CPU (maps to 7 bits wide). |
| `data_in`      | input     | `wire [data_bites-1:0]`    | Dedicated CPU data input bus for executing cache write modifications. |
| `write_enable` | input     | `wire`                       | Control strobe line activating write-through operations to the memory and cache indexes. |
| `read_enable`  | input     | `wire`                       | Control strobe line activating parallel tag evaluation and matching lookup loops. |
| `data_out`     | output    | `reg [data_bites-1:0]`     | Latched data output bus delivering the targeted word line slice back to the processor. |
| `hit`          | output    | `reg`                        | Synchronous active-high flag indicating the requested block tag is present in an active cache slot. |
| `hit_line`     | output    | `reg [hit_line_bites-1:0]` | Binary encoded line index pointer indicating exactly which cache line triggered the hit condition. |

---

## 💾 Hardware Internal Signals

Internal wires and register arrays tracking data caching allocations, memory storage, and dynamic index slicing:

| Name | Type | Description |
| ---- | ---- | ----------- |
| `cache [0:CACHE_LINES-1]` | `reg [line_bites-1:0]` | High-speed cache memory array holding mirrored local copies of active rows (4 entries of 32 bits). |
| `memory [0:RAM_BLOCKS-1]` | `reg [block_bites-1:0]` | Primary background memory structure modeling 32 blocks of external storage initialized via an external file. |
| `tag [0:CACHE_LINES-1]` | `reg [tag_bites-1:0]` | Directory tracking array holding 5-bit block tracking identifier tags for cache tag matching. |
| `valid` | `reg [CACHE_LINES-1:0]` | Bitmask register vector containing validity status flags to isolate against cold-boot data hazards. |
| `i` | `integer` | Loop iterator tracking variable reserved for array sweeps inside sequential behavioral blocks. |
| `block_address = address[address_bites -1:offset_bites]` | `wire [tag_bites-1:0]` | Real-time hardware bit-slice extracting the upper 5 block mapping bits (`address[6:2]`) from the bus. |
| `word_offset = address[offset_bites -1:0]` | `wire [offset_bites-1:0]` | Real-time hardware bit-slice isolating the lower 2 word selection bits (`address[1:0]`) within a block. |

---

## 📐 Synthesis Constants (Localparams)

Internal compile-time constants evaluating layout scales and bus weights automatically from top-level parameters:

| Name | Type | Value | Description |
| ---- | ---- | ----- | ----------- |
| `word_bites` | `localparam` | `WORD_SIZE * \`BYTE` | Total bit width of an individual data word (resolves to 8 bits). |
| `block_bites` | `localparam` | `BLOCK_SIZE * word_bites` | Complete bit weight of a multi-word row block payload (resolves to 32 bits). |
| `address_bites` | `localparam` | `$clog2(RAM_BLOCKS * BLOCK_SIZE)` | Total bus scale required to index full physical memory depth (resolves to 7 bits to map 128 bytes). |
| `data_bites` | `localparam` | `word_bites` | Sizing configuration constant matching top-level data bus widths (8 bits). |
| `line_bites` | `localparam` | `block_bites` | Physical hardware register capacity allocated to store internal cache row rows (32 bits). |
| `hit_line_bites` | `localparam` | `$clog2(CACHE_LINES)` | Encoded bit scale required to represent structural cache index locations (2 bits). |
| `offset_bites` | `localparam` | `$clog2(BLOCK_SIZE)` | Total width required to step through elements inside a structural block container (2 bits). |
| `tag_bites` | `localparam` | `address_bites - offset_bites` | Total remaining bit width reserved for full associative block identifier tags (5 bits). |

---

## ⚙️ Behavioral Processes

### `cache_operations`

* **Type:** `always @(posedge clk or posedge rst)`
* **Description:** The primary behavioral controller managing the fully associative cache lookup, data routing, and structural replacement policy. 
  * **System Reset (`rst`):** Flushes content registries, forces hit indicators low, and sets the `valid` register mask vector to zero to clear startup garbage states.
  * **Read Operation:** Initiates a sequential sweep using an internal loop to mimic parallel hardware tag comparators. If an active valid slot matches the calculated `block_address`, it asserts `hit`, exposes the line position via `hit_line`, and routes out the specific targeted byte lane. If a miss happens, it searches for the first unallocated slot (`!valid[i]`) to load data from main memory. If the cache is full, it drops back to a replacement policy overwriting line 0.
  * **Write Operation:** Implements a write-through strategy by updating the background main `memory` array immediately upon command. Concurrently, it checks the tag directory; if a write hit is detected, it modifies the corresponding byte segment within the local cache array in-place to preserve absolute consistency. If it misses, it pulls a new block into an unallocated slot or forces a replacement on slot 0.