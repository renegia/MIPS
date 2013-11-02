module CPU(clock);
  parameter LW = 6'b100011, SW = 6'b101011, BEQ = 6'b000100, J = 6'd2;
  input clock;     // O clock é uma entrada externa
                   // Os registradores arquitetonicamente visíveis e os registradores
                   // de rascunho para a implementação.
  reg [31:0] PC, Regs[0:31], Memory [0:1023], IR, ALUOut, MDR, A, B;
  reg [2:0] state;                   // Estado do processador.
  wire [5:0] opcode;                 // Usado para obter o opcode facilmente.
  wire [31:0] SignExtend, PCOffset;  // Usado para obter o campo offset com sinal extendido.
  assign opcode = IR[31:26];         // O opcode são os 6 bits mais significativos.
  assign SignExtend = {{16{IR[15]}},IR[15:0]}; // Extensão de sinal dos 16 bits menos sig-
                                               //nificativos da instrução.
  assign PCOffset = SignExtend << 2; // O offset do PC é deslocado
  
  // Coloca o PC como zero e inicia o controle no estado zero.
  initial begin PC = 0; state = 1; end
  
  // A máquina de estados -n disparada uma transição de subida do clock. 
  always @(posedge clock) begin
    Regs [0] = 0;   // Faz R0 = 0, modo rápido de garantir que R0 seja sempre 0.
    case (state)    // A ação depende do estado.
        1: begin    // A primeira etapa: buscar a instrução, incrementar o PC, ir para o próximo estado.
           IR <= Memory[PC>>2];
           PC <= PC + 4;
           state = 2; // próximo estado.
           end
         
        2: begin   // A segunda etapa: Decodificação da instrução, busca dos registradores, também cál-
                    // cula endereço de desvio.
           A <= Regs [IR[25:21]];
           B <= Regs [IR[20:16]];
           state = 3;
           ALUOut <= PC + PCOffset; // Calcula o destino de desvio relativo ao PC.
           end
          
        3: begin  // A terceira etapa: execução de load/store, execução da ALU, conclusão do branch.
           state = 4; // próximo estado padrão.
           if ((opcode == LW) | (opcode == SW)) ALUOut <= A + SignExtend; // Cálcula endereço efetivo.
           else if ((opcode == 6'b0) case(IR[5:0])  // Case para as várias instruções tipo R.
                32: ALUOut = A + B;   // Operação de soma.
                default: ALUOut = A;  // Outras operações tipo R: subtração, SLT etc.
           endcase
               
           else if (opcode == BEQ) begin
                if (A==B) PC <= ALUOut;  // Desvio tomado - atualiza o PC.
                state = 1;
                end
             
            else if (opcode = J) begin
                    PC = {PC[31:28], IR[25:0], 2'b00};  // O PC de destino do jump.
                    state = 1;
            end      // Jumps
              
            else;    // outros opcodes ou execeção para instrução indefinida entrariam aqui.
            end
              
         4: begin
            if (opcode == 6'b0) begin             // Operação da ALU.
                Regs[IR[15:11]] <= ALUOut;        // Escreve o resultado.
                state = 1;
            end                                   // Tipo R termina.
            else if (opcode == LW) begin          // Instrução load.
            MDR <= Memory[ALUOut>>2];             // Lê memória.
            state = 5;                            // Próximo estado.
            end
            
            else if(opcode == LW) begin
              Memory[ALUOut>>2] <= B;             // Escreve na memória
              state = 1;                          // Retorna para o estado 1.
            end                                   // Termina o store.
            
           else;                                  // Outras instruções entram aqui
           end
           
         5: begin                                 // LW é a única instrução ainda em execução.
            Regs[IR[20:16]] = MDR                 // Escreve o MDR no registrador.
            state = 1;
            end                                    // Completa a instrução LW
            endcase
            
            end   
endmodule
          
            
            
                     
                       
                          
            
  
  