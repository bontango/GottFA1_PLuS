-- read the dips on WillFA
-- bontango 03.2024
--
-- v 1.0 -- 895KHz input clock
-- v 1.1 900Hz input clock, continous reading
-- v 1.2 adapted to willfa11, 6strobes, 2 returns, only one time reading
-- v 1.2 adapted to RecelFA, 12strobes, one return, only one time reading
-- v 1.3 adapted to GottFA1_Plus, 3strobes, one return, only one time reading

LIBRARY ieee;
USE ieee.std_logic_1164.all;

LIBRARY ieee;
USE ieee.std_logic_1164.all;

    entity read_SB_dips is        
        port(
            clk_in  : in std_logic;               						
				i_Rst_L : in std_logic;     -- FPGA Reset					   
				--output 
				done		: out std_logic;        -- set to 1 when read finished
				sb_option	:	out std_logic_vector(1 to 3);
				-- strobes
			   dip_strobe		: out std_logic_vector(2 downto 0);
				-- input
				return_sig			: in std_logic
            );
    end read_SB_dips;
    ---------------------------------------------------
    architecture Behavioral of read_SB_dips is
	 	type STATE_T is ( Start, Read1, Read2, Read3, Idle ); 
		signal state : STATE_T := Start;       		
	begin
	
	
	 read_SB_dips: process (clk_in, i_Rst_L, return_sig)
    begin		
			if i_Rst_L = '0' then --Reset condidition (reset_l)    
			  state <= Start;
			  dip_strobe <= ( others => '1');					
			  done <= '0';
			elsif rising_edge(clk_in) then			
				case state is
					when Start =>
						dip_strobe <= "011";
						state <= Read1;						
					when Read1 =>
						sb_option(1) <= not return_sig;						
						dip_strobe <= "101";
						state <= Read2;
					when  Read2 =>
						sb_option(2) <= not return_sig;
						dip_strobe <= "110";
						state <= Read3;
					when  Read3 =>
						sb_option(3) <= not return_sig;
						dip_strobe <= "111";
						state <= Idle;																							
					when  Idle =>		
						dip_strobe <= ( others => '0');									
						done <= '1'; -- set after first round						
				end case;				
		end if;	--rising edge		
		end process;
    end Behavioral;