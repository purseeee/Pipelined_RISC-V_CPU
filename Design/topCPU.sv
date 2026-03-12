`include "RISC-VCore.sv"
`include "instructionMem.sv"
`include "dataMem.sv"

`timescale 1ns / 1ps

module topModule(
  input logic clk,
  input logic rst_n
);

  // Wires connecting the Core to the Memories
  logic [31:0] instrAddr, instrData;
  logic [31:0] dataAddr, writeData, readData;
  logic        memWrite;

  // 1. Instantiate the CPU Core
  riscv_core core_inst (
    .clk(clk),
    .rst_n(rst_n),
    .instrAddr(instrAddr),
    .instrData(instrData),
    .memWrite(memWrite),
    .dataAddr(dataAddr),
    .writeData(writeData),
    .readData(readData)
  );

  // 2. Instantiate the Instruction Memory
  instructionMemory imem_inst (
    .addr(instrAddr),
    .instr(instrData)
  );

  // 3. Instantiate the Data Memory
  dataMemory dmem_inst (
    .clk(clk),
    .we(memWrite),
    .addr(dataAddr),
    .wd(writeData),
    .rd(readData)
  );

endmodule