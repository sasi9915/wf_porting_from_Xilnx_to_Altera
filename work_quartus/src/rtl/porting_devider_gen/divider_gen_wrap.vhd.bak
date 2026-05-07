----------------- * NOTES --------------------
-- The IP was configured for unsidgned Fixed point divison with 17 bits of fractional precision. 
-- Remainder Type = Fractional ( Q16.17 ) 
-- Dividend width = 16 bits , Divisor width = 17 bits ( to accomodate the case of divisor = 1) , m_data_width  = 40 bits

-- * In the wrapper *LPM DIVIDE IP Core
-- DIvisor has 24 bits in Xilinx only 17 bits were used. In Altera, we can directly configure the divisor width to 17 bits.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- library lpm;
-- use lpm.all;

-- library altera_mf;
-- use altera_mf.altera_mf_components.all;

entity hfh_snr_est_divider is
    generic(
        G_DIVIDEND_WIDTH : positive := 16;
        G_DIVISOR_WIDTH  : positive := 17;
        G_FRAC_WIDTH     : positive := 17;
        G_LPM_PIPELINE   : natural  := 33;
        G_TARGET_LATENCY : natural  := 35;
        G_OUTPUT_WIDTH   : positive := 40;
        G_SIGNED_MODE    : boolean  := false;
        G_LPM_HINT       : string   := "MAXIMIZE_SPEED=6,LPM_REMAINDERPOSITIVE=TRUE"
    );
    port(
        aclk                   : in  std_logic;
        aresetn                : in  std_logic;
        s_axis_divisor_tvalid  : in  std_logic;
        s_axis_divisor_tdata   : in  std_logic_vector(G_DIVISOR_WIDTH - 1 downto 0);
        s_axis_dividend_tvalid : in  std_logic;
        s_axis_dividend_tdata  : in  std_logic_vector(G_DIVIDEND_WIDTH - 1 downto 0);
        m_axis_dout_tvalid     : out std_logic;
        m_axis_dout_tdata      : out std_logic_vector(G_OUTPUT_WIDTH - 1 downto 0)
    );
end entity hfh_snr_est_divider;

architecture rtl of hfh_snr_est_divider is

    constant C_NUM_WIDTH   : natural := G_DIVIDEND_WIDTH + G_FRAC_WIDTH;
    constant C_EXTRA_DELAY : integer := integer(G_TARGET_LATENCY) - integer(G_LPM_PIPELINE);

    type t_data_pipe_t is array (natural range <>) of std_logic_vector(C_NUM_WIDTH - 1 downto 0);

    signal w_rst    : std_logic;
    signal w_accept : std_logic;

    signal w_scaled_numer          : std_logic_vector(C_NUM_WIDTH - 1 downto 0);
    signal w_divisor               : std_logic_vector(G_DIVISOR_WIDTH - 1 downto 0);
    signal w_divided_quotient_raw  : std_logic_vector(C_NUM_WIDTH - 1 downto 0);
    signal w_divided_remainder_raw : std_logic_vector(G_DIVISOR_WIDTH - 1 downto 0);

    signal w_data_out   : std_logic_vector(C_NUM_WIDTH - 1 downto 0);
    signal r_valid_pipe : std_logic_vector(G_TARGET_LATENCY downto 0);
    signal r_data_pipe  : t_data_pipe_t(0 to G_TARGET_LATENCY);

    -- * IGNORE ------------ used for the signned and unsigned representation of numer and denom --------------
    -- function f_repr_mode(is_signed : boolean) return string is
    -- begin
    --     if is_signed then
    --         return "SIGNED";
    --     else
    --         return "UNSIGNED";
    --     end if;
    -- end function f_repr_mode;

begin

    assert C_EXTRA_DELAY >= 0
    report "G_TARGET_LATENCY must be >= G_LPM_PIPELINE"
    severity failure;

    assert G_OUTPUT_WIDTH >= C_NUM_WIDTH
    report "G_OUTPUT_WIDTH must be >= (G_DIVIDEND_WIDTH + G_FRAC_WIDTH)"
    severity failure;

    w_rst <= not aresetn;

    -- In this AXIS-style wrapper, accept input when both valids are high.
    w_accept <= s_axis_dividend_tvalid and s_axis_divisor_tvalid;

    -- Fixed-point scaling: quotient = (dividend << G_FRAC_WIDTH) / divisor
    -- This is done to get G_FRAC_WIDTH bits of fractional precision in the output quotient.
    -- * o/p = i/p * 2^G_FRAC_WIDTH / divisor

    w_scaled_numer <= s_axis_dividend_tdata & (G_FRAC_WIDTH - 1 downto 0 => '0');
    w_divisor      <= s_axis_divisor_tdata(G_DIVISOR_WIDTH - 1 downto 0); -- * in Xilinx , Divisor was 24 bits but only LSB 17 bits were used.

    u_lpm_divide : entity work.divider_generator

        port map(
            aclr     => w_rst,
            clock    => aclk,
            denom    => w_divisor,
            numer    => w_scaled_numer,
            quotient => w_divided_quotient_raw,
            remain   => w_divided_remainder_raw
        );

    -- Valid pipeline to match total target latency.
    valid_pipe_proc : process(aclk)
    begin
        if rising_edge(aclk) then
            if w_rst = '1' then
                r_valid_pipe <= (others => '0');
            else
                r_valid_pipe(0) <= w_accept;
                for i in 1 to G_TARGET_LATENCY loop
                    r_valid_pipe(i) <= r_valid_pipe(i - 1);
                end loop;
            end if;
        end if;
    end process valid_pipe_proc;

    -- Data path extra delay over LPM pipeline.
    g_no_extra_data_delay : if C_EXTRA_DELAY = 0 generate
        w_data_out <= w_divided_quotient_raw;
    end generate g_no_extra_data_delay;

    g_extra_data_delay : if C_EXTRA_DELAY > 0 generate
    begin
        p_extra_data_delay : process(aclk)
        begin
            if rising_edge(aclk) then
                if w_rst = '1' then
                    for i in 0 to C_EXTRA_DELAY loop
                        r_data_pipe(i) <= (others => '0');
                    end loop;
                else
                    r_data_pipe(0) <= w_divided_quotient_raw;
                    for i in 1 to C_EXTRA_DELAY loop
                        r_data_pipe(i) <= r_data_pipe(i - 1);
                    end loop;
                end if;
            end if;
        end process p_extra_data_delay;

        w_data_out <= r_data_pipe(C_EXTRA_DELAY);
    end generate g_extra_data_delay;

    m_axis_dout_tvalid <= r_valid_pipe(G_TARGET_LATENCY);
    m_axis_dout_tdata  <= std_logic_vector(resize(unsigned(w_data_out), G_OUTPUT_WIDTH)) when r_valid_pipe(G_TARGET_LATENCY) = '1' else (others => '0');

end architecture rtl;
