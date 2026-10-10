`timescale 1ns / 1ps

// Преобразователь HEX -> ASCII (полубайт -> символ)
module SG_DC_HEX_ASCII(
    input [3:0] HEX,
    output reg [7:0] ASCII
);
always @*
    case (HEX)
        4'h0: ASCII <= 8'h30; // 0
        4'h1: ASCII <= 8'h31; // 1
        4'h2: ASCII <= 8'h32; // 2
        4'h3: ASCII <= 8'h33; // 3
        4'h4: ASCII <= 8'h34; // 4
        4'h5: ASCII <= 8'h35; // 5
        4'h6: ASCII <= 8'h36; // 6
        4'h7: ASCII <= 8'h37; // 7
        4'h8: ASCII <= 8'h38; // 8
        4'h9: ASCII <= 8'h39; // 9
        4'hA: ASCII <= 8'h41; // A
        4'hB: ASCII <= 8'h42; // B
        4'hC: ASCII <= 8'h43; // C
        4'hD: ASCII <= 8'h44; // D
        4'hE: ASCII <= 8'h45; // E
        default: ASCII <= 8'h46; // F
    endcase
endmodule
