`timescale 1ns / 1ps

// Верхний уровень ЛР5 (вариант SG)
// Собирает вместе: UART, анализатор команд, обработчик, системную шину,
// контроллер светодиодов, RAM, ПЗУ сообщений, генератор сообщений.
module SG_LAB5_TOP #(
    parameter CLK_FREQ = 100_000_000 //частота CLK, Гц
)(
    // System
    input CLK,
    input SYS_NRST,        //сброс, активен в "0"
    // UART
    input UART_RXD,        //линия приёма
    output UART_TXD,       //линия передачи
    // LEDs
    output [7:0] LED
);

wire RST;
reg [1:0] RST_S;
wire CE_1kHz; //тик 1 кГц (сейчас нигде не используется)

// UART <-> ANALYZER (ODPS)
wire RX_DATA_EN;
wire [9:0] RX_DATA_T;
wire [7:0] RX_DATA;

// ANALYZER <-> ASCII_TO_HEX
wire HEX_FLG;
wire [3:0] DC_ASCII_HEX;

// ANALYZER <-> HANDLER (ODPS)
wire CMD_RDY_T;
wire [106:0] CMD_DATA_T;
wire CMD_RDY_R;

// HANDLER <-> GEN_MSG (ODPS)
wire RES_RDY_T;
wire [68:0] RES_DATA_T;
wire RES_RDY_R;

// HANDLER <-> SYSTEM BUS (STI 1.0)
wire T_S_EX_REQ;
wire [11:0] T_S_ADDR;
wire [2:0] T_S_CMD;
wire [7:0] T_S_D_WR;
wire T_S_EX_ACK;
wire [7:0] T_S_D_RD;

// SYSTEM BUS <-> CNTR_LEDS (STI 1.0)
wire I0_S_EX_REQ;
wire I0_S_ADDR;
wire [2:0] I0_S_CMD;
wire [7:0] I0_S_D_WR;
wire I0_S_EX_ACK;
wire [7:0] I0_S_D_RD;

// SYSTEM BUS <-> RAM (STI 1.0)
wire I1_S_EX_REQ;
wire [5:0] I1_S_ADDR;
wire [2:0] I1_S_CMD;
wire [7:0] I1_S_D_WR;
wire I1_S_EX_ACK;
wire [7:0] I1_S_D_RD;

// CNTR_LEDS <-> RAM (прямой порт чтения)
wire [5:0] CNTR_RAM_ADDR;
wire [7:0] CNTR_RAM_DATA;

// GEN_MSG <-> ROM
wire [6:0] ROM_ADDR;
wire [7:0] ROM_DATA;

// GEN_MSG <-> HEX_TO_ASCII
wire [3:0] HEX_DATA;
wire [7:0] DC_ASCII_DATA;

// GEN_MSG <-> UART (ODPS)
wire TX_RDY_T;
wire [7:0] TX_DATA_T;
wire TX_RDY_R;

// Синхронизатор сброса: асинхронный сброс -> два такта синхронного
always @(posedge CLK, negedge SYS_NRST) begin
    if (!SYS_NRST)
        RST_S <= 2'b11;
    else
        RST_S <= {RST_S[0], 1'b0};
end
assign RST = RST_S[1];

// Делитель частоты (1 кГц)
SG_DIVIDER #(.MOD(CLK_FREQ / 1000)) DIV_1kHz (
    .clk_in(CLK),
    .reset(RST),
    .clk_out(CE_1kHz)
);

// Контроллер UART
SG_UART #(.CLK_FREQ(CLK_FREQ), .BAUD(38400)) UART (
    .CLK(CLK),
    .RST(RST),
    .RXD(UART_RXD),
    .TXD(UART_TXD),
    .RX_DATA_EN(RX_DATA_EN),
    .RX_DATA_T(RX_DATA_T),
    .TX_RDY_T(TX_RDY_T),
    .TX_DATA_R(TX_DATA_T),
    .TX_RDY_R(TX_RDY_R)
);

// Байт с ошибкой чётности или кадра заменяется на 00h —
// анализатор на такой байт выдаст "Error command!!!"
assign RX_DATA = (|RX_DATA_T[9:8]) ? 8'h00 : RX_DATA_T[7:0];

// Анализатор команд
SG_ANALYZER ANALYZER (
    .CLK(CLK),
    .RST(RST),
    .RX_DATA_EN(RX_DATA_EN),
    .RX_DATA_R(RX_DATA),
    .ASCII_DATA(),
    .HEX_FLG(HEX_FLG),
    .DC_ASCII_HEX(DC_ASCII_HEX),
    .CMD_RDY_T(CMD_RDY_T),
    .CMD_DATA_T(CMD_DATA_T),
    .CMD_RDY_R(CMD_RDY_R)
);

// ASCII -> HEX (для входных символов)
SG_DC_ASCII_HEX ASCII_TO_HEX (
    .ASCII(RX_DATA),
    .HEX(DC_ASCII_HEX),
    .HEX_FLG(HEX_FLG)
);

// HEX -> ASCII (для вывода результата)
SG_DC_HEX_ASCII HEX_TO_ASCII (
    .HEX(HEX_DATA),
    .ASCII(DC_ASCII_DATA)
);

// ПЗУ сообщений
SG_ROM ROM (
    .ADDR(ROM_ADDR),
    .DATA(ROM_DATA)
);

// Генератор сообщений
SG_GEN_MSG GEN_MSG (
    .CLK(CLK),
    .RST(RST),
    .TX_RDY_T(TX_RDY_T),
    .TX_DATA_T(TX_DATA_T),
    .TX_RDY_R(TX_RDY_R),
    .RES_RDY_T(RES_RDY_T),
    .RES_DATA_R(RES_DATA_T),
    .RES_RDY_R(RES_RDY_R),
    .HEX_DATA(HEX_DATA),
    .DC_ASCII_DATA(DC_ASCII_DATA),
    .ADDR(ROM_ADDR),
    .DATA(ROM_DATA)
);

// Обработчик команд
SG_HANDLER_CMD HANDLER (
    .CLK(CLK),
    .RST(RST),
    .CMD_RDY_T(CMD_RDY_T),
    .CMD_DATA_R(CMD_DATA_T),
    .CMD_RDY_R(CMD_RDY_R),
    .S_EX_REQ(T_S_EX_REQ),
    .S_ADDR(T_S_ADDR),
    .S_CMD(T_S_CMD),
    .S_D_WR(T_S_D_WR),
    .S_EX_ACK(T_S_EX_ACK),
    .S_D_RD(T_S_D_RD),
    .RES_RDY_T(RES_RDY_T),
    .RES_DATA_T(RES_DATA_T),
    .RES_RDY_R(RES_RDY_R)
);

// Контроллер светодиодов
SG_CNTR_LEDS CNTR_LEDS (
    .CLK(CLK),
    .RST(RST),
    .S_EX_REQ(I0_S_EX_REQ),
    .S_ADDR(I0_S_ADDR),
    .S_CMD(I0_S_CMD),
    .S_D_WR(I0_S_D_WR),
    .S_EX_ACK(I0_S_EX_ACK),
    .S_D_RD(I0_S_D_RD),
    .LED(LED),
    .ADDR(CNTR_RAM_ADDR),
    .DATA(CNTR_RAM_DATA)
);

// RAM (64 слова x 8 бит)
SG_RAM #(.AW(6)) RAM (
    .CLK(CLK),
    .S_EX_REQ(I1_S_EX_REQ),
    .S_ADDR(I1_S_ADDR),
    .S_CMD(I1_S_CMD),
    .S_D_WR(I1_S_D_WR),
    .S_EX_ACK(I1_S_EX_ACK),
    .S_D_RD(I1_S_D_RD),
    .ADDR(CNTR_RAM_ADDR),
    .DATA(CNTR_RAM_DATA)
);

// Системная шина STI 1.0
SG_INFS_8B SYSTEM_BUS (
    // Обработчик команд
    .T_S_EX_REQ(T_S_EX_REQ),
    .T_S_ADDR(T_S_ADDR),
    .T_S_CMD(T_S_CMD),
    .T_S_D_WR(T_S_D_WR),
    .T_S_EX_ACK(T_S_EX_ACK),
    .T_S_D_RD(T_S_D_RD),
    // Контроллер светодиодов
    .I0_S_EX_REQ(I0_S_EX_REQ),
    .I0_S_ADDR(I0_S_ADDR),
    .I0_S_CMD(I0_S_CMD),
    .I0_S_D_WR(I0_S_D_WR),
    .I0_S_EX_ACK(I0_S_EX_ACK),
    .I0_S_D_RD(I0_S_D_RD),
    // RAM
    .I1_S_EX_REQ(I1_S_EX_REQ),
    .I1_S_ADDR(I1_S_ADDR),
    .I1_S_CMD(I1_S_CMD),
    .I1_S_D_WR(I1_S_D_WR),
    .I1_S_EX_ACK(I1_S_EX_ACK),
    .I1_S_D_RD(I1_S_D_RD)
);

endmodule
