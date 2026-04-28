library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_intel_sync_fifo_wrap is
end entity;

architecture sim of tb_intel_sync_fifo_wrap is

    function f_is_write_gap_value(value : natural) return boolean is
    begin
        return (value = 10) or (value = 20) or (value = 30);
    end function f_is_write_gap_value;

    constant g_DATA_WIDTH       : natural := 10;
    constant CLK_PERIOD         : time    := 10 ns;
    constant NUM_TRANSFERS      : natural := 50;
    constant RESET_GUARD_CYCLES : natural := 8;

    signal i_clk          : std_logic                                   := '0';
    signal i_resetn       : std_logic                                   := '0';
    signal i_wrreq        : std_logic                                   := '0';
    signal i_data         : std_logic_vector(g_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal i_rdreq        : std_logic                                   := '0';
    signal o_q            : std_logic_vector(g_DATA_WIDTH - 1 downto 0);
    signal o_q_val        : std_logic                                   := '0';
    signal o_usedw        : std_logic_vector(15 downto 0)               := (others => '0');
    signal o_full         : std_logic                                   := '0';
    signal o_empty        : std_logic                                   := '0';
    signal o_almost_full  : std_logic                                   := '0';
    signal o_almost_empty : std_logic                                   := '0';

    signal write_count   : natural   := 0;
    signal read_count    : natural   := 0;
    signal done_reported : std_logic := '0';

    ---monitor signlas 

    signal cycle_count        : natural := 0;
    signal input_count        : natural := 0;
    signal output_count         : natural := 0;
    signal max_usedw          : natural := 0;
    signal backpreuusre_count : natural := 0;
    signal write_cycle        : natural := 0;
    signal read_cycle         : natural := 0;
    signal latency            : natural := 0;

begin

    -- dut instation

    dut : entity work.intel_fifo_sync_wrap
        generic map(
            g_DATA_WIDTH    => g_DATA_WIDTH
        )
        port map(
            i_clk          => i_clk,
            i_resetn       => i_resetn,
            i_wrreq        => i_wrreq,
            i_data         => i_data,
            i_rdreq        => i_rdreq,
            o_q            => o_q,
            o_q_val        => o_q_val,
            o_usedw        => o_usedw,
            o_full         => o_full,
            o_empty        => o_empty,
            o_almost_full  => o_almost_full,
            o_almost_empty => o_almost_empty
        );
    

    -- clock generation

    clk_gen : process
    begin
        i_clk <= '1';
        wait for CLK_PERIOD / 2;
        i_clk <= '0';
        wait for CLK_PERIOD / 2;
    end process;

    -- reset 
    rst_gen : process
    begin
        i_resetn <= '0';
        wait for 1000 ns;
        i_resetn <= '1';
        wait;
    end process;

    -- write process with one-cycle valid low at data 10, 20, and 30
    write_proc : process
        variable data_count_v : natural := 0;
        variable insert_gap_v : boolean := false;
    begin
        i_wrreq <= '0';
        i_data  <= (others => '0');

        wait until i_resetn = '1';
        wait for RESET_GUARD_CYCLES * CLK_PERIOD;

        while data_count_v < NUM_TRANSFERS loop
            wait until rising_edge(i_clk);

            if o_full = '1' then
                i_wrreq <= '0';
            elsif f_is_write_gap_value(data_count_v) and (not insert_gap_v) then
                i_wrreq      <= '0';
                insert_gap_v := true;
            else
                i_wrreq      <= '1';
                i_data       <= std_logic_vector(to_unsigned(data_count_v, g_DATA_WIDTH));
                data_count_v := data_count_v + 1;
                insert_gap_v := false;
            end if;
        end loop;

        wait until rising_edge(i_clk);
        i_wrreq <= '0';
        wait;
    end process write_proc;

    -- read/compare process
    read_proc : process
        variable expected_data_v : unsigned(g_DATA_WIDTH - 1 downto 0) := (others => '0');
        variable read_idx_v      : natural                             := 0;
    begin
        i_rdreq <= '0';

        wait until i_resetn = '1';
        wait until rising_edge(i_clk);
        wait until write_count > 0;

        while read_idx_v < NUM_TRANSFERS loop
            wait until rising_edge(i_clk);

            if o_empty = '0' then
                assert o_q = std_logic_vector(expected_data_v)
                report "DATA MISMATCH: expected=" & integer'image(to_integer(expected_data_v)) & ", got=" & integer'image(to_integer(unsigned(o_q))) & ", read_idx=" & integer'image(read_idx_v)
                severity error;

                i_rdreq <= '1';
                wait until rising_edge(i_clk);
                i_rdreq <= '0';

                expected_data_v := expected_data_v + 1;
                read_idx_v      := read_idx_v + 1;
                read_count      <= read_idx_v;
            end if;
        end loop;

        report "TB done. Writes accepted=" & integer'image(write_count) & ", reads accepted=" & integer'image(read_idx_v)
        severity note;
        done_reported <= '1';
        wait;
    end process read_proc;

    -- write monitor
    write_mon : process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_resetn = '0' then
                write_count <= 0;
            elsif i_wrreq = '1' and o_full = '0' then
                write_count <= write_count + 1;
            end if;
        end if;
    end process write_mon;

    -- cycle process
    cycle_mon : process(i_clk, i_resetn)
    begin
        if i_resetn = '0' then
            cycle_count <= 0;
        else
            if rising_edge(i_clk) then
                cycle_count <= cycle_count + 1;
            end if;
        end if;

    end process cycle_mon;

    --measure input rate
    input_mon : process(i_clk, i_resetn)
    begin
        if i_resetn = '0' then
            input_count <= 0;

        elsif rising_edge(i_clk) then
            if i_wrreq = '1' and o_full = '0' then
                input_count <= write_count + 1;
            end if;
        end if;
    end process input_mon;

    -- measure latency
    read_mon : process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_resetn = '0' then
                output_count <= 0;
            else
                if o_q_val = '1' then
                    output_count <= read_count + 1;
                    read_cycle <= cycle_count;

                    latency <= cycle_count - write_cycle;

                    report "Latency = " & integer'image(latency)
                    severity note;
                end if;
            end if;
        end if;
    end process;

    -- measure max usedw
    usedw_mon : process(i_clk)
        variable current_usedw : natural;
    begin
        if rising_edge(i_clk) then
            current_usedw := to_integer(unsigned(o_usedw));

            if current_usedw > max_usedw then
                max_usedw <= current_usedw;
            end if;
        end if;
    end process;

    -- overall report process
    report_proc : process
    begin
        wait until done_reported = '1';

        report "=================================" severity note;
        report "Simulation Summary:" severity note;
        report "Total cycles = " & integer'image(cycle_count) severity note;
        report "Writes = " & integer'image(write_count) severity note;
        report "Reads  = " & integer'image(read_count) severity note;
        report "Max FIFO usage = " & integer'image(max_usedw) severity note;
        -- report "Backpressure events = " & integer'image(backpressure_count) severity note;

        report "=================================" severity note;

        wait;
    end process;

end architecture sim;
