`timescale 1ns / 1ps

module dilithium_low_res #(
    parameter SEC_LEVEL = 2
)(
    input  logic         clk,
    input  logic         rst,
    input  logic         start,
    input  logic [1:0]   mode,
    input  logic         valid_i,
    output logic         ready_i,
    input  logic [31:0]  data_i,
    output logic         valid_o,
    input  logic         ready_o,
    output logic [31:0]  data_o,
    output logic         done,
);

    logic [3:0]   op_in;
    logic         op_valid_in;
    logic         ready_out;
    logic [31:0]  data_in;
    logic         ready_rcv_in;
    logic         valid_in;
    logic [31:0]  data_out;
    logic         ready_rcv_out;
    logic         valid_out;

    assign data_in = data_i;
    assign data_out = data_o;
    assign valid_in = valid_i;
    assign valid_out = valid_o;
    // Name schemes are different
    assign ready_rcv_in = ready_o;
    assign ready_rcv_out = ready_in;

    adapter_low_res adapter (
        .clk     (clk),
        .rst     (rst),
        .start   (start),
        .mode    (mode),
        .op_in   (op_in),
        .op_valid_in (op_valid_in),
        .ready_out (ready_out),
        .done (done)
    );

    generate
        if (SEC_LEVEL == 2) begin
            dilithium_top_ii dilithium_low_res_ii (
                .clk(clk),
                .op_in(op_in),
                .op_valid_in(op_valid_in),
                .ready_out(ready_out),
                .data_in(data_in),
                .ready_rcv_in(ready_rcv_in),
                .valid_in(valid_in),
                .data_out(data_out),
                .ready_rcv_out(ready_rcv_out),
                .valid_out(valid_out)
            );
        end
        else if (SEC_LEVEL == 3) begin
            dilithium_top_iii dilithium_low_res_iii (
                .clk(clk),
                .op_in(op_in),
                .op_valid_in(op_valid_in),
                .ready_out(ready_out),
                .data_in(data_in),
                .ready_rcv_in(ready_rcv_in),
                .valid_in(valid_in),
                .data_out(data_out),
                .ready_rcv_out(ready_rcv_out),
                .valid_out(valid_out)
            );
        end
        else if (SEC_LEVEL == 5) begin
            dilithium_top_v dilithium_low_res_v (
                .clk(clk),
                .op_in(op_in),
                .op_valid_in(op_valid_in),
                .ready_out(ready_out),
                .data_in(data_in),
                .ready_rcv_in(ready_rcv_in),
                .valid_in(valid_in),
                .data_out(data_out),
                .ready_rcv_out(ready_rcv_out),
                .valid_out(valid_out)
            );
        end
    endgenerate

endmodule