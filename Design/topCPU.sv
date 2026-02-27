// Code your design here
`include "regFile.sv"
`include "dataMem.sv"
`include "instructionMem.sv"
`include "immExtend.sv"
`include "ALU.sv"
`include "aluDecoder.sv"
`include "controlDecoder.sv"
`include "pipelineReg.sv"

`timescale 1ns / 1ps

module topModule(
  input clk,
  input rst_n
);
  
  // =========================================================================
  // Global Feedback Wires (Execute -> Fetch)
  // Declared here so the Fetch stage knows they exist before using them
  // =========================================================================
  logic [1:0]  PCSrcE;
  logic [31:0] PCTargetE;
  logic [31:0] aluResultE;

  // PC Next Multiplexer (The Feedback Loop)
  always_comb begin
    case(PCSrcE)
      2'b00: PCNextF = PCPlus4F;   // Default: PC + 4
      2'b01: PCNextF = PCTargetE;  // Jumps (JAL) and Taken Branches
      2'b10: PCNextF = aluResultE; // JALR (ALU calculates rs1 + imm)
      default: PCNextF = PCPlus4F; 
    endcase
  end
  
  
  
  
  
  
  
  // =========================================================================
  // Fetch stage wires, instantiation, logic
  // =========================================================================
  
  // Wires internal to Fetch Stage
  logic [31:0] PCF, PCNextF, PCPlus4F; 
  logic [31:0] instrF;
  
  // Wires emerging from IF/ID into Decode Stage
  logic [31:0] instrD, PCD, PCPlus4D; 
  
  // PC Adder
  assign PCPlus4F = PCF + 32'd4;
  
  // 1. Program Counter Register (The physical PC)
  pipelineReg #(
    .WIDTH(32)
  ) PC_Reg (
    .clk(clk),
    .rst_n(rst_n), 
    .en(1'b1),      // TODO: Connect to Hazard Unit (StallF) later
    .clr(1'b0),     // PC never clears to 0 synchronously, it loads PCTarget
    .d(PCNextF),
    .q(PCF)
  );

  // 2. Instruction Memory
  instructionMemory instrMemInstance(
    .addr(PCF),
    .instr(instrF)  
  );
  
  // 3. IF/ID Pipeline Register
  pipelineReg #(
    .WIDTH(96)
  ) pipelineReg_F_D (
    .clk(clk),
    .rst_n(rst_n), 
    .en(1'b1),      // TODO: Connect to Hazard Unit (StallD) later
    .clr(1'b0),     // TODO: Connect to Hazard Unit (FlushD) later
    .d({instrF, PCF, PCPlus4F}),
    .q({instrD, PCD, PCPlus4D}) 
  );
  
  
  
  
  
  
  // =========================================================================
  // Decode stage wires, instantiation, logic
  // =========================================================================
  
  // RegFile wires
  logic [31:0] rd1D, rd2D;
  logic [4:0]  rdD;
  
  // Extract from bus, don't drive into it
  assign rdD = instrD[11:7];
  
  // NEW: Extract funct3 to identify the branch type
  logic [2:0] funct3D;
  assign funct3D = instrD[14:12]; 
  
  // immExtend wires
  logic [31:0] immExtD;
  
  // Control signals
  logic [3:0] aluControlD; 
  logic [1:0] resultSrcD;
  logic [2:0] immSrcD;     
  logic [1:0] aluOpD;      
  logic       regWriteD;  
  logic       memWriteD;
  logic       branchD;
  logic       jumpD;
  logic       jalrD;
  logic       aluSrcBD;    
  logic       aluSrcAD;    
  
  // Tie-off for future AUIPC support (default to 0: read from rd1)
  assign aluSrcAD = 1'b0; 

  // Writeback Stage Placeholders (To prevent compilation failure)
  logic        regWriteW;
  logic [4:0]  rdW;
  logic [31:0] resultW;

  // Instantiated the Missing Decoders
  controlDecoder ctrlDecInst (
    .opcode(instrD[6:0]),
    .branch(branchD),
    .resultSrc(resultSrcD),
    .memWrite(memWriteD),
    .aluOp(aluOpD),
    .aluSrc(aluSrcBD),
    .immSrc(immSrcD),
    .regWrite(regWriteD),
    .jump(jumpD),
    .jalr(jalrD)
  );

  aluDecoder aluDecInst (
    .aluOp(aluOpD),
    .funct3(instrD[14:12]),
    .funct7_5(instrD[30]),
    .ALUControl(aluControlD)
  );
  
  // RegisterFile instance
  regFile regFileInstance(
    .clk(clk),
    .we(regWriteW),      
    .a3(rdW),            
    .wd3(resultW),       
    .a1(instrD[19:15]),
    .a2(instrD[24:20]),
    .rd1(rd1D),
    .rd2(rd2D)
  );
  
  // immExtend instance
  immExtend immExtendInstance(
    .instr(instrD[31:7]),
    .immSrc(immSrcD),
    .immExt(immExtD)
  );
  
  // Wires emerging from ID/EX into Execute Stage
  logic        regWriteE, memWriteE, branchE, jumpE, jalrE, aluSrcAE, aluSrcBE;
  logic [1:0]  resultSrcE;
  logic [3:0]  aluControlE;
  logic [31:0] rd1E, rd2E, PCE, immExtE, PCPlus4E;
  logic [4:0]  rdE;
  logic [2:0]  funct3E; // NEW: Routed signal for branch evaluation

  // FIXED: Width is now exactly 181 bits to include funct3
  pipelineReg #(
    .WIDTH(181) 
  ) pipelineReg_D_E (
    .clk(clk),
    .rst_n(rst_n), 
    .en(1'b1),  // TODO: Connect to Hazard Unit later
    .clr(1'b0), // TODO: Connect to Hazard Unit later
    .d({
        regWriteD, resultSrcD, memWriteD, jumpD, branchD, jalrD,
        aluControlD, aluSrcAD, aluSrcBD, 
        rd1D, rd2D, PCD, immExtD, PCPlus4D, rdD, funct3D // Added funct3D
       }),
    .q({
        regWriteE, resultSrcE, memWriteE, jumpE, branchE, jalrE,
        aluControlE, aluSrcAE, aluSrcBE, 
        rd1E, rd2E, PCE, immExtE, PCPlus4E, rdE, funct3E // Added funct3E
       })
  );

  
  
  
  
  
  // =========================================================================
  // Execute stage wires, instantiation, logic
  // =========================================================================
  
  // Wires internal to Execute stage
  logic        zeroE;
  logic        notEqualE;
  logic        greaterE;
  logic        lesserE;
  logic        TakeBranchE; // NEW: The final branch decision wire
  
  logic [31:0] srcAE, srcBE;
  logic [31:0] writeDataE;
  // NOTE: PCSrcE, PCTargetE, and aluResultE are declared globally at the top of the file!
  
  // Wires emerging from EX/MEM into Memory Stage
  logic        regWriteM, memWriteM;
  logic [1:0]  resultSrcM;
  logic [4:0]  rdM;
  logic [31:0] aluResultM, writeDataM, PCPlus4M;
  
  // Mux polarities match Decoder logic
  assign srcAE = aluSrcAE ? PCE : rd1E; 
  assign srcBE = aluSrcBE ? immExtE : rd2E; 
  
  // Physically route rd2E to the writeData wire for 'sw' instructions
  assign writeDataE = rd2E;
  
  // Jump/branch target adder
  assign PCTargetE = PCE + immExtE;
  
  // NEW: Branch Evaluation Multiplexer
  // Looks at funct3 to choose which ALU flag decides the branch
  always_comb begin
    case(funct3E)
      3'b000: TakeBranchE = zeroE;      // BEQ
      3'b001: TakeBranchE = notEqualE;  // BNE
      3'b100: TakeBranchE = lesserE;    // BLT
      3'b101: TakeBranchE = greaterE;   // BGE
      default: TakeBranchE = 1'b0;      // Default: Do not branch
    endcase
  end

  // FIXED: Branch logic now uses the evaluated TakeBranchE wire
  always_comb begin
    if (jalrE) begin
      PCSrcE = 2'b10; // JALR jumps to the ALU Result
    end
    else if ((branchE & TakeBranchE) | jumpE) begin
      PCSrcE = 2'b01; // Branches and JAL jump to PCTargetE
    end 
    else begin
      PCSrcE = 2'b00; // Default: PC + 4
    end
  end
   
  // Instantiate main ALU
  ALU aluInstance(
    .srcA(srcAE),
    .srcB(srcBE),
    .ALUControl(aluControlE), 
    .ALUResult(aluResultE),   
    .zero(zeroE),
    .notEqual(notEqualE),
    .greater(greaterE),
    .lesser(lesserE)
  );
  
  // EX/MEM Pipeline register
  pipelineReg #(
    .WIDTH(105) 
  ) EX_MEM_Reg (
    .clk(clk),
    .rst_n(rst_n), 
    .en(1'b1),  // TODO: Connect to Hazard Unit later
    .clr(1'b0), // TODO: Connect to Hazard Unit later
    .d({regWriteE, resultSrcE, memWriteE, aluResultE, writeDataE, rdE, PCPlus4E}),
    .q({regWriteM, resultSrcM, memWriteM, aluResultM, writeDataM, rdM, PCPlus4M})
  );
  
  
  
  
  
  
  // =========================================================================
  // Memory stage wires, instantiation, logic
  // =========================================================================
  
  // Wires for mem access stage
  logic [31:0] readDataM;
  
  // Wires for writeback stage
  logic [1:0]  resultSrcW;
  logic [31:0] readDataW, aluResultW, PCPlus4W;
  
  // DataMemory instance
  dataMemory dataMemInstance(
    .clk(clk),
    .we(memWriteM),
    .addr(aluResultM), // Byte address
    .wd(writeDataM),   // Data to write (for sw)
    .rd(readDataM)     // Data read (for lw)
  );
  
  // MEM/WB Pipeline register instance
  pipelineReg #(
    .WIDTH(104) 
  ) MEM_WB_Reg (
    .clk(clk),
    .rst_n(rst_n), 
    .en(1'b1),  // TODO: Connect to Hazard Unit later
    .clr(1'b0), // TODO: Connect to Hazard Unit later
    .d({regWriteM, resultSrcM, aluResultM, readDataM, rdM, PCPlus4M}),
    .q({regWriteW, resultSrcW, aluResultW, readDataW, rdW, PCPlus4W})
  );
  
  
  
  
  
  
  // =========================================================================
  // Writeback stage logic
  // =========================================================================
  
  // 3-way Result Select Multiplexer
  // Physically drives the 'resultW' wire that loops back to the Register File
  always_comb begin
    case(resultSrcW)
      2'b00: resultW = aluResultW; // R-Type, I-Type ALU, U-Type
      2'b01: resultW = readDataW;  // Load instructions (lw)
      2'b10: resultW = PCPlus4W;   // Jumps (jal, jalr) return address
      default: resultW = aluResultW; 
    endcase
  end

endmodule