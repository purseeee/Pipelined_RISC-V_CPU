// original code
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

  // Initialize memory (Optional for TB, but good for Synthesis)
  initial begin
    for (int i = 0; i < DEPTH; i++) mem[i] = 0;
  end

  // Convert byte address -> word index
  wire [ADDR_BITS-1:0] word_addr = addr[ADDR_BITS+1:2];

  // Asynchronous read
  assign instr = mem[word_addr];

//   // --- Add this DEBUG block ---
//   always_comb begin
//     // This will print every time the address changes but prints twice because addr triggers change in word_addr, hence evaluated twice until settled during delta cycles
//     $display("DEBUG: Byte Addr = %0d  -->  Calculated Word Index = %0d", addr, word_addr);
//   end 
//   // NOTE: we use 32bit wide buses and not 4 8bit wide buses because we need the entire word in a single clock, also routing on silicon becomes horrible and unnecessary

endmodule