library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;



entity hfh_snr_est_divider_tready is
    generic(
        G_DIVIDEND_WIDTH : positive := 16;
        G_DIVISOR_WIDTH  : positive := 17;
        G_FRAC_WIDTH     : positive := 17;
        G_OUTPUT_WIDTH   : positive := 40;
        G_LPM_PIPELINE   : natural  := 33;
        G_TARGET_LATENCY : natural  := 35;
        G_FIFO_DEPTH     : positive := 128;
        G_SIGNED_MODE    : boolean  := false;
        G_LPM_HINT       : string   := "MAXIMIZE_SPEED=6,LPM_REMAINDERPOSITIVE=TRUE"
    );
    port(
        aclk                   : in  std_logic;
        aresetn                : in  std_logic;
        s_axis_divisor_tvalid  : in  std_logic;
        s_axis_divisor_tready  : out std_logic;
        s_axis_divisor_tdata   : in  std_logic_vector(G_DIVISOR_WIDTH - 1 downto 0);
        s_axis_dividend_tvalid : in  std_logic;
        s_axis_dividend_tready : out std_logic;
        s_axis_dividend_tdata  : in  std_logic_vector(G_DIVIDEND_WIDTH - 1 downto 0);
        m_axis_dout_tvalid     : out std_logic;
        m_axis_dout_tready     : in  std_logic;
        m_axis_dout_tdata      : out std_logic_vector(G_OUTPUT_WIDTH - 1 downto 0)
    );
end entity hfh_snr_est_divider_tready;

architecture rtl of hfh_snr_est_divider_tready is

    constant C_NUM_WIDTH   : natural := G_DIVIDEND_WIDTH + G_FRAC_WIDTH;
    constant C_EXTRA_DELAY : integer := integer(G_TARGET_LATENCY) - integer(G_LPM_PIPELINE);

    type t_data_pipe_t is array (natural range <>) of std_logic_vector(C_NUM_WIDTH - 1 downto 0);
    type t_fifo_mem_t  is array (0 to G_FIFO_DEPTH - 1) of std_logic_vector(C_NUM_WIDTH - 1 downto 0);

    signal w_rst     : std_logic;
    signal w_s_ready : std_logic;
    signal w_accept_tdata  : std_logic;

    signal w_scaled_numer : std_logic_vector(C_NUM_WIDTH - 1 downto 0);
    signal w_divisor      : std_logic_vector(G_DIVISOR_WIDTH - 1 downto 0);
    signal w_div_q_raw    : std_logic_vector(C_NUM_WIDTH - 1 downto 0);
    signal w_div_r_raw    : std_logic_vector(G_DIVISOR_WIDTH - 1 downto 0);

    signal w_data_out   : std_logic_vector(C_NUM_WIDTH - 1 downto 0);
    signal w_valid_pipe : std_logic_vector(G_TARGET_LATENCY downto 0);
    signal w_data_pipe  : t_data_pipe_t(0 to G_TARGET_LATENCY);

    signal r_in_flight  : natural range 0 to G_FIFO_DEPTH     := 0;
    signal r_fifo_count : natural range 0 to G_FIFO_DEPTH     := 0;
    signal r_wr_ptr     : natural range 0 to G_FIFO_DEPTH - 1 := 0;
    signal r_rd_ptr     : natural range 0 to G_FIFO_DEPTH - 1 := 0;
    signal r_fifo_mem   : t_fifo_mem_t;

    function f_repr_mode(is_signed : boolean) return string is
    begin
        if is_signed then
            return "SIGNED";
        else
            return "UNSIGNED";
        end if;
    end function f_repr_mode;

    function f_inc_ptr(
        p_ptr   : natural;
        p_depth : positive
    ) return natural is
    begin
        if p_ptr = p_depth - 1 then
            return 0;
        else
            return p_ptr + 1;
        end if;
    end function f_inc_ptr;

