`timescale 1ns / 1ps

// Делитель частоты (вариант SG)
// clk_out выдаёт одиночный импульс один раз в MOD тактов clk_in.
module SG_DIVIDER #(parameter MOD = 255)(
    input wire clk_in,
    input wire reset,
    output reg clk_out
);
    reg [$clog2(MOD) - 1 : 0] divider_counter;

    initial begin
        clk_out = 1'b0;
        divider_counter = {($clog2(MOD)){1'b0}};
    end

    always @(posedge clk_in) begin
        if (reset) begin
            clk_out <= 1'b0;
            divider_counter <= {($clog2(MOD)){1'b0}};
        end else begin
            if (divider_counter == MOD - 1) begin
                clk_out <= 1'b1;                          //один такт "1"
                divider_counter <= {($clog2(MOD)){1'b0}}; //и снова с нуля
            end else begin
                clk_out <= 1'b0;
                divider_counter <= divider_counter + 1'b1;
            end
        end
    end
endmodule
