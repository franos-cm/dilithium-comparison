`timescale 1ns / 1ps

module edge_detector (
    input  logic clk,
    input  logic rst,
    input  logic signal_in,
    output logic rising_edge
);
    // Internal register to store the previous state of the input signal
    logic signal_prev;

    // Edge detection logic
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            signal_prev  <= 1'b0;
            rising_edge  <= 1'b0;
        end else begin
            // A rising edge occurs if current is 1 and previous is 0
            rising_edge  <= (signal_in & ~signal_prev);
            signal_prev  <= signal_in;
        end
    end

endmodule