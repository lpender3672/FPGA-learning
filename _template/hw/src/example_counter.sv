// Placeholder DUT for the cocotb sim flow. Delete or replace when you
// write your project's real RTL.
//
// 4-bit synchronous counter with active-low sync reset and enable.
module example_counter #(
    parameter int WIDTH = 4
) (
    input  logic               clk,
    input  logic               rstn,
    input  logic               en,
    output logic [WIDTH-1:0]   q
);
    always_ff @(posedge clk) begin
        if (!rstn)     q <= '0;
        else if (en)   q <= q + 1'b1;
    end
endmodule
