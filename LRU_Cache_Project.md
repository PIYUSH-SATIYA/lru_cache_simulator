# Hardware LRU Cache Simulator — Project Document & Team Plan
### IIIT Vadodara | Computer Organization & Architecture | Nexys A7 FPGA

---

# PART 1: PROJECT DOCUMENT
### (The "what we are building" reference — can be submitted or shown to professor)

---

## 1. Project Title

**Hardware Implementation of an LRU Cache Simulator on FPGA**

---

## 2. Introduction

Modern CPUs cannot directly read from RAM fast enough to keep up with their own execution speed. RAM access takes roughly 100 nanoseconds; a CPU can execute an instruction in under 1 nanosecond. This mismatch is solved by **cache memory** — a small, fast storage layer that sits between the CPU and RAM and holds copies of recently used data.

This project builds a **hardware simulation of a cache memory system** in Verilog HDL, deployed on the Nexys A7 FPGA board. It demonstrates how a real cache works internally: how addresses are decoded, how data is looked up, how hits and misses are detected, and how the **Least Recently Used (LRU)** replacement policy decides what to evict when the cache is full.

This is not a software simulation written in C or Python. Every module is described as actual synthesizable hardware, running in real parallel logic on the FPGA fabric.

---

## 3. Objectives

- Understand and implement cache memory architecture in hardware
- Model set-associative cache organization using Verilog HDL
- Implement the LRU replacement policy using counter-based tracking
- Detect and handle cache hits and misses in hardware
- Display real-time cache statistics on the FPGA board
- Validate behavior through Vivado simulation before hardware deployment

---

## 4. Background Concepts

### 4.1 What is a Cache?

A cache is a small, fast memory that stores copies of data recently fetched from main memory. When the CPU requests data:

- If the data is in the cache → **Cache Hit** (fast, ~1 cycle)
- If the data is not in the cache → **Cache Miss** (slow, must fetch from RAM)

### 4.2 Set-Associative Cache

A set-associative cache divides cache storage into **sets**, and each set holds a fixed number of **ways** (cache lines). When an address is accessed:

1. The **index** field selects which set to look in
2. All ways within that set are checked simultaneously
3. The **tag** field identifies which specific memory block is stored

Our configuration:

| Parameter       | Value        |
|----------------|--------------|
| Total Blocks   | 16           |
| Associativity  | 4-way        |
| Number of Sets | 4            |
| Block Size     | 4 bytes      |

### 4.3 Address Decomposition

For a 16-bit address with our configuration:

```
| 12-bit Tag | 2-bit Index | 2-bit Offset |
```

- **Offset (2 bits):** selects byte within a 4-byte block
- **Index (2 bits):** selects which of the 4 sets to look in
- **Tag (12 bits):** identifies the exact memory block

### 4.4 LRU Replacement Policy

When a cache miss occurs and the selected set has no empty ways, one existing line must be evicted. LRU evicts the line **least recently used** — the one that has gone the longest without being accessed.

**Implementation: Age Counter Method**

Each way within a set maintains an age counter:

- On access to way `i`: reset counter `i` to 0, increment all other counters
- On eviction: replace the way with the highest counter value (oldest)

For 4-way associativity, each set needs four 2-bit counters (values 0–3).

---

## 5. System Architecture

### 5.1 High-Level Data Flow

actually there should be a real address generator module here, like and not simple switches that just passes address, as approaching more towards real simulation.

```
[Switch Input: 16-bit Address]
            |
            v
   [Address Decoder]
   splits into Tag, Index, Offset
            |
            v
   [Cache Memory Array]
   4 sets × 4 ways × (tag + valid + data)
            |
            v
   [Tag Comparator]
   compares input tag vs all 4 stored tags in selected set
            |
       _____|______
      |            |
   [HIT]        [MISS]
      |            |
      v            v
  Update LRU   Run LRU Logic
  counters     → find LRU way
               → evict it
               → load new data
               → update LRU counters
      |            |
      |____________|
            |
            v
   [Statistics Counter]
   hit_count++  or  miss_count++
            |
            v
   [7-Segment Display]
   shows hit count, miss count
            |
            v
   [LED Output]
   hit LED or miss LED blinks
```

