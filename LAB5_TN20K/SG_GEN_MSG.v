`timescale 1ns / 1ps

// Генератор сообщений (вариант SG)
// Берёт результат от обработчика, вычитывает текст из ПЗУ,
// при необходимости добавляет шестнадцатеричные цифры результата
// и отправляет всё в UART.
module SG_GEN_MSG(
    // System
    input CLK,
    input RST,
    // UART DTP ODPS
    output reg TX_RDY_T,       //выход готовности передачи данных
    output reg [7:0] TX_DATA_T,//выход передаваемых данных
    input TX_RDY_R,            //вход готовности приёма передаваемых данных
    // RES DRP ODPS
    input RES_RDY_T,           //вход готовности передачи результата
    input [68:0] RES_DATA_R,   //вход данных результата | 3 + 7 * 2 + 52 = 69
    output reg RES_RDY_R,      //выход готовности приёма результата
    // HEX -> ASCII
    output reg [3:0] HEX_DATA, //выход шестнадцатеричного числа
    input [7:0] DC_ASCII_DATA, //вход данных ASCII
    // ROM
    output reg [6:0] ADDR,     //адрес ПЗУ (128 байт, L = 7)
    input [7:0] DATA           //данные ПЗУ по адресу ADDR
);

localparam [2:0] C_ADD36 = 3'b010;
localparam [2:0] C_MUL52 = 3'b101;

localparam [2:0] IDLE = 3'd0; //ожидание данных
localparam [2:0] TRES = 3'd1; //инициализация передачи данных результата
localparam [2:0] TMEM = 3'd2; //передача данных памяти
localparam [2:0] TDT  = 3'd3; //передача данных результата
localparam [2:0] TCR  = 3'd4; //передача символа CR
localparam [2:0] TLF  = 3'd5; //передача символа LF

// Результат 52 бита = 13 полубайтов (индексы 0..12, 0 — старший).
// ADD36: сумма 37 бит -> выводятся 10 цифр (полубайты 3..12)
// MUL52: выводятся все 13 цифр (полубайты 0..12)
localparam [3:0] RES_LAST = 4'd12;

reg [2:0] FSM_STATE;
reg [3:0] RES_CT;      //счётчик символов результата
wire [3:0] CT_MX;      //загружаемое значение счётчика RES_CT
reg [6:0] END_ADDR;    //последний адрес обращения к ПЗУ
reg [51:0] RES_DATA;   //данные результата
reg RES_FLG;           //флаг "нужно печатать цифры результата"

// FSM
always @(posedge CLK, posedge RST)
    if (RST) begin
        FSM_STATE <= IDLE;
        TX_RDY_T <= 1'b0;
        TX_DATA_T <= 8'd0;
        RES_RDY_R <= 1'b1;
        RES_CT <= 4'd0;
        RES_DATA <= 52'd0;
        RES_FLG <= 1'b0;
        ADDR <= 7'd0;
        END_ADDR <= 7'd0;
    end
    else
        case (FSM_STATE)
            IDLE: if (RES_RDY_T) begin
                FSM_STATE <= TRES;
                RES_RDY_R <= 1'b0;
                ADDR <= RES_DATA_R[65:59];
                END_ADDR <= RES_DATA_R[58:52];
                RES_DATA <= RES_DATA_R[51:0];
                RES_FLG <= (RES_DATA_R[68:66] == C_ADD36) | (RES_DATA_R[68:66] == C_MUL52);
                RES_CT <= CT_MX;
            end
            TRES: begin
                // Первый символ берём из ПЗУ "как есть"
                FSM_STATE <= TMEM;
                TX_RDY_T <= 1'b1;
                TX_DATA_T <= DATA;
                ADDR <= ADDR + 1'b1;
            end
            TMEM: if (TX_RDY_R) begin
                if (ADDR == END_ADDR + 1'b1) begin
                    // Сообщение кончилось — что дальше?
                    if (RES_FLG) begin
                        // Нужно вывести цифры результата
                        FSM_STATE <= TDT;
                        RES_FLG <= 1'b0;
                        TX_DATA_T <= DC_ASCII_DATA;
                        RES_CT <= RES_CT + 1'b1;
                    end
                    else begin
                        // Иначе сразу CR
                        FSM_STATE <= TCR;
                        TX_DATA_T <= 8'h0D;
                    end
                end
                else begin
                    TX_DATA_T <= DATA;
                    ADDR <= ADDR + 1'b1;
                end
            end
            TDT: if (TX_RDY_R) begin
                if (RES_CT == RES_LAST + 1'b1) begin
                    FSM_STATE <= TCR;
                    TX_DATA_T <= 8'h0D;
                end
                else begin
                    TX_DATA_T <= DC_ASCII_DATA;
                    RES_CT <= RES_CT + 1'b1;
                end
            end
            TCR: if (TX_RDY_R) begin
                FSM_STATE <= TLF;
                TX_DATA_T <= 8'h0A;
            end
            TLF: if (TX_RDY_R) begin
                FSM_STATE <= IDLE;
                TX_RDY_T <= 1'b0;
                RES_RDY_R <= 1'b1;
            end
            default: begin
                FSM_STATE <= IDLE;
                TX_RDY_T <= 1'b0;
                TX_DATA_T <= 8'd0;
                RES_RDY_R <= 1'b1;
                RES_CT <= 4'd0;
                RES_DATA <= 52'd0;
                RES_FLG <= 1'b0;
                ADDR <= 7'd0;
                END_ADDR <= 7'd0;
            end
        endcase

// CT_MX — номер первого выводимого полубайта результата
assign CT_MX = (RES_DATA_R[68:66] == C_ADD36) ? 4'd3 : 4'd0;

// HEX_DATA — выбор текущего полубайта результата (0 — старший)
always @* begin
    case (RES_CT)
        4'd0:  HEX_DATA = RES_DATA[51:48];
        4'd1:  HEX_DATA = RES_DATA[47:44];
        4'd2:  HEX_DATA = RES_DATA[43:40];
        4'd3:  HEX_DATA = RES_DATA[39:36];
        4'd4:  HEX_DATA = RES_DATA[35:32];
        4'd5:  HEX_DATA = RES_DATA[31:28];
        4'd6:  HEX_DATA = RES_DATA[27:24];
        4'd7:  HEX_DATA = RES_DATA[23:20];
        4'd8:  HEX_DATA = RES_DATA[19:16];
        4'd9:  HEX_DATA = RES_DATA[15:12];
        4'd10: HEX_DATA = RES_DATA[11:8];
        4'd11: HEX_DATA = RES_DATA[7:4];
        4'd12: HEX_DATA = RES_DATA[3:0];
        default: HEX_DATA = 4'h0;
    endcase
end

endmodule
