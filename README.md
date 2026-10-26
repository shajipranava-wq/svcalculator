# svcalculator

A 16-bit calculator with an ALU (8 arithmetic and 8 logical operations) and a synchronous FIFO, verified with class-based SystemVerilog testbenches.

## Design Under Test

- **`calculator_main`**: the top module that connects the ALU and the FIFO.
- **FIFO**: 8 deep, 16 bits wide, with 4-bit read and write pointers and a registered `FIFO_OUT`. It uses an extra pointer bit to tell full from empty, without needing a separate counter.
- **ALU**: a 3-state FSM (IDLE / LOGIC_OP / ARITH_OP) that selects between 16 operations. `A`, `B` and the operation code are latched on the start edge.
- **Muxes**: `sel`, `selA` and `selB` choose between `data1`, `data2` and the FIFO output.
- **Extra ports for verification**: `done`, `fifo_full`, `fifo_empty` and `fifo_data_out`.

## Testbench Architecture

- Class-based testbenches: a packet, a FIFO packet, a generator, driver, monitor and scoreboard, each for the ALU testbench and the FIFO testbench.
- Mailboxes pass packets between components in order and block until data is available, which a plain queue doesn't do.
- A `calcmain` interface connects the testbench to the DUT.

```
generator -> mailbox -> driver -> DUT -> monitor -> mailbox -> scoreboard
```

## ALU Testbench

- 65,535 randomized packets, using random operands across all 16 operations.
- The scoreboard computes the expected result, overflow and underflow for every packet and compares them.
- The driver changes inputs at the negedge. The monitor samples at the posedge, the same edge as the DUT, after the driver's change has settled. This avoids a race between driving and sampling.
- The monitor also checks the `done` signal, using `start` as its trigger.

## FIFO Testbench

- An ordered, directed sequence covering the main FIFO corner cases: pop on empty, push and pop on empty, fill and push on full, push and pop on full, pop, and push and pop in the normal state.
- The scoreboard keeps a queue model. `fifo_full` and `fifo_empty` are combinational in the DUT, so they are compared against the model's state before the queue is updated.
- `FIFO_OUT` is registered, so its value shows up one packet after the pop. The scoreboard saves the expected value and compares it on the next packet.
- The monitor ignores samples taken while reset is high or unknown.

## Test Execution

- Both tests share one DUT and one interface, so they run one after the other in a single `tb_top`: the FIFO test first, then the ALU test. `fork ... join_none` starts each phase and `disable fork` stops the FIFO processes before the ALU phase starts.
- Simulated in AMD Vivado 2025.2. Use `run all` to get past the default 1000 ns run limit.

## Results

<img width="1198" height="390" alt="Screenshot 2026-10-26 151522" src="https://github.com/user-attachments/assets/6c61dc79-7058-4681-a09d-eeb78898b0b6" />

- ALU: PASS=65535 FAIL=0
- FIFO: PASS=49 FAIL=0

## Bug Injection (testbench validation)

- ALU: changed add to A-B. The scoreboard caught it.
- FIFO: changed the read index in the pop path. The `FIFO_OUT` check reported FAIL=3.
- Both bugs were reverted afterwards.

## Known Gaps / Future Work

- Mid-run reset is not tested.
- Pointer wraparound is limited: neither pointer completes a full 4-bit lap.
- The FIFO-to-ALU path (`selA`/`selB` = 0) is not tested.
- No functional coverage or assertions yet.
- The ALU test is purely random, so rare corner cases (such as equal operands) are not guaranteed to be hit.
