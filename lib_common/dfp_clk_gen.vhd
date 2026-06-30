--
-- generate 9600Hz clock for controlling MP3 DFPlayer
--

LIBRARY ieee;
USE ieee.std_logic_1164.all;

	entity dfp_clk_gen is
		port(
                clk_in  : in std_logic;                
                dfp_clk_out : out std_logic
            );
    end dfp_clk_gen;
	 
   architecture Behavioral of dfp_clk_gen is
	   signal q_cpuClkCount : integer range 0 to 10000;
		--signal q_cpuClkCount	: std_logic_vector(6 downto 0); 
    begin
		dfp_clk_gen: process (clk_in)
			begin
				if rising_edge(clk_in) then
					if q_cpuClkCount < 5208 then		
						q_cpuClkCount <= q_cpuClkCount + 1;
					else
						q_cpuClkCount <= 0;
					end if;
					if q_cpuClkCount < 2604 then		
						dfp_clk_out <= '0';
					else
						dfp_clk_out <= '1';
					end if;
				end if;
			end process;
    end Behavioral;				

-- CPU frequency 	Counter top 	Counter half-way
-- 9600hz if cpuClkCount < 5208 then 	if cpuClkCount < 2604 then

    