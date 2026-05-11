library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library altera_mf;
use altera_mf.altera_mf_components.all;

entity lpm_sync_fifo is
    generic(
        g_TYPE                   : string  := "block";
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
        o_q_val        : out std_logic                                   := '0';
        o_q            : out std_logic_vector(g_DATA_WIDTH - 1 downto 0) := (others => '0');
        o_usedw        : out std_logic_vector(15 downto 0)               := (others => '0');
        o_full         : out std_logic                                   := '0';
        o_empty        : out std_logic                                   := '0';
        o_almost_full  : out std_logic                                   := '0';
        o_almost_empty : out std_logic                                   := '0'
    );
end entity lpm_sync_fifo;

architecture arc_lpm_sync_fifo of lpm_sync_fifo is

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

    -- -- use_eab function
    -- function f_use_eab_sel(x : string) return string is
    -- begin
    --     if (x = "distributed") or (x = "DISTRIBUTED") then
    --         return "OFF";
    --     else
    --         return "ON";
    --     end if;
    -- end function;

    signal w_reset : std_logic;
    signal w_empty : std_logic;
    signal r_q_val : std_logic;
    signal w_q     : std_logic_vector(g_DATA_WIDTH - 1 downto 0)         := (others => '0');
    signal w_usedw : std_logic_vector(f_log2_size(g_DEPTH) - 1 downto 0) := (others => '0');

begin

    w_reset <= not i_resetn;

    scfifo_component : scfifo
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
            aclr         => '0',
            almost_empty => o_almost_empty,
            almost_full  => o_almost_full,
            clock        => i_clk,
            data         => i_data,
            empty        => w_empty,
            full         => o_full,
            q            => w_q,
            rdreq        => i_rdreq,
            sclr         => w_reset,
            usedw        => w_usedw,
            wrreq        => i_wrreq
        );

    process(i_resetn, i_clk) is
    begin
        if i_resetn = '0' then
            r_q_val <= '0';
        elsif i_clk'event and i_clk = '1' then
            r_q_val <= i_rdreq and not w_empty;
        end if;
    end process;

    o_q_val <= i_rdreq and not (w_empty) when (g_FWFT_MODE_ENA) else r_q_val;
    o_q     <= w_q when ((g_FWFT_MODE_ENA and (w_empty = '0')) or ((not g_FWFT_MODE_ENA) and (r_q_val = '1'))) else (others => '0');
    o_usedw <= std_logic_vector(resize(unsigned(w_usedw), 16));
    o_empty <= w_empty;

end architecture arc_lpm_sync_fifo;
