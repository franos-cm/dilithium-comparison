`timescale 1ns / 1ps
`define P 10

module tb_keygen;
    localparam SEC_LEVEL = 2;
    localparam MODE = 0;
    localparam  NUM_TV = 5;
    localparam HIGH_PERF = 1;
    localparam W = (HIGH_PERF) ? 64 : 32;

    logic [1:0] mode = MODE;
    logic rst, start, done;
    logic clk = 1;
    logic [9:0] ctr, c;
    integer start_time;
      
    logic valid_i,  ready_o;
    logic ready_i, valid_o;
    logic  [W-1:0] data_i;  
    logic [W-1:0] data_o;
    
    dilithium #(
        .HIGH_PERF(HIGH_PERF),
        .SEC_LEVEL(SEC_LEVEL)
    )
    dut (
        .clk (clk),
        .rst (rst),
        .start (start),
        .mode (mode),
        .valid_i (valid_i),
        .ready_i (ready_i),
        .data_i (data_i),
        .valid_o (valid_o),
        .ready_o (ready_o),
        .data_o (data_o)
    );

    localparam S1_SIZE = (SEC_LEVEL == 2) ? 3072
                        : (SEC_LEVEL == 3 ? 5120 : 5376);
    localparam S2_SIZE = (SEC_LEVEL == 2) ? 3072
                        : (SEC_LEVEL == 3 ? 6144 : 6144);
    localparam T0_SIZE = (SEC_LEVEL == 2) ? 13312
                        : (SEC_LEVEL == 3 ? 19968 : 26624);
    localparam T1_SIZE = (SEC_LEVEL == 2) ? 10240
                        : (SEC_LEVEL == 3 ? 15360 : 20480);
    // Ceil division for words
    localparam S1_WORDS_NUM = (S1_SIZE + W - 1) / W;
    localparam S2_WORDS_NUM = (S2_SIZE + W - 1) / W;
    localparam T0_WORDS_NUM = (T0_SIZE + W - 1) / W;
    localparam T1_WORDS_NUM = (T1_SIZE + W - 1) / W;
    localparam SEED_WORDS_NUM = (256 + W - 1) / W;
  
    logic [0:255] seed        [NUM_TV-1:0];
    logic [0:255] k           [NUM_TV-1:0];
    logic [0:255] rho         [NUM_TV-1:0];
    logic [0:255] tr          [NUM_TV-1:0];
    logic [0:S1_SIZE-1] s1    [NUM_TV-1:0];
    logic [0:S2_SIZE-1] s2    [NUM_TV-1:0];
    logic [0:T0_SIZE-1] t0    [NUM_TV-1:0];
    logic [0:T1_SIZE-1] t1    [NUM_TV-1:0];
  
    typedef enum logic [3:0] {
        S_INIT, S_START, S_Z, S_RHO, S_K,
        S_S1, S_S2, S_T1, S_T0, S_TR,
        S_STALL = 14, S_STOP  = 15
    } state_t;

    state_t state;   
  
    initial begin
        $readmemh("seed.txt",  seed);
        if (SEC_LEVEL == 2) begin
            $readmemh("/home/franos/projects/dilithium-comparison/tb/KAT/s1.txt",  s1);
            $readmemh("/home/franos/projects/dilithium-comparison/tb/KAT/s2.txt",  s2);
            $readmemh("/home/franos/projects/dilithium-comparison/tb/KAT/t0.txt",   t0);
            $readmemh("/home/franos/projects/dilithium-comparison/tb/KAT/t1.txt",  t1);
            $readmemh("/home/franos/projects/dilithium-comparison/tb/KAT/k.txt",   k);
            $readmemh("/home/franos/projects/dilithium-comparison/tb/KAT/rho.txt", rho);
            $readmemh("/home/franos/projects/dilithium-comparison/tb/KAT/tr.txt",  tr);
        end
        else if (SEC_LEVEL == 3) begin
            $readmemh("/home/franos/projects/dilithium-comparison/tb/KAT/s1_3.txt",  s1);
            $readmemh("/home/franos/projects/dilithium-comparison/tb/KAT/s2_3.txt",  s2);
            $readmemh("/home/franos/projects/dilithium-comparison/tb/KAT/t0_3.txt",   t0);
            $readmemh("/home/franos/projects/dilithium-comparison/tb/KAT/t1_3.txt",  t1);
            $readmemh("/home/franos/projects/dilithium-comparison/tb/KAT/k_3.txt",   k);
            $readmemh("/home/franos/projects/dilithium-comparison/tb/KAT/rho_3.txt", rho);
            $readmemh("/home/franos/projects/dilithium-comparison/tb/KAT/tr_3.txt",  tr);
        end
        else begin
            $readmemh("/home/franos/projects/dilithium-comparison/tb/KAT/s1_5.txt",  s1);
            $readmemh("/home/franos/projects/dilithium-comparison/tb/KAT/s2_5.txt",  s2);
            $readmemh("/home/franos/projects/dilithium-comparison/tb/KAT/t0_5.txt",   t0);
            $readmemh("/home/franos/projects/dilithium-comparison/tb/KAT/t1_5.txt",  t1);
            $readmemh("/home/franos/projects/dilithium-comparison/tb/KAT/k_5.txt",   k);
            $readmemh("/home/franos/projects/dilithium-comparison/tb/KAT/rho_5.txt", rho);
            $readmemh("/home/franos/projects/dilithium-comparison/tb/KAT/tr_5.txt",  tr);
        end
        
        valid_i = 0;
        ready_o = 0;
        data_i  = 0;
        ctr     = 0; 
        c       = 0;
    end


    // TODO: revise this
    always_ff @(posedge clk) begin
        rst     <= 0;
        start   <= 0;
        valid_i <= 0;
        ready_o <= 0;
        data_i  <= 0;
        
        unique case (state)
            S_INIT: begin
                start_time <= $time;
                rst <= 1;
                ctr <= ctr + 1;
                // Arbitrary number of reset cycles
                if (ctr == 3) begin
                    ctr <= 0;
                    state <= S_START;
                end
            end
            S_START: begin
                start <= 1;
                state <= S_Z;
            end
            S_Z: begin
                valid_i <= 1;
                data_i <= seed[c][ctr*W +: W];
               
                if (ready_i) begin
                    ctr <= ctr + 1;

                    if (ctr == SEED_WORDS_NUM - 1) begin
                        ctr <= 0;
                        state <= S_RHO;
                    end
                end 
            end
            S_RHO: begin
                ready_o <= 1;
                if (valid_o) begin
                    if (data_o !== rho[c][ctr*W+:W])
                        $display("[Rho, %d] Error: Expected %h, received %h", ctr, rho[c][ctr*W+:W], data_o); 
                
                    ctr <= ctr + 1;
                    
                    if (ctr == SEED_WORDS_NUM-1) begin
                        ctr <= 0;
                        state <= S_K;
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
                        state <= S_S1;
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
                        state <= S_T1;
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
                        state <= S_T0;
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
                        state <= S_TR;
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
                        state <= S_STOP;
                    end
                end
            end
            S_STOP: begin
                ready_o <= 1;
                c       <= c + 1;
                state   <= S_INIT;

                $display("KG[%d] completed in %d clock cycles", c, ($time-start_time)/P);

                if (c == NUM_TV-1) begin
                    c <= 0;
                    $display ("Testbench done!");
                    $finish;
                end
            end
            default: begin
                $fatal("Invalid state reached: %0d", state);
            end
        endcase
    end
      
  
    always #(`P/2) clk = ~clk;
  

endmodule
`undef P