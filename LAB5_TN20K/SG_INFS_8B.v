`timescale 1ns / 1ps

// Инфраструктура системной шины STI 1.0 (вариант SG)
// Разрядность адреса: 12 бит
// Исполнитель-0 (I0): контроллер светодиодов, 450h..451h (I/O, 1 бит адреса)
// Исполнитель-1 (I1): память RAM, F80h..FBFh (Mem, 6 бит адреса, 64 слова)
module SG_INFS_8B(
    // Порт исполнителя (подключается к обработчику команд)
    input T_S_EX_REQ,
    input [11:0] T_S_ADDR,
    input [2:0] T_S_CMD,
    input [7:0] T_S_D_WR,
    output T_S_EX_ACK,
    output [7:0] T_S_D_RD,
    // Порт инициатора 0 — контроллер светодиодов
    output I0_S_EX_REQ,
    output I0_S_ADDR,        //1 бит адреса
    output [2:0] I0_S_CMD,
    output [7:0] I0_S_D_WR,
    input I0_S_EX_ACK,
    input [7:0] I0_S_D_RD,
    // Порт инициатора 1 — RAM
    output I1_S_EX_REQ,
    output [5:0] I1_S_ADDR,  //64 слова -> log2(64) = 6 бит
    output [2:0] I1_S_CMD,
    output [7:0] I1_S_D_WR,
    input I1_S_EX_ACK,
    input [7:0] I1_S_D_RD
);

reg [1:0] EN; //сигналы выбора исполнителя: EN[0] — светодиоды, EN[1] — RAM

// Дешифратор адреса
always @* begin
    // Пространство ввода-вывода: 450h = 0100_0101_000x
    if (T_S_CMD == 3'b000 | T_S_CMD == 3'b100) begin
        if (T_S_ADDR[11:1] == 11'b0100_0101_000) EN = 2'b01;
        else EN = 2'b00;
    end
    // Пространство памяти: F80h = 1111_10xx_xxxx
    else if (T_S_CMD == 3'b001 | T_S_CMD == 3'b101) begin
        if (T_S_ADDR[11:6] == 6'b1111_10) EN = 2'b10;
        else EN = 2'b00;
    end
    // Нет ресурсов
    else EN = 2'b00;
end

// Запрос идёт только выбранному исполнителю
assign I0_S_EX_REQ = T_S_EX_REQ & EN[0];
assign I1_S_EX_REQ = T_S_EX_REQ & EN[1];

// Подтверждение: если исполнитель не выбран, считаем, что он ответил "сразу"
assign T_S_EX_ACK = (I0_S_EX_ACK | ~EN[0]) & (I1_S_EX_ACK | ~EN[1]);

// Данные чтения: складываем по ИЛИ, но маскируем нулями невыбранного исполнителя
assign T_S_D_RD = (I0_S_D_RD | ~{8{EN[0]}}) & (I1_S_D_RD | ~{8{EN[1]}});

// Порт инициатора 0 (светодиоды): используется только младший бит адреса
assign I0_S_ADDR  = T_S_ADDR[0];
assign I0_S_CMD   = T_S_CMD;
assign I0_S_D_WR  = T_S_D_WR;

// Порт инициатора 1 (RAM): младшие 6 бит адреса
assign I1_S_ADDR  = T_S_ADDR[5:0];
assign I1_S_CMD   = T_S_CMD;
assign I1_S_D_WR  = T_S_D_WR;

endmodule
