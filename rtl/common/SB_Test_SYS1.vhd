--*****************************************************************************
--
--  Title   : Soundboard test for GottFA1_PLuS
--
--  File    : SB_Test_SYS1.vhd
--
--  Author  : bontango
--
-- Notes
-- clock is 9600Hz 
--
-- v1.0 
--*****************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity SB_Test_SYS1 is
  port( 
	  clk     : in  std_logic;
	  reset   : in  std_logic;		
     button  : in  std_logic;		
      	  
	  Sound_10   : out std_logic;
	  Sound_100   : out std_logic;
	  Sound_1K   : out std_logic;
	  Sound_BG   : out std_logic;
	  
	  test_active   : out std_logic
        );
end SB_Test_SYS1;

architecture fsm of SB_Test_SYS1 is

    --   FSM states
  type state_t is ( st_check, st_start, st_test1, st_test2, st_test3, st_test4);
							
  signal state : state_t;
  
  signal counter  : integer range 0 to 64000;   -- delay

begin    
  fsm_proc : process ( clk, reset, button )
  
  begin  	  
		if ( reset = '0') then -- Asynchronous reset
		   --   output and variable initialisation		
			Sound_10 <= '0';
			Sound_100 <= '0';
			Sound_1K <= '0';
			Sound_BG <= '0';
			test_active <= '0';
			state <= st_check;
		elsif rising_edge( clk) then  -- Synchronous FSM		
		    case state is
				 when st_check =>		
				 	test_active <= '0';
					if ( button = '0' ) then
						state <= st_start;
					end if;	
					
				 when st_start =>
					test_active <= '1';
					counter <= 9600;						
					state <= st_test1;
					
				 when st_test1 =>					
					Sound_10 <= '1';															
				 	counter <= counter -1;		
					if ( counter = 0 ) then 
						Sound_10 <= '0';																				
						counter <= 9600;
						state <= st_test2;						
					end if;																													

				 when st_test2 =>					
					Sound_100 <= '1';															
				 	counter <= counter -1;		
					if ( counter = 0 ) then 
						Sound_100 <= '0';																				
						counter <= 9600;
						state <= st_test3;						
					end if;																													

				 when st_test3 =>					
					Sound_1K <= '1';															
				 	counter <= counter -1;		
					if ( counter = 0 ) then 
						Sound_1K <= '0';																				
						counter <= 64000;
						state <= st_test4;						
					end if;																													
					
				 when st_test4 =>					
					Sound_BG <= '1';															
				 	counter <= counter -1;		
					if ( counter = 0 ) then 
						Sound_BG <= '0';																				
						counter <= 9600;
						state <= st_check;
					end if;																															
			end case;  --  state
		end if; -- rising_edge(clk)
  end process fsm_proc;
end fsm;
