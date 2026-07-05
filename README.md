# MIPS-architecture-pipelined
A structural 5-stage MIPS-like pipelined processor implemented in Verilog for educational computer architecture exploration.


This repository contains a functional, 5-stage pipelined processor (Instruction Fetch, Decode, Execute, Memory, Writeback) written in Verilog. It supports a fundamental subset of instructions—including basic ALU operations, Load/Store, and Branching. The design includes documented bug fixes for non-blocking assignments and comes with a self-contained testbench to simulate execution and verify register states, making it an excellent foundational prototype for understanding hardware pipeline design.

5-Stage Pipeline: Explicit separation of IF, ID, EX, MEM, and WB stages.

Basic ISA: Supports RR/RM ALU ops, Load/Store, and Branching.

Runnable Testbench: Includes a built-in test module for immediate simulation and waveform generation (VCD).

Educational Focus: Clearly documented state transitions and bug-fix notes for learning purposes.
