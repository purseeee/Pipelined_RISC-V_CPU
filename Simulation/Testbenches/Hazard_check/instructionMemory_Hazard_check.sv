// module instructionMemory #(
//   parameter WIDTH = 32,
//   parameter DEPTH = 1024
// )(
//   input  logic [WIDTH-1:0] addr,  // byte address (PC)
//   output logic [WIDTH-1:0] instr
// );

//   localparam ADDR_BITS = $clog2(DEPTH);

//   // 'mem' to match standard usage and TB
//   logic [WIDTH-1:0] mem [0:DEPTH-1];

//   // Initialize memory and load the stress-test assembly
//   initial begin
//     // 1. Wipe memory clean
//     for (int i = 0; i < DEPTH; i++) mem[i] = 0;

//     // 2. Load the Hazard Stress-Test Assembly
    
//     // Test 1: Data Hazards & Multiplexer Forwarding
//     mem[0]  = 32'h00100093; // addi x1, x0, 1   (x1 = 1)
//     mem[1]  = 32'h00200113; // addi x2, x0, 2   (x2 = 2)
//     mem[2]  = 32'h002081b3; // add  x3, x1, x2  (x3 = 3)
//     mem[3]  = 32'h00118233; // add  x4, x3, x1  (x4 = 4) -> RAW on x3! Forwards from Execute stage.
//     mem[4]  = 32'h004182b3; // add  x5, x3, x4  (x5 = 7) -> RAW on x4 & x3! Forwards from Execute AND Memory stages.

//     // Test 2: Load-Use Hazard & Stalling
//     mem[5]  = 32'h00502023; // sw   x5, 0(x0)   (mem[0] = 7)
//     mem[6]  = 32'h00002303; // lw   x6, 0(x0)   (x6 = 7)
//     mem[7]  = 32'h001303b3; // add  x7, x6, x1  (x7 = 8) -> Load-Use Hazard! Forces 1-cycle stall, then forwards.

//     // Test 3: Control Hazards & Branch Flushing
//     mem[8]  = 32'h00038a63; // beq  x7, x0, 20  (8 != 0, branch NOT taken. CPU should continue normally)
//     mem[9]  = 32'h00a00413; // addi x8, x0, 10  (x8 = 10)
//     mem[10] = 32'h00840663; // beq  x8, x8, 12  (10 == 10, branch TAKEN!) -> Jumps to mem[13], flushes mem[11] & mem[12].
//     mem[11] = 32'h00000013; // nop              -> SHOULD BE FLUSHED (If executed, simulation fails)
//     mem[12] = 32'h00000013; // nop              -> SHOULD BE FLUSHED (If executed, simulation fails)

//     // Success State (Reached only if all stalls and flushes worked perfectly)
//     mem[13] = 32'h06400493; // pass: addi x9, x0, 100 (Load target address 100)
//     mem[14] = 32'h0ff00513; // addi x10, x0, 255      (Load success code 255)
//     mem[15] = 32'h00a4a023; // sw   x10, 0(x9)        (Writes 255 to mem[100] -> TRIGGERS TESTBENCH SUCCESS!)
//     mem[16] = 32'h0000006f; // loop: j loop           (Infinite loop fallback)
//   end

//   // Convert byte address -> word index
//   wire [ADDR_BITS-1:0] word_addr = addr[ADDR_BITS+1:2];

//   // Asynchronous read
//   assign instr = mem[word_addr];
  
// endmodule