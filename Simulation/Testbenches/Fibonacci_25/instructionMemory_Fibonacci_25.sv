module instructionMemory #(
  parameter WIDTH = 32,
  parameter DEPTH = 1024
)(
  input  logic [WIDTH-1:0] addr,  // byte address (PC)
  output logic [WIDTH-1:0] instr
);

  localparam ADDR_BITS = $clog2(DEPTH);

  // 'mem' to match standard usage and TB
  logic [WIDTH-1:0] mem [0:DEPTH-1];

  // Initialize memory and load the Fibonacci assembly
  initial begin
    for (int i = 0; i < DEPTH; i++) mem[i] = 0;

    // =========================================================================
    // Assembly Program: fib(25)
    // C-Code equivalent:
    // int n = 25, a = 0, b = 1, temp;
    // while (n != 0) { temp = a + b; a = b; b = temp; n--; }
    // mem[100] = a;
    // =========================================================================
    
    // --- Initialization ---
    mem[0]  = 32'h01900093; // addi x1, x0, 25      (x1/n = 25)
    mem[1]  = 32'h00000113; // addi x2, x0, 0       (x2/a = 0)
    mem[2]  = 32'h00100193; // addi x3, x0, 1       (x3/b = 1)
    
    // --- Loop Start (PC = 12) ---
    mem[3]  = 32'h00008c63; // beq  x1, x0, end     (If n==0, branch to end. Offset +24 bytes)
    
    // --- Math (Heavy Forwarding Required) ---
    mem[4]  = 32'h00310233; // add  x4, x2, x3      (x4/temp = a + b)
    mem[5]  = 32'h00018113; // addi x2, x3, 0       (a = b)
    mem[6]  = 32'h00020193; // addi x3, x4, 0       (b = temp) -> RAW Hazard! Needs x4 from EX or MEM
    
    // --- Decrement and Repeat ---
    mem[7]  = 32'hfff08093; // addi x1, x1, -1      (n = n - 1)
    mem[8]  = 32'hfedff06f; // jal  x0, loop        (Jump unconditionally back to PC 12. Offset -20 bytes)
    
    // --- End (PC = 36) ---
    mem[9]  = 32'h06400493; // addi x9, x0, 100     (Load target memory address 100)
    mem[10] = 32'h0024a023; // sw   x2, 0(x9)       (Store final Fibonacci answer 'a' to mem[100])
    
    // --- Halt ---
    mem[11] = 32'h0000006f; // halt: j halt         (Infinite loop to prevent falling off the edge)
  end

  // Convert byte address -> word index
  wire [ADDR_BITS-1:0] word_addr = addr[ADDR_BITS+1:2];

  // Async