`include "regFile.sv"
`include "immExtend.sv"
`include "ALU.sv"
`include "aluDecoder.sv"
`include "controlDecoder.sv"
`include "pipelineReg.sv"
`include "hazardHandler.sv"

`timescale 1ns / 1ps

module riscv_core(
  input  logic        clk,
  input  logic        rst_n,
  
  // Instruction Memory Interface
  output logic [31:0] instrAddr,
  input  logic [31:0] instrData,
  
  // Data Memory Interface
  output logic        memWrite,
  output logic [31:0] dataAddr,
  output logic [31:0] writeData,
  input  logic [31:0] readData
);
  
  // =========================================================================
  // Global Feedback Wires (Execute -> Fetch)
  // Declared here so the Fetch stage knows they exist before using them
  // =========================================================================
  logic [1:0]  PCSrcE;
  logic [31:0] PCTargetE;
  logic [31:0] aluResultE;

  // PC Next Multiplexer (The Feedback Loop)
  logic [31:0] PCF, PCNextF, PCPlus4F; 
  
  always_comb begin
    case(PCSrcE)
      2'b00: PCNextF = PCPlus4F;   // Default: PC + 4
      2'b01: PCNextF = PCTargetE;  // Jumps (JAL) and Taken Branches
      2'b10: PCNextF = aluResultE; // JALR (ALU calculates rs1 + imm)
      default: PCNextF = PCPlus4F; 
    endcase
  end
  
  // =========================================================================
  // Hazard Unit Wires
  // =========================================================================
  logic [1:0] forwardAE, forwardBE;
  logic       stallF, stallD, flushD, flushE;
  logic [4:0] rs1E, rs2E; // Emerges from D/E pipeline register

  // =========================================================================
  // Fetch stage wires, instantiation, logic
  // =========================================================================
  
  // Wires internal to Fetch Stage
  logic [31:0] instrF;
  
  // Connect to external Instruction Memory (Replaces instrMemInstance)
  assign instrAddr = PCF;
  assign instrF = instrData;
  
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
    .en(~stallF),    // CONNECTED: Hazard Unit (StallF)
    .clr(1'b0),      // PC never clears to 0 synchronously, it loads PCTarget
    .d(PCNextF),
    .q(PCF)
  );

  // 3. IF/ID Pipeline Register
  pipelineReg #(
    .WIDTH(96)
  ) pipelineReg_F_D (
    .clk(clk),
    .rst_n(rst_n), 
    .en(~stallD),    // CONNECTED: Hazard Unit (StallD)
    .clr(flushD),    // CONNECTED: Hazard Unit (FlushD)
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

  // FIXED: Width is now exactly 191 bits to include funct3 AND rs1D/rs2D
  pipelineReg #(
    .WIDTH(191) 
  ) pipelineReg_D_E (
    .clk(clk),
    .rst_n(rst_n), 
    .en(1'b1),    
    .clr(flushE), // CONNECTED: Hazard Unit (FlushE)
    .d({
        regWriteD, resultSrcD, memWriteD, jumpD, branchD, jalrD,
        aluControlD, aluSrcAD, aluSrcBD, 
        rd1D, rd2D, PCD, immExtD, PCPlus4D, rdD, funct3D,
        instrD[19:15], instrD[24:20] // NEW: Passing rs1D and rs2D to Execute
       }),
    .q({
        regWriteE, resultSrcE, memWriteE, jumpE, branchE, jalrE,
        aluControlE, aluSrcAE, aluSrcBE, 
        rd1E, rd2E, PCE, immExtE, PCPlus4E, rdE, funct3E,
        rs1E, rs2E                   // NEW: Emerging as rs1E and rs2E
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
  logic [31:0] forwardedAE, forwardedBE; // NEW: Wires for 3-way muxes
  // NOTE: PCSrcE, PCTargetE, and aluResultE are declared globally at the top of the file!
  
  // Wires emerging from EX/MEM into Memory Stage
  logic        regWriteM, memWriteM;
  logic [1:0]  resultSrcM;
  logic [4:0]  rdM;
  logic [31:0] aluResultM, writeDataM, PCPlus4M;
  
  // NEW: 3-Way Forwarding Multiplexers
  always_comb begin
    case(forwardAE)
      2'b00: forwardedAE = rd1E;       // Use register data
      2'b01: forwardedAE = resultW;    // Hazard from Writeback
      2'b10: forwardedAE = aluResultM; // Hazard from Memory
      default: forwardedAE = rd1E;
    endcase
  end

  always_comb begin
    case(forwardBE)
      2'b00: forwardedBE = rd2E;
      2'b01: forwardedBE = resultW;
      2'b10: forwardedBE = aluResultM;
      default: forwardedBE = rd2E;
    endcase
  end

  // Mux polarities match Decoder logic (Now using forwarded data)
  assign srcAE = aluSrcAE ? PCE : forwardedAE; 
  assign srcBE = aluSrcBE ? immExtE : forwardedBE; 
  
  // Physically route rd2E to the writeData wire for 'sw' instructions (Forwarded)
  assign writeDataE = forwardedBE;
  
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

  // Instantiating the Hazard Handler
  hazardHandler hazardUnitInstance (
    .rs1E(rs1E), .rs2E(rs2E), .rs1D(instrD[19:15]), .rs2D(instrD[24:20]),
    .rdM(rdM), .rdW(rdW), .rdE(rdE),
    .regWriteM(regWriteM), .regWriteW(regWriteW),
    .resultSrcE0(resultSrcE[0]), // 1 indicates a Load instruction
    .PCSrcE(PCSrcE != 2'b00),    // True if a branch or jump is taken
    .forwardAE(forwardAE), .forwardBE(forwardBE),
    .flushE(flushE), .stallF(stallF), .stallD(stallD), .flushD(flushD)
  );
  
  // EX/MEM Pipeline register
  pipelineReg #(
    .WIDTH(105) 
  ) EX_MEM_Reg (
    .clk(clk),
    .rst_n(rst_n), 
    .en(1'b1),  
    .clr(1'b0), 
    .d({regWriteE, resultSrcE, memWriteE, aluResultE, writeDataE, rdE, PCPlus4E}),
    .q({regWriteM, resultSrcM, memWriteM, aluResultM, writeDataM, rdM, PCPlus4M})
  );

  // =========================================================================
  // Memory stage wires, instantiation, logic
  // =========================================================================
  
  // Wires for mem access stage
  logic [31:0] readDataM;
  
  // Connect to external Data Memory (Replaces dataMemInstance)
  assign memWrite = memWriteM;
  assign dataAddr = aluResultM;
  assign writeData = writeDataM;
  assign readDataM = readData;
  
  // Wires for writeback stage
  logic [1:0]  resultSrcW;
  logic [31:0] readDataW, aluResultW, PCPlus4W;
  
  // MEM/WB Pipeline register instance
  pipelineReg #(
    .WIDTH(104) 
  ) MEM_WB_Reg (
    .clk(clk),
    .rst_n(rst_n), 
    .en(1'b1),  
    .clr(1'b0), 
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