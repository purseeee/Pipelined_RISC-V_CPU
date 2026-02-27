module regFile #(
    parameter WIDTH = 32
)(
    input  logic             clk, 
    input  logic             we,
    input  logic [4:0]       a1, a2, a3,
    input  logic [WIDTH-1:0] wd3,
    output logic [WIDTH-1:0] rd1, rd2
);

    logic [WIDTH-1:0] rf [31:0];

    // Synchronous write with async reset
  always_ff @(negedge clk) begin
      
      if (we && a3 != 5'b0) begin
            rf[a3] <= wd3;
        end
    end
    

    // Asynchronous read
    assign rd1 = (a1 != 5'b0) ? rf[a1] : {WIDTH{1'b0}};
    assign rd2 = (a2 != 5'b0) ? rf[a2] : {WIDTH{1'b0}};

endmodule