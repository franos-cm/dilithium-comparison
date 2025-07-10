`timescale 1ns / 1ps

module adapter_low_res (
    // High perf interface
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

    // Low res interface, inverted
    output  logic [3:0]   op_in,
    output  logic         op_valid_in,
    input   logic         ready_out,
    output  logic         ready_rcv_in,
    input   logic [31:0]  data_out,
    input   logic         ready_rcv_out,
    input   logic         valid_out
);

    localparam logic[1:0] KEYGEN_MODE = 0;
    localparam logic[1:0] SIGN_MODE = 2'd2;
    localparam logic[1:0] VERIFY_MODE = 2'd1;

    localparam logic[1:0] INGEST_OPCODE = 2'b11;
    localparam logic[1:0] DUMP_OPCODE = 2'b10;
    localparam logic[1:0] PK_SUB_OPCODE = 2'b00;
    localparam logic[1:0] SK_SUB_OPCODE = 2'b01;
    localparam logic[1:0] SIG_SUB_OPCODE = 2'b10;
    localparam logic[1:0] SEED_SUB_OPCODE = 2'b11;

    localparam logic[3:0] KEYGEN_OPCODE = 4'b0111;

    localparam logic[3:0] PRE_VERIFY_OPCODE = 4'b0101;
    localparam logic[3:0] DIGEST_OPCODE = 4'b0001;
    localparam logic[3:0] VERIFY_OPCODE = 4'b0100;


    // constant PAYLOAD_TYPE_PK   : std_logic_vector(1 downto 0) := "00";
    // constant PAYLOAD_TYPE_SK   : std_logic_vector(1 downto 0) := "01";
    // constant PAYLOAD_TYPE_SIG  : std_logic_vector(1 downto 0) := "10";
    // constant PAYLOAD_TYPE_SEED : std_logic_vector(1 downto 0) := "11";
    
    // constant OPCODE_IDLE : std_logic_vector(3 downto 0)         := "0000";
    // constant OPCODE_STOR : std_logic_vector(3 downto 0)         := "1100"; -- upper bit indicates 2-bit opcode with 2-bit parameter
    // constant OPCODE_LOAD : std_logic_vector(3 downto 0)         := "1000";
    // constant OPCODE_DIGEST_MSG : std_logic_vector(3 downto 0)   := "0001"; -- upper bit indicates 4-bit opcode
    // constant OPCODE_SIGN : std_logic_vector(3 downto 0)         := "0010";
    // constant OPCODE_SIGN_PRECOMP : std_logic_vector(3 downto 0) := "0011"; 
    // constant OPCODE_VRFY : std_logic_vector(3 downto 0)         := "0100";
    // constant OPCODE_VRFY_PRECOMP : std_logic_vector(3 downto 0) := "0101";
    // constant OPCODE_KGEN : std_logic_vector(3 downto 0)         := "0111";


    // FSM states
    typedef enum logic [5:0] {
        IDLE,
        // Keygen states
        KEYGEN_INGEST_SEED,
        KEYGEN_EXECUTE,
        KEYGEN_DUMP_SK,
        KEYGEN_DUMP_PK,
        // Verify states
        VERIFY_INGEST_PK,
        VERIFY_INGEST_SIG,
        VERIFY_PREPROCESS,
        VERIFY_INGEST_MSG_LEN,
        VERIFY_INGEST_MSG,
        VERIFY_EXECUTE,
        VERIFY_WAIT_DUMP
    } state_t;
    state_t current_state, next_state;

    // State register
    always_ff @(posedge clk) begin
        if (rst)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end


    logic verify_reg_enable, verify_result;
    regm #(
        .WIDTH(1)
    ) verify_result_reg (
        .clk(clk),
        .rst(rst),
        .en(verify_reg_enable),
        .data_in(ready_rcv_out),
        .data_out(verify_result)
    );

    logic handshake_completed, last_msg_word_en, last_msg_word_rst, last_msg_word;
    assign handshake_completed = ready_rcv_out & valid_i;
    assign last_msg_word_rst = handshake_completed & last_msg_word;
    latch msg_end_latch (
        .clk (clk),
        .rst(rst | last_msg_word_rst),
        .set(last_msg_word_en),
        .q(last_msg_word)
    );

    logic[31:0] msg_len_ctr;
    logic len_ctr_enable, len_ctr_load;
    always_ff @(posedge clk) begin
        if (len_ctr_load) begin
            msg_len_ctr = data_i;
        end
        else if (len_ctr_enable) begin
            msg_len_ctr = msg_len_ctr < 4 ? 0 : msg_len_ctr - 4;
        end
    end

    // Mealy Finite State Machine
    // TODO: check if DONE signals are being correctly asserted
    always_comb begin
        data_o         = data_out;
        valid_o        = valid_out;
        ready_i        = ready_rcv_out;

        ready_rcv_in   = ready_o;
        op_in          = 0;
        op_valid_in    = 0;
        
        len_ctr_load   = 0;
        len_ctr_enable = 0;
        done           = 0;

        unique case (current_state)
            // Initial state
            IDLE: begin
                if (start) begin
                    if (mode == KEYGEN_MODE) begin
                        op_in = {INGEST_OPCODE, SEED_SUB_OPCODE};
                        op_valid_in = 1;
                        next_state = KEYGEN_INGEST_SEED;
                    end
                    else if (mode == VERIFY_MODE) begin
                        op_in = {INGEST_OPCODE, PK_SUB_OPCODE};
                        op_valid_in = 1;
                        next_state = VERIFY_INGEST_PK;
                    end
                end
            end

            // Verify states
            VERIFY_INGEST_PK: begin
                next_state = VERIFY_INGEST_PK;
                if (ready_out) begin
                    op_in = {INGEST_OPCODE, SIG_SUB_OPCODE};
                    op_valid_in = 1;
                    next_state = VERIFY_INGEST_SIG;
                end
            end
            VERIFY_INGEST_SIG: begin
                next_state = VERIFY_INGEST_SIG;
                if (ready_out) begin
                    op_in = PRE_VERIFY_OPCODE;
                    op_valid_in = 1;
                    next_state = VERIFY_PREPROCESS;
                end
            end
            VERIFY_PREPROCESS: begin
                next_state = ready_out ? VERIFY_INGEST_MSG_LEN : VERIFY_PREPROCESS;
            end
            VERIFY_INGEST_MSG_LEN: begin
                next_state = VERIFY_INGEST_MSG_LEN;
                ready_i = valid_i;
                if (valid_i) begin
                    len_ctr_load = 1;
                    op_valid_in = 1;
                    last_msg_word_en = (data_i <= 4);
                    op_in = DIGEST_OPCODE;
                    next_state = VERIFY_INGEST_MSG;
                end
            end
            VERIFY_INGEST_MSG: begin
                next_state = VERIFY_INGEST_MSG;
                len_ctr_enable = handshake_completed;
                last_msg_word_en = (handshake_completed & (msg_len_ctr <= 8));
                ready_rcv_in = handshake_completed & last_msg_word;

                if (ready_out) begin
                    op_in = VERIFY_OPCODE;
                    op_valid_in = 1;
                    next_state = VERIFY_EXECUTE;
                end
            end
            // NOTE: have state transition and result latching dependent
            //       on two different signals seem risky...
            VERIFY_EXECUTE: begin
                ready_rcv_in = 0;
                valid_o      = 0;
                verify_reg_enable = valid_out;
                next_state = ready_out ? VERIFY_WAIT_DUMP : VERIFY_EXECUTE;
            end
            VERIFY_WAIT_DUMP: begin
                ready_rcv_in = 0;
                valid_o = 1;
                done = 1;
                data_o = {31'b0, verify_result};
                next_state = ready_o ? IDLE : VERIFY_WAIT_DUMP;
            end

            // Keygen states
            KEYGEN_INGEST_SEED: begin
                if (ready_out) begin
                    op_in = KEYGEN_OPCODE;
                    op_valid_in = 1;
                end
                next_state = ready_out ? KEYGEN_EXECUTE : KEYGEN_INGEST_SEED;
            end
            KEYGEN_EXECUTE: begin
                if (ready_out) begin
                    op_in = {DUMP_OPCODE, SK_SUB_OPCODE};
                    op_valid_in = 1;
                end
                next_state = ready_out ? KEYGEN_DUMP_SK : KEYGEN_EXECUTE;
            end
            KEYGEN_DUMP_SK: begin
                if (ready_out) begin
                    op_in = {DUMP_OPCODE, PK_SUB_OPCODE};
                    op_valid_in = 1;
                end
                next_state = ready_out ? KEYGEN_DUMP_PK: KEYGEN_DUMP_SK;
            end
            KEYGEN_DUMP_PK: begin
                next_state = ready_out ? IDLE : KEYGEN_DUMP_PK;
                done = ready_out;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule