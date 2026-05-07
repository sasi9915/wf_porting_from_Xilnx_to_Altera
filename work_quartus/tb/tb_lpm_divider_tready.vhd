library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use ieee.std_logic_textio.all;

entity tb_divider_tready is
end entity;

architecture sim of tb_divider_tready is

    constant CLK_PERIOD : time := 10 ns;

    signal aclk    : std_logic := '0';
    signal aresetn : std_logic := '0';

    -- INPUTS
    signal s_axis_dividend_tvalid : std_logic := '0';
    signal s_axis_dividend_tready : std_logic;
    signal s_axis_dividend_tdata  : std_logic_vector(15 downto 0);

    signal s_axis_divisor_tvalid : std_logic := '0';
    signal s_axis_divisor_tready : std_logic;
    signal s_axis_divisor_tdata  : std_logic_vector(23 downto 0);

    -- OUTPUTS
    signal m_axis_dout_tvalid : std_logic;
    signal m_axis_dout_tready : std_logic := '1';
    signal m_axis_dout_tdata  : std_logic_vector(39 downto 0);

begin

    -- Clock
    clk_gen_proc : process
    begin
        aclk <= '1';
        wait for CLK_PERIOD / 2;
        aclk <= '0';
        wait for CLK_PERIOD / 2;
    end process;

    -- DUT
    uut : entity work.hfh_snr_est_divider_tready
        port map(
            aclk                   => aclk,
            aresetn                => aresetn,
            s_axis_dividend_tvalid => s_axis_dividend_tvalid,
            s_axis_dividend_tready => s_axis_dividend_tready,
            s_axis_dividend_tdata  => s_axis_dividend_tdata,
            s_axis_divisor_tvalid  => s_axis_divisor_tvalid,
            s_axis_divisor_tready  => s_axis_divisor_tready,
            s_axis_divisor_tdata   => s_axis_divisor_tdata(16 downto 0),
            m_axis_dout_tvalid     => m_axis_dout_tvalid,
            m_axis_dout_tready     => m_axis_dout_tready,
            m_axis_dout_tdata      => m_axis_dout_tdata
        );

    -- RESET

    process
    begin
        aresetn <= '0';
        wait for 50 ns;
        aresetn <= '1';
        wait;
    end process;

    -- INPUT DRIVER (AXI style)

    process
    begin
        wait until aresetn = '1';
        wait for 20 ns;

        s_axis_dividend_tvalid <= '0';
        s_axis_divisor_tvalid  <= '0';
        wait until rising_edge(aclk);

        for i in 1 to 10 loop
            s_axis_dividend_tdata  <= std_logic_vector(to_unsigned(i * 5, 16));
            s_axis_divisor_tdata   <= std_logic_vector(to_unsigned(i + 1, 24));
            s_axis_dividend_tvalid <= '1';
            s_axis_divisor_tvalid  <= '1';

            -- Hold valid/data until handshake happens.
            loop
                wait until rising_edge(aclk);
                exit when (s_axis_dividend_tready = '1') and (s_axis_divisor_tready = '1');
            end loop;
        end loop;

        s_axis_dividend_tvalid <= '0';
        s_axis_divisor_tvalid  <= '0';

        wait;
    end process;

    -- BACKPRESSURE GENERATOR

    process
    begin
        wait until aresetn = '1';

        while true loop
            m_axis_dout_tready <= '1';
            wait for 80 ns;

            m_axis_dout_tready <= '0';  -- block output
            wait for 50 ns;
        end loop;
    end process;

    -- MONITOR

    process(aclk)
    begin
        if rising_edge(aclk) then
            if m_axis_dout_tvalid = '1' and m_axis_dout_tready = '1' then

                report "RAW Output = " & integer'image(to_integer(unsigned(m_axis_dout_tdata(31 downto 0))));
            end if;
        end if;
    end process;

end architecture;