### 5.2 Module Breakdown

The system is divided into 6 Verilog modules:

```
top_module
├── addr_decoder
├── cache_memory
├── tag_comparator
├── lru_controller
├── cache_controller (FSM)
└── stats_display
```

---

## 6. Module Specifications

### Module 1: `addr_decoder`

**Purpose:** Splits the 16-bit input address into tag, index, and offset.

**Ports:**

| Port       | Direction | Width  | Description                    |
|-----------|-----------|--------|-------------------------------|
| `addr`    | input     | 16-bit | Full memory address            |
| `tag`     | output    | 12-bit | Tag field for comparisons      |
| `index`   | output    | 2-bit  | Set selection                  |
| `offset`  | output    | 2-bit  | Byte selection within block    |

**Logic:** Pure combinational wire assignment. No clock needed.

```
tag    = addr[15:4]
index  = addr[3:2]
offset = addr[1:0]
```

---

### Module 2: `cache_memory`

**Purpose:** Stores all cache lines. The core storage of the system.

**Structure:**

```
cache[set][way] = {valid_bit, tag[11:0], data[31:0]}
```

That is: 4 sets × 4 ways = 16 entries, each holding 1 valid bit + 12-bit tag + 32-bit data = 45 bits per entry.

**Ports:**

| Port          | Direction | Description                          |
|--------------|-----------|--------------------------------------|
| `clk`        | input     | Clock                                |
| `index`      | input     | Which set to access                  |
| `way_sel`    | input     | Which way to write (on miss)         |
| `write_en`   | input     | Write enable signal                  |
| `tag_in`     | input     | Tag to store on miss                 |
| `data_in`    | input     | Data to store on miss                |
| `tag_out`    | output    | All 4 tags from selected set         |
| `data_out`   | output    | All 4 data blocks from selected set  |
| `valid_out`  | output    | All 4 valid bits from selected set   |

**Implementation note:** Use `reg` arrays in Verilog. BRAM inference happens automatically for larger arrays but for this size, registers are fine.

---

### Module 3: `tag_comparator`

**Purpose:** Checks whether the incoming tag matches any of the 4 stored tags in the selected set. Reports which way matched (if any).

**Ports:**

| Port         | Direction | Description                                 |
|-------------|-----------|---------------------------------------------|
| `tag_in`    | input     | Tag from address decoder                    |
| `tag_stored`| input     | 4 × 12-bit tags from cache memory           |
| `valid_bits`| input     | 4 valid bits                                |
| `hit`       | output    | 1 if any way matched                        |
| `hit_way`   | output    | 2-bit index of which way matched            |

**Logic:** Pure combinational. Four parallel equality comparisons. Hit is valid only if tag matches AND valid bit is 1.

```
hit_way0 = (tag_in == tag_stored[0]) && valid_bits[0]
hit_way1 = (tag_in == tag_stored[1]) && valid_bits[1]
hit_way2 = (tag_in == tag_stored[2]) && valid_bits[2]
hit_way3 = (tag_in == tag_stored[3]) && valid_bits[3]

hit = hit_way0 | hit_way1 | hit_way2 | hit_way3
```

---

### Module 4: `lru_controller`

**Purpose:** Maintains age counters for all ways in all sets. On a hit or miss, updates counters. On a miss, reports which way is LRU (to be evicted).

**LRU Counter Logic (Age Counter Method):**

Each set has 4 counters, one per way (values 0–3):
- Counter 0 = most recently used
- Counter 3 = least recently used (evict this one)

On access to way `W`:
- Set counter[W] = 0
- Increment all other counters (capped at 3)

