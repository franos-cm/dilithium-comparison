-- COPYRIGHT (c) 2021 ALL RIGHT RESERVED
-- Chair for Security Engineering
-- Georg Land (georg.land@rub.de)
-- License: see LICENSE file

-- THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY 
-- KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
-- PARTICULAR PURPOSE.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.dilithium_ii.all;
use work.interfaces_ii.all;
use work.memmap_ii.all;

entity store_ii is
    Port (
        clk : in std_logic;
        d   : in store_in_type;
        q   : out store_out_type
    );
end store_ii;

architecture Behavioral of store_ii is

    type state_type is (idle, s_seed, s_rho, s_t1, s_k, s_tr,
    s_s1_loadreg, s_s1_store, 
    s_s2_loadreg, s_s2_store, 
    s_t0, s_t0_finish, 
    s_c, s_z, s_z_finish,
    s_h, s_h_rcv, s_h_poly_rcv, s_h_poly);
    signal state, nextstate : state_type;
    
    signal rcntd : counter_in_type;
    signal rcntq : counter_out_type;
    signal rcnt : natural range 0 to 256/32-1;
    
    signal etareg : std_logic_vector(95 downto 0);
    signal etareg_en_load, etareg_en_store : std_logic;
    signal etareg_out : payload_array(0 to 3);
    signal elcntd, escntd : counter_in_type;
    signal elcntq, escntq : counter_out_type;
    
    signal hbuf : std_logic_vector(31 downto 0);
    signal hbuf_en : std_logic;
    signal omegacntd : counter_in_type;
    signal omegacntq : counter_out_type;
    signal omegacnt : natural range 0 to DILITHIUM_omega+DILITHIUM_k-1;
    
    signal memcntd : counter_in_type;
    signal memcntq : counter_out_type;
    signal memcnt : natural range 0 to DILITHIUM_N*DILITHIUM_k/4-1;
    type memcnt_pipeline_type is array(1 to DELAY_CONV_YZ) of natural range 0 to DILITHIUM_N*DILITHIUM_k/4-1;
    signal memcnt_pipeline : memcnt_pipeline_type;
    signal memcnt_en_pipeline : std_logic_vector(1 to DELAY_CONV_YZ) := (others => '0');
    signal memcnt_pipeline_en : std_logic;

begin
--------------------------------------------------------------------------------------------------
-- memory counter_ii
--------------------------------------------------------------------------------------------------
memory_counter: entity work.counter_ii
generic map (max_value => DILITHIUM_N*DILITHIUM_k/4-1)
port map (
    clk => clk,
    d => memcntd,
    q => memcntq,
    value => memcnt
);

--------------------------------------------------------------------------------------------------
-- storing h: omega counter_ii and h buffer
--------------------------------------------------------------------------------------------------
omega_counter: entity work.counter_ii
generic map (max_value => DILITHIUM_omega+DILITHIUM_k-1)
port map (
    clk => clk,
    d => omegacntd,
    q => omegacntq,
    value => omegacnt
);
h_buffer: process(clk)
begin
    if rising_edge(clk)
    then
        if hbuf_en = '1'
        then
            hbuf <= d.payload;
        end if;
    end if;
end process;

--------------------------------------------------------------------------------------------------
-- eta polynomials buffer register
--------------------------------------------------------------------------------------------------
eta2reg: if DILITHIUM_eta = 2 -- use the whole 96 bit register
generate
    eta_register: process(clk)
    begin
        if rising_edge(clk)
        then
            if etareg_en_load = '1'
            then
                for i in 0 to 3
                loop
                    etareg(95-i*8 downto 96-i*8-8) <= d.payload(i*8+7 downto i*8);
                end loop;
                etareg(63 downto 0) <= etareg(95 downto 32);
            elsif etareg_en_store = '1'
            then
                etareg(83 downto 0) <= etareg(95 downto 12);
                etareg(95 downto 84) <= (others => '0');
            end if;
        end if;
    end process;
    erogen: for i in 0 to 3
    generate
        etareg_out(i) <= std_logic_vector(
            to_unsigned(
                (
                (DILITHIUM_eta 
                - to_integer
                    (
                        unsigned
                        (
                            etareg(i*3+2 downto i*3)
                        )
                    )) mod DILITHIUM_Q
                ), 23));
    end generate;
    eta_load_counter: entity work.counter_ii
    generic map (max_value => 96/32-1)
    port map (
        clk => clk,
        d => elcntd,
        q => elcntq,
        value => open
    );
    eta_store_counter: entity work.counter_ii
    generic map (max_value => 96/12-1)
    port map (
        clk => clk,
        d => escntd,
        q => escntq,
        value => open
    );
