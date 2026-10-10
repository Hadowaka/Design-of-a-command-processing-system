`timescale 1ns / 1ps

// Контроллер UART (вариант SG)
// Синхронизатор: 2 триггера | Скорость: 38400 бод | Чётность: Odd
// Стоповых битов: 2 | RATIO: 8 (выборок на бит)
module SG_UART #(
    parameter CLK_FREQ = 100_000_000, //частота CLK, Гц (Nexys A7 — 100 МГц, Tang Nano 20K — 27 МГц)
    parameter BAUD = 38400            //скорость передачи, бод
)(
    // System
    input CLK,        //вход синхронизации
    input RST,        //вход асинхронного сброса
    // UART
    input RXD,        //линия приёма данных
    output reg TXD,   //линия передачи данных
    // DTP (приём)
    output reg RX_DATA_EN,   //выход готовности принятых данных
    output reg [9:0] RX_DATA_T, //[9] — ошибка кадра, [8] — ошибка чётности, [7:0] — данные
    // DRP (передача)
    input TX_RDY_T,          //вход готовности передачи данных
    input [7:0] TX_DATA_R,   //вход передаваемых данных
    output reg TX_RDY_R      //выход готовности приёма данных на передачу
);

// Генератор сигнала разрешения UART_CE (частота = BAUD * 8)
// UART_DIV = CLK_FREQ / (BAUD * 8) с округлением:
//   100 МГц: 100 000 000 / 38 400 / 8 = 325,52 -> 326 (38 344 бод, -0,15 %)
//    27 МГц:  27 000 000 / 38 400 / 8 =  87,89 ->  88 (38 352 бод, -0,13 %)
localparam integer UART_DIV = (CLK_FREQ + BAUD * 4) / (BAUD * 8);
localparam integer CT_W = $clog2(UART_DIV); //разрядность счётчика делителя

reg [CT_W-1:0] UART_CT;
reg UART_CE;

//счётчик делителя: считает до UART_DIV-1 и выдаёт один тик UART_CE
always @(posedge CLK, posedge RST)
    if (RST) begin
        UART_CT <= {CT_W{1'b0}};
        UART_CE <= 1'b0;
    end
    else begin
        if (UART_CT == UART_DIV - 1) UART_CT <= {CT_W{1'b0}};
        else UART_CT <= UART_CT + 1'b1;
        UART_CE <= (UART_CT == UART_DIV - 1);
    end

// Синхронизатор входа RXD (2 триггера)
reg [1:0] RXD_SYNC;
wire RXD_RG;

always @(posedge CLK, posedge RST)
    if (RST) RXD_SYNC <= 2'b11;
    else RXD_SYNC <= {RXD_SYNC[0], RXD};
assign RXD_RG = RXD_SYNC[1]; //уже синхронизированный сигнал RX

// Счётчики выборок (RATIO = 8 -> 3 бита)
reg [2:0] RX_SAMP_CT;
reg [2:0] TX_SAMP_CT;
reg RXCT_R; //сброс счётчика RX
reg TXCT_R; //сброс счётчика TX
wire RX_CE; //середина бита при приёме (отсчёт 3)
wire TX_CE; //конец бита при передаче (отсчёт 7)

//счётчик выборок при приёме
always @(posedge CLK, posedge RST)
    if (RST) RX_SAMP_CT <= 3'd0;
    else if (RXCT_R) RX_SAMP_CT <= 3'd0;
    else if (UART_CE) RX_SAMP_CT <= RX_SAMP_CT + 1'b1;
assign RX_CE = UART_CE & (RX_SAMP_CT == 3'd3);

//счётчик выборок при передаче
always @(posedge CLK, posedge RST)
    if (RST) TX_SAMP_CT <= 3'd0;
    else if (TXCT_R) TX_SAMP_CT <= 3'd0;
    else if (UART_CE) TX_SAMP_CT <= TX_SAMP_CT + 1'b1;
assign TX_CE = UART_CE & (TX_SAMP_CT == 3'd7);

// Автомат приёма RX_FSM
localparam RX_IDLE  = 3'd0; //ожидание стартового бита
localparam RX_RSTRB = 3'd1; //приём стартового бита
localparam RX_RDT   = 3'd2; //приём данных
localparam RX_RPARB = 3'd3; //приём бита чётности
localparam RX_RSTB1 = 3'd4; //приём первого стопового бита
localparam RX_RSTB2 = 3'd5; //приём второго стопового бита
localparam RX_WEND  = 3'd6; //ожидание конца кадра (после ошибки кадра)

reg [2:0] RX_FSM;
reg [2:0] RX_DATA_CT; //счётчик принятых бит данных

always @(posedge CLK, posedge RST)
    if (RST) begin
        RX_FSM <= RX_IDLE;
        RX_DATA_EN <= 1'b0;
        RX_DATA_T <= 10'd0;
        RX_DATA_CT <= 3'd0;
        RXCT_R <= 1'b1;
    end
    else
        case (RX_FSM)
            RX_IDLE: begin
                RX_DATA_EN <= 1'b0;
                if (~RXD_RG) begin //поймали стартовый бит (линия просела)
                    RX_FSM <= RX_RSTRB;
                    RX_DATA_T[9] <= 1'b0;
                    RXCT_R <= 1'b0;
                end
            end
            RX_RSTRB: if (RX_CE) begin
                if (RXD_RG) begin //ложный старт — линия снова в 1
                    RX_FSM <= RX_IDLE;
                    RXCT_R <= 1'b1;
                end
                else RX_FSM <= RX_RDT;
            end
            RX_RDT: if (RX_CE) begin
                RX_DATA_T[7:0] <= {RXD_RG, RX_DATA_T[7:1]}; //младшим битом вперёд
                RX_DATA_CT <= RX_DATA_CT + 1'b1;
                if (RX_DATA_CT == 3'd7) RX_FSM <= RX_RPARB;
            end
            RX_RPARB: if (RX_CE) begin
                RX_FSM <= RX_RSTB1;
                //Odd: число единиц в данных и бите чётности должно быть нечётным
                RX_DATA_T[8] <= ~(^{RX_DATA_T[7:0], RXD_RG});
            end
            RX_RSTB1: if (RX_CE) begin
                if (RXD_RG) RX_FSM <= RX_RSTB2;
                else begin
                    RX_FSM <= RX_WEND;
                    RX_DATA_T[9] <= 1'b1; //ошибка кадра: стоп-бит не 1
                end
            end
            RX_RSTB2: if (RX_CE) begin
                if (RXD_RG) begin
                    RX_FSM <= RX_IDLE;
                    RX_DATA_EN <= 1'b1; //кадр принят успешно
                    RXCT_R <= 1'b1;
                end
                else begin
                    RX_FSM <= RX_WEND;
                    RX_DATA_T[9] <= 1'b1; //ошибка кадра
                end
            end
            RX_WEND: if (RXD_RG) begin //дождались, пока линия снова в 1
                RX_FSM <= RX_IDLE;
                RX_DATA_EN <= 1'b1;
                RXCT_R <= 1'b1;
            end
            default: begin
                RX_FSM <= RX_IDLE;
                RX_DATA_EN <= 1'b0;
                RX_DATA_T <= 10'd0;
                RX_DATA_CT <= 3'd0;
                RXCT_R <= 1'b1;
            end
        endcase

// Автомат передачи TX_FSM
localparam TX_IDLE  = 3'd0; //ожидание данных
localparam TX_WCE   = 3'd1; //ожидание сигнала UART_CE
localparam TX_TSTRB = 3'd2; //передача стартового бита
localparam TX_TDT   = 3'd3; //передача данных
localparam TX_TPARB = 3'd4; //передача бита чётности
localparam TX_TSTB1 = 3'd5; //передача первого стопового бита
localparam TX_TSTB2 = 3'd6; //передача второго стопового бита

reg [2:0] TX_FSM;
reg [2:0] TX_DATA_CT;    //счётчик переданных бит данных
reg TX_PAR_BIT_RG;       //бит чётности (Odd)
reg [7:0] TX_DATA;

always @(posedge CLK, posedge RST)
    if (RST) begin
        TX_FSM <= TX_IDLE;
        TX_DATA <= 8'h0;
        TX_PAR_BIT_RG <= 1'b1;
        TX_RDY_R <= 1'b1;
        TX_DATA_CT <= 3'd0;
        TXD <= 1'b1;
        TXCT_R <= 1'b1;
    end
    else
        case (TX_FSM)
            TX_IDLE: if (TX_RDY_T) begin
                TX_DATA <= TX_DATA_R;
                TX_PAR_BIT_RG <= ~(^TX_DATA_R); //Odd parity
                TX_RDY_R <= 1'b0;
                if (UART_CE) begin
                    TX_FSM <= TX_TSTRB;
                    TXD <= 1'b0; //стартовый бит
                    TXCT_R <= 1'b0;
                end
                else TX_FSM <= TX_WCE;
            end
            TX_WCE: if (UART_CE) begin
                TX_FSM <= TX_TSTRB;
                TXD <= 1'b0;
                TXCT_R <= 1'b0;
            end
            TX_TSTRB: if (TX_CE) begin
                TX_FSM <= TX_TDT;
                TXD <= TX_DATA[0];
                TX_DATA <= {1'b0, TX_DATA[7:1]}; //сдвигаем вправо
            end
            TX_TDT: if (TX_CE) begin
                TX_DATA <= {1'b0, TX_DATA[7:1]};
                TX_DATA_CT <= TX_DATA_CT + 1'b1;
                if (TX_DATA_CT == 3'd7) begin
                    TX_FSM <= TX_TPARB;
                    TXD <= TX_PAR_BIT_RG;
                end
                else TXD <= TX_DATA[0];
            end
            TX_TPARB: if (TX_CE) begin
                TX_FSM <= TX_TSTB1;
                TXD <= 1'b1; //стоп-бит
            end
            TX_TSTB1: if (TX_CE) TX_FSM <= TX_TSTB2;
            TX_TSTB2: if (TX_CE) begin
                TX_FSM <= TX_IDLE;
                TX_RDY_R <= 1'b1; //передача завершена
                TXCT_R <= 1'b1;
            end
            default: begin
                TX_FSM <= TX_IDLE;
                TX_DATA <= 8'h0;
                TX_PAR_BIT_RG <= 1'b1;
                TX_RDY_R <= 1'b1;
                TX_DATA_CT <= 3'd0;
                TXD <= 1'b1;
                TXCT_R <= 1'b1;
            end
        endcase

endmodule
