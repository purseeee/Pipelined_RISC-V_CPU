module hazardHandler(

  input logic [4:0] rs1E, //new signal, extract from instruction bits in D stage. rs1D
  input logic [4:0] rs2E,
  input logic [4:0] rs1d,
  input logic [4:0] rs2d,
  input logic [4:0] rdM,
  input logic [4:0] rdW,
  input logic [4:0] rdE,
  input logic regWriteM,
  input logic regWriteW,
  input logic resultSrcE0,
  input logic PCSrcE,
  //forward
  output logic [1:0] forwardAE, 
  output logic [1:0] forwardBE,
  //flush
  output logic flushE, 
  output logic stallF,
  output logic stallD,
  //branch
  output logic flushD

);
  
  logic lwStall;
  
  
  //forward logic
  always_comb begin
    if (((rs2E == rdM) && regWriteM) && (rs2E!=0)) begin
      forwardBE = 2'b10;
    end 
    
    else if (((rs2E == rdW) && regWriteW) && (rs2E!=0)) begin
      forwardBE = 2'b01;
    end    
    
    else
      forwardBE = 2'b00;
  end
  
  
  
  always_comb begin
    
    if (((rs1E == rdM) && regWriteM) && (rs1E!=0)) begin
      forwardAE = 2'b10;
    end
    
    else if (((rs1E == rdW) && regWriteW) && (rs1E!=0)) begin
      forwardAE = 2'b01;
    end
    
    else
      forwardAE = 2'b00;
  end
  
  
  
  //stall logic
  assign lwStall = (resultSrcE0 && ((rs1d == rdE) || (rs2d == rdE)) && (rdE != 5'b0)); //when resultSrcE0 is 1, data is writtenback from dataMem. Also avoid unnecessary (most compilers don't generate this but still) stall when rdE = 0;
  //assign flushE = lwStall; //handle in branch logic
  assign stallF = lwStall;
  assign stallD = lwStall;
  
  
  
  
  //branch prediction
  assign flushD = PCSrcE; //if branch is being taken, flush the current decoded instruction and executed instruction, now new instruction will be fetched so no need to flush Fetch stage register
  assign flushE = PCSrcE || lwStall; 
  
 
endmodule