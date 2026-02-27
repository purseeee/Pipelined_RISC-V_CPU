// =========================================================================
// Single-File Pipelined RISC-V Core (Verilog-2001 for Yosys)
// =========================================================================

`timescale 1ns / 1ps

// -------------------------------------------------------------------------
// Submodule: Pipeline Register
// -------------------------------------------------------------------------
module pipelineReg #(
    parameter WIDTH = 32
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             en,
    input  wire             clr,
    input  wire [WIDTH-1:0] d,
    output reg  [WIDTH-1:0] q
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q <= {WIDTH{1'b0}};
        end else if (clr) begin
            q <= {WIDTH{1'b0}};
        end else if (en) begin
            q <= d;
        end
    end
endmodule

// -------------------------------------------------------------------------
// Submodule: Instruction Memory (Placeholder ROM)
// -------------------------------------------------------------------------
module instructionMemory (
    input  wire [31:0] addr,
    output wire [31:0] instr
);
    reg [31:0] rom [0:255]; // 1KB Instruction memory
    
    // Read word-aligned address (ignoring bottom 2 bits)
    assign instr = rom[addr[9:2]]; 
endmodule

// -------------------------------------------------------------------------
// Submodule: Data Memory (Placeholder RAM)
// -------------------------------------------------------------------------
module dataMemory (
    input  wire        clk,
    input  wire        we,
    input  wire [31:0] addr,
    input  wire [31:0] wd,
    output wire [31:0] rd
);
    reg [31:0] ram [0:1023]; // 4KB Data memory
    
    // Read is asynchronous/combinational
    assign rd = ram[addr[11:2]]; 
    
    // Write is synchronous
    always @(posedge clk) begin
        if (we) begin
            ram[addr[11:2]] <= wd;
        end
    end
endmodule

// -------------------------------------------------------------------------
// Submodule: Register File
// -------------------------------------------------------------------------
module regFile (
    input  wire        clk,
    input  wire        we,
    input  wire [4:0]  a1,
    input  wire [4:0]  a2,
    input  wire [4:0]  a3,
    input  wire [31:0] wd3,
    output wire [31:0] rd1,
    output wire [31:0] rd2
);
    reg [31:0] rf [31:0];
    
    // Write on positive edge. Ensure register 0 remains 0.
    always @(posedge clk) begin
        if (we && a3 != 5'd0) begin
            rf[a3] <= wd3;
        end
    end
    
    // Forwarding logic omitted; standard asynchronous read
    assign rd1 = (a1 != 5'd0) ? rf[a1] : 32'd0;
    assign rd2 = (a2 != 5'd0) ? rf[a2] : 32'd0;
endmodule

// -------------------------------------------------------------------------
// Submodule: Immediate Extension Unit
// -------------------------------------------------------------------------
module immExtend (
    input  wire [31:7] instr,
    input  wire [2:0]  immSrc,
    output reg  [31:0] immExt
);
    always @(*) begin
        case(immSrc)
            3'b000: immExt = {{20{instr[31]}}, instr[31:20]};                           // I-Type
            3'b001: immExt = {{20{instr[31]}}, instr[31:25], instr[11:7]};              // S-Type
            3'b010: immExt = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0}; // B-Type
            3'b011: immExt = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0}; // J-Type
            3'b100: immExt = {instr[31:12], 12'b0};                                     // U-Type
            default: immExt = 32'd0;
        endcase
    end
endmodule

// -------------------------------------------------------------------------
// Submodule: Control Decoder
// -------------------------------------------------------------------------
module controlDecoder (
    input  wire [6:0] opcode,
    output reg        branch,
    output reg  [1:0] resultSrc,
    output reg        memWrite,
    output reg  [1:0] aluOp,
    output reg        aluSrc,
    output reg  [2:0] immSrc,
    output reg        regWrite,
    output reg        jump,
    output reg        jalr
);
    always @(*) begin
        // Defaults to prevent latches
        branch    = 1'b0; 
        resultSrc = 2'b00; 
        memWrite  = 1'b0; 
        aluOp     = 2'b00;
        aluSrc    = 1'b0; 
        immSrc    = 3'b000; 
        regWrite  = 1'b0; 
        jump      = 1'b0; 
        jalr      = 1'b0;
        
        case(opcode)
            7'b0000011: begin regWrite = 1'b1; immSrc = 3'b000; aluSrc = 1'b1; memWrite = 1'b0; resultSrc = 2'b01; branch = 1'b0; aluOp = 2'b00; jump = 1'b0; jalr = 1'b0; end // lw
            7'b0100011: begin regWrite = 1'b0; immSrc = 3'b001; aluSrc = 1'b1; memWrite = 1'b1; resultSrc = 2'b00; branch = 1'b0; aluOp = 2'b00; jump = 1'b0; jalr = 1'b0; end // sw
            7'b0110011: begin regWrite = 1'b1; immSrc = 3'b000; aluSrc = 1'b0; memWrite = 1'b0; resultSrc = 2'b00; branch = 1'b0; aluOp = 2'b10; jump = 1'b0; jalr = 1'b0; end // R-type
            7'b1100011: begin regWrite = 1'b0; immSrc = 3'b010; aluSrc = 1'b0; memWrite = 1'b0; resultSrc = 2'b00; branch = 1'b1; aluOp = 2'b01; jump = 1'b0; jalr = 1'b0; end // B-type
            7'b0010011: begin regWrite = 1'b1; immSrc = 3'b000; aluSrc = 1'b1; memWrite = 1'b0; resultSrc = 2'b00; branch = 1'b0; aluOp = 2'b10; jump = 1'b0; jalr = 1'b0; end // I-type ALU
            7'b1101111: begin regWrite = 1'b1; immSrc = 3'b011; aluSrc = 1'b0; memWrite = 1'b0; resultSrc = 2'b10; branch = 1'b0; aluOp = 2'b00; jump = 1'b1; jalr = 1'b0; end // jal
            7'b1100111: begin regWrite = 1'b1; immSrc = 3'b000; aluSrc = 1'b1; memWrite = 1'b0; resultSrc = 2'b10; branch = 1'b0; aluOp = 2'b00; jump = 1'b0; jalr = 1'b1; end // jalr
            7'b0110111: begin regWrite = 1'b1; immSrc = 3'b100; aluSrc = 1'b1; memWrite = 1'b0; resultSrc = 2'b00; branch = 1'b0; aluOp = 2'b00; jump = 1'b0; jalr = 1'b0; end // lui
            default:    ;
        endcase
    end
endmodule

// -------------------------------------------------------------------------
// Submodule: ALU Decoder
// -------------------------------------------------------------------------
module aluDecoder (
    input  wire [1:0] aluOp,
    input  wire [2:0] funct3,
    input  wire       funct7_5,
    output reg  [3:0] ALUControl
);
    always @(*) begin
        case(aluOp)
            2'b00: ALUControl = 4'b0000; // add (for lw/sw/lui)
            2'b01: ALUControl = 4'b0001; // sub (for branches)
            2'b10: begin // R-type or I-type ALU
                case(funct3)
                    3'b000: if (funct7_5) ALUControl = 4'b0001; // sub
                            else          ALUControl = 4'b0000; // add
                    3'b010: ALUControl = 4'b0101; // slt
                    3'b110: ALUControl = 4'b0011; // or
                    3'b111: ALUControl = 4'b0010; // and
                    default: ALUControl = 4'b0000; 
                endcase
            end
            default: ALUControl = 4'b0000;
        endcase
    end
endmodule

// -------------------------------------------------------------------------
// Submodule: Main ALU
// -------------------------------------------------------------------------
module ALU (
    input  wire [31:0] srcA,
    input  wire [31:0] srcB,
    input  wire [3:0]  ALUControl,
    output reg  [31:0] ALUResult,
    output wire        zero,
    output wire        notEqual,
    output wire        greater,
    output wire        lesser
);
    always @(*) begin
        case(ALUControl)
            4'b0000: ALUResult = srcA + srcB;
            4'b0001: ALUResult = srcA - srcB;
            4'b0010: ALUResult = srcA & srcB;
            4'b0011: ALUResult = srcA | srcB;
            4'b0101: ALUResult = ($signed(srcA) < $signed(srcB)) ? 32'd1 : 32'd0;
            default: ALUResult = 32'd0;
        endcase
    end
    
    assign zero     = (ALUResult == 32'd0);
    assign notEqual = ~zero;
    assign greater  = ($signed(srcA) >= $signed(srcB));
    assign lesser   = ($signed(srcA) <  $signed(srcB));
endmodule

// -------------------------------------------------------------------------
// TOP MODULE: Pipelined RISC-V Datapath
// -------------------------------------------------------------------------
// -------------------------------------------------------------------------
// TOP MODULE: Pipelined RISC-V Datapath (Visualization Safe)
// -------------------------------------------------------------------------
module topModule(
    input  wire        clk,
    input  wire        rst_n,

    // ========= DEBUG OUTPUTS =========
    output wire [31:0] debug_pcF,
    output wire [31:0] debug_pcD,
    output wire [31:0] debug_pcE,
    output wire [31:0] debug_pcM,
    output wire [31:0] debug_pcW,
    output wire [31:0] debug_instrD,
    output wire [31:0] debug_aluE,
    output wire [31:0] debug_memRead,
    output wire [31:0] debug_writeBack
);
    // =========================================================================
    // Global Feedback Wires (Execute -> Fetch)
    // =========================================================================
    reg  [1:0]  PCSrcE;
    wire [31:0] PCTargetE;
    wire [31:0] aluResultE;

    // PC Next Multiplexer
    reg [31:0] PCNextF;
    always @(*) begin
        case(PCSrcE)
            2'b00: PCNextF = PCPlus4F;   // Default: PC + 4
            2'b01: PCNextF = PCTargetE;  // Jumps (JAL) and Taken Branches
            2'b10: PCNextF = aluResultE; // JALR (ALU calculates rs1 + imm)
            default: PCNextF = PCPlus4F; 
        endcase
    end
    
    // =========================================================================
    // Fetch Stage
    // =========================================================================
    wire [31:0] PCF, PCPlus4F, instrF;
    wire [31:0] instrD, PCD, PCPlus4D; 
    
    assign PCPlus4F = PCF + 32'd4;
    
    pipelineReg #(.WIDTH(32)) PC_Reg (
        .clk(clk), .rst_n(rst_n), 
        .en(1'b1), .clr(1'b0), 
        .d(PCNextF), .q(PCF)
    );

    instructionMemory instrMemInstance(
        .addr(PCF), .instr(instrF)  
    );
    
    pipelineReg #(.WIDTH(96)) pipelineReg_F_D (
        .clk(clk), .rst_n(rst_n), 
        .en(1'b1), .clr(1'b0), 
        .d({instrF, PCF, PCPlus4F}),
        .q({instrD, PCD, PCPlus4D}) 
    );
    
    // =========================================================================
    // Decode Stage
    // =========================================================================
    wire [31:0] rd1D, rd2D;
    wire [4:0]  rdD;
    wire [2:0]  funct3D;
    
    assign rdD = instrD[11:7];
    assign funct3D = instrD[14:12]; 
    
    wire [31:0] immExtD;
    wire [3:0]  aluControlD; 
    wire [1:0]  resultSrcD;
    wire [2:0]  immSrcD;     
    wire [1:0]  aluOpD;      
    wire        regWriteD;  
    wire        memWriteD;
    wire        branchD;
    wire        jumpD;
    wire        jalrD;
    wire        aluSrcBD;    
    wire        aluSrcAD;    
    
    assign aluSrcAD = 1'b0; // Default AUIPC tie-off

    // Writeback Stage Placeholders
    wire        regWriteW;
    wire [4:0]  rdW;
    reg  [31:0] resultW;

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
    
    immExtend immExtendInstance(
        .instr(instrD[31:7]),
        .immSrc(immSrcD),
        .immExt(immExtD)
    );
    
    wire        regWriteE, memWriteE, branchE, jumpE, jalrE, aluSrcAE, aluSrcBE;
    wire [1:0]  resultSrcE;
    wire [3:0]  aluControlE;
    wire [31:0] rd1E, rd2E, PCE, immExtE, PCPlus4E;
    wire [4:0]  rdE;
    wire [2:0]  funct3E; 

    pipelineReg #(.WIDTH(181)) pipelineReg_D_E (
        .clk(clk), .rst_n(rst_n), 
        .en(1'b1), .clr(1'b0), 
        .d({
            regWriteD, resultSrcD, memWriteD, jumpD, branchD, jalrD,
            aluControlD, aluSrcAD, aluSrcBD, 
            rd1D, rd2D, PCD, immExtD, PCPlus4D, rdD, funct3D
        }),
        .q({
            regWriteE, resultSrcE, memWriteE, jumpE, branchE, jalrE,
            aluControlE, aluSrcAE, aluSrcBE, 
            rd1E, rd2E, PCE, immExtE, PCPlus4E, rdE, funct3E
        })
    );
    
    // =========================================================================
    // Execute Stage
    // =========================================================================
    wire        zeroE;
    wire        notEqualE;
    wire        greaterE;
    wire        lesserE;
    reg         TakeBranchE; 
    
    wire [31:0] srcAE, srcBE;
    wire [31:0] writeDataE;
    
    wire        regWriteM, memWriteM;
    wire [1:0]  resultSrcM;
    wire [4:0]  rdM;
    wire [31:0] aluResultM, writeDataM, PCPlus4M;
    
    assign srcAE = aluSrcAE ? PCE : rd1E; 
    assign srcBE = aluSrcBE ? immExtE : rd2E; 
    assign writeDataE = rd2E;
    assign PCTargetE = PCE + immExtE;
    
    // Branch Evaluation
    always @(*) begin
        case(funct3E)
            3'b000: TakeBranchE = zeroE;      // BEQ
            3'b001: TakeBranchE = notEqualE;  // BNE
            3'b100: TakeBranchE = lesserE;    // BLT
            3'b101: TakeBranchE = greaterE;   // BGE
            default: TakeBranchE = 1'b0;      
        endcase
    end

    // PCSrcE Logic
    always @(*) begin
        if (jalrE) begin
            PCSrcE = 2'b10; 
        end
        else if ((branchE & TakeBranchE) | jumpE) begin
            PCSrcE = 2'b01; 
        end 
        else begin
            PCSrcE = 2'b00; 
        end
    end
     
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
    
    pipelineReg #(.WIDTH(105)) EX_MEM_Reg (
        .clk(clk), .rst_n(rst_n), 
        .en(1'b1), .clr(1'b0), 
        .d({regWriteE, resultSrcE, memWriteE, aluResultE, writeDataE, rdE, PCPlus4E}),
        .q({regWriteM, resultSrcM, memWriteM, aluResultM, writeDataM, rdM, PCPlus4M})
    );
    
    // =========================================================================
    // Memory Stage
    // =========================================================================
    wire [31:0] readDataM;
    
    wire [1:0]  resultSrcW;
    wire [31:0] readDataW, aluResultW, PCPlus4W;
    
    dataMemory dataMemInstance(
        .clk(clk),
        .we(memWriteM),
        .addr(aluResultM),
        .wd(writeDataM),  
        .rd(readDataM)    
    );
    
    pipelineReg #(.WIDTH(104)) MEM_WB_Reg (
        .clk(clk), .rst_n(rst_n), 
        .en(1'b1), .clr(1'b0), 
        .d({regWriteM, resultSrcM, aluResultM, readDataM, rdM, PCPlus4M}),
        .q({regWriteW, resultSrcW, aluResultW, readDataW, rdW, PCPlus4W})
    );
    
    // =========================================================================
    // Writeback Stage
    // =========================================================================
    always @(*) begin
        case(resultSrcW)
            2'b00: resultW = aluResultW; 
            2'b01: resultW = readDataW;  
            2'b10: resultW = PCPlus4W;   
            default: resultW = aluResultW; 
        endcase
    end


    // =========================================================================
    // Debug Signal Assignments (Prevents Optimization Removal)
    // =========================================================================
    assign debug_pcF      = PCF;
    assign debug_pcD      = PCD;
    assign debug_pcE      = PCE;
    assign debug_pcM      = aluResultM;   // Proxy for M stage activity
    assign debug_pcW      = aluResultW;   // Proxy for W stage activity
    assign debug_instrD   = instrD;
    assign debug_aluE     = aluResultE;
    assign debug_memRead  = readDataM;
    assign debug_writeBack= resultW;

endmodule