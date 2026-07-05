module processor(clk1, clk2);

input clk1, clk2;

reg [31:0] mem[0:1023];
reg [31:0] register[0:31];
reg [31:0] PC, IF_ID_IR, IF_ID_NPC;
reg [31:0] ID_EX_IR, ID_EX_NPC, ID_EX_A, ID_EX_B, ID_EX_Imm;
reg [2:0]  ID_EX_type, EX_MEM_type, MEM_WB_type;
reg [31:0] EX_MEM_IR, EX_MEM_ALUOut, EX_MEM_B, EX_MEM_NPC;
reg        EX_MEM_cond;
reg [31:0] MEM_WB_IR, MEM_WB_LMD, MEM_WB_ALUOut;

parameter  ADD=6'b000000, SUB=6'b000001, AND=6'b000010, OR=6'b000011,
           SLT=6'b000100, MUL=6'b000101, HLT=6'b111111,
           LW=6'b001000, SW=6'b001001, ADDI=6'b001010, SUBI=6'b001011,
           SLTI=6'b001100, BNEQZ=6'b001101, BEQZ=6'b001110;

parameter  RR_ALU=3'b000, RM_ALU=3'b001, LOAD=3'b010,
           STORE=3'b011, BRANCH=3'b100, HALT=3'b101;

reg HALTED, TAKEN_BRANCH;

// ─── IF Stage (clk1) ──────────────────────────────────────────────────────────
always @(posedge clk1)
    if (HALTED == 0) begin
        if (((EX_MEM_IR[31:26] == BEQZ)  && (EX_MEM_cond == 1)) ||
            ((EX_MEM_IR[31:26] == BNEQZ) && (EX_MEM_cond == 0))) begin
            IF_ID_NPC <= EX_MEM_NPC + 1;
            IF_ID_IR  <= mem[EX_MEM_NPC];
            PC        <= EX_MEM_NPC + 1;
        end
        else begin
            IF_ID_NPC <= PC + 1;
            IF_ID_IR  <= mem[PC];
            PC        <= PC + 1;
        end
    end

// ─── ID Stage (clk2) ──────────────────────────────────────────────────────────
always @(posedge clk2)
    if (HALTED == 0) begin
        ID_EX_IR  <= IF_ID_IR;
        ID_EX_NPC <= IF_ID_NPC;
        ID_EX_A   <= register[IF_ID_IR[25:21]];
        ID_EX_B   <= register[IF_ID_IR[20:16]];
        ID_EX_Imm <= {{16{IF_ID_IR[15]}}, IF_ID_IR[15:0]};

        $display("IF_ID_IR = %b , register %b", IF_ID_IR[25:21], register[IF_ID_IR[25:21]]);

        case (IF_ID_IR[31:26])
            ADD,SUB,AND,OR,SLT,MUL : ID_EX_type <= RR_ALU;
            ADDI,SUBI,SLTI         : ID_EX_type <= RM_ALU;
            LW                     : ID_EX_type <= LOAD;
            SW                     : ID_EX_type <= STORE;
            BEQZ,BNEQZ             : ID_EX_type <= BRANCH;
            HLT                    : ID_EX_type <= HALT;
            default                : ID_EX_type <= 3'bxxx;
        endcase
    end

