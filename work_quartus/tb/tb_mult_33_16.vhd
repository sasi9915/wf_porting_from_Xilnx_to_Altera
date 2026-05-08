library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_mult_33_16 is
end tb_mult_33_16;

architecture Behavioral of tb_mult_33_16 is

    constant C_CLK_PERIOD : time := 10 ns;

    signal clk : std_logic := '0';

    signal i_a : std_logic_vector(32 downto 0) := (others => '0');
    signal i_b : std_logic_vector(15 downto 0) := (others => '0');

    signal o_p : std_logic_vector(31 downto 0);

    constant C_PIPLINED_LATENCY : natural := 4;

    type t_expected_array is array (0 to C_PIPLINED_LATENCY - 1) of signed(31 downto 0);
    type t_valid_array is array (0 to C_PIPLINED_LATENCY - 1) of std_logic;

    signal r_expected_array : t_expected_array := (others => (others => '0'));
    signal r_valid_array    : t_valid_array    := (others => '0');
    signal r_expected_next  : signed(31 downto 0) := (others => '0');
    signal r_expected_valid : std_logic := '0';

begin

    -- clk_gen
    clk_gen : process
    begin
        clk <= '1';
        wait for C_CLK_PERIOD / 2;
        clk <= '0';
        wait for C_CLK_PERIOD / 2;
    end process clk_gen;

    -- DUT instantiation
    dut : entity work.mult_33_16_wrap
        port map(
            clk => clk,
            i_a => i_a,
            i_b => i_b,
            o_p => o_p
        );

    -- stimulus process
    stim_proc : process
        variable v_full_product     : signed(48 downto 0);
        variable v_expected_product : signed(31 downto 0);

        procedure apply_and_check(
            constant a_val : signed(32 downto 0);
            constant b_val : signed(15 downto 0)
        ) is
        begin
            -- Drive inputs away from active sampling edge to avoid race/visibility issues
            wait until rising_edge(clk);

            -- Apply inputs
            i_a <= std_logic_vector(a_val);
            i_b <= std_logic_vector(b_val);

            -- Calculate expected value and keep only bits [42:11]
            v_full_product := a_val * b_val;
            v_expected_product := v_full_product(42 downto 11);

            -- Push expected sample into pipeline stage 0
            r_expected_next <= v_expected_product;
            r_expected_valid <= '1';

            -- DUT and checker sample on rising edge
         
        end procedure apply_and_check;

    begin
        -- initial delay
        wait for 50 ns;

        -- test cases
        apply_and_check(to_signed(1001, 33), to_signed(200, 16));
        apply_and_check(to_signed(5000, 33), to_signed(-100, 16));
        apply_and_check(to_signed(-2000, 33), to_signed(300, 16));
        apply_and_check(to_signed(-1500, 33), to_signed(-250, 16));
        apply_and_check(to_signed(123456, 33), to_signed(321, 16));
        apply_and_check(to_signed(0, 33), to_signed(1000, 16));

        -- flush pipeline
        for i in 0 to 10 loop
            apply_and_check(to_signed(0, 33), to_signed(0, 16));
        end loop;

        -- Stop injecting new expected samples and allow valid bits to drain
        r_expected_valid <= '0';
        for i in 1 to C_PIPLINED_LATENCY loop
            wait until rising_edge(clk);
        end loop;

        -- End simulation
        report "Simulation Finished Successfully" severity note;
        wait;

    end process stim_proc;

    -- Checker and expected pipeline shift
    checker_proc : process(clk)
    begin
        if rising_edge(clk) then
            -- Shift pipeline from stage 0 towards output stage

            r_expected_array(0) <= r_expected_next;
            r_valid_array(0) <= r_expected_valid;
            
            for i in C_PIPLINED_LATENCY - 1 downto 1 loop
                r_expected_array(i) <= r_expected_array(i - 1);
                r_valid_array(i) <= r_valid_array(i - 1);
            end loop;
            

            -- Check only when output-stage expected value is valid
            if r_valid_array(C_PIPLINED_LATENCY - 1) = '1' then
                assert signed(o_p) = r_expected_array(C_PIPLINED_LATENCY - 1)
                    report "Mismatch at output pipeline stage"
                    severity error;
            end if;
        end if;
    end process checker_proc;

end architecture Behavioral;