end generate;
eta4reg: if DILITHIUM_eta = 4 -- use the lower 32 bits only
generate
    eta_register: process(clk)
    begin
        if rising_edge(clk)
        then
            if etareg_en_load = '1'
            then
                for i in 0 to 3
                loop
                    etareg(31-i*8 downto 32-i*8-8) <= d.payload(i*8+7 downto i*8);
                end loop;
            elsif etareg_en_store = '1'
            then
                etareg(15 downto 0) <= etareg(31 downto 16);
                etareg(31 downto 16) <= (others => '0');
            end if;
        end if;
    end process;
    erogen: for i in 0 to 3
    generate
        etareg_out(i) <= std_logic_vector(
            to_unsigned(
                (
                (DILITHIUM_eta 
                - to_integer
                    (
                        unsigned
                        (
                            etareg(i*4+3 downto i*4)
                        )
                    )) mod DILITHIUM_Q
                ), 23));
    end generate;
    eta_store_counter: entity work.counter_ii
    generic map (max_value => 32/16-1)
    port map (
        clk => clk,
        d => escntd,
        q => escntq,
        value => open
    );
end generate;

--------------------------------------------------------------------------------------------------
-- register counter_ii
--------------------------------------------------------------------------------------------------
reg_counter: entity work.counter_ii
generic map (max_value => 256/32-1)
port map (
    clk => clk,
    d => rcntd,
    q => rcntq,
    value => rcnt
);

--------------------------------------------------------------------------------------------------
-- reg output
--------------------------------------------------------------------------------------------------
q.rhoregd.data <= d.payload;
q.Kregd.data <= d.payload;
q.trregd.data <= d.payload;
q.chashregd.data <= d.payload;
q.seedregd.data <= d.payload;

--------------------------------------------------------------------------------------------------
-- z buffering
--------------------------------------------------------------------------------------------------
q.fifo160datad <= d.payload;

--------------------------------------------------------------------------------------------------
-- t0 and z buffering and conversion
--------------------------------------------------------------------------------------------------
q.zfifodatad <= d.payload;
q.fifot0datad <= d.payload;
convyzdatagen: process(state, d)
begin
    if state = s_t0 or state = s_t0_finish
    then
        for i in 0 to 3
        loop
            q.convyzd.data(i)(22 downto 13) <= (others => '0');
            q.convyzd.data(i)(12 downto 0) <= d.fifot0dataq((i+1)*13-1 downto i*13);
        end loop;
    else
        for i in 0 to 3
        loop
            q.convyzd.data(i)(22 downto DILITHIUM_loggamma1+1) <= (others => '0');
            q.convyzd.data(i)(DILITHIUM_loggamma1 downto 0) <= d.zfifodataq((i+1)*(DILITHIUM_loggamma1+1)-1 downto i*(DILITHIUM_loggamma1+1));
        end loop;
    end if;
end process;

--------------------------------------------------------------------------------------------------
-- memcnt pipeline
--------------------------------------------------------------------------------------------------
delay_memcnt: process(clk)
begin
    if rising_edge(clk)
    then
        if memcnt_pipeline_en = '1'
        then
            for i in DELAY_CONV_YZ downto 2
            loop
                memcnt_pipeline(i) <= memcnt_pipeline(i-1);
                memcnt_en_pipeline(i) <= memcnt_en_pipeline(i-1);
            end loop;
            memcnt_pipeline(1) <= memcnt;
            memcnt_en_pipeline(1) <= memcntd.en;
        end if;
    end if;
end process;

