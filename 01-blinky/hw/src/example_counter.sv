// Sim-only placeholder DUT. NOT instantiated in the deployed block design;
// the BD wires the AXI GPIO loopback directly. This module exists purely
// so the cocotb flow has something real to simulate.
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
