library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_down_counter is
end tb_down_counter;

architecture sim of tb_down_counter is
    constant WIDTH : positive := 8;

    signal i_clk : std_logic := '0';
    signal i_rst_n : std_logic := '0';
    signal i_en : std_logic := '0';
    signal o_count : std_logic_vector(WIDTH-1 downto 0);

constant CLK_PERIOD : time := 10 ns;

begin 
    uut : entity work.down_counter
        generic map (
            WIDTH => WIDTH
        )
        port map (
            i_clk => i_clk,
            i_rst_n => i_rst_n,
            i_en => i_en,
            o_count => o_count
        );
    
    -- Clock generation
    clk_process : process
    begin
        while true loop
            i_clk <= '1';
            wait for CLK_PERIOD / 2;
            i_clk <= '0';
            wait for CLK_PERIOD / 2;
        end loop;
    end process;


    -- Stimulus process
    Stimulus_process : process
    begin
        -- Apply reset
        i_rst_n <= '0';
        i_en <= '0';
        wait for 20 ns;

        -- Release reset and enable counting
        i_rst_n <= '1';
        wait for 20 ns;

        -- Enable counting
        i_en <= '1';
        wait for 200 ns;

        -- pause simulation
        i_en <= '0';
        wait for 20 ns;

        --resume counting
        i_en <= '1';
        wait for 100 ns;

        wait; -- Wait indefinitely to end simulation
    end process;

   

end sim;