--------------------------------------------------------------------------------------------------
-- memory mux
--------------------------------------------------------------------------------------------------
mmux: process(state, d, memcnt, etareg_en_store, etareg_out, memcnt_pipeline, memcnt_en_pipeline)
variable m, p : natural;
variable memcntaddr : coef_addr_array(0 to 3);
variable memcntaddr_rev : coef_addr_array(0 to 3);
begin

    q.memd <= (others => ZEROMEM);
    
    for i in 0 to 3
    loop
        memcntaddr(i) := std_logic_vector(to_unsigned(memcnt mod (DILITHIUM_N/4), 6)) & std_logic_vector(to_unsigned(i, 2));
        for j in 0 to 7
        loop
            memcntaddr_rev(i)(j) := memcntaddr(i)(7-j);
        end loop;
    end loop;
    
    case state is 
        when s_t0 | s_t0_finish =>
            m := memory_map.t0(memcnt_pipeline(DELAY_CONV_YZ) / (DILITHIUM_N/4)).memory_index;
            p := memory_map.t0(memcnt_pipeline(DELAY_CONV_YZ) / (DILITHIUM_N/4)).poly_index;
            q.memd(m).wsel <= p;
            for i in 0 to 3
            loop
                memcntaddr(i) := std_logic_vector(to_unsigned(memcnt_pipeline(DELAY_CONV_YZ) mod (DILITHIUM_N/4), 6)) & std_logic_vector(to_unsigned(i, 2));
                for j in 0 to 7
                loop
                    q.memd(m).waddr(i)(j) <= memcntaddr(i)(7-j);
                end loop;
            end loop;
            q.memd(m).wen <= (others => memcnt_en_pipeline(DELAY_CONV_YZ));
            q.memd(m).wdata <= d.convyzq;
            
        when s_t1 =>
            m := memory_map.t1(memcnt / (DILITHIUM_N/4)).memory_index;
            p := memory_map.t1(memcnt / (DILITHIUM_N/4)).poly_index;
            q.memd(m).wsel <= p;
            q.memd(m).waddr <= memcntaddr_rev;
            q.memd(m).wen <= (others => d.fifo160q.valid);
            for i in 0 to 3
            loop
                q.memd(m).wdata(i)(22 downto 13) <= d.fifo160dataq(i*10+9 downto i*10);
                q.memd(m).wdata(i)(12 downto 0) <= (others => '0');
            end loop;
            
        when s_s1_loadreg | s_s1_store =>
            m := memory_map.s1(memcnt / (DILITHIUM_N/4)).memory_index;
            p := memory_map.s1(memcnt / (DILITHIUM_N/4)).poly_index;
            q.memd(m).wsel <= p;
            q.memd(m).waddr <= memcntaddr_rev;
            q.memd(m).wen <= (others => etareg_en_store);
            q.memd(m).wdata <= etareg_out;
            
        when s_s2_loadreg | s_s2_store =>
            m := memory_map.s2(memcnt / (DILITHIUM_N/4)).memory_index;
            p := memory_map.s2(memcnt / (DILITHIUM_N/4)).poly_index;
            q.memd(m).wsel <= p;
            q.memd(m).waddr <= memcntaddr_rev;
            q.memd(m).wen <= (others => etareg_en_store);
            q.memd(m).wdata <= etareg_out;
            
        when s_z | s_z_finish =>
            m := memory_map.zy((memcnt_pipeline(DELAY_CONV_YZ) / (DILITHIUM_N/4)) mod DILITHIUM_l).memory_index;
            p := memory_map.zy((memcnt_pipeline(DELAY_CONV_YZ) / (DILITHIUM_N/4)) mod DILITHIUM_l).poly_index;
            q.memd(m).wsel <= p;
            for i in 0 to 3
            loop
                memcntaddr(i) := std_logic_vector(to_unsigned(memcnt_pipeline(DELAY_CONV_YZ) mod (DILITHIUM_N/4), 6)) & std_logic_vector(to_unsigned(i, 2));
                for j in 0 to 7
                loop
                    q.memd(m).waddr(i)(j) <= memcntaddr(i)(7-j);
                end loop;
            end loop;
            q.memd(m).wen <= (others => memcnt_en_pipeline(DELAY_CONV_YZ));
            q.memd(m).wdata <= d.convyzq;
            
        when others =>
    end case;
end process;

