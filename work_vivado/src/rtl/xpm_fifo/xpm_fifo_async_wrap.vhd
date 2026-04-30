library ieee;
use ieee.std_logic_1164.all;

Library xpm;
use xpm.vcomponents.all;


entity xpm_fifo_async_wrap is

    generic
    (
        g_TYPE                          : string  := "block";
        g_DATA_WIDTH                    : natural := 10;
        g_DEPTH                         : natural := 2048;
        g_FWFT_MODE_ENA                 : boolean := true;
        
        g_ALMOST_FULL_THRESHOLD         : integer := 2048 - 128;
        g_ALMOST_EMPTY_THRESHOLD        : integer := 128
        
    );
    port 
    (
        i_wr_resetn         : in std_logic;
        i_wr_clk            : in std_logic;

        i_rd_clk            : in std_logic;
        
        i_wrreq             : in std_logic;
        i_data              : in std_logic_vector(g_DATA_WIDTH-1 downto 0);
        
        i_rdreq             : in std_logic;
        
        o_q_val             : out std_logic := '0';
        o_q                 : out std_logic_vector(g_DATA_WIDTH-1 downto 0) := (others => '0');
        
        o_wr_usedw          : out std_logic_vector(15 downto 0) := (others => '0');
        o_rd_usedw          : out std_logic_vector(15 downto 0) := (others => '0');
        
        o_wr_full           : out std_logic := '0';
        o_rd_empty          : out std_logic := '0';
        
        o_wr_almost_full    : out std_logic := '0';
        o_rd_almost_empty   : out std_logic := '0'
    );

end entity;

architecture arc_xpm_fifo_async_wrap of xpm_fifo_async_wrap is

    signal w_wr_reset               : std_logic;
    signal w_rd_empty               : std_logic;
    signal r_q_val                  : std_logic;
    signal w_wr_usedw               : std_logic_vector(17 downto 0);
    signal w_rd_usedw               : std_logic_vector(17 downto 0);

    function f_mod_sel (x : boolean) return string is
    begin
        if(x) then
            return "fwft";
        else
            return "std";
        end if;
    end f_mod_sel;

    function f_read_latency_sel (x : boolean) return integer is
    begin
        if(x) then
            return 0;
        else
            return 1;
        end if;
    end f_read_latency_sel;

    function f_log2_size (A : natural) return natural is
    begin
        for I in 1 to 64 loop               -- Works for up to 64 bits
            if (2**I >= A) then
                return(I);
            end if;
        end loop;
        return(63);
    end function f_log2_size;


begin

    w_wr_reset <= not(i_wr_resetn);
    
    xpm_fifo_async_inst : xpm_fifo_async
    generic map 
    (
        SIM_ASSERT_CHK => 0,                                            -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        CDC_SYNC_STAGES => 3,                                           -- DECIMAL
        DOUT_RESET_VALUE => "0",                                        -- String
        ECC_MODE => "no_ecc",                                           -- String
        FIFO_MEMORY_TYPE => "g_TYPE",                                   -- String
        FIFO_READ_LATENCY => f_read_latency_sel(g_FWFT_MODE_ENA),       -- DECIMAL
        FIFO_WRITE_DEPTH => g_DEPTH,                                    -- DECIMAL
        FULL_RESET_VALUE => 0,                                          -- DECIMAL
        PROG_EMPTY_THRESH => g_ALMOST_EMPTY_THRESHOLD,                  -- DECIMAL
        PROG_FULL_THRESH => g_ALMOST_FULL_THRESHOLD,                    -- DECIMAL
        RD_DATA_COUNT_WIDTH => f_log2_size(g_DEPTH) + 1,                -- DECIMAL
        READ_DATA_WIDTH => g_DATA_WIDTH,                                -- DECIMAL
        READ_MODE => f_mod_sel(g_FWFT_MODE_ENA),                        -- String
        RELATED_CLOCKS => 0,                                            -- DECIMAL
        USE_ADV_FEATURES => "1F0F",                                     -- String
        WAKEUP_TIME => 0,                                               -- DECIMAL
        WRITE_DATA_WIDTH => g_DATA_WIDTH,                               -- DECIMAL
        WR_DATA_COUNT_WIDTH => f_log2_size(g_DEPTH) + 1                 -- DECIMAL

    )
    port map
    (
        rst => w_wr_reset,
        wr_rst_busy => open,
        rd_rst_busy => open,

        wr_clk => i_wr_clk,
        wr_en => i_wrreq,
        din => i_data,   
        wr_ack => open,
        wr_data_count => w_wr_usedw(f_log2_size(g_DEPTH) downto 0),

        rd_clk => i_rd_clk,
        rd_en => i_rdreq,
        dout => o_q,
        rd_data_count => w_rd_usedw(f_log2_size(g_DEPTH) downto 0),

        data_valid => open,

        overflow => open,
        underflow => open,

        empty => w_rd_empty,
        full => o_wr_full,
        almost_empty => open,
        almost_full => open,
        prog_empty => o_rd_almost_empty,
        prog_full => o_wr_almost_full,
              
        dbiterr => open,             
                   
        sbiterr => open,             
               
        injectdbiterr => '0',
        injectsbiterr => '0',
        sleep => '0'
                                                 
    );

    w_wr_usedw(17 downto f_log2_size(g_DEPTH) + 1) <= (others => '0');
    w_rd_usedw(17 downto f_log2_size(g_DEPTH) + 1) <= (others => '0');
    
    process(i_rd_clk) is
    begin
        if i_rd_clk'event and i_rd_clk = '1' then
            r_q_val <= i_rdreq and not(w_rd_empty);
        end if;
    end process;
   
    o_q_val <= i_rdreq and not(w_rd_empty) when (g_FWFT_MODE_ENA) else r_q_val;

    

    o_wr_usedw <= w_wr_usedw(15 downto 0);
    o_rd_usedw <= w_rd_usedw(15 downto 0);
    o_rd_empty <= w_rd_empty;
    



end arc_xpm_fifo_async_wrap;
