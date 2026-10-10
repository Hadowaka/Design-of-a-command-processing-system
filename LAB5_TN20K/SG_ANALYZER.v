`timescale 1ns / 1ps

// Анализатор команд (вариант SG)
// Команды: ADD36, MUL52, WR12_8, ON12_8, OFF12_8, LED12_8
module SG_ANALYZER(
    // System
    input CLK,
    input RST,
    // UART Data
    input RX_DATA_EN,        //вход готовности передачи данных
    input [7:0] RX_DATA_R,   //вход принимаемых данных
    // ASCII -> HEX
    output [7:0] ASCII_DATA, //выход данных ASCII
    input HEX_FLG,           //вход флага шестнадцатеричного числа
    input [3:0] DC_ASCII_HEX,//вход шестнадцатеричного числа
    // DTP Port
    output reg CMD_RDY_T,       //выход готовности передачи команды
    output reg [106:0] CMD_DATA_T, //выход передаваемых данных команды | N = 107
    input CMD_RDY_R             //вход готовности приёма команды
);
// Разрядность данных команды K:
//   ADD36   : 36 + 36 = 72
//   MUL52   : 52 + 52 = 104  <- максимум
//   x12_8   : 12 + 8  = 20
// K = 104, N = K + 3 = 107
// CMD_DATA_T[106:104] — CMD_TYPE, CMD_DATA_T[103:0] — DATA

// Коды команд
localparam [2:0] C_ADD36 = 3'b010;
localparam [2:0] C_MUL52 = 3'b101;
localparam [2:0] C_WR    = 3'b001;
localparam [2:0] C_ON    = 3'b111;
localparam [2:0] C_OFF   = 3'b100;
localparam [2:0] C_LED   = 3'b110;
localparam [2:0] C_ERR   = 3'b011;

// Состояния автомата
localparam [4:0] IDLE      = 5'd0;  //ожидание данных
localparam [4:0] SROPR     = 5'd1;  //начало приёма аргумента команды
localparam [4:0] ROPR      = 5'd2;  //приём аргумента команды
localparam [4:0] EROPR     = 5'd3;  //конец приёма аргумента команды
localparam [4:0] ERCMD     = 5'd4;  //конец приёма команды
localparam [4:0] TRANS     = 5'd5;  //передача команды или ошибки

// ADD36
localparam [4:0] A_ST      = 5'd6;  //A
localparam [4:0] D1_ST     = 5'd7;  //D (aDd)
localparam [4:0] D2_ST     = 5'd8;  //D (adD)
localparam [4:0] N3_ST     = 5'd9;  //3
localparam [4:0] N6_ST     = 5'd10; //6

// MUL52
localparam [4:0] M_ST      = 5'd11; //M
localparam [4:0] U_ST      = 5'd12; //U
localparam [4:0] L1_ST     = 5'd13; //L (muL)
localparam [4:0] N5_ST     = 5'd14; //5
localparam [4:0] N2_1_ST   = 5'd15; //2 (MUL52)

// WR12_8
localparam [4:0] W_ST      = 5'd16; //W
localparam [4:0] R_ST      = 5'd17; //R

// ON12_8, OFF12_8
localparam [4:0] O_ST      = 5'd18; //O
localparam [4:0] N_ST      = 5'd19; //N
localparam [4:0] F1_ST     = 5'd20; //F (oFf)
localparam [4:0] F2_ST     = 5'd21; //F (ofF)

// LED12_8
localparam [4:0] L2_ST     = 5'd22; //L (Led)
localparam [4:0] E_ST      = 5'd23; //E
localparam [4:0] D3_ST     = 5'd24; //D (leD)

// общий суффикс 12_8
localparam [4:0] N1_ST     = 5'd25; //1
localparam [4:0] N2_2_ST   = 5'd26; //2 (x12_8)
localparam [4:0] UNDL_ST   = 5'd27; //_
localparam [4:0] N8_ST     = 5'd28; //8

reg [4:0] FSM_STATE; //состояние автомата
reg [3:0] DATA_CT;   //счётчик полубайтов операнда (до 13 -> 4 бита)
reg [3:0] END_CT;    //количество полубайтов в текущем операнде
reg OPR2_FLG;        //флаг второго операнда
reg [1:0] X12_8_FLG; //какая команда оканчивается на 12_8: 00-WR, 01-ON, 10-OFF, 11-LED

// Флаги распознаваемых символов
wire A_FLG, D_FLG, M_FLG, U_FLG, L_FLG, W_FLG, R_FLG, O_FLG, N_FLG, F_FLG, E_FLG;
wire NUM1_FLG, NUM2_FLG, NUM3_FLG, NUM5_FLG, NUM6_FLG, NUM8_FLG;
wire UNDERLINE_FLG, SPACE_FLG, CR_FLG, LF_FLG;

// Переход в TRANS с кодом ошибки
`define SG_ERROR begin FSM_STATE <= TRANS; CMD_RDY_T <= 1'b1; CMD_DATA_T[106:104] <= C_ERR; end

