library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_fir_top is
end entity;

architecture tb of tb_fir_top is

    -- Testbench-side DUT interface signals
    signal i_clk     : std_logic := '0';
    signal i_resetn  : std_logic := '0';

    signal i_data    : std_logic_vector(15 downto 0) := (others => '0');
    signal i_valid   : std_logic                     := '0';
    signal o_ready   : std_logic;

    signal o_data    : std_logic_vector(23 downto 0);
    signal o_valid   : std_logic;
    signal i_ready   : std_logic                     := '1';

    constant CLK_PERIOD : time := 3.33 ns;

    type data_array_t is array (0 to 9) of integer;
    constant c_input_data : data_array_t := (
        1, 2, 3, 4, 5,
        6, 7, 8, 9, 10
    );

begin

    -- Clock generation
    i_clk <= not i_clk after CLK_PERIOD / 2;

    -- Active-low reset gen
    rst_gen : process
    begin
        i_resetn <= '0';
        wait for 50 ns;
        i_resetn <= '1';
        wait;
    end process rst_gen;

    -- DUT
    uut: entity work.fir_top
        port map (
            clk     => i_clk,
            rst     => not i_resetn,
            i_data  => i_data,
            i_valid => i_valid,
            o_ready => o_ready,
            o_data  => o_data,
            o_valid => o_valid,
            i_ready => i_ready
        );

    -- Stimulus
    process
    begin
        wait until i_resetn = '1';
        wait until rising_edge(i_clk);

        -- Hold valid/data stable until each sample is accepted (o_ready='1').
        for i in c_input_data'range loop
            i_valid <= '1';
            i_data  <= std_logic_vector(to_signed(c_input_data(i), i_data'length));
            loop
                wait until rising_edge(i_clk);
                exit when o_ready = '1';
            end loop;
        end loop;

        i_valid <= '0';
        i_data  <= (others => '0');

        wait for 3500 ns;
        assert false report "Simulation Finished" severity failure;
    end process;

end architecture;
