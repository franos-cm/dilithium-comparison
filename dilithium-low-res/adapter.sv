`timescale 1ns / 1ps

module adapter_low_res (
    // High perf interface
    input  logic         clk,
    input  logic         rst,
    input  logic         start,
    input  logic [1:0]   mode,
    // input  logic         valid_i,
    // output logic         ready_i,
    // input  logic [31:0]  data_i,
    // output logic         valid_o,
    // input  logic         ready_o,
    // output logic [31:0]  data_o,
    output logic         done,

    // Low res interface, inverted
    output  logic [3:0]   op_in,
    output  logic         op_valid_in,
    input   logic         ready_out

    // output  logic [31:0]  data_in,
    // output  logic         ready_rcv_in,
    // output  logic         valid_in,
    // input   logic [31:0]  data_out,
    // input   logic         ready_rcv_out,
    // input   logic         valid_out
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
        KEYGEN_INGEST_SEED,
        KEYGEN_EXECUTE,
        KEYGEN_DUMP_SK,
        KEYGEN_DUMP_PK
    } state_t;
    state_t current_state, next_state;

    // State register
    always_ff @(posedge clk) begin
        if (rst)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end


    // Mealy Finite State Machine
    always_comb begin
        op_in = 0;
        op_valid_in = 0;
        done = 0;

        unique case (current_state)
            // Initial state
            IDLE: begin
                if (start) begin
                    if (mode == KEYGEN_MODE) begin
                        op_in = {INGEST_OPCODE, SEED_SUB_OPCODE};
                        op_valid_in = 1;
                        next_state = KEYGEN_INGEST_SEED;
                    end
                end
            end

            // Keygen states
            KEYGEN_INGEST_SEED: begin
                if (ready_out) begin
                    op_in = KEYGEN_OPCODE;
                    op_valid_in = 1;
                end
                next_state = ready_out ? KEYGEN_EXECUTE: KEYGEN_INGEST_SEED;
            end
            KEYGEN_EXECUTE: begin
                if (ready_out) begin
                    op_in = {DUMP_OPCODE, SK_SUB_OPCODE};
                    op_valid_in = 1;
                end
                next_state = ready_out ? KEYGEN_DUMP_SK: KEYGEN_EXECUTE;
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