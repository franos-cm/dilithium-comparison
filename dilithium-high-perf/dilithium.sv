`timescale 1ns / 1ps

module dilithium_high_perf (
    input  logic           clk,
    input  logic           rst,
    input  logic           start,
    input  logic[1:0]      mode,
    input  logic[2:0]      sec_lvl,
    input  logic           valid_i,
    output logic           ready_i,
    input  logic[63:0]     data_i,
    output logic           valid_o,
    input  logic           ready_o,
    output logic[63:0]     data_o,
    output logic           done,
    output logic           last,
    output logic           sign_reject
);
    logic dilithium_valid_o, dilithium_ready_o;
    logic [63:0] dilithium_data_o;

    adapter_high_perf adapter (
        .clk     (clk),
        .rst     (rst),
        .start   (start),
        .mode    (mode),
        .sec_lvl (sec_lvl),
        .dilithium_valid_o (dilithium_valid_o),
        .dilithium_ready_o (dilithium_ready_o),
        .dilithium_data_o (dilithium_data_o),
        .valid_o (valid_o),
        .ready_o (ready_o),
        .data_o (data_o),
        .done (done),
        .last (last)
    );

    combined_top top (
        .clk     (clk),
        .rst     (rst),
        .start   (start),
        .mode    (mode),
        .sec_lvl (sec_lvl),
        .valid_i (valid_i),
        .ready_i (ready_i),
        .data_i (data_i),
        .valid_o (dilithium_valid_o),
        .ready_o (dilithium_ready_o),
        .data_o (dilithium_data_o),
        .sign_reject(sign_reject)
    );

endmodule