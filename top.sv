module dilithium #(
    parameter HIGH_PERF = 1,
    parameter SEC_LEVEL = 2,
    parameter W = (HIGH_PERF) ? 64 : 32
)(
    input  logic         clk,
    input  logic         rst,
    input  logic         start,
    input  logic [1:0]   mode,
    input  logic         valid_i,
    output logic         ready_i,
    input  logic [W-1:0] data_i,
    output logic         valid_o,
    input  logic         ready_o,
    output logic [W-1:0] data_o,
    output logic         done_o
);

    // Wires for intermediate signals
    generate
        if (HIGH_PERF) begin
            dilithium_high_perf high_perf_instance (
                .clk(clk),
                .rst(rst),
                .start(start),
                .mode(mode),
                .sec_lvl(3'SEC_LEVEL),
                .valid_i(valid_i),
                .ready_i(ready_i),
                .data_i(data_i),
                .valid_o(valid_o),
                .ready_o(ready_o),
                .data_o(data_o),
                .done_o (done_o)
            );
        end
        else begin
            dilithium_low_res (
                .SEC_LEVEL = SEC_LEVEL
            )
            low_res_instance (
                .clk(clk),
                .op_in(op_in),
                .op_valid_in(op_valid_in),
                .ready_out(ready_out),
                .data_in(data_in),
                .ready_rcv_in(ready_rcv_in),
                .valid_in(valid_in),
                .data_out(data_out),
                .ready_rcv_out(ready_rcv_out),
                .valid_out(valid_out),
                .done_o (done_o)
            );
        end
    endgenerate

endmodule