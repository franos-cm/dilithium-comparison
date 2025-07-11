`timescale 1ns / 1ps

import tb_pkg::*;

module tb_sign;
    localparam logic[1:0] MODE = SIGN_MODE;

    logic tb_rst;
    logic [9:0] ctr, tv_ctr;
    integer start_time, dump_time;
    logic low_res_sk_done;

    logic clk = 1;
    logic rst, start, done;
    logic valid_i,  ready_o;
    logic ready_i, valid_o;
    logic  [W-1:0] data_i;  
    logic [W-1:0] data_o;

    logic [0:SEED_SIZE-1]  rho       [NUM_TV-1:0];
    logic [0:SEED_SIZE-1]  k         [NUM_TV-1:0];
    logic [0:S1_SIZE-1]    s1        [NUM_TV-1:0];
    logic [0:S2_SIZE-1]    s2        [NUM_TV-1:0];
    logic [0:T0_SIZE-1]    t0        [NUM_TV-1:0];
    logic [0:SEED_SIZE-1]  tr        [NUM_TV-1:0];
    logic [0:SEED_SIZE-1]  c         [NUM_TV-1:0];
    logic [0:Z_SIZE-1]     z         [NUM_TV-1:0];
    logic [0:H_SIZE-1]     h         [NUM_TV-1:0];
    logic [0:MSG_SIZE-1]   msg       [NUM_TV-1:0];
    logic [0:MSG_LEN_SIZE] msg_len   [NUM_TV-1:0];
  
    // NOTE: different Dilithiums will have different transitions
    typedef enum logic [3:0] {
        S_INIT, S_START, LOAD_RHO, LOAD_MLEN, LOAD_TR,
        LOAD_MSG, LOAD_K, LOAD_S1, LOAD_S2, LOAD_T0, UNLOAD_Z,
        UNLOAD_H, UNLOAD_C, S_STOP
    } state_t;
    state_t state;


    dilithium #(
        .HIGH_PERF(HIGH_PERF),
        .SEC_LEVEL(SEC_LEVEL)
    )
    dut (
        .clk (clk),
        .rst (rst),
        .start (start),
        .mode (MODE),
        .valid_i (valid_i),
        .ready_i (ready_i),
        .data_i (data_i),
        .valid_o (valid_o),
        .ready_o (ready_o),
        .data_o (data_o)
    );


    initial begin
        $readmemh({TV_SHARED_PATH, "rho.txt"}, rho);
        $readmemh({TV_SHARED_PATH, "k.txt"}, k);
        $readmemh({TV_SHARED_PATH, "msg.txt"}, msg);
        $readmemh({TV_SHARED_PATH, "msg_len.txt"}, msg_len);
        $readmemh({TV_PATH, "s1.txt"}, s1);
        $readmemh({TV_PATH, "s2.txt"}, s2);
        $readmemh({TV_PATH, "t0.txt"}, t0);
        $readmemh({TV_PATH, "tr.txt"}, tr);
        $readmemh({TV_PATH, "c.txt"}, c);
        $readmemh({TV_PATH, "z.txt"}, z);
        $readmemh({TV_PATH, "h.txt"}, h);
    end

    initial begin
        tb_rst = 1;
        #(2*P);
        tb_rst = 0;
    end

    always_ff @(posedge clk) begin
        if (tb_rst) begin
            valid_i         <= 0;
            ready_o         <= 0;
            data_i          <= 0;
            ctr             <= 0; 
            tv_ctr          <= 0;
            start           <= 0;
            rst             <= 1;
            state           <= S_INIT;
        end

        else begin
            rst     <= 0;
            start   <= 0;
            valid_i <= 0;
            ready_o <= 0;
            data_i  <= 0;
        
            unique case (state)
                S_INIT: begin
                    rst <= 1;
                    ctr <= ctr + 1;
                    // Arbitrary number of reset cycles
                    if (ctr == 3) begin
                        ctr <= 0;
                        state <= S_START;
                    end
                end
                S_START: begin
                    start_time <= $time;
                    start <= 1;
                    state <= LOAD_RHO;
                end
                LOAD_RHO: begin
                    valid_i <= 1;
                    data_i <= rho[tv_ctr][ctr*W +: W];
                
                    if (ready_i) begin
                        if (ctr == SEED_WORDS_NUM-1) begin
                            ctr    <= 0;
                            state  <= HIGH_PERF ? LOAD_MLEN : LOAD_MLEN;
                            data_i <= HIGH_PERF ? msg_len[tv_ctr] : msg_len[tv_ctr];
                        end else begin
                            ctr    <= ctr + 1;
                            data_i <= rho[tv_ctr][(ctr+1)*W +: W];
                        end
                    end
                end
                LOAD_MLEN: begin
                    valid_i <= 1;
                    data_i <= msg_len[tv_ctr];
                
                    if (ready_i) begin
                        state  <= HIGH_PERF ? LOAD_TR : LOAD_TR;
                        data_i <= HIGH_PERF ? tr[tv_ctr][0 +: W] : tr[tv_ctr][0 +: W];
                    end
                end
                LOAD_TR: begin
                    valid_i <= 1;
                    data_i <= tr[tv_ctr][ctr*W +: W];
                
                    if (ready_i) begin
                        if (ctr == SEED_WORDS_NUM-1) begin
                            ctr    <= 0;
                            state  <= HIGH_PERF ? LOAD_MSG : LOAD_MSG;
                            data_i <= msg[tv_ctr][0 +: W];
                        end else begin
                            ctr    <= ctr + 1;
                            data_i <= tr[tv_ctr][(ctr+1)*W +: W];
                        end
                    end
                end
                LOAD_MSG: begin
                    valid_i <= 1;
                    data_i <= msg[tv_ctr][ctr*W +: W];
                
                    if (ready_i) begin
                        if ((ctr+1)*W >= msg_len[tv_ctr]*8) begin
                            ctr     <= 0;
                            state   <= HIGH_PERF ? LOAD_K : LOAD_K;
                            data_i  <= k[tv_ctr][0 +: W];
                            valid_i <= HIGH_PERF ? 1 : 0;
                        end else begin
                            ctr    <= ctr + 1;
                            data_i <= msg[tv_ctr][(ctr+1)*W +: W];
                        end
                    end
                end
                LOAD_K: begin
                    valid_i <= 1;
                    data_i <= k[tv_ctr][ctr*W +: W];
                
                    if (ready_i) begin
                        if (ctr == SEED_WORDS_NUM-1) begin
                            ctr    <= 0;
                            state  <= HIGH_PERF ? LOAD_S1 : LOAD_S1;
                            data_i <= HIGH_PERF ? s1[tv_ctr][0 +: W] : h[tv_ctr][0 +: W];
                        end else begin
                            ctr    <= ctr + 1;
                            data_i <= k[tv_ctr][(ctr+1)*W +: W];
                        end
                    end
                end
                LOAD_S1: begin
                    valid_i <= 1;
                    data_i <= s1[tv_ctr][ctr*W +: W];
                
                    if (ready_i) begin
                        if (ctr == S1_WORDS_NUM-1) begin
                            ctr    <= 0;
                            state  <= HIGH_PERF ? LOAD_S2 : LOAD_MLEN;
                            data_i <= s2[tv_ctr][0 +: W];
                        end else begin
                            ctr    <= ctr + 1;
                            data_i <= s1[tv_ctr][(ctr+1)*W +: W];
                        end
                    end
                end
                LOAD_S2: begin
                    valid_i <= 1;
                    data_i <= s2[tv_ctr][ctr*W +: W];
                
                    if (ready_i) begin
                        if (ctr == S2_WORDS_NUM-1) begin
                            ctr    <= 0;
                            state  <= HIGH_PERF ? LOAD_T0 : LOAD_MLEN;
                            data_i <= t0[tv_ctr][0 +: W];
                        end else begin
                            ctr    <= ctr + 1;
                            data_i <= s2[tv_ctr][(ctr+1)*W +: W];
                        end
                    end
                end
                LOAD_T0: begin
                    valid_i <= 1;
                    data_i <= t0[tv_ctr][ctr*W +: W];
                
                    if (ready_i) begin
                        if (ctr == T0_WORDS_NUM-1) begin
                            ctr    <= 0;
                            state  <= HIGH_PERF ? UNLOAD_Z : LOAD_MLEN;
                            // data_i <= t0[tv_ctr][0 +: W];
                        end else begin
                            ctr    <= ctr + 1;
                            data_i <= t0[tv_ctr][(ctr+1)*W +: W];
                        end
                    end
                end        
                UNLOAD_Z: begin
                    ready_o <= 1;
                    if (valid_o) begin
                        // Since low-res dilithium dumps the data as a separate operation
                        // it is useful to keep track of both also separately
                        dump_time  <= $time;

                        if (data_o !== z[tv_ctr][ctr*W+:W])
                            $display("[Z, %d] Error: Expected %h, received %h", ctr, z[tv_ctr][ctr*W+:W], data_o); 
                    
                        ctr <= ctr + 1;
                        
                        if (ctr == Z_WORDS_NUM-1) begin
                            ctr <= 0;
                            state <= HIGH_PERF ? UNLOAD_H : UNLOAD_H;
                        end
                    end
                end        
                UNLOAD_H: begin
                    ready_o <= 1;
                    if (valid_o) begin
                        if (data_o != h[tv_ctr][ctr*W+:W])
                            $display("[H, %d] Error: Expected %h, received %h", ctr, h[tv_ctr][ctr*W+:W], data_o); 
                    
                        ctr <= ctr + 1;
                        
                        if (ctr == H_WORDS_NUM-1) begin
                            ctr <= 0;
                            state <= HIGH_PERF ? UNLOAD_C : UNLOAD_C;
                        end
                    end
                end
                UNLOAD_C: begin
                    ready_o <= 1;
                    if (valid_o) begin
                        if (data_o !== c[tv_ctr][ctr*W+:W])
                            $display("[c, %d] Error: Expected %h, received %h", ctr, c[tv_ctr][ctr*W+:W], data_o); 
        
                        ctr <= ctr + 1;
                        
                        if (ctr == SEED_WORDS_NUM-1) begin
                            ctr <= 0;
                            state <= HIGH_PERF ? S_STOP : S_STOP;
                        end
                    end
                end
                S_STOP: begin
                    tv_ctr  <= tv_ctr + 1;
                    state   <= S_INIT;

                    if (HIGH_PERF) begin
                        $display("SG%d[%d] completed in %d clock cycles", SEC_LEVEL, tv_ctr, ($time-start_time)/P);
                    end else begin
                        $display(
                            "SG%d[%d] completed in %d (exec) + %d (dump) = %d (total) clock cycles",
                            SEC_LEVEL, c, (dump_time-start_time)/P, ($time-dump_time)/P, ($time-start_time)/P
                        );
                    end
                    if (tv_ctr == NUM_TV-1) begin
                        $display ("Testbench done!");
                        $finish;
                    end       
                end
                default: begin
                    $fatal(1, "Invalid state reached: %0d", state);
                end
            endcase
        end
    end

    always #(P/2) clk = ~clk;

endmodule