// FSM
always @(posedge CLK, posedge RST)
    if (RST) begin
        FSM_STATE <= IDLE;
        CMD_RDY_T <= 1'b0;
        CMD_DATA_T <= 107'd0;
        DATA_CT <= 4'd0;
        END_CT <= 4'd0;
        OPR2_FLG <= 1'b0;
        X12_8_FLG <= 2'b00;
    end
    else begin
        case (FSM_STATE)
            // IDLE — ожидание первого символа команды
            IDLE: if (RX_DATA_EN) begin
                if (A_FLG) FSM_STATE <= A_ST;
                else if (M_FLG) FSM_STATE <= M_ST;
                else if (W_FLG) FSM_STATE <= W_ST;
                else if (O_FLG) FSM_STATE <= O_ST;
                else if (L_FLG) FSM_STATE <= L2_ST;
                else `SG_ERROR
            end

            // ---------- ADD36 ----------
            A_ST:  if (RX_DATA_EN) begin if (D_FLG) FSM_STATE <= D1_ST; else `SG_ERROR end
            D1_ST: if (RX_DATA_EN) begin if (D_FLG) FSM_STATE <= D2_ST; else `SG_ERROR end
            D2_ST: if (RX_DATA_EN) begin if (NUM3_FLG) FSM_STATE <= N3_ST; else `SG_ERROR end
            N3_ST: if (RX_DATA_EN) begin if (NUM6_FLG) FSM_STATE <= N6_ST; else `SG_ERROR end
            N6_ST: if (RX_DATA_EN) begin
                if (SPACE_FLG) begin
                    FSM_STATE <= SROPR;
                    CMD_DATA_T[106:104] <= C_ADD36;
                end
                else `SG_ERROR
            end

            // ---------- MUL52 ----------
            M_ST:  if (RX_DATA_EN) begin if (U_FLG) FSM_STATE <= U_ST; else `SG_ERROR end
            U_ST:  if (RX_DATA_EN) begin if (L_FLG) FSM_STATE <= L1_ST; else `SG_ERROR end
            L1_ST: if (RX_DATA_EN) begin if (NUM5_FLG) FSM_STATE <= N5_ST; else `SG_ERROR end
            N5_ST: if (RX_DATA_EN) begin if (NUM2_FLG) FSM_STATE <= N2_1_ST; else `SG_ERROR end
            N2_1_ST: if (RX_DATA_EN) begin
                if (SPACE_FLG) begin
                    FSM_STATE <= SROPR;
                    CMD_DATA_T[106:104] <= C_MUL52;
                end
                else `SG_ERROR
            end

            // ---------- WR12_8 ----------
            W_ST: if (RX_DATA_EN) begin if (R_FLG) FSM_STATE <= R_ST; else `SG_ERROR end
            R_ST: if (RX_DATA_EN) begin
                if (NUM1_FLG) begin FSM_STATE <= N1_ST; X12_8_FLG <= 2'b00; end
                else `SG_ERROR
            end

            // ---------- ON12_8 / OFF12_8 ----------
            O_ST: if (RX_DATA_EN) begin
                if (N_FLG) FSM_STATE <= N_ST;
                else if (F_FLG) FSM_STATE <= F1_ST;
                else `SG_ERROR
            end
            N_ST: if (RX_DATA_EN) begin
                if (NUM1_FLG) begin FSM_STATE <= N1_ST; X12_8_FLG <= 2'b01; end
                else `SG_ERROR
            end
            F1_ST: if (RX_DATA_EN) begin if (F_FLG) FSM_STATE <= F2_ST; else `SG_ERROR end
            F2_ST: if (RX_DATA_EN) begin
                if (NUM1_FLG) begin FSM_STATE <= N1_ST; X12_8_FLG <= 2'b10; end
                else `SG_ERROR
            end

            // ---------- LED12_8 ----------
            L2_ST: if (RX_DATA_EN) begin if (E_FLG) FSM_STATE <= E_ST; else `SG_ERROR end
            E_ST:  if (RX_DATA_EN) begin if (D_FLG) FSM_STATE <= D3_ST; else `SG_ERROR end
            D3_ST: if (RX_DATA_EN) begin
                if (NUM1_FLG) begin FSM_STATE <= N1_ST; X12_8_FLG <= 2'b11; end
                else `SG_ERROR
            end

            // ---------- общий суффикс 12_8 ----------
            N1_ST:   if (RX_DATA_EN) begin if (NUM2_FLG) FSM_STATE <= N2_2_ST; else `SG_ERROR end
            N2_2_ST: if (RX_DATA_EN) begin if (UNDERLINE_FLG) FSM_STATE <= UNDL_ST; else `SG_ERROR end
            UNDL_ST: if (RX_DATA_EN) begin if (NUM8_FLG) FSM_STATE <= N8_ST; else `SG_ERROR end
            N8_ST: if (RX_DATA_EN) begin
                if (SPACE_FLG) begin
                    FSM_STATE <= SROPR;
                    case (X12_8_FLG)
                        2'b00:   CMD_DATA_T[106:104] <= C_WR;  //WR12_8
                        2'b01:   CMD_DATA_T[106:104] <= C_ON;  //ON12_8
                        2'b10:   CMD_DATA_T[106:104] <= C_OFF; //OFF12_8
                        default: CMD_DATA_T[106:104] <= C_LED; //LED12_8
                    endcase
                end
                else `SG_ERROR
            end

            // SROPR — начало приёма аргумента (первая hex-цифра)
            SROPR: if (RX_DATA_EN) begin
                if (HEX_FLG) begin
                    FSM_STATE <= ROPR;
                    CMD_DATA_T[103:0] <= {CMD_DATA_T[99:0], DC_ASCII_HEX};
                    DATA_CT <= DATA_CT + 1'b1;
                end
                else `SG_ERROR
            end

            // ROPR — приём аргумента команды
            ROPR: if (RX_DATA_EN) begin
                if (HEX_FLG) begin
                    CMD_DATA_T[103:0] <= {CMD_DATA_T[99:0], DC_ASCII_HEX};
                    if (DATA_CT == END_CT - 1'b1) begin
                        FSM_STATE <= EROPR;
                        DATA_CT <= 4'd0;
                    end
                    else DATA_CT <= DATA_CT + 1'b1;
                end
                else `SG_ERROR
            end

            // EROPR — конец приёма аргумента
            EROPR: if (RX_DATA_EN) begin
                if (~OPR2_FLG & SPACE_FLG) begin
                    FSM_STATE <= SROPR; //переходим ко второму операнду
                    OPR2_FLG <= 1'b1;
                end
                else if (OPR2_FLG & CR_FLG) FSM_STATE <= ERCMD;
                else `SG_ERROR
            end

            // ERCMD — конец приёма команды (ждём LF)
            ERCMD: if (RX_DATA_EN) begin
                FSM_STATE <= TRANS;
                CMD_RDY_T <= 1'b1;
                if (~LF_FLG) CMD_DATA_T[106:104] <= C_ERR;
            end

            // TRANS — передача команды или ошибки
            TRANS: if (CMD_RDY_R) begin
                FSM_STATE <= IDLE;
                CMD_RDY_T <= 1'b0;
                OPR2_FLG <= 1'b0;
                X12_8_FLG <= 2'b00;
                DATA_CT <= 4'd0;
            end

            default: begin
                FSM_STATE <= IDLE;
                CMD_RDY_T <= 1'b0;
                CMD_DATA_T <= 107'd0;
                DATA_CT <= 4'd0;
                END_CT <= 4'd0;
                OPR2_FLG <= 1'b0;
                X12_8_FLG <= 2'b00;
            end
        endcase

        // END_CT — сколько hex-символов в текущем операнде
        case (OPR2_FLG)
            1'b0: // первый операнд
                case (CMD_DATA_T[106:104])
                    C_ADD36: END_CT <= 4'd9;  //36 бит
                    C_MUL52: END_CT <= 4'd13; //52 бита
                    C_WR, C_ON, C_OFF, C_LED:
                             END_CT <= 4'd3;  //адрес 12 бит
                    default: END_CT <= 4'd0;  //ошибка
                endcase
            1'b1: // второй операнд
                case (CMD_DATA_T[106:104])
                    C_ADD36: END_CT <= 4'd9;  //36 бит
                    C_MUL52: END_CT <= 4'd13; //52 бита
                    C_WR, C_ON, C_OFF, C_LED:
                             END_CT <= 4'd2;  //данные 8 бит
                    default: END_CT <= 4'd0;  //ошибка
                endcase
        endcase
    end

`undef SG_ERROR

