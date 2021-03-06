module CPU(clock);
  parameter LW = 6'b100011, SW = 6'b101011, BEQ = 6'b000100, no_op = 32'b00000_100000, ALUop = 6'b0;
  input clock;     // O clock � uma entrada externa
                   // Os registradores arquitetonicamente vis�veis e os registradores
                   // de rascunho para a implementa��o.
  
  reg [31:0] PC, Regs[0:31], IMemory [0:1023], DMemory[0:1023], IFIDIR, IDEXA, IDEXB, IDEXIR, EXMEMIR, EXMEMB, EXMEMALUOut, MEMWBValue, MEMWBIR;  // mem�rias separadas e registradores de pipeline
  wire [4:0] IDEXrs, IDEXrt, EXMEMrd, MEMWBrd, MEMWBrt;        // Acessa campos do registrador
  wire [5:0] EXMEMop, MEMWBop, IDEXop;                         // Mant�m os opcodes
  wire [31:0] Ain, Bin;  
  
  // Declara os sinais de bypass
  wire takebranch, stall, bypassAfromMEM, bypassAfromALUinWB, bypassBfromMEM, bypassBfromALUinWB, bypassAfromLWinWB, bypassBfromLWWINB;
        
  assign IDEXrs = IDEXIR[25:21]; assign IDEXrt = IDEXIR[15:11]; assign EXMEMrd = EXMEMIR[15:11];
  assign MEMWBrd = MEMWBIR[20:16]; assign EXMEMop = EXMEMIR[31:26];
  assign MEMWBrt = MEMWBIR[25:20];
  assign MEMWBop = MEMWBIR[31:26]; assign IDEXop = IDEXIR[31:26];
  
  // Bypass para entrada A do est�gio MEM para uma opera��o da ALU
  assign bypassAfromMEM = (IDEXrs == EXMEMrd) & (IDEXrt!=0) & (EXMEMop == ALUop); // Sim, bypass
  
  // Bypass para entrada B do est�gio MEM para opera��o da ALU
  assign bypassBfromMEM = (IDEXrt == EXMEMrd) & (IDEXrs!=0) & (EXMEMop == ALUop); // Sim, bypass
  
  // Bypass para a entrada A do est�gio WB para uma opera��o da ALU
  assign bypassAfromALUinWB = (IDEXrs == MEMWBrd) & (IDEXrs!=0) & (MEMWBop==ALUop);
  
  // Bypass para a entrada B do est�gio WB para uma opera��o ALU
  assign bypassBfromALUinWB = (IDEXrt == MEMWBrd) & (IDEXrt!=0) & (MEMWBop==ALUop);
  
  // Bypass para a entrada A do est�gio WB para uma opera��o LW
  assign bypassAfromLWinWB = (IDEXrs  == MEMWBIR[20:16]) & (IDEXrs!=0) & (MEMWBop==LW);
  
  // Bypass para a entrada B do est�gio WB para uma opera��o LW
  assign bypassBfromLWinWB = (IDEXrt  == MEMWBIR[20:16]) & (IDEXrt!=0) & (MEMWBop==LW);
  
  // A entrada A para a ALU sofre bypass por MEM se houver um bypass ali,
  // sen�o, por WB se houver um bypass ali, e n�o vem do registrador IDEX
  assign Ain = bypassAfromMEM? EXMEMALUOut:
                        (bypassAfromALUinWB | bypassAfromLWinWB)? MEMWBValue: IDEXA;
  
  // A entrada B para a ALU sofre bypass por MEM se houver um bypass ali,
  // sen�o, por WB se houver um bypass ali, e n�o vem do registrador IDEX
  assign Bin = bypassBfromMEM? EXMEMALUOut:
                        (bypassBfromALUinWB | bypassBfromLWinWB)? MEMWBValue: IDEXB;
                        
    
  
  // O sinal para detectar um stall com base no uso de um resultado de LW
  assign stall = (MEMWBIR[31:26]==LW) && ((((IDEXop==LW) | (IDEXop==SW)) && (IDEXrs==MEMWBrd)) | ((IDEXop==ALUop) && ((IDEXrs==MEMWBrd) | (IDEXrt==MEMWBrd)))); // stall para calcular endere�o
                                                                                                                                                              // uso da ALU
  
  // Sinal para um desvio tomado: instru��o � BEQ e registradores s�o iguais
  assign takebranch = (IFIDIR[31:26]==BEQ) && (Regs[IFIDIR[25:21]]==Regs [IFIDIR[20:16]]);
  
    reg [5:0] i; // usado para iniciar registradores
    initial begin 
    PC = 0;
    IFIDIR=no_op; IDEXIR=no_op; MEMWBIR=no_op; // Coloca no ops em registradores de pipeline
    for (i=0; i<=31;i=1+1) Regs[i] = i;        // inicializa registradores
  end
  
  always @ (posedge clock) begin
     if(~stall) begin                          // Os tr�s primeiros est�gios sofrem stall se houver um hazard no load
        if(~takebranch) begin                 // Primeira instru��o do pipeline esta sendo buscada
           IFIDIR <= IMemory[PC>>2];
           PC = PC + 4;
         end else begin                        // ID cont�m desvio tomado; inst. em IF errada; insere no op e reseta PC
         IFIDIR <= no_op;
         PC <= PC + ({{16{IFIDIR[15]}}, IFIDIR[15:0]}<<2);
       end
       
  // Segunda instru��o no pipeline est� buscando registradores
  IDEXA <= Regs[IFIDIR[25:21]]; IDEXB <= Regs[IFIDIR[20: 16]];   // Busca dois registradores
  IDEXIR <= IFIDIR;                                              // Passa IR para a frente - isso poderia ficar em qualquer lugar
                                                                // pois afeta apenas o pr�pximo est�gio!
  
  // Terceira instru��o est� realizando c�lculo de endere�o ou opera��o ALU
  if ((IDEXop==LW) | (IDEXop==SW))                              // C�lculo de endere�o e copia B
       EXMEMALUOut <= IDEXA + {{16{IDEXIR[15]}}, IDEXIR[15:0]};
  else if (IDEXop==ALUop) case (IDEXIR[5:0])                    //  CASE para as v�rias instru��es tipo R
  
        32: EXMEMALUOut <= Ain + Bin;                           // acrescenta opera��o
        default: ;                                              // outras duas opera��es tipo R: subtract, SLT etc
      endcase
      
      EXMEMIR <= IDEXIR; EXMEMB <= IDEXB;                       // passa para frente os registradores IR & B
    end
  else EXMEMIR <= no_op;                                        // Congela os 3 primeiros est�gios do pipeline; injeta nop na sa�da de EX
  
  
 // Est�gio mem do pipeline
 if (EXMEMop==ALUop) MEMWBValue <= EXMEMALUOut;                 // passa para frente o resultado da ALU
      else if (EXMEMop == LW) MEMWBValue <= DMemory[EXMEMALUOut>>2];
      else if (EXMEMop == SW) DMemory[EXMEMALUOut>>2] <= EXMEMB;    // Armazena
      MEMWBIR <= EXMEMIR;                                           // Passa para frente IR
  
  // O est�gio WB
  if ((MEMWBop==ALUop) & (MEMWBrd!=0)) Regs[MEMWBrd] <= MEMWBValue;  // Opera��o ALU
  else if ((EXMEMop==LW) & (MEMWBrt!=0)) Regs[MEMWBrt] <= MEMWBValue;
  end
  
endmodule


  
         
  
  
  
  
  
  
  
  
  
 
            
                     
                       
                          
            
  
  