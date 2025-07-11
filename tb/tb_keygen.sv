`timescale 1ns / 1ps

import tb_pkg::*;

module tb_keygen;
    localparam logic[1:0] MODE = KEYGEN_MODE;

    logic tb_rst;
    logic [9:0] ctr, c;
    integer start_time, dump_time;
    logic low_res_sk_done;

    logic clk = 1;
    logic rst, start, done;
    logic valid_i,  ready_o;
    logic ready_i, valid_o;
    logic  [W-1:0] data_i;  
    logic [W-1:0] data_o;

    logic [0:SEED_SIZE-1] seed  [NUM_TV-1:0];
    logic [0:SEED_SIZE-1] k     [NUM_TV-1:0];
    logic [0:SEED_SIZE-1] rho   [NUM_TV-1:0];
    logic [0:SEED_SIZE-1] tr    [NUM_TV-1:0];
    logic [0:S1_SIZE-1]   s1    [NUM_TV-1:0];
    logic [0:S2_SIZE-1]   s2    [NUM_TV-1:0];
    logic [0:T0_SIZE-1]   t0    [NUM_TV-1:0];
    logic [0:T1_SIZE-1]   t1    [NUM_TV-1:0];
  
    // NOTE: different Dilithiums will have different transitions
    typedef enum logic [3:0] {
        S_INIT, S_START, S_Z, S_RHO, S_K,
        S_S1, S_S2, S_T1, S_T0, S_TR, S_STOP
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
        $readmemh({TV_SHARED_PATH, "seed.txt"}, seed);
        $readmemh({TV_SHARED_PATH, "k.txt"}, k);
        $readmemh({TV_SHARED_PATH, "rho.txt"}, rho);
        $readmemh({TV_PATH, "s1.txt"}, s1);
        $readmemh({TV_PATH, "s2.txt"}, s2);
        $readmemh({TV_PATH, "t0.txt"}, t0);
        $readmemh({TV_PATH, "t1.txt"}, t1);
        $readmemh({TV_PATH, "tr.txt"}, tr);
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
            c               <= 0;
            start           <= 0;
            low_res_sk_done <= 0;
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
                    state <= S_Z;
                end
                S_Z: begin
                    valid_i <= 1;
                    data_i  <= seed[c][0 +: W];
                
                    if (ready_i) begin
                        ctr <= ctr + 1;
                        data_i <= seed[c][(ctr+1)*W +: W];

                        if (ctr == SEED_WORDS_NUM - 1) begin
                            ctr <= 0;
                            state <= S_RHO;
                        end
                    end
                end
                S_RHO: begin
                    ready_o <= 1;
                    if (valid_o) begin
                        // Since low-res dilithium dumps the data as a separate operation
                        // it is usful to keep track of both also separately
                        dump_time  <= $time;

                        if (data_o !== rho[c][ctr*W+:W])
                            $display("[Rho, %d] Error: Expected %h, received %h", ctr, rho[c][ctr*W+:W], data_o); 
                    
                        ctr <= ctr + 1;
                        
                        if (ctr == SEED_WORDS_NUM-1) begin
                            ctr <= 0;
                            state <= low_res_sk_done ? S_T1 : S_K;
                            low_res_sk_done <= !(HIGH_PERF);
                        end
                    end
                end        
                S_K: begin
                    ready_o <= 1;
                    if (valid_o) begin
                        if (data_o !== k[c][ctr*W+:W])
                            $display("[K, %d] Error: Expected %h, received %h", ctr, k[c][ctr*W+:W], data_o); 
                    
                        ctr <= ctr + 1;
                        
                        if (ctr == SEED_WORDS_NUM-1) begin
                            ctr <= 0;
                            state <= HIGH_PERF ? S_S1 : S_TR;
                        end
                    end
                end
                S_S1: begin
                    ready_o <= 1;
                    if (valid_o) begin
                        if (data_o !== s1[c][ctr*W+:W])
                            $display("[S1, %d] Error: Expected %h, received %h", ctr, s1[c][ctr*W+:W], data_o); 
        
                        ctr <= ctr + 1;
                        
                        if (ctr == S1_WORDS_NUM-1) begin
                            ctr <= 0;
                            state <= S_S2;
                        end
                    end
                end
                S_S2: begin
                    ready_o <= 1;
                    if (valid_o) begin
                        if (data_o !== s2[c][ctr*W+:W])
                            $display("[S2, %d] Error: Expected %h, received %h", ctr, s2[c][ctr*W+:W], data_o); 
                    
                        ctr <= ctr + 1;
                        
                        if (ctr == S2_WORDS_NUM-1) begin
                            ctr <= 0;
                            state <= HIGH_PERF ? S_T1 : S_T0; // S_STOP
                        end
                    end
                end
                S_T1: begin
                    ready_o <= 1;
                    if (valid_o) begin
                        if (data_o !== t1[c][ctr*W+:W])
                            $display("[T1, %d] Error: Expected %h, received %h", ctr, t1[c][ctr*W+:W], data_o); 

                        ctr <= ctr + 1;
                        
                        if (ctr == T1_WORDS_NUM-1) begin
                            ctr <= 0;
                            state <= HIGH_PERF ? S_T0 : S_STOP;
                        end
                    end
                end
                S_T0: begin
                    ready_o <= 1;
                    if (valid_o) begin
                        if (data_o !== t0[c][ctr*W+:W])
                            $display("[T0, %d] Error: Expected %h, received %h", ctr, t0[c][ctr*W+:W], data_o); 
                        ctr <= ctr + 1;
                        
                        if (ctr == T0_WORDS_NUM-1) begin
                            ctr <= 0;
                            state <= HIGH_PERF ? S_TR : S_RHO;
                        end
                    end
                end
                S_TR: begin
                    ready_o <= 1;
                    if (valid_o) begin
                        if (data_o !== tr[c][ctr*W+:W])
                            $display("[TR, %d] Error: Expected %h, received %h", ctr, tr[c][ctr*W+:W], data_o); 
                    
                        ctr <= ctr + 1;
                        
                        if (ctr == SEED_WORDS_NUM-1) begin
                            ctr <= 0;
                            state <= HIGH_PERF ? S_STOP : S_S1;
                        end
                    end
                end
                S_STOP: begin
                    ready_o <= 1;
                    c       <= c + 1;
                    state   <= S_INIT;

                    if (HIGH_PERF) begin
                        $display("KG%d[%d] completed in %d clock cycles", SEC_LEVEL, c, ($time-start_time)/P);
                    end else begin
                        $display(
                            "KG%d[%d] completed in %d (exec) + %d (dump) = %d (total) clock cycles",
                            SEC_LEVEL, c, (dump_time-start_time)/P, ($time-dump_time)/P, ($time-start_time)/P
                        );
                    end

                    if (c == NUM_TV-1) begin
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