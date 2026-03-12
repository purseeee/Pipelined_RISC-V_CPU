`timescale 1ns/1ps

module tb;
  
  //====================================
  //SIGNALS
  //====================================
  logic clk;
  logic rst_n;
  
  //====================================
  //INSTANTIATE DUT 
  //====================================  
  topModule dut (
    .clk(clk),
    .rst_n(rst_n)
  );
  
  //====================================
  //BEGIN CLOCK GENERATION
  //==================================== 
  initial clk = 0;
  always #5 clk = ~clk;
  
  //====================================
  //RESET THE CPU
  //==================================== 
  initial begin
    rst_n = 0;
    #15; // Hold reset for 15ns (a cycle and a half)
    rst_n = 1;
  end
  
  // ============================
  // Monitor
  // ============================
  initial begin
    $display("==========================================");
    $display("Starting RISC-V CPU Simulation");
    $display("==========================================");

    // Timeout protection
    #20000;
    $display("TIMEOUT: Simulation did not finish.");
    $finish;
  end
  
  // ============================
  // Result Checker
  // ============================
  always @(posedge clk) begin

    if (dut.core_inst.memWrite) begin
      if(dut.core_inst.dataAddr == 32'd100)begin
        if(dut.core_inst.writeData == 32'd75025)begin
          $display("==========================================");
          $display("SUCCESS: Correct data written!");
          $display("Result = %0d", dut.core_inst.writeData);
          $display("Simulation Time = %0t", $time);
          $display("==========================================");
          $finish;
        end
      end
    end
  end
  
  // ============================
  // Optional Debug Monitor
  // ============================
  initial begin
    $monitor("Time=%0t | PC=%0h | writeData=%0d",
             $time,
             dut.core_inst.PCF,
             dut.core_inst.writeData);
  end
endmodule