The LRU way is whichever counter holds value 3.

**Ports:**

| Port         | Direction | Description                            |
|-------------|-----------|----------------------------------------|
| `clk`       | input     | Clock                                  |
| `reset`     | input     | Reset all counters                     |
| `update_en` | input     | Enable counter update                  |
| `index`     | input     | Which set to update                    |
| `used_way`  | input     | Which way was just accessed            |
| `lru_way`   | output    | Which way is currently LRU (evict me) |

**Structure:**

```
counters[4 sets][4 ways] → each 2 bits wide
```

---

### Module 5: `cache_controller`

**Purpose:** The FSM brain that coordinates all other modules. Decides what happens each clock cycle based on current state and inputs.

**States:**

```
IDLE → LOOKUP → HIT_UPDATE
                         ↓ (on hit)  → back to IDLE
              → MISS_EVICT → MISS_LOAD → back to IDLE
```

| State          | What happens                                              |
|---------------|-----------------------------------------------------------|
| `IDLE`        | Wait for `access_request` button press                    |
| `LOOKUP`      | Latch address, send to decoder, comparator runs           |
| `HIT_UPDATE`  | Signal hit, update LRU counters for accessed way          |
| `MISS_EVICT`  | Signal miss, identify LRU way to evict                    |
| `MISS_LOAD`   | Write new tag + data into evicted way, update LRU         |

**Ports:**

| Port             | Direction | Description                      |
|-----------------|-----------|----------------------------------|
| `clk`           | input     | Clock (100 MHz on Nexys A7)      |
| `reset`         | input     | System reset                     |
| `access_req`    | input     | From button press                |
| `addr_in`       | input     | 16-bit address from switches     |
| `hit`           | input     | From tag comparator              |
| `hit_way`       | input     | From tag comparator              |
| `lru_way`       | input     | From LRU controller              |
| `write_en`      | output    | To cache memory                  |
| `lru_update_en` | output    | To LRU controller                |
| `cache_hit_out` | output    | To stats module + LED            |
| `cache_miss_out`| output    | To stats module + LED            |

---

### Module 6: `stats_display`

**Purpose:** Counts total hits and misses. Drives the 7-segment display and LEDs.

**Behavior:**

- `hit_count` increments on every `cache_hit` signal
- `miss_count` increments on every `cache_miss` signal
- Display alternates between showing hit count and miss count (switchable by button)

**Nexys A7 7-segment:**

The Nexys A7 has 8 seven-segment digits. Use digits 7–4 for hit count and digits 3–0 for miss count, displayed simultaneously.

| Digits [7:4] | Digits [3:0] |
|-------------|-------------|
| Hit Count   | Miss Count  |

**LEDs:**

- `LED[0]` = HIGH for 2 clock cycles on cache hit
- `LED[1]` = HIGH for 2 clock cycles on cache miss

---

### Module 7: `top_module`

**Purpose:** Connects all modules together. Maps FPGA physical pins to module ports.

**FPGA I/O Mapping:**

| FPGA Resource     | Connected To         | Purpose                   |
|------------------|---------------------|---------------------------|
| `SW[15:0]`       | `addr_in`           | 16-bit memory address     |
| `BTNC`           | `access_req`        | Submit access request     |
| `BTNL`           | `reset`             | Reset entire system       |
| `LED[0]`         | `cache_hit_out`     | Blink on hit              |
| `LED[1]`         | `cache_miss_out`    | Blink on miss             |
| `SEG[7:0]`       | `stats_display`     | Hit/miss counts           |
| `AN[7:0]`        | `stats_display`     | Digit enable signals      |

---

## 7. Simulation Plan

Before deploying to hardware, every module must be individually simulated in Vivado using a **testbench**.

A testbench is a separate Verilog file (not synthesizable) that:
1. Instantiates your module
2. Applies input signals at specific times
3. Lets you observe outputs on a waveform viewer

