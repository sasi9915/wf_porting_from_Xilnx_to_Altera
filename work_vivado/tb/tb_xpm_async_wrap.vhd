library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_xpm_async_wrap is
end entity;

architecture sim of tb_xpm_async_wrap is

    constant g_DATA_WIDTH    : natural := 10;
    constant c_NUM_TRANSFERS : natural := 50;

    constant c_WR_CLK_PERIOD         : time    := 10 ns;
    constant c_RD_CLK_PERIOD         : time    := 14 ns;
    constant c_WR_RESET_GUARD_CYCLES : natural := 40;
    constant c_RD_RESET_GUARD_CYCLES : natural := 40;

    signal i_wr_clk    : std_logic := '0';
    signal i_rd_clk    : std_logic := '0';
    signal i_wr_resetn : std_logic := '0';

    signal i_wrreq : std_logic                                   := '0';
    signal i_rdreq : std_logic                                   := '0';
    signal i_data  : std_logic_vector(g_DATA_WIDTH - 1 downto 0) := (others => '0');

    signal o_q_val           : std_logic;
    signal o_q               : std_logic_vector(g_DATA_WIDTH - 1 downto 0);
    signal o_wr_usedw        : std_logic_vector(15 downto 0);
    signal o_rd_usedw        : std_logic_vector(15 downto 0);
    signal o_wr_full         : std_logic;
    signal o_rd_empty        : std_logic;
    signal o_wr_almost_full  : std_logic;
    signal o_rd_almost_empty : std_logic;

    signal   r_write_count      : natural := 0;
    signal   r_read_count       : natural := 0;
    constant c_SINGLE_TEST_DATA : natural := 15;

