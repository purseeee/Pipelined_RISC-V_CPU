module aluDecoder(
  input  logic [1:0] aluOp,       // from main control
  input  logic [2:0] funct3,      // instr[14:12]
  input  logic       funct7_5,    // instr[30]
  output logic [3:0] ALUControl   // EXPANDED to 4 bits
);

  always_comb begin
    case (aluOp)

      // 00: lw/sw/lui/auipc/jal/jalr -> ADD
      2'b00: ALUControl = 4'b0000;

      // 01: branches -> SUB (ALU subtracts to compare, Zero flag tells us if equal)
      2'b01: ALUControl = 4'b1000;

      // 10: R-type
      2'b10: begin
        case (funct3)
          3'b000: ALUControl = (funct7_5) ? 4'b1000 : 4'b0000; // SUB / ADD
          3'b001: ALUControl = 4'b0001; // SLL
          3'b010: ALUControl = 4'b0010; // SLT
          3'b011: ALUControl = 4'b0011; // SLTU
          3'b100: ALUControl = 4'b0100; // XOR
          3'b101: ALUControl = (funct7_5) ? 4'b1101 : 4'b0101; // SRA / SRL
          3'b110: ALUControl = 4'b0110; // OR
          3'b111: ALUControl = 4'b0111; // AND
          default: ALUControl = 4'b0000;
        endcase
      end

      // 11: I-Type ALU (Immediate)
      2'b11: begin
        case (funct3)
          3'b000: ALUControl = 4'b0000; // ADDI (Always ADD, ignores funct7)
          3'b001: ALUControl = 4'b0001; // SLLI 
          3'b010: ALUControl = 4'b0010; // SLTI
          3'b011: ALUControl = 4'b0011; // SLTIU
          3'b100: ALUControl = 4'b0100; // XORI
          
          // FIX: Shifts require funct7_5 to distinguish SRAI from SRLI
          3'b101: ALUControl = (funct7_5) ? 4'b1101 : 4'b0101; // SRAI / SRLI
          
          3'b110: ALUControl = 4'b0110; // ORI
          3'b111: ALUControl = 4'b0111; // ANDI
          default: ALUControl = 4'b0000;
        endcase
      end

      default: ALUControl = 4'b0000;
    endcase
  end

endmodule