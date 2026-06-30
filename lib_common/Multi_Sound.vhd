-- VHDL implementation of the Gottlieb MA-55 sound board used in System 80 pinball machines. Panthera, 
-- Spiderman, Circus, CounterForce, StarRace, James Bond 007, Time Line, Force II, Pink Panther, 
-- Volcano (export), Black Hole (export), Devil's Dare (export), Eclipse (export).
-- S1 through S8 are sound control lines, all input signals are active-low. Sound_Tones is only 
-- supported on a few games, later ones will crash if this is set to tones mode.
-- Original hardware used a 6530 RRIOT, this is based on an adaptation to replace the RRIOT with a 
-- more commonly available 6532 RIOT and separate ROM. Some general info on the operation of the MA-55 
-- board can be found here http://www.flipprojets.fr/AudioMA55_EN.php
-- (c)2015 James Sweet
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
-- Changelog:
-- V0.5 initial release
-- V1.0 minor cleanup, added list of supported games

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity Multi_Sound is
	port(
		cpu_clk		:	in		std_logic; -- 800 KHz CPU clock
		clk_50		:	in		std_logic; -- DAC clock, 30-100 MHz works well
		Reset_l		:	in 	std_logic; -- Reset, active low
		Test			:	in  	std_logic; -- Test button, active low
		Attract		:	in		std_logic; -- 0 Enables attract mode, 1 disables
		Sound_Tones	:	in		std_logic; -- Most games need this set to 1 (Sound mode)
		S_1000		:  in		std_logic;
		S_100			: 	in 	std_logic;
		S_10			:	in 	std_logic;
		S_Tilt		:	in 	std_logic;
		S_Game_Over	:	in 	std_logic;
		Audio_O		: 	out	std_logic;
		cpu_addr		:  buffer std_logic_vector(11 downto 0);
		rom1_dout	: in std_logic_vector(7 downto 0);
		rom2_dout	: in std_logic_vector(7 downto 0);
		game_sel	:	in 	std_logic_vector(3 downto 0)  -- game selection
		);
end Multi_Sound;


architecture rtl of Multi_Sound is

signal phi2				: std_logic;

--signal cpu_addr		: std_logic_vector(11 downto 0);
signal cpu_din			: std_logic_vector(7 downto 0);
signal cpu_dout		: std_logic_vector(7 downto 0);
signal cpu_wr_n		: std_logic;

signal soundrom1_cs		: std_logic;
signal soundrom2_cs			: std_logic;

signal ram_dout	   : std_logic_vector(7 downto 0);
signal ram_cs			: std_logic;

signal riot_dout		: std_logic_vector(7 downto 0);
signal riot_pb			: std_logic_vector(7 downto 0);
signal riot_cs  		: std_logic;
signal riot_io_cs		: std_logic;
signal riot_rs_n		: std_logic;

signal audio			: std_logic_vector(7 downto 0);

begin

-- Phase 2 clock is complement of CPU clock
phi2 <= not cpu_clk; 
	
	
-- Bus control
cpu_din <=
	ram_dout when ram_cs='1' else
	riot_dout when riot_io_cs='1' else
	rom1_dout when soundrom1_cs = '1' else
	rom2_dout when soundrom2_cs = '1' else
	x"FF";

-- Address decoding
riot_rs_n <= not cpu_addr(9);
riot_cs <= not cpu_addr(10) and not cpu_addr(11); --both for IO and ram
ram_cs <= riot_cs and riot_rs_n;
riot_io_cs <= riot_cs and not riot_rs_n;

soundrom1_cs 		<= '1' when cpu_addr(11 downto 10) ="01" else -- 0x0400 - 0x07FF 
							'1' when cpu_addr(11 downto 10) ="10" else -- Mirror 0x0800 - 0x0BFF							
							'0';
							
soundrom2_cs 		<= '1' when cpu_addr(11 downto 10) ="11" else -- 0x0C00 - 0x0FFF
							'0';
							
riot_pb(5) <= cpu_addr(10); --CS2 (needed?)


-- Option switches
riot_pb(4) <= attract; -- Attract mode sounds enable (S2 on board)
riot_pb(7) <= sound_tones; --sound_tones; (S1 on board)-- Sound or tones mode, many games lack tone support and require this to be high 

-- Sound selection inputs
riot_pb(0) <= (not S_1000);
riot_pb(1) <= (not S_100);
riot_pb(2) <= (not S_10);
riot_pb(3) <= (not S_Tilt);
riot_pb(6) <= (not S_Game_Over); 


U1: entity work.T65 -- Real circuit used 6503, same as 6502 but fewer pins
port map(
	Mode    			=> "00",
	Res_n   			=> reset_l,
	Enable  			=> '1',
	Clk     			=> cpu_clk,
	Rdy     			=> '1',
	Abort_n 			=> '1',
	IRQ_n   			=> '1',
	NMI_n   			=> test,
	SO_n    			=> '1',
	R_W_n 			=> cpu_wr_n,
	A(11 downto 0)	=> cpu_addr,       
	DI     			=> cpu_din,
	DO    			=> cpu_dout
	);
	
U2: entity work.R6530 -- Should be 6530 RRIOT but using a RIOT instead with a separate ROM
port map(
	phi2   => phi2,
   rst_n  => reset_l,
   cs     => riot_io_cs,
   rw_n    => cpu_wr_n,
	irq_n  => open,
	
   add      => cpu_addr(3 downto 0),
   din	 => cpu_dout,
	dout	 => riot_dout,
	
	pa_in	 => x"00",
   pa_out   => audio,
   pb_in   => riot_pb,
	pb_out	 => open
 );
	
	
RIOT_RAM: entity work.SB_RAM -- RIOT internal RAM 128Byte, 6530 will only use 64Byte
port map(
	address	=> cpu_addr(6 downto 0),
	clock		=> clk_50, 
	data		=>  cpu_dout (7 DOWNTO 0),
	wren 		=> ram_cs and not cpu_wr_n,
	q			=> ram_dout
);
	
	
U3: entity work.DAC
  generic map(
  msbi_g => 7)
port  map(
   clk_i   => clk_50,
   res_n_i => reset_l,
   dac_i   => audio,
   dac_o   => audio_O
);

end rtl;
		