**Simulation order:**
1. `addr_decoder` — verify tag/index/offset split for known addresses
2. `tag_comparator` — verify hit/miss detection with known stored tags
3. `lru_controller` — verify counters update correctly after sequential accesses
4. `cache_controller` — verify FSM transitions are correct
5. `top_module` — full integration test with a scripted access sequence

**Key test sequence to verify LRU:**

```
Access: Set 0, load ways 0,1,2,3 (fills up set 0)
Access: Way 1 again (way 1 becomes most recent, way 0 becomes LRU)
Access: New address → should evict way 0, NOT way 1
```

If your LRU logic evicts way 0 here, it's correct.

---

## 8. Expected Demo Behavior

1. Reset the board (BTNL)
2. Set switches to an address (e.g., `0000000000000000`)
3. Press BTNC → Miss (LED[1] lights, miss count increments)
4. Press BTNC again (same address) → Hit (LED[0] lights, hit count increments)
5. Set switches to three more new addresses, press BTNC each time → all misses (fills the set)
6. Set switches to a 5th new address for the same set → Miss + LRU eviction happens
7. Set switches back to address 2 (which should still be in cache) → Hit

The 7-segment display tracks the running count throughout.

---

---

# PART 2: INTERNAL TEAM PLAN
### (The "how we execute this" guide — for your team's use only)

---

## Week-by-Week Plan

### Week 1 — Learn, Setup, Build the Easy Parts

**Goal:** Everyone understands Verilog basics. Vivado is installed and working. The two simplest modules are coded and simulated.

**Day 1–2: Verilog Fundamentals (Everyone does this)**

You only need to understand these 6 things to build this project:

```verilog
// 1. Module declaration
module my_module(input a, input b, output c);
endmodule

// 2. Wire vs Reg
wire x;        // combinational, assigned by assign
reg y;         // sequential, assigned inside always block

// 3. Assign (combinational logic)
assign c = a & b;

// 4. Always block (sequential logic — runs on clock edge)
always @(posedge clk) begin
    y <= y + 1;  // non-blocking assignment, always use <= here
end

// 5. If/else inside always
always @(posedge clk) begin
    if (reset) y <= 0;
    else y <= y + 1;
end

// 6. Parameters (configurable constants)
parameter WAYS = 4;
parameter SETS = 4;
```

Spend 2 days on this. Use the free resource: **HDLBits** (hdlbits.01xz.net) — it's an online Verilog exercise site. Do the first 10 exercises. That's enough for this project.

**Day 3: Vivado Setup**

- Install Vivado (free version: Vivado ML Edition)
- Create a new project, select board: **xc7a100tcsg324-1** (Nexys A7 100T)
- Create a simple test module (an AND gate), simulate it, verify waveform
- This is just to confirm your tools work before touching real code

**Day 4–5: Build `addr_decoder` and `tag_comparator`**

These are the two simplest modules. Both are pure combinational (no clock needed). Whoever finishes first helps the other.

Person 1 builds `addr_decoder`:
```verilog
module addr_decoder(
    input  [15:0] addr,
    output [11:0] tag,
    output [1:0]  index,
    output [1:0]  offset
);
    assign tag    = addr[15:4];
    assign index  = addr[3:2];
    assign offset = addr[1:0];
endmodule
```
That's literally the entire module. Write a testbench that feeds in 5 different addresses and confirm the outputs split correctly.

Person 2 builds `tag_comparator` (slightly more work, but still simple).

Person 3 starts reading about FSMs — look up "Verilog FSM tutorial" and understand the pattern. You'll need it for Week 3.

---

### Week 2 — Build the Storage and Statistics

**Goal:** `cache_memory` and `stats_display` are coded, simulated, and working independently.

**Person 1 + Person 2: `cache_memory`**

This module is essentially a 2D array of registers:

```verilog
reg [11:0] tags    [0:3][0:3];  // [set][way]
reg        valid   [0:3][0:3];
reg [31:0] data    [0:3][0:3];
```

On write: when `write_en` is high, write `tag_in` and `data_in` into `cache[index][way_sel]`, set valid bit.
On read: output all 4 tags and valid bits from `cache[index]` combinationally.

Test it: manually write to a set, read back, verify tags match.

**Person 3: `stats_display`**

This module needs to learn one extra thing: **7-segment encoding** on the Nexys A7. The display uses multiplexed anodes (AN signals) — you rapidly switch between digits, displaying one at a time, faster than the human eye can see, so it looks like all digits are lit simultaneously.

There are many open-source 7-segment controller examples for Nexys boards. Find one on GitHub or OpenCores, understand it, and adapt it. Don't write it from scratch.

Stats logic itself is simple:
```verilog
always @(posedge clk) begin
    if (hit_in)  hit_count  <= hit_count  + 1;
    if (miss_in) miss_count <= miss_count + 1;
end
```

---

### Week 3 — The Hard Part: LRU + FSM

**Goal:** `lru_controller` and `cache_controller` are coded and simulated. This is the core intellectual challenge of the project.

**Person 3 (strongest): `cache_controller` FSM**

The FSM has 5 states. Map them out on paper BEFORE writing any Verilog. Draw a state diagram: circles for states, arrows for transitions, labels for conditions. If you can't draw it, you can't code it.

Pattern to follow:

```verilog
// Two-always FSM pattern (standard, clean)
// Always block 1: state register (sequential)
always @(posedge clk or posedge reset) begin
    if (reset) state <= IDLE;
    else state <= next_state;
end

// Always block 2: next state + output logic (combinational)
always @(*) begin
    case (state)
        IDLE: begin
            if (access_req) next_state = LOOKUP;
            else next_state = IDLE;
        end
        LOOKUP: begin
            if (hit) next_state = HIT_UPDATE;
            else next_state = MISS_EVICT;
        end
        // ... etc
    endcase
end
```

**Person 1 + Person 2: `lru_controller`**

Draw a 4×4 table on paper. Columns = sets (0–3), Rows = ways (0–3). Each cell = age counter (0 = most recent, 3 = oldest). Manually simulate 5–6 accesses by hand on paper and update the counters yourself. Once you can do it by hand, coding it is straightforward.

```verilog
// counters[set][way] = age
reg [1:0] counters [0:3][0:3];

always @(posedge clk) begin
    if (update_en) begin
        // Way `used_way` in set `index` was just accessed
        // Reset its counter, increment all others
        // ...
    end
end
```

The LRU way output is whichever way in the indexed set has counter = 3.

**Simulation checkpoint for Week 3:**

Before moving on, simulate this exact sequence and verify:
- Access set 0, way 0 → counters: [0, 1, 2, 3] (way 0 newest, way 3 LRU)
- Access set 0, way 2 → counters: [1, 2, 0, 3] (way 2 newest, way 3 still LRU)
- Access set 0, way 3 → counters: [2, 3, 1, 0] (way 3 newest, way 1 is now LRU)

If your simulation matches this, LRU is correct.

---

### Week 4 — Integration, Debug, Deploy

**Goal:** All modules wired together in `top_module`. Simulated as a complete system. Flashed to Nexys A7 and demoed.

**Day 1–2: Write `top_module` and integration testbench**

`top_module` is mostly just wiring — instantiate each submodule and connect their ports. The skill here is getting port connections right. Use named port connections (`.portname(signal)`) not positional — easier to read and debug.

Run the full test sequence described in Section 7 of this document.

**Day 3: Synthesize and check for errors**

