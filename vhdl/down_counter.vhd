library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- 8-bit synchronous down counter with active-low asynchronous reset and enable.
entity down_counter is
    generic (
        WIDTH : positive := 8
    );
    port (
        clk   : in  std_logic;
        rst_n : in  std_logic;                          -- active-low reset
        en    : in  std_logic;                          -- count when '1'
        q     : out std_logic_vector(WIDTH-1 downto 0)
    );
end entity down_counter;

architecture rtl of down_counter is
    signal count_reg : unsigned(WIDTH-1 downto 0) := (others => '0');
begin
    process (clk, rst_n)
    begin
        if rst_n = '0' then
            count_reg <= (others => '1');              -- preload max value on reset
        elsif rising_edge(clk) then
            if en = '1' then
                count_reg <= count_reg - 1;
            end if;
        end if;
    end process;

    q <= std_logic_vector(count_reg);
end architecture rtl;
