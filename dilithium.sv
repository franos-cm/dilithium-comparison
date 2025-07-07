`timescale 1ns / 1ps

module dilithium #(
    parameter HIGH_PERF = 1,
    parameter SEC_LEVEL = 2,
    parameter W = (HIGH_PERF) ? 64 : 32
)(
    input  logic         clk,
    input  logic         rst,
    input  logic         start,
    input  logic [1:0]   mode,
    output logic         done,
    input  logic         valid_i,
    output logic         ready_i,
    input  logic [W-1:0] data_i,
    output logic         valid_o,
    input  logic         ready_o,
    output logic [W-1:0] data_o
);
    logic start_strobe;
    logic done_strobe;

    edge_detector start_detector (
        .clk  (clk),
        .rst  (rst),
        .signal_in(start),
        .rising_edge(start_strobe)
    );

    latch done_latch (
        .clk  (clk),
        .rst  (rst),
        .set(done_strobe),
        .q(done)
    );

    // Wires for intermediate signals
    generate
        if (HIGH_PERF) begin
            dilithium_high_perf high_perf_instance (
                .clk(clk),
                .rst(rst),
                .start(start_strobe),
                .mode(mode),
                .sec_lvl(3'SEC_LEVEL),
                .valid_i(valid_i),
                .ready_i(ready_i),
                .data_i(data_i),
                .valid_o(valid_o),
                .ready_o(ready_o),
                .data_o(data_o),
                .done(done_strobe)
            );
        end
        else begin
            dilithium_low_res (
                .SEC_LEVEL = SEC_LEVEL
            )
            low_res_instance (
                .clk(clk),
                .rst(rst),
                .start(start_strobe),
                .mode(mode),
                .valid_i(valid_i),
                .ready_i(ready_i),
                .data_i(data_i),
                .valid_o(valid_o),
                .ready_o(ready_o),
                .data_o(data_o),
                .done(done_strobe)
            );
        end
    endgenerate

endmodule