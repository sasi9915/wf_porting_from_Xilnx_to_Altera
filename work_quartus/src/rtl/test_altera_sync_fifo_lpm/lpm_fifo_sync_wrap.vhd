library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library altera_mf;
use altera_mf.altera_mf_components.all;

entity intel_fifo_sync_wrap is
    generic(
        g_DATA_WIDTH             : natural := 10;
        g_DEPTH                  : natural := 2048;
        g_FWFT_MODE_ENA          : boolean := true;
        g_ALMOST_FULL_THRESHOLD  : integer := 2048 - 128;
        g_ALMOST_EMPTY_THRESHOLD : integer := 128
    );
    port(
        i_resetn       : in  std_logic;
        i_clk          : in  std_logic;
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

    signal w_reset : std_logic;
    signal w_empty : std_logic;
    signal w_usedw : std_logic_vector(f_log2_size(g_DEPTH) - 1 downto 0) := (others => '0');
    signal r_q_val : std_logic;

begin

    -- reset conversion
    w_reset <= not (i_resetn);

    u_fifo : scfifo
        generic map(
            add_ram_output_register => "OFF",
            allow_rwcycle_when_full => "OFF",
            almost_empty_value      => g_ALMOST_EMPTY_THRESHOLD,
            almost_full_value       => g_ALMOST_FULL_THRESHOLD,
            intended_device_family  => "Cyclone V",
            lpm_numwords            => g_DEPTH,
            lpm_showahead           => f_showahead_sel(g_FWFT_MODE_ENA),
            lpm_width               => g_DATA_WIDTH,
            lpm_widthu              => f_log2_size(g_DEPTH),
            overflow_checking       => "ON",
            underflow_checking      => "ON",
            use_eab                 => "ON",
            lpm_hint                => "UNUSED",
            lpm_type                => "scfifo"
        )
        port map(
            clock        => i_clk,
            aclr         => w_reset,
            sclr         => '0',
            data         => i_data,
            wrreq        => i_wrreq,
            rdreq        => i_rdreq,
            q            => o_q,
            full         => o_full,
            empty        => w_empty,
            almost_full  => o_almost_full,
            almost_empty => o_almost_empty,
            usedw        => w_usedw
        );

    -- q_val generation
    process(i_resetn, i_clk)
    begin
        if i_resetn = '0' then
            r_q_val <= '0';
        elsif rising_edge(i_clk) then
            r_q_val <= i_rdreq and not (w_empty);
        end if;
    end process;

    o_q_val <= i_rdreq and not (w_empty) when g_FWFT_MODE_ENA else r_q_val;
    o_empty <= w_empty;
    o_usedw <= std_logic_vector(resize(unsigned(w_usedw), 16));

end architecture;
