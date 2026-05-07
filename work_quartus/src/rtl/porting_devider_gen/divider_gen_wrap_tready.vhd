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
        G_TARGET_LATENCY : natural  := 36;
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

    signal w_resetn           : std_logic;
    signal w_slave_side_ready : std_logic;
    signal w_accepted_tdata   : std_logic;

    signal w_scaled_numer          : std_logic_vector(C_NUM_WIDTH - 1 downto 0);
    signal w_divisor               : std_logic_vector(G_DIVISOR_WIDTH - 1 downto 0);
    signal w_divided_quaotient_raw : std_logic_vector(C_NUM_WIDTH - 1 downto 0);
    signal w_divided_remainder_raw : std_logic_vector(G_DIVISOR_WIDTH - 1 downto 0);

    signal w_data_out    : std_logic_vector(C_NUM_WIDTH - 1 downto 0);
    signal r_valid_piped : std_logic_vector(G_TARGET_LATENCY downto 0);
    signal r_data_piped  : t_data_pipe_t(0 to G_TARGET_LATENCY);

    signal r_datacount_in_flight : natural range 0 to G_FIFO_DEPTH     := 0;
    signal r_fifo_datacount      : natural range 0 to G_FIFO_DEPTH     := 0;
    signal r_write_pointer       : natural range 0 to G_FIFO_DEPTH - 1 := 0;
    signal r_read_pointer        : natural range 0 to G_FIFO_DEPTH - 1 := 0;
    signal r_fifo_memory         : t_fifo_mem_t;

    -- * NOTE : This was not used in here
    -- function f_repr_mode(is_signed : boolean) return string is
    -- begin
    --     if is_signed then
    --         return "SIGNED"; 
    --     else
    --         return "UNSIGNED";
    --     end if;
    -- end function f_repr_mode;

    -- *Circular buffer pointer incrementer. ( for circular memory indexing in output FIFO ) 

    function f_inc_ptr(
        p_poniter   : natural;
        p_depth : positive
    ) return natural is
    begin
        if p_poniter = p_depth - 1 then
            return 0;
        else
            return p_poniter + 1;
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

    w_resetn <= not aresetn;

    -- Backpressure-safe input ready:
    -- keep invariant (in_flight + fifo_count) < G_FIFO_DEPTH before accepting new op.
    w_slave_side_ready     <= '1' when (r_datacount_in_flight + r_fifo_datacount) < G_FIFO_DEPTH else '0';
    s_axis_dividend_tready <= w_slave_side_ready;
    s_axis_divisor_tready  <= w_slave_side_ready;

    w_accepted_tdata <= s_axis_dividend_tvalid and s_axis_divisor_tvalid and w_slave_side_ready;

    -- Fixed-point scaling: quotient = (dividend << G_FRAC_WIDTH) / divisor
    w_scaled_numer <= s_axis_dividend_tdata & (G_FRAC_WIDTH - 1 downto 0 => '0'); -- mathematically equivalent to shift left by G_FRAC_WIDTH
    w_divisor      <= s_axis_divisor_tdata(G_DIVISOR_WIDTH - 1 downto 0);

    u_lpm_divide : entity work.divider_generator

        port map(
            aclr     => w_resetn,
            clock    => aclk,
            denom    => w_divisor,
            numer    => w_scaled_numer,
            quotient => w_divided_quaotient_raw,
            remain   => w_divided_remainder_raw
        );

    -- Track in-flight operations through target latency.
    valid_pipe_proc : process(aclk)
    begin
        if rising_edge(aclk) then
            if w_resetn = '1' then
                r_valid_piped         <= (others => '0');
                r_datacount_in_flight <= 0;
            else
                r_valid_piped(0) <= w_accepted_tdata;
                for i in 1 to G_TARGET_LATENCY loop
                    r_valid_piped(i) <= r_valid_piped(i - 1);
                end loop;

                if (w_accepted_tdata = '1') and (r_valid_piped(G_TARGET_LATENCY) = '0') then
                    r_datacount_in_flight <= r_datacount_in_flight + 1;
                elsif (w_accepted_tdata = '0') and (r_valid_piped(G_TARGET_LATENCY) = '1') then
                    if r_datacount_in_flight > 0 then
                        r_datacount_in_flight <= r_datacount_in_flight - 1;
                    else
                        r_datacount_in_flight <= 0;
                    end if;
                else
                    r_datacount_in_flight <= r_datacount_in_flight;
                end if;
            end if;
        end if;
    end process valid_pipe_proc;

    -- Data path extra delay over LPM pipeline.
    g_no_extra_data_delay : if C_EXTRA_DELAY = 0 generate
        w_data_out <= w_divided_quaotient_raw;
    end generate g_no_extra_data_delay;

    g_extra_data_delay : if C_EXTRA_DELAY > 0 generate
    begin
        p_extra_data_delay : process(aclk)
        begin
            if rising_edge(aclk) then
                if w_resetn = '1' then
                    for i in 0 to C_EXTRA_DELAY loop
                        r_data_piped(i) <= (others => '0');
                    end loop;
                else
                    r_data_piped(0) <= w_divided_quaotient_raw;
                    for i in 1 to C_EXTRA_DELAY loop
                        r_data_piped(i) <= r_data_piped(i - 1);
                    end loop;
                end if;
            end if;
        end process p_extra_data_delay;

        w_data_out <= r_data_piped(C_EXTRA_DELAY);
    end generate g_extra_data_delay;

    -- Output FIFO to support m_axis_dout_tready backpressure.
    out_fifo_proc : process(aclk)
    begin
        if rising_edge(aclk) then
            if w_resetn = '1' then
                r_fifo_datacount <= 0;
                r_write_pointer  <= 0;
                r_read_pointer   <= 0;
            else
                if r_valid_piped(G_TARGET_LATENCY) = '1' then
                    r_fifo_memory(r_write_pointer) <= w_data_out;
                    r_write_pointer                <= f_inc_ptr(r_write_pointer, G_FIFO_DEPTH);
                end if;

                if (r_fifo_datacount > 0) and (m_axis_dout_tready = '1') then
                    r_read_pointer <= f_inc_ptr(r_read_pointer, G_FIFO_DEPTH);
                end if;

                if (r_valid_piped(G_TARGET_LATENCY) = '1') and not ((r_fifo_datacount > 0) and (m_axis_dout_tready = '1')) then
                    assert r_fifo_datacount < G_FIFO_DEPTH
                    report "Output FIFO overflow in hfh_snr_est_divider_tready"
                    severity failure;
                    r_fifo_datacount <= r_fifo_datacount + 1;
                elsif (r_valid_piped(G_TARGET_LATENCY) = '0') and ((r_fifo_datacount > 0) and (m_axis_dout_tready = '1')) then
                    if r_fifo_datacount > 0 then
                        r_fifo_datacount <= r_fifo_datacount - 1;
                    end if;
                end if;
            end if;
        end if;
    end process out_fifo_proc;

    m_axis_dout_tvalid <= '1' when r_fifo_datacount > 0 else '0';
    m_axis_dout_tdata  <= std_logic_vector(resize(unsigned(r_fifo_memory(r_read_pointer)), G_OUTPUT_WIDTH)) when r_fifo_datacount > 0 else (others => '0');

end architecture rtl;
