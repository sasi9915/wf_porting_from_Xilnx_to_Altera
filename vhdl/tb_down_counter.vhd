library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_down_counter is
end entity tb_down_counter;

architecture sim of tb_down_counter is
    constant WIDTH : positive := 8;

    signal clk   : std_logic := '0';
    signal rst_n : std_logic := '0';
    signal en    : std_logic := '0';
    signal q     : std_logic_vector(WIDTH-1 downto 0);

    constant CLK_PERIOD : time := 20 ns;
begin
    uut: entity work.down_counter
        generic map (
            WIDTH => WIDTH
        )
        port map (
            clk   => clk,
            rst_n => rst_n,
            en    => en,
            q     => q
        );

    clk <= not clk after CLK_PERIOD / 2;

    stimulus: process
    begin
        -- Keep reset active for a couple of cycles.
        rst_n <= '0';
        en    <= '0';
        wait for 2 * CLK_PERIOD;

        -- Release reset; counter should hold while enable is low.
        rst_n <= '1';
        wait for 3 * CLK_PERIOD;

        -- Enable counting down.
        en <= '1';
        wait for 10 * CLK_PERIOD;

        -- Pause counting.
        en <= '0';
        wait for 3 * CLK_PERIOD;

        -- Resume counting.
        en <= '1';
        wait for 6 * CLK_PERIOD;

        wait;
    end process;

    checks: process (clk)
        variable prev_q : unsigned(WIDTH-1 downto 0) := (others => '1');
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                assert q = (q'range => '1')
                    report "Counter not initialized to all ones during reset"
                    severity error;
                prev_q := (others => '1');
            elsif en = '1' then
                assert unsigned(q) = prev_q - 1
                    report "Counter did not decrement by 1"
                    severity error;
                prev_q := unsigned(q);
            else
                assert unsigned(q) = prev_q
                    report "Counter changed while enable was low"
                    severity error;
            end if;
        end if;
    end process;
end architecture sim;
