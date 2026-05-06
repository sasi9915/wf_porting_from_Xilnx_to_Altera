library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_lpm_divider is
end entity;

architecture sim of tb_lpm_divider is

    signal aclk    : std_logic := '0';
    signal aresetn : std_logic := '0';

    -- Inputs
    signal s_axis_dividend_tvalid : std_logic                     := '0';
    signal s_axis_dividend_tdata  : std_logic_vector(15 downto 0) := (others => '0');

    signal s_axis_divisor_tvalid : std_logic                     := '0';
    signal s_axis_divisor_tdata  : std_logic_vector(23 downto 0) := (others => '0');

    -- Outputs
    signal m_axis_dout_tvalid : std_logic;
    signal m_axis_dout_tdata  : std_logic_vector(39 downto 0);

begin

    aclk <= not aclk after 5 ns;

    process
    begin
        aresetn <= '0';                 -- reset active
        wait for 20 ns;

        aresetn <= '1';                 -- release reset

        wait;
    end process;

    -- DUT

    uut : entity work.hfh_snr_est_divider
        port map(
            aclk                   => aclk,
            aresetn                => aresetn,
            s_axis_dividend_tvalid => s_axis_dividend_tvalid,
            s_axis_dividend_tdata  => s_axis_dividend_tdata,
            s_axis_divisor_tvalid  => s_axis_divisor_tvalid,
            s_axis_divisor_tdata   => s_axis_divisor_tdata(16 downto 0),
            m_axis_dout_tvalid     => m_axis_dout_tvalid,
            m_axis_dout_tdata      => m_axis_dout_tdata
        );

    -- Stimulus

    process
    begin
        wait for 40 ns;

        -- TEST 1: 5 / 2
        s_axis_dividend_tdata <= std_logic_vector(to_unsigned(5, 16));
        s_axis_divisor_tdata  <= std_logic_vector(to_unsigned(2, 24));

        s_axis_dividend_tvalid <= '1';
        s_axis_divisor_tvalid  <= '1';

        wait for 10 ns;

        s_axis_dividend_tvalid <= '0';
        s_axis_divisor_tvalid  <= '0';

        wait for 400 ns;

        -- TEST 2: 10 / 3
        s_axis_dividend_tdata <= std_logic_vector(to_unsigned(10, 16));
        s_axis_divisor_tdata  <= std_logic_vector(to_unsigned(3, 24));

        s_axis_dividend_tvalid <= '1';
        s_axis_divisor_tvalid  <= '1';

        wait for 10 ns;

        s_axis_dividend_tvalid <= '0';
        s_axis_divisor_tvalid  <= '0';

        wait for 400 ns;

        wait;
    end process;

    -- Monitor output

    process(aclk)
    begin
        if rising_edge(aclk) then
            if m_axis_dout_tvalid = '1' then
                report "Output valid: " & integer'image(to_integer(unsigned(m_axis_dout_tdata)));
            end if;
        end if;
    end process;

end architecture;