Click "Run Synthesis" in Vivado. Common first-time errors:
- Latches inferred (means a signal isn't assigned in all branches of an `always` block — add a default assignment)
- Timing violations (usually means you have combinational logic that's too slow — simplify it)

**Day 4: Generate bitstream and flash to board**

In Vivado: Run Implementation → Generate Bitstream → Open Hardware Manager → Program Device.

**Day 5: Buffer day**

It won't work perfectly on first flash. Bugs found during hardware testing that weren't visible in simulation:
- Buttons have physical bounce — add a debounce circuit for the access request button (or use BTNC with the board's built-in debounce if available)
- 7-segment display may flicker — check your refresh rate logic

---

## Module Ownership Summary

| Module             | Owner    | Difficulty | Week Due |
|-------------------|----------|-----------|----------|
| `addr_decoder`    | Person 1 | Easy      | Week 1   |
| `tag_comparator`  | Person 2 | Easy      | Week 1   |
| `cache_memory`    | Person 1+2 | Medium  | Week 2   |
| `stats_display`   | Person 3 | Medium    | Week 2   |
| `lru_controller`  | Person 1+2 | Hard    | Week 3   |
| `cache_controller`| Person 3 | Hard      | Week 3   |
| `top_module`      | Everyone | Medium    | Week 4   |

---

## Vivado Workflow Cheatsheet

```
New Project
  └─ Add Sources → Write Verilog modules here
  └─ Add Simulation Sources → Write testbenches here
  └─ Run Simulation → View waveform to debug

Once all modules work in simulation:
  └─ Add Constraints file (.xdc) → Maps ports to physical pins
  └─ Run Synthesis → Check for errors
  └─ Run Implementation → Check timing
  └─ Generate Bitstream → Creates the config file for FPGA
  └─ Open Hardware Manager → Connect board → Program Device
```

The `.xdc` constraints file for Nexys A7 is publicly available from Digilent (the board manufacturer). Download the master XDC file from their GitHub and uncomment only the pins you actually use. Don't write pin mappings manually.

---

## Debugging Tips

**"My simulation shows wrong output"**
- Add `$display("state=%b, hit=%b", state, hit);` inside your always block to print values
- Check that you used `<=` (non-blocking) inside clocked always blocks, not `=`

**"My module works in simulation but not on the board"**
- Almost always a timing or button bounce issue
- Add a simple button debouncer
- Check your clock constraints in the XDC file

**"LRU is evicting the wrong way"**
- Simulate just the `lru_controller` in isolation with the exact counter update sequence above
- Draw the counter state on paper after each step and compare to waveform

**"7-segment shows garbage"**
- The Nexys A7's segment display is active-low (0 = segment ON, not 1)
- Anodes are also active-low
- Invert your outputs if you copied code that assumes active-high

---

## Minimum Viable Project vs Stretch Goals

**Minimum (must have for passing):**
- Working cache hit/miss detection
- LRU eviction that correctly handles a full set
- Hit/miss count on 7-segment display

**Good (comfortable grade, demonstrates understanding):**
- All of the above + correct FSM with all 5 states
- LED feedback on hit/miss
- Clean module separation, each independently testable

**Stretch (if you have time and are enjoying it):**
- UART output — send hit/miss results to laptop over serial, display in terminal
- Parameterize WAYS and SETS so you can change config without rewriting logic
- Add a "show cache contents" mode where pressing a button cycles through displaying each set's current tag on the 7-segment

---

## Useful Resources

| Resource | Link | What For |
|----------|------|----------|
| HDLBits | hdlbits.01xz.net | Learn Verilog with exercises |
| Nexys A7 Reference Manual | digilent.com/reference/programmable-logic/nexys-a7 | Board pinouts, specs |
| Nexys A7 Master XDC | github.com/Digilent/digilent-xdc | Pin constraint file |
| Nandland Verilog Tutorials | nandland.com | Best beginner Verilog explanations |
| FPGA4Fun | fpga4fun.com | UART and practical FPGA examples |

---

*Document version 1.0 | Last updated for project kickoff*
