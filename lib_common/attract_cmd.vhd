--*****************************************************************************
--
--  Title   : Attract mode for System1
--
--  File    : attract_cmd.vhd
--
--  Author  : bontango
--
--  will read binary commands from 'rom'
--  this rom need to be created with tool 'attractcsv2bin'
--  see lisy.dev
--available commands:
--time <wait time> <s | ms >
--Wait ‘wait time’ in seconds or milliseconds before executing the next command.
--Only integer values are supported!
--
--GOTTFA code: 0x1 <high byte> <low byte>
--Translated into ms, meaning 65s maximum wait time
--
--lamp <lamp number> <on | off >
--Switch the lamp ‘lamp number’ ( 1..36) to ON or OFF
--
--GOTTFA code: 0x2 <lampnumber> <0|1>
--Lapnumber 1-36 0==OFF 1==ON
--
--GOTTFA code: 0x3 
--Jump to first attract command
--
--
-- Notes
-- clock is 400KHz ( 2,5 u sec) -> 1ms is 400 counter ticks
-- 10second delay at start in order not to interfere with game initialisation
-- 1 second delay during game play
-- v1.0 do not include 'High Score to date' lamp !!!
-- v1.1 includes HSTD lamp (checked/controlled within time command)
--*****************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity attract_cmd is
  port( 
		clk     : in  std_logic;
      reset   : in  std_logic;		
      game_over_relay : in  std_logic;		
		HSTD : in  std_logic;		
		
		address : buffer  std_logic_vector( 11 downto 0); -- address of command in rom
		  
		data    : in std_logic_vector( 7 downto 0); -- command
		
		ld    : out std_logic_vector( 3 downto 0); --  lamps ld
		ds    : out std_logic_vector( 3 downto 0); --  lamps ds
		
		ctrl	: out std_logic --signal if attract is active
        );
end attract_cmd;

architecture fsm of attract_cmd is

    --   FSM states
  type state_t is ( st_start_delay, st_wait_game_over, st_get_cmd, st_read_para1, st_read_para2,
							st_execute_cmd, st_time, st_lamp, st_lamp_2, st_lamp_3, st_check, st_stop, st_HSTD_1, st_HSTD_2 );
  signal state : state_t;
  
  signal command : std_logic_vector( 7 downto 0);
  signal para1 : std_logic_vector( 7 downto 0);
  signal para2 : std_logic_vector( 7 downto 0);
  -- remember ld data of each flipflop
  type ld_data is array (0 to 8) of std_logic_vector (3 downto 0);
  signal ld_sik : ld_data;
  signal ld_value : std_logic_vector( 3 downto 0);
  signal flipflop_number : integer range 0 to 10;
  signal counter  : integer range 0 to 50000000;   -- delay
  signal old_HSTD : std_logic;
