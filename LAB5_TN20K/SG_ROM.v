`timescale 1ns / 1ps

// ПЗУ сообщений (вариант SG), версия для Tang Nano 20K / Gowin EDA.
// Содержимое то же, что и в mem.mem, но записано через case —
// так синтезатору не нужно искать файл инициализации.
module SG_ROM(
    input [6:0] ADDR,   //адрес символа в ПЗУ
    output reg [7:0] DATA //код символа (ASCII)
);

always @* begin
    case (ADDR)
        // "Result ADD36: "
        7'd0:  DATA = 8'h52; // R
        7'd1:  DATA = 8'h65; // e
        7'd2:  DATA = 8'h73; // s
        7'd3:  DATA = 8'h75; // u
        7'd4:  DATA = 8'h6C; // l
        7'd5:  DATA = 8'h74; // t
        7'd6:  DATA = 8'h20; // пробел
        7'd7:  DATA = 8'h41; // A
        7'd8:  DATA = 8'h44; // D
        7'd9:  DATA = 8'h44; // D
        7'd10: DATA = 8'h33; // 3
        7'd11: DATA = 8'h36; // 6
        7'd12: DATA = 8'h3A; // :
        7'd13: DATA = 8'h20; // пробел

        // "Result MUL52: "
        7'd14: DATA = 8'h52; // R
        7'd15: DATA = 8'h65; // e
        7'd16: DATA = 8'h73; // s
        7'd17: DATA = 8'h75; // u
        7'd18: DATA = 8'h6C; // l
        7'd19: DATA = 8'h74; // t
        7'd20: DATA = 8'h20; // пробел
        7'd21: DATA = 8'h4D; // M
        7'd22: DATA = 8'h55; // U
        7'd23: DATA = 8'h4C; // L
        7'd24: DATA = 8'h35; // 5
        7'd25: DATA = 8'h32; // 2
        7'd26: DATA = 8'h3A; // :
        7'd27: DATA = 8'h20; // пробел

        // "Success WR12_8"
        7'd28: DATA = 8'h53; // S
        7'd29: DATA = 8'h75; // u
        7'd30: DATA = 8'h63; // c
        7'd31: DATA = 8'h63; // c
        7'd32: DATA = 8'h65; // e
        7'd33: DATA = 8'h73; // s
        7'd34: DATA = 8'h73; // s
        7'd35: DATA = 8'h20; // пробел
        7'd36: DATA = 8'h57; // W
        7'd37: DATA = 8'h52; // R
        7'd38: DATA = 8'h31; // 1
        7'd39: DATA = 8'h32; // 2
        7'd40: DATA = 8'h5F; // _
        7'd41: DATA = 8'h38; // 8

        // "Success ON12_8"
        7'd42: DATA = 8'h53; // S
        7'd43: DATA = 8'h75; // u
        7'd44: DATA = 8'h63; // c
        7'd45: DATA = 8'h63; // c
        7'd46: DATA = 8'h65; // e
        7'd47: DATA = 8'h73; // s
        7'd48: DATA = 8'h73; // s
        7'd49: DATA = 8'h20; // пробел
        7'd50: DATA = 8'h4F; // O
        7'd51: DATA = 8'h4E; // N
        7'd52: DATA = 8'h31; // 1
        7'd53: DATA = 8'h32; // 2
        7'd54: DATA = 8'h5F; // _
        7'd55: DATA = 8'h38; // 8

        // "Success OFF12_8"
        7'd56: DATA = 8'h53; // S
        7'd57: DATA = 8'h75; // u
        7'd58: DATA = 8'h63; // c
        7'd59: DATA = 8'h63; // c
        7'd60: DATA = 8'h65; // e
        7'd61: DATA = 8'h73; // s
        7'd62: DATA = 8'h73; // s
        7'd63: DATA = 8'h20; // пробел
        7'd64: DATA = 8'h4F; // O
        7'd65: DATA = 8'h46; // F
        7'd66: DATA = 8'h46; // F
        7'd67: DATA = 8'h31; // 1
        7'd68: DATA = 8'h32; // 2
        7'd69: DATA = 8'h5F; // _
        7'd70: DATA = 8'h38; // 8

        // "Success LED12_8"
        7'd71: DATA = 8'h53; // S
        7'd72: DATA = 8'h75; // u
        7'd73: DATA = 8'h63; // c
        7'd74: DATA = 8'h63; // c
        7'd75: DATA = 8'h65; // e
        7'd76: DATA = 8'h73; // s
        7'd77: DATA = 8'h73; // s
        7'd78: DATA = 8'h20; // пробел
        7'd79: DATA = 8'h4C; // L
        7'd80: DATA = 8'h45; // E
        7'd81: DATA = 8'h44; // D
        7'd82: DATA = 8'h31; // 1
        7'd83: DATA = 8'h32; // 2
        7'd84: DATA = 8'h5F; // _
        7'd85: DATA = 8'h38; // 8

        // "Error command!!!"
        7'd86: DATA = 8'h45; // E
        7'd87: DATA = 8'h72; // r
        7'd88: DATA = 8'h72; // r
        7'd89: DATA = 8'h6F; // o
        7'd90: DATA = 8'h72; // r
        7'd91: DATA = 8'h20; // пробел
        7'd92: DATA = 8'h63; // c
        7'd93: DATA = 8'h6F; // o
        7'd94: DATA = 8'h6D; // m
        7'd95: DATA = 8'h6D; // m
        7'd96: DATA = 8'h61; // a
        7'd97: DATA = 8'h6E; // n
        7'd98: DATA = 8'h64; // d
        7'd99: DATA = 8'h21; // !
        7'd100: DATA = 8'h21; // !
        7'd101: DATA = 8'h21; // !

        default: DATA = 8'h00; //всё, что вне таблицы — ноль
    endcase
end

endmodule
