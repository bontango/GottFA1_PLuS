-- simple transmitter for DFPLAYR_Mini
--
-- This is free software: you can redistribute
-- it and/or modify it under the terms of the GNU General
-- Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your
-- option) any later version.
--
-- This is distributed in the hope that it will
-- be useful, but WITHOUT ANY WARRANTY; without even the
-- implied warranty of MERCHANTABILITY or FITNESS FOR A
-- PARTICULAR PURPOSE. See the GNU General Public License
-- for more details.
--
-- Version 0.1
--
-- The general command structure consists of 10 bytes of which five are fixed, 
-- two are a checksum, and three specify the action (one is the command and two are parameters)
-- Format is
-- byte    function         value
-- (0)     start byte       0x7E
-- (1)     version info     0xFF
-- (2)     number of bytes  0x06
-- (3)     command          0x..  <- the command specifies by the user
-- (4)     command feedback 0x00  (if no feedback is required)
-- (5)     parameter 1 [DH] 0x..  <- 1st parameter (high-byte) specified by user
-- (6)     parameter 2 [DL] 0x..  <- 2nd parameter (low-byte) specified by user
-- (7)     checksum high    0x..  <- calculation is given below
-- (8)     checksum low     0x..  <- calculation is given below
-- (9)     end command      0xEF
--
-- checksum = - ( byte(1)+byte(2)+byte(3)+byte(4)+byte(5)+byte(6) )
-- and byte(7) and byte(8) are obtained as
-- checksumHigh = highByte(checksum)
-- checksumLow = lowByte(checksum) 
--
-- Statemaschine FSM
--
-- States:
-- RST_State: 
-- Wait: wait for 'do_send' & BUSY (which is LOW while a file is playing)
-- Sending: send complete command
-- goto Wait State
--
-- v0.2 RecelFA version with Background music only
-- v0.3 GottFA1_PLuS: with 1 second timer at trigger detect as SYS1 do deactivate game_over relay between balls
-- v0.4 option wether each game starts background new or continue at old pos
-- v0.5 with reset cmd at start

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity DFPlayer_Mini_CMD is
    Port ( trigger : in STD_LOGIC; --std_logic_vector (5 downto 0); -- 5 sounds plus background
           clk : in  STD_LOGIC; -- need to be fix 9600baud
           rst : in  STD_LOGIC; --reset_l
			  start_new : in  STD_LOGIC; --option to start background each time at start song
           txd : out  STD_LOGIC); --txd pin
end DFPlayer_Mini_CMD;

architecture Behavioral of DFPlayer_Mini_CMD is

function reverse_any_vector (a: in std_logic_vector)
    return std_logic_vector is
  variable result: std_logic_vector(a'RANGE);
  alias aa: std_logic_vector(a'REVERSE_RANGE) is a;
begin
  for i in aa'RANGE loop
    result(i) := aa(i);
  end loop;
  return result;
end; -- function reverse_any_vector

	signal DFcmd_cmd  : std_logic_vector (7 downto 0); -- the command for DFPlayer
	signal DFcmd_par1 : std_logic_vector (7 downto 0); --Parameter 1 (folder)
	signal DFcmd_par2 : std_logic_vector (7 downto 0); --Parameter 2 (soundnumber)
				 
  signal command : std_logic_vector (79 downto 0);  
  signal old_trigger :  STD_LOGIC; 
  signal running :  STD_LOGIC; 
	
  type STATE_T is ( Init, Idle, S_delay, S_decide, Send, Construct); 
  signal state : STATE_T;        --State
  signal counter  : integer range 0 to 5000;   -- delay
  
  -- Structure of DFPlayer command over serial
  constant DFcmd_Start_Byte: unsigned (7 downto 0):=X"7E"; -- each command starts with 0x7E  
  constant DFcmd_Version: unsigned (7 downto 0):=X"FF"; -- version is always 0xFF
  constant DFcmd_len: unsigned (7 downto 0):=X"06"; -- len: number of bytes after len, always 6
  constant DFcmd_feedb: unsigned (7 downto 0):=X"00"; -- 0 == no feedback neededed
  constant DFcmd_End_Byte: unsigned (7 downto 0):=X"EF"; -- Ende Byte, always 0xEF  
 
begin

DFPLAYR_Mini : process (clk, rst, trigger) is
  variable bitcounter : integer range 0 to 100 := 99;
begin
  if rst = '0' then --Reset condidition (reset_l)
    txd <= '1';
	 old_trigger <= '0';
	 running <= '0';
	 counter <= 0;
    state <= Init;    
  elsif rising_edge(clk)then    	 
    case state is
		when Init => 	 
			DFcmd_cmd <= X"42"; -- cmd for query status
			DFcmd_par1 <= x"00"; -- not used
			DFcmd_par2 <= X"00"; -- not used
	 		state <= Construct;					 
	   when Idle => 
			if trigger /= old_trigger then	
					state <= S_delay;				
			end if; -- trigger /= old_trigger

		when S_delay => 	
				--wait one second to eliminate SYS1 glitches		
					counter <= counter +1;					
					if ( counter >= 4800 ) then --500ms 
						counter <= 0;						
						if trigger /= old_trigger then	--check again after delay
							old_trigger <= trigger;
							state <= S_decide;				
						else
							state <= Idle; -- glitch, goto idle again
						end if;												
					end if;																													
			
		when S_decide => 			
					if trigger = '1' then
						if running = '0' or start_new = '1' then
							DFcmd_cmd <= X"17"; -- cmd for repeat folder to playback
							DFcmd_par1 <= x"00"; -- fix
							DFcmd_par2 <= X"02"; -- playback folder
							running <= '1';
						else
							DFcmd_cmd <= X"0D"; -- cmd for play
							DFcmd_par1 <= x"00"; -- fix
							DFcmd_par2 <= x"00"; -- fix									
						end if;
					else
						DFcmd_cmd <= X"0E"; -- cmd for pause
						DFcmd_par1 <= x"00"; -- fix
						DFcmd_par2 <= x"00"; -- fix				
					end if;
					state <= Construct;				
					
		when Construct => 
			 --command(73 downto )
			 command <=   '0' & std_logic_vector(DFcmd_Start_Byte) & '1' -- startbyte is symmetric, no rverse needed
							& '0' & reverse_any_vector(std_logic_vector(DFcmd_Version)) & '1'
							& '0' & reverse_any_vector(std_logic_vector(DFcmd_len)) & '1'
							& '0' & reverse_any_vector(DFcmd_cmd) & '1'
							& '0' & reverse_any_vector(std_logic_vector(DFcmd_feedb)) & '1'
							& '0' & reverse_any_vector(DFcmd_par1) & '1'
							& '0' & reverse_any_vector(DFcmd_par2) & '1'
							& '0' & reverse_any_vector(std_logic_vector(DFcmd_End_Byte)) & '1';
			 -- reset counter
			 bitcounter := 79; --without checksum
			 -- new state
          state <= Send;
      when Send =>   
        txd <= command(bitcounter); 
        bitcounter := bitcounter - 1;
        if bitcounter = 0 then          
          state <= Idle;
        end if;
      end case;
  end if;
end process;
end architecture;

