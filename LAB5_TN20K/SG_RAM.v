`timescale 1ns / 1ps

// Параметризируемая память RAM (вариант SG): 64 слова x 8 бит
module SG_RAM #(
    parameter AW = 6 //log2(64) = 6
)
(
    // System
    input CLK,
    // STI 1.0
    input S_EX_REQ,          //запрос
    input [AW-1:0] S_ADDR,   //адрес
    input [2:0] S_CMD,       //команда
    input [7:0] S_D_WR,      //данные для записи
    output S_EX_ACK,         //подтверждение
    output [7:0] S_D_RD,     //данные чтения
    // Порт прямого чтения
    input [AW-1:0] ADDR,     //шина адреса ОЗУ
    output [7:0] DATA        //шина данных ОЗУ
);

reg [7:0] MEMORY [0:(2**AW)-1];

//обнуляем память при старте — чтобы не ловить X в симуляции
integer i;
initial
    for (i = 0; i < 2**AW; i = i + 1) MEMORY[i] = 8'h00;

wire WE = S_EX_REQ & ~S_CMD[2]; //разрешение записи (старший бит команды = 1 -> чтение)

always @(posedge CLK)
    if (WE) MEMORY[S_ADDR] <= S_D_WR;

assign S_D_RD  = MEMORY[S_ADDR]; //чтение по адресу STI
assign S_EX_ACK = 1'b1;           //подтверждение всегда сразу
assign DATA    = MEMORY[ADDR];    //прямой порт чтения

endmodule
