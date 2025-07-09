`timescale 1ns / 1ps

module tb_verify;
    localparam integer HIGH_PERF = 1;
    localparam integer SEC_LEVEL = 2;
    localparam logic[1:0] MODE = 2'd1;
    localparam integer NUM_TV = 5;

    localparam integer P = 10;
    localparam integer W = (HIGH_PERF) ? 64 : 32;

    localparam MSG_SIZE = 3300*8; // Largest msg size from test vector
    localparam MSG_LEN_SIZE = $clog2(MSG_SIZE);
    localparam Z_SIZE = (SEC_LEVEL == 2) ? 18432
                        : (SEC_LEVEL == 3 ? 25600 : 35840);
    localparam H_SIZE = (SEC_LEVEL == 2) ? 672
                        : (SEC_LEVEL == 3 ? 488 : 664);
    localparam T1_SIZE = (SEC_LEVEL == 2) ? 10240
                         : (SEC_LEVEL == 3 ? 15360 : 20480);
    

    // Ceil division for words
    localparam Z_WORDS_NUM = (Z_SIZE + W - 1) / W;
    localparam H_WORDS_NUM = (H_SIZE + W - 1) / W;
    localparam T1_WORDS_NUM = (T1_SIZE + W - 1) / W;
    localparam RHO_WORDS_NUM = (255 + W - 1) / W;
  
    logic [0:255] rho                [NUM_TV-1:0];
    logic [0:255] c                  [NUM_TV-1:0];
    logic [0:MSG_SIZE-1] msg         [NUM_TV-1:0];
    logic [0:MSG_LEN_SIZE] msg_len   [NUM_TV-1:0];
    logic [0:Z_SIZE-1] z             [NUM_TV-1:0];
    logic [0:H_SIZE-1] h             [NUM_TV-1:0];
    logic [0:T1_SIZE-1] t1           [NUM_TV-1:0];


    logic tb_rst;
    logic [9:0] ctr, tv_ctr;
    integer start_time, dump_time;
    logic low_res_sk_done;

    logic clk = 1;
    logic [1:0] mode = MODE;
    logic rst, start, done;
    logic valid_i,  ready_o;
    logic ready_i, valid_o;
    logic  [W-1:0] data_i;  
    logic [W-1:0] data_o;
  
    // NOTE: different Dilithiums will have different transitions
    typedef enum logic [3:0] {
        S_INIT, S_START, LOAD_RHO, LOAD_C, LOAD_Z, LOAD_T1,
        LOAD_MLEN, LOAD_MSG, LOAD_H, UNLOAD_RESULT, S_STOP
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
        .mode (mode),
        .valid_i (valid_i),
        .ready_i (ready_i),
        .data_i (data_i),
        .valid_o (valid_o),
        .ready_o (ready_o),
        .data_o (data_o)
    );

  
    initial begin
        $readmemh("/home/franos/projects/dilithium-comparison/tb/KAT/shared/rho.txt", rho);
        $readmemh("/home/franos/projects/dilithium-comparison/tb/KAT/shared/msg.txt", msg);
        $readmemh("/home/franos/projects/dilithium-comparison/tb/KAT/shared/msg_len.txt", msg_len);
    
        if (SEC_LEVEL == 2) begin
            $readmemh("/home/franos/projects/dilithium-comparison/tb/KAT/t1_2.txt", t1);
            $readmemh("/home/franos/projects/dilithium-comparison/tb/KAT/c_2.txt", c);
            $readmemh("/home/franos/projects/dilithium-comparison/tb/KAT/z_2.txt", z);
            $readmemh("/home/franos/projects/dilithium-comparison/tb/KAT/h_2.txt", h);
        end
        else if (SEC_LEVEL == 3) begin
            $readmemh("/home/franos/projects/dilithium-comparison/tb/KAT/t1_3.txt", t1);
            $readmemh("/home/franos/projects/dilithium-comparison/tb/KAT/c_3.txt", c);
            $readmemh("/home/franos/projects/dilithium-comparison/tb/KAT/z_3.txt", z);
            $readmemh("/home/franos/projects/dilithium-comparison/tb/KAT/h_3.txt", h);
        end
        else begin
            $readmemh("/home/franos/projects/dilithium-comparison/tb/KAT/t1_5.txt", t1);
            $readmemh("/home/franos/projects/dilithium-comparison/tb/KAT/c_5.txt", c);
            $readmemh("/home/franos/projects/dilithium-comparison/tb/KAT/z_5.txt", z);
            $readmemh("/home/franos/projects/dilithium-comparison/tb/KAT/h_5.txt", h);
        end
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
                    state <= LOAD_RHO;
                end
                LOAD_RHO: begin
                    valid_i <= 1;
                    data_i <= rho[tv_ctr][ctr*W +: W];
                
                    if (ready_i) begin
                        if (ctr == RHO_WORDS_NUM-1) begin
                            state  <= LOAD_C;
                            ctr    <= 0;
                            data_i <= c[tv_ctr][0 +: W];
                        end else begin
                            ctr    <= ctr + 1;
                            data_i <= rho[tv_ctr][(ctr+1)*W +: W];
                        end
                    end
                end
                LOAD_C: begin
                    valid_i <= 1;
                    data_i <= c[tv_ctr][ctr*W +: W];
                
                    if (ready_i) begin
                        if (ctr == RHO_WORDS_NUM-1) begin
                            state  <= LOAD_Z;
                            ctr    <= 0;
                            data_i <= z[tv_ctr][0 +: W];
                        end else begin
                            ctr    <= ctr + 1;
                            data_i <= c[tv_ctr][(ctr+1)*W +: W];
                        end
                    end
                end
                LOAD_Z: begin
                    valid_i <= 1;
                    data_i <= z[tv_ctr][ctr*W +: W];
                
                    if (ready_i) begin
                        if (ctr == Z_WORDS_NUM-1) begin
                            state  <= LOAD_T1;
                            ctr    <= 0;
                            data_i <= t1[tv_ctr][0 +: W];
                        end else begin
                            ctr    <= ctr + 1;
                            data_i <= z[tv_ctr][(ctr+1)*W +: W];
                        end
                    end
                end
                LOAD_T1: begin
                    valid_i <= 1;
                    data_i <= t1[tv_ctr][ctr*W +: W];
                
                    if (ready_i) begin
                        if (ctr == T1_WORDS_NUM-1) begin
                            state  <= LOAD_MLEN;
                            ctr    <= 0;
                            data_i <= msg_len[tv_ctr];
                        end else begin
                            ctr    <= ctr + 1;
                            data_i <= t1[tv_ctr][(ctr+1)*W +: W];
                        end
                    end
                end
                LOAD_MLEN: begin
                    valid_i <= 1;
                    data_i <= msg_len[tv_ctr];
                
                    if (ready_i) begin
                        state  <= LOAD_MSG;
                        ctr    <= 0;
                        data_i <= msg[tv_ctr][0 +: W];
                    end
                end
                LOAD_MSG: begin
                    valid_i <= 1;
                    data_i <= msg[tv_ctr][ctr*W +: W];
                
                    if (ready_i) begin
                        if ((ctr+1)*W >= msg_len[tv_ctr]*8) begin
                            state  <= LOAD_H;
                            ctr    <= 0;
                            data_i <= h[tv_ctr][0 +: W];
                        end else begin
                            ctr    <= ctr + 1;
                            data_i <= msg[tv_ctr][(ctr+1)*W +: W];
                        end
                    end
                end
                LOAD_H: begin
                    valid_i <= 1;
                    data_i <= h[tv_ctr][ctr*W +: W];
                
                    if (ready_i) begin
                        if (ctr == H_WORDS_NUM-1) begin
                            state  <= UNLOAD_RESULT;
                            ctr    <= 0;
                        end else begin
                            ctr    <= ctr + 1;
                            data_i <= h[tv_ctr][(ctr+1)*W +: W];
                        end
                    end
                end
                UNLOAD_RESULT: begin
                    ready_o <= 1;
                    if (valid_o) begin
                        if (data_o == 1) begin
                            $display("Rejected");
                        end
                        state <= S_STOP;
                    end
                end
                S_STOP: begin
                    ready_o <= 1;
                    tv_ctr  <= tv_ctr + 1;
                    state   <= S_INIT;
                    ctr     <= 0;

                    $display("VY%d[%d] completed in %d clock cycles", SEC_LEVEL, tv_ctr, ($time-start_time)/10);

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