begin    
  fsm_proc : process ( reset, clk, HSTD, game_over_relay, data)
  variable time_H: integer range 0 to 256;
  variable time_L: integer range 0 to 256;
  
  begin  	  
		if ( reset = '0') then -- Asynchronous reset
		   --   output and variable initialisation		
		   ctrl			<= '0';	
			address     <= ( others => '0');
			ld    	   <= ( others => '1'); --inverter on GottFA
			ds		      <= ( others => '1'); --rest position
			ld_sik      <= (others=>(others=>'1'));
			counter		<= 5000000; --12 seconds delay at power up
			old_HSTD		<= '0';
			state <= st_check;
		elsif rising_edge( clk) then  -- Synchronous FSM		
		    case state is
			    ---- check for 'G' at first byte in attract mode rom
				 when st_check =>
					if ( data = x"47" ) then
						address     <= x"010"; --commands start after GottFA1 string
						state <= st_start_delay;
					else
						state <= st_stop;
					end if;
			    ---- State 0 delay at start
				 when st_start_delay =>
				 	counter <= counter -1;		
					if ( counter = 0 ) then 
						state <= st_wait_game_over;
						counter <= 0;						
					end if;																													
			    ---- State 1 wait for game over ---
				 when st_wait_game_over =>
				   ctrl <= '0'; 
				   if (game_over_relay = '1') then		
						ctrl <= '1';
						state <= st_get_cmd;
					end if;	
				 ---- State 2a read command
				 when st_get_cmd =>
					command <= data;
					-- prepare address for next byte
					address <= std_LOGIC_VECTOR(unsigned(address) +1);		
					state <= st_read_para1;
				 ---- State 2b read parameter one
				 when st_read_para1 =>
					para1 <= data;
					-- prepare address for next byte
					address <= std_LOGIC_VECTOR(unsigned(address) +1);		
					state <= st_read_para2;
				 ---- State 2c read parameter two
				 when st_read_para2 =>
					para2 <= data;
					-- prepare address for next byte
					address <= std_LOGIC_VECTOR(unsigned(address) +1);		
					state <= st_execute_cmd;					
				 ---- State 3 execute command
				 when st_execute_cmd =>
					-- possible commands
					case to_integer(unsigned(command)) is
						when 16#01# => -- time
							--calculate wait time
							time_H := to_integer(unsigned(para1));
							time_L := to_integer(unsigned(para2));							
							counter <= (256*time_H + time_L) * 400;
							state <= st_time;
						when 16#02# => -- lamp setting
						   -- calculate flip-flop number and ld value from para1 (lampnumber)
							-- and set ld_value depending on ON or OFF
							if para2 = x"00" then -- OFF is set bit (remember: inverter on GottFA)
								case para1(1 downto 0) is 										
									when "00" => ld_value <= "0001";
									when "01" => ld_value <= "0010";
									when "10" => ld_value <= "0100";
									when "11" => ld_value <= "1000";								
								end case;
							else --ON
								case para1(1 downto 0) is 
									when "00" => ld_value <= "1110";
									when "01" => ld_value <= "1101";
									when "10" => ld_value <= "1011";
									when "11" => ld_value <= "0111";								
								end case;						
							end if;
							 --4bits 0..8 plus 1
							flipflop_number <= to_integer( unsigned(para1(5 downto 2))) +1;
							state <= st_lamp;
						when 16#03# => -- restart	
							-- prepare address for next byte
							address <= x"010";
							state <= st_wait_game_over;													
						when others => -- stop attract mode for any other command
							state <= st_stop;
					end case; -- cmd
				 -- command execution wait specific time highbyte-lowbyte in ms
				 when st_time =>
					counter <= counter -1;		
					--check game over during time wait
					 if (game_over_relay = '0') then			
					   	address <= x"010";							
							counter <= 0;
							state <= st_wait_game_over;														
					end if;	

					--check/set HSTD during time wait
					-- need to set lamp without changing other lamps
					 if (HSTD /= old_HSTD) then	
							old_HSTD <= HSTD;
							-- flipflop 1, ds=1 ld_value 0100 or 1011 - OFF is set bit (remember: inverter on GottFA)
							if (HSTD = '0') then
								ld_sik(1) <= ld_sik(1) or "0100";
								ld <= ld_sik(1) or "0100";
							else --ON
								ld_sik(1) <= ld_sik(1) and "1011";
								ld <= ld_sik(1) and "1011";
							end if;							
							state <= st_HSTD_1;
					end if;	

					if ( counter = 0 ) then 
						state <= st_wait_game_over;
						counter <= 0;						
					end if;						
				-- set HSTD
				when st_HSTD_1 =>						
						ds <= "0001";
						state <= st_HSTD_2;
						
				when st_HSTD_2 =>		
						--set ds to rest pos and back to time routine ( one tick missing)
						ds <= "1111";
						state <= st_time;

				 -- command execution set lamp number para1 to state para2
				 when st_lamp =>
					if para2 = x"00" then -- OFF is set bit (remember: inverter on GottFA)
						ld_sik(flipflop_number) <= ld_sik(flipflop_number) or ld_value;
						ld <= ld_sik(flipflop_number) or ld_value;
					else -- ON
						ld_sik(flipflop_number) <= ld_sik(flipflop_number) and ld_value;
						ld <= ld_sik(flipflop_number) and ld_value;
					end if;
						state <= st_lamp_2;
				when st_lamp_2 =>		
						--set ds to right flipflop
						ds <= std_logic_vector(to_unsigned(flipflop_number,ds'length));
						state <= st_lamp_3;
				when st_lamp_3 =>		
						--set ds to rest pos
						ds <= "1111";
						state <= st_wait_game_over;		
				when st_stop =>		
						ctrl <= '0'; 				
			end case;  --  state
		end if; -- rising_edge(clk)
  end process fsm_proc;
end fsm;
