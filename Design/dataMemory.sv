module dataMemory #(
    parameter WIDTH = 32,
    parameter DEPTH = 1024   // number of 32-bit words
)(
    input  logic             clk,
    input  logic             we,
    input  logic [WIDTH-1:0] addr,  // BYTE address
    input  logic [WIDTH-1:0] wd,
    output logic [WIDTH-1:0] rd
);

    localparam ADDR_BITS = $clog2(DEPTH);
    logic [WIDTH-1:0] mem [0:DEPTH-1];

    // Convert byte address -> word index
    wire [ADDR_BITS-1:0] word_addr = addr[ADDR_BITS+1:2];

    always_ff @(posedge clk) begin
        // Synchronous Write
        if (we) begin
            mem[word_addr] <= wd;
        end

    end
  
  // Add this outside (Asynchronous Read)
  assign rd = mem[word_addr];

endmodule