// Флаги распознаваемых символов
assign A_FLG = RX_DATA_R == 8'h41; //A
assign D_FLG = RX_DATA_R == 8'h44; //D
assign M_FLG = RX_DATA_R == 8'h4D; //M
assign U_FLG = RX_DATA_R == 8'h55; //U
assign L_FLG = RX_DATA_R == 8'h4C; //L
assign W_FLG = RX_DATA_R == 8'h57; //W
assign R_FLG = RX_DATA_R == 8'h52; //R
assign O_FLG = RX_DATA_R == 8'h4F; //O
assign N_FLG = RX_DATA_R == 8'h4E; //N
assign F_FLG = RX_DATA_R == 8'h46; //F
assign E_FLG = RX_DATA_R == 8'h45; //E
assign NUM1_FLG = RX_DATA_R == 8'h31; //1
assign NUM2_FLG = RX_DATA_R == 8'h32; //2
assign NUM3_FLG = RX_DATA_R == 8'h33; //3
assign NUM5_FLG = RX_DATA_R == 8'h35; //5
assign NUM6_FLG = RX_DATA_R == 8'h36; //6
assign NUM8_FLG = RX_DATA_R == 8'h38; //8
assign UNDERLINE_FLG = RX_DATA_R == 8'h5F; //_
assign SPACE_FLG = RX_DATA_R == 8'h20; //пробел
assign CR_FLG = RX_DATA_R == 8'h0D; //CR
assign LF_FLG = RX_DATA_R == 8'h0A; //LF

assign ASCII_DATA = RX_DATA_R;

endmodule
