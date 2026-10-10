`timescale 1ns / 1ps

// Обработчик команд (вариант SG)
// Принимает разобранную команду, выполняет арифметику / обращение к шине
// и формирует результат для генератора сообщений.
module SG_HANDLER_CMD(
    // System
    input CLK,
    input RST,
    // DRP ODPS (приём команды от анализатора)
    input CMD_RDY_T,          //вход готовности передачи данных
    input [106:0] CMD_DATA_R, //вход принимаемых данных команды | N = 107
    output reg CMD_RDY_R,     //выход готовности приёма команды
    // STI 1.0 (инициатор системной шины)
    output reg S_EX_REQ,      //выход запроса инициатора
    output reg [11:0] S_ADDR, //выход адреса инициатора | разрядность шины адреса = 12
    output reg [2:0] S_CMD,   //выход команды инициатора
    output reg [7:0] S_D_WR,  //выход данных для записи инициатора
    input S_EX_ACK,           //вход подтверждения инициатора
    input [7:0] S_D_RD,       //вход данных чтения инициатора
    // DTP ODPS (передача результата в генератор сообщений)
    output reg RES_RDY_T,     //выход готовности передачи результата
    output [68:0] RES_DATA_T, //выход данных результата | 3 + 7 * 2 + 52 = 69
    input RES_RDY_R           //вход готовности приёма результата
);

// Формат CMD_DATA_R:
//   [106:104] - код команды
//   ADD36 : [71:36] - OPR1, [35:0]  - OPR2
//   MUL52 : [103:52] - OPR1, [51:0] - OPR2
//   x12_8 : [19:8]  - ADDR, [7:0]   - OPR
// Формат RES_DATA_T:
//   [68:66] RES_TYPE | [65:59] START_ADDR | [58:52] END_ADDR | [51:0] RES_DATA

localparam [2:0] C_ADD36 = 3'b010;
localparam [2:0] C_MUL52 = 3'b101;
localparam [2:0] C_WR    = 3'b001;
localparam [2:0] C_ON    = 3'b111;
localparam [2:0] C_OFF   = 3'b100;
localparam [2:0] C_LED   = 3'b110;
localparam [2:0] C_ERR   = 3'b011;

localparam [2:0] WDATA = 3'd0; //ожидание данных
localparam [2:0] ALZ   = 3'd1; //анализ команды
localparam [2:0] WR    = 3'd2; //запись в адресное пространство
localparam [2:0] IORD  = 3'd3; //чтение пространства ввода-вывода
localparam [2:0] IOWR  = 3'd4; //запись в пространство ввода-вывода
localparam [2:0] TRANS = 3'd5; //передача результата
localparam [2:0] MUL   = 3'd6; //последовательное умножение 52x52

reg [2:0] FSM_STATE;  //состояние автомата
reg [106:0] CMD_DATA; //сохранённые данные команды
reg [51:0] RES_DATA;  //регистр результата (52 бита)
reg [6:0] START_ADDR; //адрес первого символа сообщения в ПЗУ
reg [6:0] END_ADDR;   //адрес последнего символа сообщения в ПЗУ

// Умножитель "сдвиг-сложение": 52 такта, младшие 52 бита произведения.
// Однотактный умножитель 52x52 не укладывается в период 10 нс.
reg [51:0] MUL_A; //множимое (сдвигается влево)
reg [51:0] MUL_B; //множитель (сдвигается вправо)
reg [5:0] MUL_CT; //счётчик тактов умножения

wire [2:0] CMD_TYPE = CMD_DATA[106:104];

// FSM
always @(posedge CLK, posedge RST)
    if (RST) begin
        FSM_STATE <= WDATA;
        CMD_DATA <= 107'd0;
        CMD_RDY_R <= 1'b1;
        RES_RDY_T <= 1'b0;
        RES_DATA <= 52'd0;
        S_EX_REQ <= 1'b0;
        S_ADDR <= 12'd0;
        S_CMD <= 3'b000;
        S_D_WR <= 8'd0;
        MUL_A <= 52'd0;
        MUL_B <= 52'd0;
        MUL_CT <= 6'd0;
    end
    else
        case (FSM_STATE)
            WDATA: if (CMD_RDY_T) begin
                FSM_STATE <= ALZ;
                CMD_DATA <= CMD_DATA_R;
                CMD_RDY_R <= 1'b0;
            end
            ALZ:
                case (CMD_TYPE)
                    C_ADD36: begin //сложение 36 + 36 -> 37 бит
                        FSM_STATE <= TRANS;
                        RES_DATA <= {15'd0, ({1'b0, CMD_DATA[71:36]} + {1'b0, CMD_DATA[35:0]})};
                        RES_RDY_T <= 1'b1;
                    end
                    C_MUL52: begin //умножение 52 x 52 -> младшие 52 бита
                        FSM_STATE <= MUL;
                        RES_DATA <= 52'd0;
                        MUL_A <= CMD_DATA[103:52];
                        MUL_B <= CMD_DATA[51:0];
                        MUL_CT <= 6'd52;
                    end
                    C_WR: begin //WR12_8 — запись в пространство памяти
                        FSM_STATE <= WR;
                        S_EX_REQ <= 1'b1;
                        S_ADDR <= CMD_DATA[19:8];
                        S_CMD <= 3'b001;
                        S_D_WR <= CMD_DATA[7:0];
                    end
                    C_LED: begin //LED12_8 — запись в пространство ввода-вывода
                        FSM_STATE <= WR;
                        S_EX_REQ <= 1'b1;
                        S_ADDR <= CMD_DATA[19:8];
                        S_CMD <= 3'b000;
                        S_D_WR <= CMD_DATA[7:0];
                    end
                    C_ON, C_OFF: begin //ON12_8 / OFF12_8 — чтение-модификация-запись
                        FSM_STATE <= IORD;
                        S_EX_REQ <= 1'b1;
                        S_ADDR <= CMD_DATA[19:8];
                        S_CMD <= 3'b100;
                    end
                    default: begin //ошибка формата команды
                        FSM_STATE <= TRANS;
                        RES_RDY_T <= 1'b1;
                    end
                endcase
            MUL: begin
                if (MUL_B[0]) RES_DATA <= RES_DATA + MUL_A;
                MUL_A <= {MUL_A[50:0], 1'b0};
                MUL_B <= {1'b0, MUL_B[51:1]};
                MUL_CT <= MUL_CT - 1'b1;
                if (MUL_CT == 6'd1) begin
                    FSM_STATE <= TRANS;
                    RES_RDY_T <= 1'b1;
                end
            end
            IORD: if (S_EX_ACK) begin
                FSM_STATE <= IOWR;
                S_CMD <= 3'b000;
                if (CMD_TYPE == C_ON) S_D_WR <= S_D_RD | CMD_DATA[7:0]; //установка маски
                else S_D_WR <= S_D_RD & (~CMD_DATA[7:0]);               //сброс маски
            end
            IOWR: if (S_EX_ACK) begin
                FSM_STATE <= TRANS;
                S_EX_REQ <= 1'b0;
                RES_RDY_T <= 1'b1;
            end
            WR: if (S_EX_ACK) begin
                FSM_STATE <= TRANS;
                S_EX_REQ <= 1'b0;
                RES_RDY_T <= 1'b1;
            end
            TRANS: if (RES_RDY_R) begin
                FSM_STATE <= WDATA;
                RES_RDY_T <= 1'b0;
                CMD_RDY_R <= 1'b1;
            end
            default: begin
                FSM_STATE <= WDATA;
                CMD_DATA <= 107'd0;
                CMD_RDY_R <= 1'b1;
                RES_RDY_T <= 1'b0;
                RES_DATA <= 52'd0;
                S_EX_REQ <= 1'b0;
                S_ADDR <= 12'd0;
                S_CMD <= 3'b000;
                S_D_WR <= 8'd0;
                MUL_A <= 52'd0;
                MUL_B <= 52'd0;
                MUL_CT <= 6'd0;
            end
        endcase

  // Начальный и последний адрес сообщения в ПЗУ (см. mem.mem (Для tang nano 20k см. SG_ROM.v ))
always @* begin
    case (CMD_TYPE)
        C_ADD36: begin START_ADDR = 7'd0;  END_ADDR = 7'd13;  end //"Result ADD36: "
        C_MUL52: begin START_ADDR = 7'd14; END_ADDR = 7'd27;  end //"Result MUL52: "
        C_WR:    begin START_ADDR = 7'd28; END_ADDR = 7'd41;  end //"Success WR12_8"
        C_ON:    begin START_ADDR = 7'd42; END_ADDR = 7'd55;  end //"Success ON12_8"
        C_OFF:   begin START_ADDR = 7'd56; END_ADDR = 7'd70;  end //"Success OFF12_8"
        C_LED:   begin START_ADDR = 7'd71; END_ADDR = 7'd85;  end //"Success LED12_8"
        default: begin START_ADDR = 7'd86; END_ADDR = 7'd101; end //"Error command!!!"
    endcase
end

// Формирование RES_DATA_T (неиспользуемый код 000 передаётся как ошибка)
wire [2:0] RES_TYPE = (CMD_TYPE == 3'b000) ? C_ERR : CMD_TYPE;
assign RES_DATA_T = {RES_TYPE, START_ADDR, END_ADDR, RES_DATA};

endmodule
