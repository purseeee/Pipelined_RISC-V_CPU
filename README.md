# Pipelined RV32I CPU Core

## Project Overview

This project implements a 32-bit RISC-V processor based on the base integer (RV32I) instruction set architecture. The processor uses a 5-stage pipeline: Fetch, Decode, Execute, Memory, and Writeback. 

The design was developed and simulated using EDA Playground. Yosys was used to generate structural netlists to visualize the datapath. 

Currently, the datapath is structurally complete for basic pipelined execution. It does not include a hazard unit. Pipeline hazards are not handled in hardware and must be managed manually in software.

## Supported Instructions

* **R-Type:** `add`, `sub`, `and`, `or`, `slt`
* **I-Type:** `addi`, `lw`
* **S-Type:** `sw`
* **B-Type:** `beq`, `bne`, `blt`, `bge`
* **J-Type:** `jal`, `jalr`
* **U-Type:** `lui`

## Hardware Modules and Design Details

### Pipeline Registers
A single parameterized register module is used for all stage boundaries (IF/ID, ID/EX, EX/MEM, MEM/WB). The bit-width is calculated exactly for each stage so the synthesis tool does not generate unused flip-flops. 

```verilog
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


###Instruction Memory
The instruction memory is a read-only memory (ROM). The RISC-V architecture uses byte addresses, but instructions are 32 bits (4 bytes) wide. The module ignores the bottom two bits of the incoming address to correctly fetch word-aligned instructions.

```verilog
reg [31:0] rom [0:255]; 
    
    // Read word-aligned address (ignoring bottom 2 bits)
    assign instr = rom[addr[9:2]];

###Data Memory
The data memory is a random-access memory (RAM). Similar to the instruction memory, it ignores the bottom two bits of the address to ensure 32-bit word alignment. Memory reads are combinational, while writes occur synchronously on the clock edge.

```verilog
// Read word-aligned address (ignoring bottom 2 bits)
    assign rd = ram[addr[11:2]]; 
    
    // Write is synchronous
    always @(posedge clk) begin
        if (we) ram[addr[11:2]] <= wd;
    end




###Register File and Writeback
The register file contains 32 registers, each 32 bits wide. Register zero (x0) is hardwired to zero. During the Writeback stage, writes happen synchronously on the positive clock edge. Reads are asynchronous.

```verilog
always @(posedge clk) begin
        if (we && a3 != 5'd0) begin // Ensure x0 is never overwritten
            rf[a3] <= wd3;
        end
    end
    
    // Asynchronous reads
    assign rd1 = (a1 != 5'd0) ? rf[a1] : 32'd0;


###Immediate Extension
This module extracts the immediate values encoded within the instruction and sign-extends them to 32 bits based on the instruction format type.

```verilog
always @(*) begin
        case(immSrc)
            3'b000: immExt = {{20{instr[31]}}, instr[31:20]};                           // I-Type
            3'b010: immExt = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0}; // B-Type
            // ... other formats handled here
            default: immExt = 32'd0;
        endcase
    end



###ALU Decoder
The ALU Decoder uses the aluOp signal and combines it with the funct3 and funct7 instruction fields to determine the exact mathematical operation for the Main ALU.


```verilog
always @(*) begin
        case(aluOp)
            2'b10: begin // R-type or I-type ALU instructions
                case(funct3)
                    3'b000: if (funct7_5) ALUControl = 4'b0001; // sub
                            else          ALUControl = 4'b0000; // add
                    3'b010: ALUControl = 4'b0101;               // slt
                    // ... other operations
                endcase
            end
            // ... default operations
        endcase
    end


###Main ALU
The Main ALU performs arithmetic and logical operations. It outputs a 32-bit result and mathematical condition flags to be used by the branch evaluation logic.


```verilog
always @(*) begin
        case(ALUControl)
            4'b0000: ALUResult = srcA + srcB;
            4'b0101: ALUResult = ($signed(srcA) < $signed(srcB)) ? 32'd1 : 32'd0;
            // ... other operations
        endcase
    end
    
    // Condition flags for branch evaluation
    assign zero     = (ALUResult == 32'd0);
    assign greater  = ($signed(srcA) >= $signed(srcB));



###Branch Evaluation
Branch conditions are evaluated in the Execute stage. Since the ALU outputs all mathematical flags at once, the funct3 bits are passed to the Execute stage to pick the correct flag for the specific branch type. This decision is used to update the Program Counter.


```verilog
// Evaluate the condition required by funct3
    always @(*) begin
        case(funct3E)
            3'b000: TakeBranchE = zeroE;      // BEQ
            3'b001: TakeBranchE = notEqualE;  // BNE
            3'b100: TakeBranchE = lesserE;    // BLT
            3'b101: TakeBranchE = greaterE;   // BGE
            default: TakeBranchE = 1'b0;      
        endcase
    end

    // PCSrc multiplexer logic feeding back to Fetch
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








