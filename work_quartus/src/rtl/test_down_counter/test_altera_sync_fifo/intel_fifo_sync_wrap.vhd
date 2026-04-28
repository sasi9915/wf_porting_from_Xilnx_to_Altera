library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity intel_fifo_sync_wrap is
    generic(
        g_DATA_WIDTH    : natural := 10;
        g_FWFT_MODE_ENA : boolean := true
    );
    port(
        i_clk          : in  std_logic;
        i_resetn       : in  std_logic;
        i_wrreq        : in  std_logic;
        i_data         : in  std_logic_vector(g_DATA_WIDTH - 1 downto 0);
        i_rdreq        : in  std_logic;
        o_q            : out std_logic_vector(g_DATA_WIDTH - 1 downto 0);
        o_q_val        : out std_logic;
        o_usedw        : out std_logic_vector(15 downto 0);
        o_full         : out std_logic;
        o_empty        : out std_logic;
        o_almost_full  : out std_logic;
        o_almost_empty : out std_logic
    );
end entity;

architecture rtl of intel_fifo_sync_wrap is

    constant C_IP_DATA_WIDTH : natural := 10;

    signal w_empty : std_logic;
    signal w_full  : std_logic;
    signal w_usedw : std_logic_vector(10 downto 0);
    signal w_reset : std_logic;
    signal r_q_val : std_logic;
    signal w_q     : std_logic_vector(C_IP_DATA_WIDTH - 1 downto 0);
    signal w_data  : std_logic_vector(C_IP_DATA_WIDTH - 1 downto 0);

begin

    assert g_DATA_WIDTH = C_IP_DATA_WIDTH
        report "intel_fifo_sync_wrap: g_DATA_WIDTH must be 10 to match generated altera_sync_fifo IP."
        severity failure;

    w_reset <= not i_resetn;
    w_data  <= i_data;

    fifo_inst : entity work.altera_sync_fifo
        
        port map(
            clock        => i_clk,
            sclr         => w_reset,
            data         => w_data,
            wrreq        => i_wrreq,
            rdreq        => i_rdreq,
            q            => w_q,
            full         => w_full,
            empty        => w_empty,
            almost_full  => o_almost_full,
            almost_empty => o_almost_empty,
            usedw        => w_usedw
        );

    process(i_clk, w_reset)
    begin
        if w_reset = '1' then
            r_q_val <= '0';
        elsif rising_edge(i_clk) then
            r_q_val <= i_rdreq and not w_empty;
        end if;
    end process;

    o_full  <= w_full;
    o_empty <= w_empty;
    o_q     <= w_q;
    o_usedw <= std_logic_vector(resize(unsigned(w_usedw), 16));
    o_q_val <= i_rdreq and not w_empty when g_FWFT_MODE_ENA else r_q_val;

end architecture;
