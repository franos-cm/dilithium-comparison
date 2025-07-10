`timescale 1ns / 1ps

module dilithium_low_res #(
    parameter integer SEC_LEVEL = 2
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
    output logic         done
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


    adapter_low_res adapter (
        .clk         (clk),
        .rst         (rst),
        .start       (start),
        .mode        (mode),
        .done        (done),

        .valid_i     (valid_i),
        .ready_i     (ready_i),
        .data_i      (data_i),
    
        .valid_o     (valid_o),
        .ready_o     (ready_o),
        .data_o      (data_o),

        .op_in           (op_in),
        .op_valid_in     (op_valid_in),

        .ready_out       (ready_out),
        .ready_rcv_in    (ready_rcv_in),
        .data_out        (data_out),
        .ready_rcv_out   (ready_rcv_out),
        .valid_out       (valid_out)
    );

    generate
        if (SEC_LEVEL == 2) begin
            dilithium_top_ii dilithium_low_res_ii (
                .clk(clk),
                .op_in(op_in),
                .op_valid_in(op_valid_in),
                .ready_out(ready_out),
                .data_in(data_i),
                .ready_rcv_in(ready_rcv_in),
                .valid_in(valid_i),
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
                .data_in(data_i),
                .ready_rcv_in(ready_rcv_in),
                .valid_in(valid_i),
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
                .data_in(data_i),
                .ready_rcv_in(ready_rcv_in),
                .valid_in(valid_i),
                .data_out(data_out),
                .ready_rcv_out(ready_rcv_out),
                .valid_out(valid_out)
            );
        end
    endgenerate

endmodule