--------------------------------------------------------------------------------------------------
-- state machine
--------------------------------------------------------------------------------------------------
states: process(clk)
begin
    if rising_edge(clk)
    then
        if d.rst = '1'
        then
            state <= idle;
        else
            state <= nextstate;
        end if;
    end if;
end process;

signals: process(state, d, escntq, hbuf, rcntq, memcntq, memcnt, elcntq, omegacntq, omegacnt, memcnt_en_pipeline)
begin
    nextstate <= state;
    
    q.ready <= '0';
    q.ready_rcv <= '0';
    
    rcntd.en <= '0';
    rcntd.rst <= '0';
    
    q.rhoregd.en_rotate <= '0';
    q.rhoregd.en_write <= '0';
    q.Kregd.en_rotate <= '0';
    q.Kregd.en_write <= '0';
    q.trregd.en_rotate <= '0';
    q.trregd.en_write <= '0';
    q.chashregd.en_rotate <= '0';
    q.chashregd.en_write <= '0';
    q.seedregd.en_rotate <= '0';
    q.seedregd.en_write <= '0';
    
    q.hregd <= ZEROHREG;
    
    q.fifot0d.en <= '1'; -- keep fifo in load state...
    q.fifot0d.rst <= '0';
    q.fifot0d.valid <= '0'; -- valid is 0 anyways
    q.fifot0d.ready_rcv <= '0';
    
    elcntd.en <= '0';
    elcntd.rst <= '0';
    escntd.en <= '0';
    escntd.rst <= '0';
    etareg_en_load <= '0';
    etareg_en_store <= '0';
    
    omegacntd.en <= '0';
    omegacntd.rst <= '0';
    hbuf_en <= '0';
    
    q.zfifod.en <= '1'; -- keep fifo in load state...
    q.zfifod.rst <= '0';
    q.zfifod.valid <= '0'; -- valid is 0 anyways
    q.zfifod.ready_rcv <= '0';
    q.convyzd.en <= '0';
    q.convyzd.sub <= (others => '0');
    
    q.fifo160d.en <= '1'; -- keep fifo in load state...
    q.fifo160d.rst <= '0';
    q.fifo160d.valid <= '0'; -- valid is 0 anyways
    q.fifo160d.ready_rcv <= '0';
    
    memcntd.en <= '0';
    memcntd.rst <= '0';
    memcnt_pipeline_en <= '0';
    
    case state is
        when idle => 
            q.ready <= '1';
            
            q.zfifod.rst <= '1';
            q.fifo160d.rst <= '1';
            q.fifot0d.rst <= '1';
            
            rcntd.rst <= '1';
            elcntd.rst <= '1';
            escntd.rst <= '1';
            omegacntd.rst <= '1';
            memcntd.rst <= '1';
    
            
            if d.en = '1'
            then
                case d.payload_type is
                    when PAYLOAD_TYPE_PK => nextstate <= s_rho;
                    when PAYLOAD_TYPE_SK => nextstate <= s_rho;
                    when PAYLOAD_TYPE_SIG => nextstate <= s_c;
                    when PAYLOAD_TYPE_SEED => nextstate <= s_seed;
                    when others =>
                end case;
            end if;
        
        -----------------------------------------------------------------------------
        -- store keygen_ii seed
        -----------------------------------------------------------------------------
        when s_seed => 
            q.ready_rcv <= '1';
            
            rcntd.en <= d.valid;
            q.seedregd.en_rotate <= d.valid;
            q.seedregd.en_write <= d.valid;
            
            if rcntq.max = '1' and d.valid = '1'
            then
                nextstate <= idle;
            end if;
        
        -----------------------------------------------------------------------------
        -- store rho
        -----------------------------------------------------------------------------
        when s_rho => 
            q.ready_rcv <= d.valid;
            rcntd.en <= d.valid;
            q.rhoregd.en_rotate <= d.valid;
            q.rhoregd.en_write <= d.valid;
            
            if rcntq.max = '1' and d.valid = '1'
            then
                case d.payload_type is
                    when PAYLOAD_TYPE_PK => nextstate <= s_t1;
                    when PAYLOAD_TYPE_SK => nextstate <= s_k; rcntd.rst <= '1';
                    when others => nextstate <= idle; -- error
                end case;
            end if;
        
        -----------------------------------------------------------------------------
        -- store K
        -----------------------------------------------------------------------------
        when s_k =>
            q.ready_rcv <= d.valid;
            rcntd.en <= d.valid;
            q.Kregd.en_rotate <= d.valid;
            q.Kregd.en_write <= d.valid;
            
            if rcntq.max = '1' and d.valid = '1'
            then
                nextstate <= s_tr;
                rcntd.rst <= '1';
            end if;
        
        -----------------------------------------------------------------------------
        -- store tr
        -----------------------------------------------------------------------------
        when s_tr =>
            q.ready_rcv <= d.valid;
            rcntd.en <= d.valid;
            q.trregd.en_rotate <= d.valid;
            q.trregd.en_write <= d.valid;
            
            if rcntq.max = '1' and d.valid = '1'
            then
                nextstate <= s_s1_loadreg;
            end if;
        
        -----------------------------------------------------------------------------
        -- store t1
        -----------------------------------------------------------------------------
        when s_t1 =>
            q.ready_rcv <= d.fifo160q.ready_rcv; -- and not d.fifo160q.toggle;
            q.fifo160d.valid <= d.valid;
            q.fifo160d.ready_rcv <= '1';
            memcntd.en <= d.fifo160q.valid;
            
            if memcntq.max = '1' and d.fifo160q.valid = '1'
            then
                nextstate <= idle; -- loading pk done
            end if;
        
        -----------------------------------------------------------------------------
        -- store s1
        -----------------------------------------------------------------------------
        when s_s1_loadreg =>
            q.ready_rcv <= d.valid;
            elcntd.en <= d.valid;
            etareg_en_load <= d.valid;
            escntd.rst <= '1'; -- prepare for storing
            
            if DILITHIUM_eta = 4
            then
                if d.valid = '1'
                then
                    nextstate <= s_s1_store;
                end if;
            elsif DILITHIUM_eta = 2
            then
                if elcntq.max = '1' and d.valid = '1'
                then
                    nextstate <= s_s1_store;
                end if;
            else
                report "bad eta" severity failure;
            end if;
        
        when s_s1_store =>
            q.ready_rcv <= '0';
            escntd.en <= '1';
            etareg_en_store <= '1';
            memcntd.en <= '1';
            elcntd.rst <= '1'; -- prepare for loading
            
            if memcnt = DILITHIUM_l*DILITHIUM_N/4-1
            then
                memcntd.rst <= '1';
                nextstate <= s_s2_loadreg; -- loading s1 done
            elsif escntq.max = '1'
            then
                nextstate <= s_s1_loadreg;
            end if;
        
        -----------------------------------------------------------------------------
        -- store s2
        -----------------------------------------------------------------------------
        when s_s2_loadreg =>
            q.ready_rcv <= d.valid;
            elcntd.en <= d.valid;
            etareg_en_load <= d.valid;
            escntd.rst <= '1'; -- prepare for storing
            
            if DILITHIUM_eta = 4
            then
                if d.valid = '1'
                then
                    nextstate <= s_s2_store;
                end if;
            elsif DILITHIUM_eta = 2
            then
                if elcntq.max = '1' and d.valid = '1'
                then
                    nextstate <= s_s2_store;
                end if;
            else
                report "bad eta" severity failure;
            end if;
        
        when s_s2_store =>
            q.ready_rcv <= '0';
            escntd.en <= '1';
            etareg_en_store <= '1';
            memcntd.en <= '1';
            elcntd.rst <= '1'; -- prepare for loading
            
            if memcntq.max = '1'
            then
                memcntd.rst <= '1';
                nextstate <= s_t0; -- loading s2 done
            elsif escntq.max = '1'
            then
                nextstate <= s_s2_loadreg;
            end if;
        
        -----------------------------------------------------------------------------
        -- store t0
        -----------------------------------------------------------------------------
        when s_t0 =>
            q.ready_rcv <= d.fifot0q.ready_rcv; -- and not d.fifot0q.toggle;
            q.fifot0d.valid <= d.valid;
            q.fifot0d.ready_rcv <= '1';
            q.convyzd.en <= '1';
            q.convyzd.sub <= std_logic_vector(to_unsigned(2**12, 23));
            memcntd.en <= d.fifot0q.valid;
            memcnt_pipeline_en <= '1';
            
            if memcntq.max = '1' and d.fifot0q.valid = '1'
            then
                nextstate <= s_t0_finish;
            end if;
        
        when s_t0_finish =>
            q.convyzd.en <= '1';
            q.convyzd.sub <= std_logic_vector(to_unsigned(2**12, 23));
            memcnt_pipeline_en <= '1';
            if memcnt_pipeline(DELAY_CONV_YZ) = DILITHIUM_k*DILITHIUM_N/4-1
            then
                nextstate <= idle; -- loading sk done
            end if;
        
        -----------------------------------------------------------------------------
        -- store c
        -----------------------------------------------------------------------------
        when s_c =>
            q.ready_rcv <= d.valid;
            rcntd.en <= d.valid;
            q.chashregd.en_rotate <= d.valid;
            q.chashregd.en_write <= d.valid;
            
            memcntd.rst <= '1'; -- prepare for s_z
            
            if rcntq.max = '1'
            then
                nextstate <= s_z;
            end if;
        
        -----------------------------------------------------------------------------
        -- store z
        -----------------------------------------------------------------------------
        when s_z =>
            q.ready_rcv <= d.zfifoq.ready_rcv;
            q.zfifod.valid <= d.valid;
            q.zfifod.ready_rcv <= '1';
            q.convyzd.en <= '1';
            q.convyzd.sub <= std_logic_vector(to_unsigned(2**DILITHIUM_loggamma1, 23));
            memcntd.en <= d.zfifoq.valid;
            memcnt_pipeline_en <= '1';
            
            if memcnt = DILITHIUM_l*DILITHIUM_N/4-1
            then
                nextstate <= s_z_finish;
            end if;
            
        when s_z_finish =>
            q.convyzd.en <= '1';
            q.convyzd.sub <= std_logic_vector(to_unsigned(2**DILITHIUM_loggamma1, 23));
            memcnt_pipeline_en <= '1';
            if memcnt_pipeline(DELAY_CONV_YZ) = DILITHIUM_l*DILITHIUM_N/4-1
            then
                nextstate <= s_h_rcv;
            end if;
        
        -----------------------------------------------------------------------------
        -- unpack h
        -----------------------------------------------------------------------------
        when s_h_rcv => 
            -- q.ready_rcv <= '1';
            -- hbuf_en <= d.valid;
            
            if d.valid = '1'
            then
                hbuf_en <= '1';
                q.ready_rcv <= '1';
                nextstate <= s_h;
            end if;
        
        when s_h => 
            omegacntd.en <= '1';
            q.hregd.en_rotate_data <= '1';
            q.hregd.en_write_data <= '1';
            q.hregd.data_offset <= hbuf(31-(omegacnt mod 4)*8 downto 32-(omegacnt mod 4)*8-8);
            
            if (omegacnt mod 4) = 3
            then
                if omegacnt = DILITHIUM_omega-1
                then
                    nextstate <= s_h_poly_rcv;
                else
                    nextstate <= s_h_rcv;
                end if;
            elsif omegacnt = DILITHIUM_omega-1
            then
                nextstate <= s_h_poly;
            end if; 
        
        when s_h_poly_rcv =>
            --q.ready_rcv <= '1';
            --hbuf_en <= d.valid;
            
            if d.valid = '1'
            then
                hbuf_en <= '1';
                q.ready_rcv <= '1';
                nextstate <= s_h_poly;
            end if;
        
        when s_h_poly =>
            omegacntd.en <= '1';
            q.hregd.en_rotate_poly <= '1';
            q.hregd.en_write_poly <= '1';
            q.hregd.poly_offset <= hbuf(31-(omegacnt mod 4)*8 downto 32-(omegacnt mod 4)*8-8);
            
            if omegacntq.max = '1'
            then
                nextstate <= idle; -- DONE loading signature
            elsif (omegacnt mod 4) = 3
            then
                nextstate <= s_h_poly_rcv;
            end if;
        
    end case;

end process;

end Behavioral;
