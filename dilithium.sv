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
    // NOTE: for some reason casting doesnt work, so this is necessary
    // localparam logic [2:0] sec_lvl_sig = 3'(SEC_LEVEL);
    localparam logic [2:0] sec_lvl_sig = (SEC_LEVEL == 2) ? 3'b010 :
                                         (SEC_LEVEL == 3) ? 3'b011 :
                                         (SEC_LEVEL == 5) ? 3'b101 : 3'b000;

    logic start_strobe;
    logic done_strobe;


    edge_detector start_detector (
        .clk  (clk),
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
                .sec_lvl(sec_lvl_sig),
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
            dilithium_low_res #(
                .SEC_LEVEL(SEC_LEVEL)
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