begin

    assert C_EXTRA_DELAY >= 0
    report "G_TARGET_LATENCY must be >= G_LPM_PIPELINE"
    severity failure;

    assert G_OUTPUT_WIDTH >= C_NUM_WIDTH
    report "G_OUTPUT_WIDTH must be >= (G_DIVIDEND_WIDTH + G_FRAC_WIDTH)"
    severity failure;

    -- Must absorb possible in-flight results after backpressure assertion.
    assert G_FIFO_DEPTH >= (G_TARGET_LATENCY + 2)
    report "G_FIFO_DEPTH too small for chosen latency. Use at least G_TARGET_LATENCY+2."
    severity failure;

    w_rst <= not aresetn;

    -- Backpressure-safe input ready:
    -- keep invariant (in_flight + fifo_count) < G_FIFO_DEPTH before accepting new op.
    w_s_ready              <= '1' when (r_in_flight + r_fifo_count) < G_FIFO_DEPTH else '0';
    s_axis_dividend_tready <= w_s_ready;
    s_axis_divisor_tready  <= w_s_ready;

    w_accept_tdata <= s_axis_dividend_tvalid and s_axis_divisor_tvalid and w_s_ready;

    -- Fixed-point scaling: quotient = (dividend << G_FRAC_WIDTH) / divisor
    w_scaled_numer <= s_axis_dividend_tdata & (G_FRAC_WIDTH - 1 downto 0 => '0');
    w_divisor      <= s_axis_divisor_tdata(G_DIVISOR_WIDTH - 1 downto 0);

    u_lpm_divide : entity work.divider_generator

        port map(
            aclr     => w_rst,
            clock    => aclk,
            denom    => w_divisor,
            numer    => w_scaled_numer,
            quotient => w_div_q_raw,
            remain   => w_div_r_raw
        );

    -- Track in-flight operations through target latency.
    p_valid_pipe : process(aclk)
    begin
        if rising_edge(aclk) then
            if w_rst = '1' then
                w_valid_pipe <= (others => '0');
                r_in_flight  <= 0;
            else
                w_valid_pipe(0) <= w_accept_tdata;
                for i in 1 to G_TARGET_LATENCY loop
                    w_valid_pipe(i) <= w_valid_pipe(i - 1);
                end loop;

                if (w_accept_tdata = '1') and (w_valid_pipe(G_TARGET_LATENCY) = '0') then
                    r_in_flight <= r_in_flight + 1;
                elsif (w_accept_tdata = '0') and (w_valid_pipe(G_TARGET_LATENCY) = '1') then
                    if r_in_flight > 0 then
                        r_in_flight <= r_in_flight - 1;
                    else
                        r_in_flight <= 0;
                    end if;
                else
                    r_in_flight <= r_in_flight;
                end if;
            end if;
        end if;
    end process p_valid_pipe;

    -- Data path extra delay over LPM pipeline.
    g_no_extra_data_delay : if C_EXTRA_DELAY = 0 generate
        w_data_out <= w_div_q_raw;
    end generate g_no_extra_data_delay;

    g_extra_data_delay : if C_EXTRA_DELAY > 0 generate
    begin
        p_extra_data_delay : process(aclk)
        begin
            if rising_edge(aclk) then
                if w_rst = '1' then
                    for i in 0 to C_EXTRA_DELAY loop
                        w_data_pipe(i) <= (others => '0');
                    end loop;
                else
                    w_data_pipe(0) <= w_div_q_raw;
                    for i in 1 to C_EXTRA_DELAY loop
                        w_data_pipe(i) <= w_data_pipe(i - 1);
                    end loop;
                end if;
            end if;
        end process p_extra_data_delay;

        w_data_out <= w_data_pipe(C_EXTRA_DELAY);
    end generate g_extra_data_delay;

    -- Output FIFO to support m_axis_dout_tready backpressure.
    p_out_fifo : process(aclk)
    begin
        if rising_edge(aclk) then
            if w_rst = '1' then
                r_fifo_count <= 0;
                r_wr_ptr     <= 0;
                r_rd_ptr     <= 0;
            else
                if w_valid_pipe(G_TARGET_LATENCY) = '1' then
                    r_fifo_mem(r_wr_ptr) <= w_data_out;
                    r_wr_ptr             <= f_inc_ptr(r_wr_ptr, G_FIFO_DEPTH);
                end if;

                if (r_fifo_count > 0) and (m_axis_dout_tready = '1') then
                    r_rd_ptr <= f_inc_ptr(r_rd_ptr, G_FIFO_DEPTH);
                end if;

                if (w_valid_pipe(G_TARGET_LATENCY) = '1') and not ((r_fifo_count > 0) and (m_axis_dout_tready = '1')) then
                    assert r_fifo_count < G_FIFO_DEPTH
                    report "Output FIFO overflow in hfh_snr_est_divider_tready"
                    severity failure;
                    r_fifo_count <= r_fifo_count + 1;
                elsif (w_valid_pipe(G_TARGET_LATENCY) = '0') and ((r_fifo_count > 0) and (m_axis_dout_tready = '1')) then
                    if r_fifo_count > 0 then
                        r_fifo_count <= r_fifo_count - 1;
                    end if;
                end if;
            end if;
        end if;
    end process p_out_fifo;

    m_axis_dout_tvalid <= '1' when r_fifo_count > 0 else '0';
    m_axis_dout_tdata  <= std_logic_vector(resize(unsigned(r_fifo_mem(r_rd_ptr)), G_OUTPUT_WIDTH)) when r_fifo_count > 0 else (others => '0');

end architecture rtl;
