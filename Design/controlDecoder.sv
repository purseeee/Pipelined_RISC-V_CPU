module controlDecoder(
  input  logic [6:0] opcode,
  output logic       branch,
  output logic [1:0] resultSrc, 
  output logic       memWrite,
  output logic [1:0] aluOp, 
  output logic       aluSrc,
  output logic [2:0] immSrc,    // RESTORED: 3 bits for U-Type
  output logic       regWrite,
  output logic       jump,      
  output logic       jalr
);

  always_comb begin
    // Defaults
    branch    = 0;
    resultSrc = 2'b00;
    memWrite  = 0;
    aluOp     = 2'b00;
    aluSrc    = 0;
    immSrc    = 3'b000;       
    regWrite  = 0;
    jump      = 0;
    jalr      = 0;

    case(opcode)
      7'b0000011 : begin // lw
        resultSrc = 2'b01; 
        aluSrc    = 1;
        regWrite  = 1;
      end
      7'b0100011 : begin // sw
        resultSrc = 2'b00; 
        memWrite  = 1;
        aluSrc    = 1;
        immSrc    = 3'b001;     
      end
      7'b0110011 : begin // R-type
        resultSrc = 2'b00; 
        aluOp     = 2'b10;
        regWrite  = 1;
      end
      7'b1100011 : begin // branches
        branch    = 1;
        resultSrc = 2'b00; 
        aluOp     = 2'b01;
        immSrc    = 3'b010;     
      end
      7'b0010011 : begin // addi (I-Type ALU)
        resultSrc = 2'b00; 
        aluOp     = 2'b11; 
        aluSrc    = 1;     
        immSrc    = 3'b000;    
        regWrite  = 1;
      end
      7'b1101111 : begin // jal 
        jump      = 1;
        resultSrc = 2'b10; 
        immSrc    = 3'b011;     
        regWrite  = 1;
      end
      7'b1100111 : begin // jalr 
        jalr      = 1;     
        resultSrc = 2'b10; 
        aluSrc    = 1;     
        immSrc    = 3'b000;     
        regWrite  = 1;
        aluOp     = 2'b00; // FIXED: Force ADD for rs1 + imm
      end
      7'b0110111 : begin // lui (RESTORED)
        resultSrc = 2'b00;      
        aluSrc    = 1;          
        immSrc    = 3'b100;     
        regWrite  = 1;
        aluOp     = 2'b00;      
      end
      default: begin end
    endcase
  end
endmodule