begin

    -- dut instantiation

    dut : entity work.xpm_fifo_async_wrap
        generic map(
            g_DATA_WIDTH => g_DATA_WIDTH
        )
        port map(
            i_wr_resetn       => i_wr_resetn,
            i_wr_clk          => i_wr_clk,
            i_rd_clk          => i_rd_clk,
            i_wrreq           => i_wrreq,
            i_data            => i_data,
            i_rdreq           => i_rdreq,
            o_q_val           => o_q_val,
            o_q               => o_q,
            o_wr_usedw        => o_wr_usedw,
            o_rd_usedw        => o_rd_usedw,
            o_wr_full         => o_wr_full,
            o_rd_empty        => o_rd_empty,
            o_wr_almost_full  => o_wr_almost_full,
            o_rd_almost_empty => o_rd_almost_empty
        );

    -- clock generation

    wr_clk_gen : process
    begin
        i_wr_clk <= '1';
        wait for c_WR_CLK_PERIOD / 2;
        i_wr_clk <= '0';
        wait for c_WR_CLK_PERIOD / 2;
    end process;

    rd_clk_gen : process
    begin
        i_rd_clk <= '1';
        wait for c_RD_CLK_PERIOD / 2;
        i_rd_clk <= '0';
        wait for c_RD_CLK_PERIOD / 2;
    end process;

    -- resest gen
    rst_proc : process
    begin
        i_wr_resetn <= '0';
        wait for 1000 ns;
        i_wr_resetn <= '1';
        wait;
    end process;

    -------------------------------------------- *NOTE --------------------------------------------
    -- Default test enabled now: full transfer test (0 to c_NUM_TRANSFERS-1).
    -- If you want to run the single write/read test below, comment out BOTH:
    -- 1) wr_proc
    -- 2) rd_proc
    ----------------------------------------------------------------------------------------------

   -- write process ( WR_CLK domain )
    wr_proc : process
        variable v_data : natural := 0;
    begin
        i_wrreq <= '0';
        i_data  <= (others => '0');

        wait until i_wr_resetn = '1';
        for i in 1 to c_WR_RESET_GUARD_CYCLES loop
            wait until rising_edge(i_wr_clk);
        end loop;

        while v_data < c_NUM_TRANSFERS loop
            wait until rising_edge(i_wr_clk);

            if o_wr_full = '0' then
                i_data        <= std_logic_vector(to_unsigned(v_data, g_DATA_WIDTH));
                i_wrreq       <= '1';
                wait until rising_edge(i_wr_clk);
                i_wrreq       <= '0';
                r_write_count <= r_write_count + 1;
                v_data        := v_data + 1;
            end if;
        end loop;

        i_wrreq <= '0';
        i_data  <= (others => '0');
        wait;
    end process wr_proc;

    -- read process ( RD_CLK domain )
    rd_proc : process
        variable v_expected_data : natural := 0;
    begin
        i_rdreq <= '0';

        wait until i_wr_resetn = '1';
        for i in 1 to c_RD_RESET_GUARD_CYCLES loop
            wait until rising_edge(i_rd_clk);
        end loop;

        -- Start checking after all writes are complete for deterministic debug.
        wait until r_write_count = c_NUM_TRANSFERS;

        while v_expected_data < c_NUM_TRANSFERS loop
            wait until rising_edge(i_rd_clk);

            if o_rd_empty = '0' then
                -- FWFT mode: output data is already valid when empty='0'.
                assert o_q = std_logic_vector(to_unsigned(v_expected_data, g_DATA_WIDTH))
                report "Data mismatch at expected read value " & integer'image(v_expected_data) & ", got " & integer'image(to_integer(unsigned(o_q)))
                severity error;

                -- Pop exactly one word.
                i_rdreq <= '1';
                wait until rising_edge(i_rd_clk);
                i_rdreq <= '0';

                v_expected_data := v_expected_data + 1;
                r_read_count    <= r_read_count + 1;
            end if;
        end loop;

        report "ASYNC FIFO Test Completed. Total Writes: " & integer'image(c_NUM_TRANSFERS) & ", Total Reads: " & integer'image(v_expected_data);
        wait;

    end process rd_proc;

    -------------------------------------------- NOTE --------------------------------------------
    -- Optional test: single write/read in FWFT mode.
    -- How to use:
    -- 1) comment out wr_proc and rd_proc above
    -- 2) uncomment this process
    --
    -- This test writes c_SINGLE_TEST_DATA (=15), then reads as soon as data appears
    -- on the read side (after async clock-domain crossing delay).
    ----------------------------------------------------------------------------------------------
    -- single_wr_rd_proc : process
    -- begin
    --     i_wrreq <= '0';
    --     i_rdreq <= '0';
    --     i_data  <= (others => '0');

    --     wait until i_wr_resetn = '1';

    --     for i in 1 to c_WR_RESET_GUARD_CYCLES loop
    --         wait until rising_edge(i_wr_clk);
    --     end loop;

    --     for i in 1 to c_RD_RESET_GUARD_CYCLES loop
    --         wait until rising_edge(i_rd_clk);
    --     end loop;

        
    --     i_data        <= std_logic_vector(to_unsigned(c_SINGLE_TEST_DATA, g_DATA_WIDTH));
    --     i_wrreq       <= '1';
    --     wait until rising_edge(i_wr_clk);
    --     i_wrreq       <= '0';
    --     r_write_count <= r_write_count + 1;

    --     -- On read side, wait until FIFO is not empty (FWFT data is already on o_q)
    --     wait until rising_edge(i_rd_clk);
    --     while o_rd_empty = '1' loop
    --         wait until rising_edge(i_rd_clk);
    --     end loop;

    --     assert o_q = std_logic_vector(to_unsigned(c_SINGLE_TEST_DATA, g_DATA_WIDTH))
    --     report "Single test mismatch before rdreq. expected=" & integer'image(c_SINGLE_TEST_DATA) & ", got=" & integer'image(to_integer(unsigned(o_q)))
    --     severity error;

    --     -- Pop that one word
    --     i_rdreq      <= '1';
    --     wait until rising_edge(i_rd_clk);
    --     i_rdreq      <= '0';
    --     r_read_count <= r_read_count + 1;

    --     report "Single async FWFT test passed. Wrote and read value " & integer'image(c_SINGLE_TEST_DATA)
    --     severity note;
    --     wait;
    -- end process single_wr_rd_proc;

end architecture sim;
