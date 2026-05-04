library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library altera_mf;
use altera_mf.altera_mf_components.all;

entity lpm_async_fifo_wrap is
    generic(
        g_DATA_WIDTH             : natural := 10;
        g_DEPTH                  : natural := 2048;
        g_FWFT_MODE_ENA          : boolean := true;
        g_ALMOST_FULL_THRESHOLD  : natural := 2048 - 128;
        g_ALMOST_EMPTY_THRESHOLD : natural := 128
    );
    port(
        i_wr_resetn       : in  std_logic;
        i_wr_clk          : in  std_logic;
        i_rd_clk          : in  std_logic;
        i_wrreq           : in  std_logic;
        i_data            : in  std_logic_vector(g_DATA_WIDTH - 1 downto 0);
        i_rdreq           : in  std_logic;
        o_q_val           : out std_logic;
        o_q               : out std_logic_vector(g_DATA_WIDTH - 1 downto 0);
        o_wr_usedw        : out std_logic_vector(15 downto 0);
        o_rd_usedw        : out std_logic_vector(15 downto 0);
        o_wr_full         : out std_logic;
        o_rd_empty        : out std_logic;
        o_wr_almost_full  : out std_logic;
        o_rd_almost_empty : out std_logic
    );
end entity;

architecture rtl of lpm_async_fifo_wrap is

    -- log2 function
    function f_log2_size(A : natural) return natural is
    begin
        for I in 1 to 64 loop
            if (2 ** I >= A) then
                return I;
            end if;
        end loop;
        return 63;
    end function;

    -- showahead function
    function f_showahead_sel(x : boolean) return string is
    begin
        if x then
            return "ON";
        else
            return "OFF";
        end if;
    end function;

    signal w_wr_reset : std_logic;
    signal w_wr_full  : std_logic;
    signal w_rd_empty : std_logic;
    signal r_q_val    : std_logic;
    signal w_wr_usedw : std_logic_vector(f_log2_size(g_DEPTH) - 1 downto 0) := (others => '0');
    signal w_rd_usedw : std_logic_vector(f_log2_size(g_DEPTH) - 1 downto 0) := (others => '0');

begin
    w_wr_reset <= not i_wr_resetn;

    u_fifo : dcfifo

        generic map(
            add_ram_output_register => "OFF",
            add_usedw_msb_bit       => "OFF",
            clocks_are_synchronized => "FALSE",
            delay_rdusedw           => 1,
            delay_wrusedw           => 1,
            intended_device_family  => "Cyclone V",
            lpm_numwords            => g_DEPTH,
            lpm_showahead           => f_showahead_sel(g_FWFT_MODE_ENA),
            lpm_width               => g_DATA_WIDTH,
            lpm_widthu              => f_log2_size(g_DEPTH),
            overflow_checking       => "ON",
            rdsync_delaypipe        => 5,
            underflow_checking      => "ON",
            use_eab                 => "ON",
            write_aclr_synch        => "OFF",
            wrsync_delaypipe        => 5,
            lpm_hint                => "UNUSED",
            lpm_type                => "dcfifo"
        )
        port map(
            aclr    => w_wr_reset,
            data    => i_data,
            rdclk   => i_rd_clk,
            rdreq   => i_rdreq,
            wrclk   => i_wr_clk,
            wrreq   => i_wrreq,
            q       => o_q,
            rdempty => w_rd_empty,
            rdusedw => w_rd_usedw,
            wrfull  => w_wr_full,
            wrusedw => w_wr_usedw,
            rdfull  => open,
            wrempty => open
        );

    process(i_rd_clk)
    begin
        if i_wr_resetn = '0' then
            r_q_val <= '0';

        elsif i_rd_clk'event and i_rd_clk = '1' then
            r_q_val <= i_rdreq and not w_rd_empty;
        end if;
    end process;

    o_q_val    <= i_rdreq and not w_rd_empty when g_FWFT_MODE_ENA else r_q_val;
    o_rd_empty <= w_rd_empty;
    o_wr_full  <= w_wr_full;

    o_rd_usedw <= std_logic_vector(resize(unsigned(w_rd_usedw), 16));
    o_wr_usedw <= std_logic_vector(resize(unsigned(w_wr_usedw), 16));

    o_wr_almost_full  <= '1' when unsigned(w_wr_usedw) >= g_ALMOST_FULL_THRESHOLD else '0';
    o_rd_almost_empty <= '1' when unsigned(w_rd_usedw) <= g_ALMOST_EMPTY_THRESHOLD else '0';

end architecture;

