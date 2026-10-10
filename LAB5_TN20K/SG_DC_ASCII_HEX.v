`timescale 1ns / 1ps

// Преобразователь ASCII -> HEX (один символ)
module SG_DC_ASCII_HEX(
    input [7:0] ASCII,
    output reg [3:0] HEX,
    output HEX_FLG
);
// HEX_FLG = 1, если символ вообще является hex-цифрой
assign HEX_FLG = ASCII == 8'h30 | // 0
                 ASCII == 8'h31 | // 1
                 ASCII == 8'h32 | // 2
                 ASCII == 8'h33 | // 3
                 ASCII == 8'h34 | // 4
                 ASCII == 8'h35 | // 5
                 ASCII == 8'h36 | // 6
                 ASCII == 8'h37 | // 7
                 ASCII == 8'h38 | // 8
                 ASCII == 8'h39 | // 9
                 ASCII == 8'h61 | // a
                 ASCII == 8'h62 | // b
                 ASCII == 8'h63 | // c
                 ASCII == 8'h64 | // d
                 ASCII == 8'h65 | // e
                 ASCII == 8'h66 | // f
                 ASCII == 8'h41 | // A
                 ASCII == 8'h42 | // B
                 ASCII == 8'h43 | // C
                 ASCII == 8'h44 | // D
                 ASCII == 8'h45 | // E
                 ASCII == 8'h46;  // F

// ---------------------------------------
// ASCII -> HEX
always @*
    if (ASCII == 8'h31) HEX <= 4'h1;
    else if (ASCII == 8'h32) HEX <= 4'h2;
    else if (ASCII == 8'h33) HEX <= 4'h3;
    else if (ASCII == 8'h34) HEX <= 4'h4;
    else if (ASCII == 8'h35) HEX <= 4'h5;
    else if (ASCII == 8'h36) HEX <= 4'h6;
    else if (ASCII == 8'h37) HEX <= 4'h7;
    else if (ASCII == 8'h38) HEX <= 4'h8;
    else if (ASCII == 8'h39) HEX <= 4'h9;
    else if (ASCII == 8'h41 | ASCII == 8'h61) HEX <= 4'hA;
    else if (ASCII == 8'h42 | ASCII == 8'h62) HEX <= 4'hB;
    else if (ASCII == 8'h43 | ASCII == 8'h63) HEX <= 4'hC;
    else if (ASCII == 8'h44 | ASCII == 8'h64) HEX <= 4'hD;
    else if (ASCII == 8'h45 | ASCII == 8'h65) HEX <= 4'hE;
    else if (ASCII == 8'h46 | ASCII == 8'h66) HEX <= 4'hF;
    else HEX <= 4'h0; //не hex-цифра -> 0 (HEX_FLG при этом = 0)
endmodule
