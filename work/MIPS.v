module CPU(clock);
  parameter LW = 6'b100011, SW = 6'b101011, BEQ = 6'b000100, J = 6'd2;
  input clock;     // O clock � uma entrada externa
                   // Os registradores arquitetonicamente vis�veis e os registradores
                   // de rascunho para a implementa��o.
  reg [31:0] PC, Regs[0:31], Memory [0:1023], IR, ALUOut, MDR, A, B;
  reg [2:0] state;                   // Estado do processador.
  wire [5:0] opcode;                 // Usado para obter o opcode facilmente.
  wire [31:0] SignExtend, PCOffset;  // Usado para obter o campo offset com sinal extendido.
  assign opcode = IR[31:26];         // O opcode s�o os 6 bits mais significativos.
  assign SignExtend = {{16{IR[15]}},IR[15:0]}; // Extens�o de sinal dos 16 bits menos sig-
                                               //nificativos da instru��o.
  assign PCOffset = SignExtend << 2; // O offset do PC � deslocado
  
  // Coloca o PC como zero e inicia o controle no estado zero.
  initial begin PC = 0; state = 1; end
  
  // A m�quina de estados -n disparada uma transi��o de subida do clock. 
  always @(posedge clock) begin
    Regs [0] = 0;   // Faz R0 = 0, modo r�pido de garantir que R0 seja sempre 0.
    case (state)    // A a��o depende do estado.
        1: begin    // A primeira etapa: buscar a instru��o, incrementar o PC, ir para o pr�ximo estado.
           IR <= Memory[PC>>2];
           PC <= PC + 4;
           state = 2; // pr�ximo estado.
           end
         
        2: begin   // A segunda etapa: Decodifica��o da instru��o, busca dos registradores, tamb�m c�l-
                    // cula endere�o de desvio.
           A <= Regs [IR[25:21]];
           B <= Regs [IR[20:16]];
           state = 3;
           ALUOut <= PC + PCOffset; // Calcula o destino de desvio relativo ao PC.
           end
          
        3: begin  // A terceira etapa: execu��o de load/store, execu��o da ALU, conclus�o do branch.
           state = 4; // pr�ximo estado padr�o.
           if ((opcode == LW) | (opcode == SW)) ALUOut <= A + SignExtend; // C�lcula endere�o efetivo.
           else if ((opcode == 6'b0) case(IR[5:0])  // Case para as v�rias instru��es tipo R.
                32: ALUOut = A + B;   // Opera��o de soma.
                default: ALUOut = A;  // Outras opera��es tipo R: subtra��o, SLT etc.
           endcase
               
           else if (opcode == BEQ) begin
                if (A==B) PC <= ALUOut;  // Desvio tomado - atualiza o PC.
                state = 1;
                end
             
            else if (opcode = J) begin
                    PC = {PC[31:28], IR[25:0], 2'b00};  // O PC de destino do jump.
                    state = 1;
            end      // Jumps
              
            else;    // outros opcodes ou exece��o para instru��o indefinida entrariam aqui.
            end
              
         4: begin
            if (opcode == 6'b0) begin             // Opera��o da ALU.
                Regs[IR[15:11]] <= ALUOut;        // Escreve o resultado.
                state = 1;
            end                                   // Tipo R termina.
            else if (opcode == LW) begin          // Instru��o load.
            MDR <= Memory[ALUOut>>2];             // L� mem�ria.
            state = 5;                            // Pr�ximo estado.
            end
            
            else if(opcode == LW) begin
              Memory[ALUOut>>2] <= B;             // Escreve na mem�ria
              state = 1;                          // Retorna para o estado 1.
            end                                   // Termina o store.
            
           else;                                  // Outras instru��es entram aqui
           end
           
         5: begin                                 // LW � a �nica instru��o ainda em execu��o.
            Regs[IR[20:16]] = MDR                 // Escreve o MDR no registrador.
            state = 1;
            end                                    // Completa a instru��o LW
            endcase
            
            end   
endmodule
          
            
            
                     
                       
                          
            
  
  