// ─── EX Stage (clk1) ──────────────────────────────────────────────────────────
always @(posedge clk1)
    if (HALTED == 0) begin
        EX_MEM_IR   <= ID_EX_IR;
        EX_MEM_type <= ID_EX_type;
        TAKEN_BRANCH <= 0;

        case (ID_EX_type)

            RR_ALU: begin
                case (ID_EX_IR[31:26])
                    ADD : EX_MEM_ALUOut <= ID_EX_A + ID_EX_B;
                    SUB : EX_MEM_ALUOut <= ID_EX_A - ID_EX_B;
                    AND : EX_MEM_ALUOut <= ID_EX_A & ID_EX_B;
                    OR  : EX_MEM_ALUOut <= ID_EX_A | ID_EX_B;
                    SLT : EX_MEM_ALUOut <= ID_EX_A < ID_EX_B;
                    MUL : EX_MEM_ALUOut <= ID_EX_A * ID_EX_B;
                    default : EX_MEM_ALUOut <= 32'hxxxxxxxx;
                endcase
            end

            RM_ALU: begin
                case (ID_EX_IR[31:26])
                    ADDI : EX_MEM_ALUOut <= ID_EX_A + ID_EX_Imm;
                    SUBI : EX_MEM_ALUOut <= ID_EX_A - ID_EX_Imm;
                    SLTI : EX_MEM_ALUOut <= ID_EX_A < ID_EX_Imm;
                    default : EX_MEM_ALUOut <= 32'hxxxxxxxx;
                endcase
            end

            LOAD, STORE: begin
                EX_MEM_ALUOut <= ID_EX_A + ID_EX_Imm;
                EX_MEM_B <= ID_EX_B;
            end

            BRANCH: begin
                EX_MEM_NPC  <= ID_EX_NPC + ID_EX_Imm;
                EX_MEM_cond <= (ID_EX_A == 0);
                if ((ID_EX_IR[31:26] == BEQZ  && ID_EX_A == 0) ||
                    (ID_EX_IR[31:26] == BNEQZ && ID_EX_A != 0))
                    TAKEN_BRANCH <= 1;
            end

        endcase
    end

// ─── MEM Stage (clk2) ─────────────────────────────────────────────────────────
always @(posedge clk2)
    if (HALTED == 0) begin
        MEM_WB_IR   <= EX_MEM_IR;
        MEM_WB_type <= EX_MEM_type;
        case (EX_MEM_type)
            RR_ALU, RM_ALU : MEM_WB_ALUOut <= EX_MEM_ALUOut;
            STORE : if (TAKEN_BRANCH == 0) mem[EX_MEM_ALUOut] <= EX_MEM_B;
            LOAD  : MEM_WB_LMD <= mem[EX_MEM_ALUOut];
        endcase
    end

// ─── WB Stage (clk1) ──────────────────────────────────────────────────────────
always @(posedge clk1)
    if (HALTED == 0) begin
        if (TAKEN_BRANCH == 0)
            case (MEM_WB_type)
                RR_ALU : register[MEM_WB_IR[15:11]] <= MEM_WB_ALUOut;
                RM_ALU : register[MEM_WB_IR[20:16]] <= MEM_WB_ALUOut;
                LOAD   : register[MEM_WB_IR[20:16]] <= MEM_WB_LMD;
                HALT   : HALTED <= 1'b1;
                default: ; 
            endcase
    end

endmodule


// ─── Testbench ────────────────────────────────────────────────────────────────
module testbench();
reg clk1, clk2;
integer k;

processor me (clk1, clk2);

initial begin
    clk1 = 0; clk2 = 0;
    repeat(20) begin
        #5 clk1 = 1; #5 clk1 = 0;
        #5 clk2 = 1; #5 clk2 = 0;
    end
end

initial begin
    for (k = 0; k < 31; k = k + 1)
        me.register[k] = k;
    me.register[0] = 32'h00000000;

    me.mem[0] = 32'h2801000a;   // ADDI R1, R0, 10
    me.mem[1] = 32'h28020014;   // ADDI R2, R0, 20
    me.mem[2] = 32'h28030019;   // ADDI R3, R0, 25
    me.mem[3] = 32'h0ce77800;   // OR   R7, R7, R7  (NOP)
    me.mem[4] = 32'h0ce77800;   // OR   R7, R7, R7  (NOP)
    me.mem[5] = 32'h00222000;   // ADD  R4, R1, R2
    me.mem[6] = 32'h0ce77800;   // OR   R7, R7, R7  (NOP)
    me.mem[7] = 32'h00832800;   // ADD  R5, R4, R3
    me.mem[8] = 32'hfc000000;   // HL

    me.HALTED       = 0;
    me.PC           = 0;
    me.TAKEN_BRANCH = 0;

    #280
    for (k = 0; k < 6; k = k + 1)
        $display("k->%1d   register -> %d", k, me.register[k+1]);
end

initial begin
    $dumpfile("mips.vcd");
    $dumpvars(0, testbench);
    #300 $finish;
end

endmodule
