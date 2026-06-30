--*****************************************************************************
--
--  Title   : Read dips for System1
--
--  File    : read_sys1_dips.vhd
--
--  Author  : bontango
--
--*****************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity read_sys1_dips is
  port( 
		clk     : in  std_logic;
		reset   : in  std_logic;		
						  
		dips    : in std_logic_vector( 7 downto 0); -- command
		
		ds    :   out std_logic_vector( 3 downto 0); --  lamps ds control read of SYS1 dips		
		gtb_dips	: out std_logic_vector( 23 downto 0); 
		done   : out  std_logic
        );
end read_sys1_dips;

architecture fsm of read_sys1_dips is

    --   FSM states
  type state_t is ( st_set_1, st_read_1, st_set_2, st_read_2, st_set_3, st_read_3, st_idle );							
  signal state : state_t;
  
begin    
  fsm_proc : process ( reset, clk)
  
  begin  	  
		if ( reset = '0') then -- Asynchronous reset
		   --   output and variable initialisation		
			gtb_dips    	   <= ( others => '1'); --inverter on GottFA			
			ds		      <= ( others => '1'); --rest position
			done <= '0';
			state <= st_set_1;
		elsif rising_edge( clk) then  -- Synchronous FSM
		    case state is
			    ---- activate DIP Bank 1
				 when st_set_1 =>
					ds <= "0000";
					state <= st_read_1;
			    ---- read DIP Bank 1 value
				 when st_read_1 =>
					gtb_dips(7 downto 0) <= dips;
					state <= st_set_2;					
			    ---- activate DIP Bank 2
				 when st_set_2 =>
					ds <= "0001";
					state <= st_read_2;
			    ---- read DIP Bank 2 value
				 when st_read_2 =>
					gtb_dips(15 downto 8) <= dips;
					state <= st_set_3;
			    ---- activate DIP Bank 3
				 when st_set_3 =>
					ds <= "0010";
					state <= st_read_3;
			    ---- read DIP Bank 3 value
				 when st_read_3 =>
					gtb_dips(23 downto 16) <= dips;
					state <= st_idle;
				 when st_idle =>
					ds <= "1111";				 
					done <= '1';
			end case;  --  state
		end if; -- rising_edge(clk)
  end process fsm_proc;
end fsm;
