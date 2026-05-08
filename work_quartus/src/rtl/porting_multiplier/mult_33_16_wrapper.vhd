library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mult_33_16_wrap is 
    port (
        clk : in std_logic;
        i_a : in std_logic_vector(32 downto 0);
        i_b : in std_logic_vector(15 downto 0);
        o_p : out std_logic_vector(31 downto 0)
    );
end mult_33_16_wrap;

architecture sim of mult_33_16_wrap is

    signal w_mult_full : std_logic_vector(48 downto 0);

begin

    u_mult: entity work.mult_gen
        port map (
            clock => clk,
            dataa => i_a,
            datab => i_b,
            result => w_mult_full
        );

    -- * NOTE :
    -- Match Vivado output extraction:
    --
    -- Vivado settings:
    --     Output MSB = 42
    --     Output LSB = 11
    --
    -- Equivalent:
    --     output = full_product(42 downto 11)
  

    o_p <= w_mult_full(42 downto 11);

end architecture sim;