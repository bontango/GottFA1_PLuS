-- VHDL implementation of a System1 Gottlieb MPU
-- (c)2020 bontango
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
--  a simplified design for implementing Rockwell parts needed for a Gottlieb System1 MPU
--  U4 & U5 have RAM and ROM, RAM is in this modul, Rom from Main: U4_ROM (0x0800-0x0fff) and U5_Rom ( 0x0- 0x07ff)
-- Content:
-- U1 pps4-2 CPU
-- U2 (device 0x06) GPIO 10696 - NVRAM in / out 
-- U3 (device 0x03) GPIO 10696 - Lamps, strobe, dip switches, bits 8 & 9 of PGOL address
-- U4 (device 0x04) RRIO A1753 - Solenoids, NVRAM R/W & enable
-- U5 (device 0x02) RRIO A1752 - Switch matrix
-- U6 (device 0x0d) GPKD 10788 - Display
-- Z22 5101 NVRAM
-- Z23 PGOL 1KB Rom
-- Z30 74154
-- Changelog:
-- v0.90 26.01.2022 bontango initial release, moved from 0.13 to HW 1.00 and v0.90
-- v0.91 28.01.2022 bontango added metastability for switches & sderror message
-- v0.92 04.02.2022 added delay for credit sw trigger and negated GTB reset for be able to adjust replay scores
-- v0.93 05.02.2022 freeplay added, sw1 splittet to games select & options
-- v0.94 19.03.2022 r10788 v0.5 prevent display ghosting
-- v0.95 25.03.2022 r10788 v0.6 more display ghosting prevention
-- v0.96 26.03.2022 r10788 v0.8 ghosting gap adjustable for tube or LED
-- v0.97 test gap 300 because of ghosting with org displays -> r10788 v0.8 changed from 200 to 300!
-- v0.98 added attract mode

-- Version 2.00	 -- converted 0.98 to 2.00 for Cyclone IV ( EP4CE6F17C8 )
-- Version 3.00	 -- converted 0.98 to 3.00 for Cyclone IV ( EP4CE6E22C8N  )
-- Version 3.03    -- eprom v06 with reduced clock & fixed games setting '0' for eprom

-- TODO: add functionality with Test button

-- Version 7.00 -- PLuS hardware v2.xx & Quartus v22
-- Version 8.00 -- PLuS hardware v2.1x Cyclone 10 compatible
-- Version 9.00 -- PLuS hardware v2.1x for Cyclone 10
-- Version 9.01 -- test button produces sound
-- Version 9.02 -- dfp player activated with 'active' signal/LED to prevent garbage
-- Version 9.03 -- moved Button_Test to SB_Test (no Gottlieb SB test button anymore -> fix '1')

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity SYS1 is
	port(
	   -- the FPGA board
		clk_50	: in std_logic;
		reset_sw	: in std_logic;
		LED_0 	: out STD_LOGIC;						
		LED_1 	: out STD_LOGIC;
		LED_2 	: out STD_LOGIC;				
		
		-- LEDs
		LED_SD_Error : out STD_LOGIC;						
		LED_active : out STD_LOGIC;						
		
		-- switchmatrix
		--sw_strobe : out std_logic_vector(4 downto 0);						
		sw_strobe : buffer std_logic_vector(4 downto 0);
		sw_return : in std_logic_vector(7 downto 0);
		 
		-- dip banks
		GTB_dips : in std_logic_vector(7 downto 0);
		
		-- game selection & options GottFA
		sw1_dips : in std_logic_vector(3 downto 0);		
		sw2_dips : in std_logic_vector(3 downto 0);		
		
		-- special switches
		sw_reset : in std_logic;
		sw_outhole : in std_logic;
		sw_slam : in std_logic;
		
		-- lamps
		ld : out std_logic_vector(3 downto 0);
		ds : out std_logic_vector(3 downto 0); -- via Z30  74154		
		
		--displays
		--disp_strobes : out std_logic_vector(3 downto 0); --via real IC12 & 12 HCT138
		disp_strobes : buffer std_logic_vector(3 downto 0); --via real IC12 & 12 HCT138
		disp_seg_A : out std_logic_vector(1 to 8); -- Group A - (8) is h segment
		disp_seg_B : out std_logic_vector(1 to 8); -- Group B - (8) is h segment
		
		--solenoids
		solenoids : out std_logic_vector(7 downto 0);
				
		-- SPI SD card & EEprom
		CS_SDcard	: 	buffer 	std_logic;
		CS_EEprom	: 	buffer 	std_logic;
		MOSI			: 	out 	std_logic;
		MISO			: 	in 	std_logic;
		CLK			: 	out 	std_logic;
		
		-- GottFA test switch
		Button_Test	: 	in 	std_logic;
		
		-- Soundboard
		audio_o			: 	out 	std_logic;
		SB_Test			: 	in 	std_logic;
		SB_Dip_Return	: 	in 	std_logic;
		
		audio_RX			: 	out 	std_logic -- Miniplayer
		

		);
end SYS1;


architecture rtl of SYS1 is

signal cpu_clk		: std_logic; -- 400 kHz CPU clock
signal reset_l	 	: std_logic := '0';
signal reset_sw_stable	:	std_logic; 

-- CPU PPS4/2
signal cpu_addr		: std_logic_vector(11 downto 0);
signal cpu_din			: std_logic_vector(7 downto 0);
signal cpu_w_io		: std_logic := '1';

signal io_data : std_logic_vector( 3 downto 0); -- data from IO device
signal io_data_U2 : std_logic_vector( 3 downto 0); -- data from IO device U2
signal io_data_U3 : std_logic_vector( 3 downto 0); -- data from IO device U3
signal io_data_U4 : std_logic_vector( 3 downto 0); -- data from IO device U4
signal io_data_U5 : std_logic_vector( 3 downto 0); -- data from IO device U5
signal io_cmd  : std_logic_vector( 3 downto 0); -- cmd to IO device
signal io_device    : std_logic_vector( 3 downto 0); -- ID of IO device
signal io_accu    : std_logic_vector( 3 downto 0); -- accu for input to IO device
signal io_port    : std_logic_vector( 3 downto 0); -- port of IO device (BL)

signal cpu_di_a		: std_logic_vector(3 downto 0);
signal cpu_di_b		: std_logic_vector(3 downto 0);
signal cpu_do_a		: std_logic_vector(3 downto 0);
signal cpu_do_b		: std_logic_vector(3 downto 0);

--  5101 RAM
signal r5101_addr		: std_logic_vector(7 downto 0);	  
signal r5101_dout_4bit 	: std_logic_vector(3 downto 0);	  
signal r5101_dout_8bit 	: std_logic_vector(7 downto 0);	  
signal r5101_din 	: std_logic_vector(3 downto 0);	  
signal r5101_cs		: std_logic;
signal ram_E2	: std_logic;
signal ram_WR	: std_logic;

-- ROMs
signal pgol_dout  : std_logic_vector(7 downto 0);
signal pgol_addr_8	: std_logic;
signal pgol_addr_9	: std_logic;
signal U4_rom_dout  : std_logic_vector(7 downto 0);
signal U5_rom_dout 	: std_logic_vector(7 downto 0);
signal A_rom_dout 	: std_logic_vector(7 downto 0);
signal SB_rom2_dout 	: std_logic_vector(7 downto 0);
signal SB_rom1_dout 	: std_logic_vector(7 downto 0);

-- address decoding helper
--signal pgol_cs		: std_logic;
signal U4_rom_cs		: std_logic;
signal U5_rom_cs		: std_logic;

-- IO devices
--signal data_io		: std_logic_vector(7 downto 0);
signal U2_cs		: std_logic;
signal U3_cs		: std_logic;
signal U4_cs		: std_logic;
signal U5_cs		: std_logic;
signal U6_cs		: std_logic;


-- displays
signal display_group_A : std_logic_vector(3 downto 0);
signal display_group_B : std_logic_vector(3 downto 0);
signal bm_disp_seg_A : std_logic_vector(1 to 8); --boot message
signal bm_disp_seg_B : std_logic_vector(1 to 8); --boot message
signal bm_disp_strobes : std_logic_vector(3 downto 0); --boot message
signal game_disp_seg_A : std_logic_vector(1 to 8); 
signal game_disp_seg_B : std_logic_vector(1 to 8);
signal game_disp_strobes : std_logic_vector(3 downto 0);

-- address decoding helper
signal U5_rom_addr	:  std_logic_vector(10 downto 0);
signal U4_rom_addr	:  std_logic_vector(10 downto 0);
signal PGOL_rom_addr	:  std_logic_vector(9 downto 0);
signal PGOL_rom_cpu_addr : std_logic_vector(9 downto 0);
signal A_rom_addr	:  std_logic_vector(11 downto 0);
signal attract_addr	:  std_logic_vector(11 downto 0);
-- 
signal SB_rom1_addr	:  std_logic_vector(9 downto 0);
signal SB_rom2_addr	:  std_logic_vector(9 downto 0);

-- SD card
signal address_sd_card	:  std_logic_vector(13 downto 0);
signal data_sd_card	:  std_logic_vector(7 downto 0);
signal wr_rom			:  std_logic;
signal wr_U5_rom			:  std_logic;
signal wr_U4_rom			:  std_logic;
signal wr_PGOL_rom			:  std_logic;
signal wr_A_rom			:  std_logic;
signal wr_SB_rom1			:  std_logic;
signal wr_SB_rom2			:  std_logic;
signal SDcard_MOSI	:	std_logic; 
signal SDcard_CLK		:	std_logic; 
signal SDcard_error	:	std_logic; 

-- EEprom we use 128Bytes
signal address_eeprom	:  std_logic_vector(6 downto 0);
signal data_eeprom	:  std_logic_vector(7 downto 0);
signal wr_ram			:  std_logic;
signal EEprom_MOSI	:	std_logic; 
signal EEprom_CLK		:	std_logic; 
signal EEprom_active	:	std_logic; 

-- trigger
signal game_over_relay			: std_logic;
signal tilt_relay			: std_logic;
signal HSTD			: std_logic;
signal clk_Z1			: std_logic;
signal test_sw			: std_logic;
signal credit_sw			: std_logic;


--internal helpers
signal sw_slam_intern		: std_logic;
signal solenoids_intern : std_logic_vector(7 downto 0);
signal sw_return_stable : std_logic_vector(7 downto 0);
signal sw_return_intern : std_logic_vector(7 downto 0);
signal sw_freeplay : std_logic_vector(7 downto 0);
signal sim_coin		: 	std_logic:= '0';

-- init & boot message helper
signal game_running		: 	std_logic:= '0';
signal dig0					:  std_logic_vector(3 downto 0);
signal dig1					:  std_logic_vector(3 downto 0);
signal dig2					:  std_logic_vector(3 downto 0);

signal	bm_st1_display1:	string(1 to 6);
signal	bm_st1_display2:	string(1 to 6);
signal	bm_st1_display3:	string(1 to 6);
signal	bm_st1_display4:	string(1 to 6);

-- attract mode ld&sd switch for lamps
signal game_ld			: std_logic_vector(3 downto 0);
signal game_ds			: std_logic_vector(3 downto 0);
signal attract_ld		: std_logic_vector(3 downto 0);
signal attract_ds		: std_logic_vector(3 downto 0);
signal attract_running		: 	std_logic:= '0';

-- read & save Gottlieb DIPs at start
-- as we use DIP24 as option for attract mode
signal gtb_dips_ds			: std_logic_vector(3 downto 0);
signal gtb_dips_red	: 	std_logic:= '0';
signal gtb_dips_save		: 	std_logic_vector(23 downto 0);
signal game_gtb_dips 	: 	std_logic_vector(7 downto 0);

-- Sound_Tones
signal SB_cpu_addr		: std_logic_vector(11 downto 0);
signal SB_cpu_clk		: std_logic; -- 832 kHz CPU clock for Soundboard
signal sb_option		: std_logic_vector(1 to 3);
signal sb_dip_strobe	: std_logic_vector(2 downto 0);
signal sb_status		: string (1 to 2);		
signal dfp_clk		: std_logic; 
signal sound_3tone		: std_logic; 
signal sound_multi		: std_logic; 
signal Sound_10		: std_logic; 
signal Sound_100		: std_logic; 
signal Sound_1K		: std_logic; 

signal sb_test_active		: std_logic; 
signal SB_Test_Sound_10		: std_logic; 
signal SB_Test_Sound_100		: std_logic; 
signal SB_Test_Sound_1K		: std_logic; 
signal SB_Test_Sound_BG		: std_logic; 
signal SB_game_over		: std_logic; 

begin

-- general assigments
LED_active <= not game_running;
LED_SD_Error <= SDcard_error;


----------------------
-- boot message
----------------------
bm_st1_display2 <= "BY BON" when reset_l = '0' else "V 903 ";
bm_st1_display3 <= "TANGO " when reset_l = '0' else "READSD";
bm_st1_display4 <= " 2022 " when reset_l = '0' else "ERROR " when sdcard_error = '0' else "      ";

sb_status <= "00" when sb_option(1 to 2) = "00" 
				 else "01" when sb_option(1 to 2) = "01" 
				 else "10" when sb_option(1 to 2) = "10" 
				 else "11";

BM: entity work.boot_message
port map(
	clk		=> clk_50, 		
   reset  => reset_sw_stable,
	-- input (display data)
	display1	=>  "GOTTFA",
	display2	=>  bm_st1_display2,
	display3	=>  bm_st1_display3,
	display4	=>  bm_st1_display4,	
	status_d(1)	=> character'val(to_integer(unsigned(dig0))+48),
	status_d(2)	=> character'val(to_integer(unsigned(dig1))+48),
	status_d(3 to 4)	=> sb_status, --"1S", -- Switch 1
	-- output
	group_A => bm_disp_seg_A,
	group_B => bm_disp_seg_B,
	strobes => bm_disp_strobes
	);

---------------------
-- shared SPI bus
----------------------
--SD card only at start of game
MOSI <= SDcard_MOSI when reset_l = '0' else EEprom_MOSI;
CLK <= SDcard_CLK when reset_l = '0' else EEprom_CLK;

	---------------------
-- count events
-- indicate game running or not
---------------------
COUNT_EVENTS: entity work.count_to_zero
port map(   
   Clock => clk_50,
	count =>"00000011",
	d_in => ram_E2,		
	d_out => game_running,
	clear => reset_l
	);
	
-- display bm switch
disp_seg_A <= bm_disp_seg_A when game_running = '0' else game_disp_seg_A;
disp_seg_B <= bm_disp_seg_B when game_running = '0' else game_disp_seg_B;
disp_strobes <= bm_disp_strobes when game_running = '0' else game_disp_strobes;
	
CONVB: entity work.byte_to_decimal
port map(
	clk_in	=> clk_50, 	
	mybyte	=> "1111" & sw1_dips,
	dig0 => dig0,
	dig1 => dig1,
	dig2 => dig2
	);

-- options
sw_slam_intern <= '1' when sw2_dips(3) = '0' else sw_slam; --slam deactivate with option Dip4 ON


-- Address decoding here, 
-- 0x0000-0x07FF	U5 Rom
U5_rom_cs	<= '1' when cpu_addr(11) = '0' else '0';
-- 0x0800-0x0FFF	U4 Rom
U4_rom_cs	<= '1' when cpu_addr(11) = '1' else '0';
-- PGOL rom is red direct by CPU

------------------
-- ROMs ----------
-- moved to RAM, initial 16KByte read from SD
-- one file of 16Kbyte for all Gottlieb Variants
-- address selection	
-- read from SD when wr_rom == 1
-- else map to address room
------------------
					
					
-- content of U5 rom is read from first 2K of SD
wr_U5_rom <= '1' when ((wr_rom='1') and (address_sd_card(13 downto 11) ="000" )) else '0';
U5_rom_addr <=  --2K
	address_sd_card(10 downto 0) when wr_U5_rom = '1' else
	cpu_addr(10 downto 0);

-- content of U4 rom is read from second 2K of SD
wr_U4_rom <= '1' when ((wr_rom='1') and (address_sd_card(13 downto 11) ="001" )) else '0';
U4_rom_addr <=  --2K
	address_sd_card(10 downto 0) when wr_U4_rom = '1' else
	cpu_addr(10 downto 0);

-- content of PGOL rom is read from 5.K on SD
wr_PGOL_rom <= '1' when ((wr_rom='1') and (address_sd_card(13 downto 10) = "0100" )) else '0';
PGOL_rom_addr <= --1K
	address_sd_card(9 downto 0) when wr_PGOL_rom = '1' else
	PGOL_rom_cpu_addr;

-- content of Soundrom is read from 6.K on SD	
wr_SB_rom1 <= '1' when ((wr_rom='1') and (address_sd_card(13 downto 10) = "0101" )) else '0';	
SB_rom1_addr <= --1K
	address_sd_card(9 downto 0) when wr_SB_rom1 = '1' else
	SB_cpu_addr(9 downto 0);

-- content of Mask Soundrom is read from 7.K on SD	
wr_SB_rom2 <= '1' when ((wr_rom='1') and (address_sd_card(13 downto 10) = "0110" )) else '0';	
SB_rom2_addr <= --1K
	address_sd_card(9 downto 0) when wr_SB_rom2 = '1' else
	SB_cpu_addr(9 downto 0);
	
-- content of Attract mode 'rom' is read from last 4K on SD
wr_A_rom <= '1' when ((wr_rom='1') and (address_sd_card(13 downto 12) = "11" )) else '0';
A_rom_addr <=  --4K
	address_sd_card(11 downto 0) when wr_A_rom = '1' else
	attract_addr;
	
-- construct the 'normal' PGOL addr first
PGOL_rom_cpu_addr(3 downto 0) <= not cpu_do_a;
PGOL_rom_cpu_addr(7 downto 4) <= not cpu_do_b;
PGOL_rom_cpu_addr(8) <= pgol_addr_8;
PGOL_rom_cpu_addr(9) <= pgol_addr_9;

-- Bus control
cpu_din <= 
U5_rom_dout when U5_rom_cs='1' else
U4_rom_dout when U4_rom_cs='1' else
x"FF";

--IO decoding
U2_cs <= '1' when io_device="0110" and cpu_w_io = '1' else '0'; --0x06  U2 GPIO 10696 - NVRAM in / out
U3_cs <= '1' when io_device="0011" and cpu_w_io = '1' else '0'; --0x03  U3 GPIO 10696 - Lamps, strobe, dip switches, bits 8 & 9 of PGOL address
U4_cs <= '1' when io_device="0100" and cpu_w_io = '1' else '0'; --0x04  U4 RRIO A1753 - Solenoids, NVRAM R/W & enable
U5_cs <= '1' when io_device="0010" and cpu_w_io = '1' else '0'; --0x02  U5 RRIO A1752 - Switch matrix
U6_cs <= '1' when io_device="1101" and cpu_w_io = '1' else '0'; --0x0d  U6 GPKD 10788 - Display

io_data <=
io_data_U2 when U2_cs = '1' else 
io_data_U3 when U3_cs = '1' else
io_data_U4 when U4_cs = '1' else
io_data_U5 when U5_cs = '1' else
x"F";


-- cpu clock 400Khz
clock_gen: entity work.cpu_clk_gen 
port map(   
	clk_in => clk_50,
	cpu_clk_out	=> cpu_clk,
	reset => reset_l
);

U1: entity work.PPS4 -- Rockwell PPS4/2
port map(
	clk     			=> cpu_clk,
	reset   			=> reset_l,
	w_io				=> cpu_w_io,	
	io_cmd			=> io_cmd,
	io_data			=> io_data,
	io_device		=> io_device,
	io_accu			=> io_accu,
	io_port			=> io_port,
	d_in    			=> cpu_din,	
	addr				=> cpu_addr,
	di_a				=> cpu_di_a,
	di_b				=> cpu_di_b,
	do_a				=> cpu_do_a,
	do_b				=> cpu_do_b
	--accu_debug => ld --RTH debug
	);

-- U2 NVRAM control ----
U2_IO: entity work.r10696
port map(
		  clk => clk_50,
        reset  => reset_l,
        device_id   => "0110", -- U2 has ID 0x06
		  w_io   => cpu_w_io,
		  --cs => U2_cs,
		  		  
		  io_data => io_data_U2,
		  
		  io_device  => io_device,
		  io_cmd   => io_cmd,
		  io_accu  => io_accu,
		  
		  group_A_in => r5101_dout_4bit,   -- inverter IC		  
		  group_B_in => "0000", --spare
		  group_C_in => "0000", --spare
		  
		  group_A_out => r5101_addr(7 downto 4),
		  group_B_out => r5101_addr(3 downto 0),
		  group_C_out => r5101_din
	);	

--  U3 GPIO 10696 - Lamps, strobe, dip switches, bits 8 & 9 of PGOL address
U3_IO: entity work.r10696
port map(
		  clk => clk_50,
        reset  => reset_l,
        device_id   => "0011", -- U3 has ID 0x03
		  w_io   => cpu_w_io,
		  --cs => U3_cs,
		  		  
		  io_data => io_data_U3,
		  
		  io_device  => io_device,
		  io_cmd   => io_cmd,
		  io_accu  => io_accu,
		  
		  group_A_in => not game_gtb_dips(3 downto 0), --GTB_dips(3 downto 0),
		  group_B_in => not game_gtb_dips(7 downto 4), --GTB_dips(7 downto 4),		  
		  group_C_in(0) => '0', --spare
		  group_C_in(1) => not sw_reset,		  -- no inverter on GottFA1 PCB here
		  group_C_in(2) => sw_outhole,		  
		  group_C_in(3) => sw_slam_intern,		  		  
		  		  
		  group_A_out => game_ld,
		  group_B_out => game_ds,
		  group_C_out(0) => pgol_addr_8,
		  group_C_out(1) => pgol_addr_9
		  );	

		 
PGOL_ROM: entity work.PGOL_ROM -- PGOL game rom 
port map(
	address => PGOL_rom_addr,
	clock		=> clk_50, 
	data => data_sd_card,
	wren => wr_PGOL_rom,		
	q(7 downto 4)			=> open, --because of data format RTH: change?
	q(3 downto 0)			=> cpu_di_a
	);	

		
U4_ROM: entity work.U4_ROM -- U4 System ROM 2KByte
port map(
	address	=> U4_rom_addr,
	clock		=> clk_50, 
	data => data_sd_card,
	wren => wr_U4_rom,		
	q			=> U4_rom_dout
	);	

-- U4 RRIO A1753 - Solenoids, NVRAM R/W & enable
U4_IO: entity work.rA17xx 
port map(
		  clk => clk_50,
        reset  => reset_l,
        device_id   => "0100", -- U4 has ID 0x04
		  w_io   => cpu_w_io,
		  		  
		  io_data => io_data_U4,
		  
		  io_device  => io_device,
		  io_cmd   => io_cmd,
		  
		  io_accu  => io_accu,
		  io_port => io_port,
		  
		  io_port_in(15 downto 0)  => "0000000000000000",
		  io_port_out( 7 downto 0) => solenoids_intern,		  
		  io_port_out( 12 downto 8) => open,
		  io_port_out(13) => ram_E2,
		  io_port_out(14) => ram_WR,
		  io_port_out(15) => open
	);	
		
U5_ROM: entity work.U5_ROM -- U5 System ROM 2KByte
port map(
	address	=> U5_rom_addr,
	clock		=> clk_50, 
	data => data_sd_card,
	wren => wr_U5_rom,		
	q			=> U5_rom_dout
	);	

SB_ROM1: entity work.SB_ROM -- Sound ROM 1KByte
port map(
	address	=> SB_Rom1_addr,
	clock		=> clk_50, 
	data => data_sd_card,
	wren => wr_SB_rom1,		
	q			=> SB_rom1_dout
	);	

SB_ROM2: entity work.SB_ROM -- Sound ROM 1KByte
port map(
	address	=> SB_Rom2_addr,
	clock		=> clk_50, 
	data => data_sd_card,
	wren => wr_SB_rom2,		
	q			=> SB_rom2_dout
	);	

--  U5 RRIO A1752 - Switch matrix	
U5_IO: entity work.rA17xx 
port map(
		  clk => clk_50,
        reset  => reset_l,
        device_id   => "0010", -- U5 has ID 0x02
		  w_io   => cpu_w_io,
		  		  
		  io_data => io_data_U5,
		  
		  io_device  => io_device,
		  io_cmd   => io_cmd,
		  io_accu  => io_accu,
		  io_port => io_port,

		  io_port_in(7 downto 0)  => "00000000",		  
		  io_port_in(15 downto 8)  => sw_return_intern,		
		  io_port_out( 4 downto 0) => sw_strobe,
		  io_port_out( 15 downto 5) => open
	);	
	
	
U6_IO: entity work.r10788
port map(
		  clk => clk_50,
        reset  => reset_l,
        device_id   => "1101", -- U6 has ID 0x0d
		  w_io   => cpu_w_io,
		  		  
		  --io_data => io_data_U6,
		  
		  io_device  => io_device,
		  io_cmd   => io_cmd,
		  io_accu  => io_accu,
		  		  
		  group_A => display_group_A,
		  group_B => display_group_B,
		  strobes => game_disp_strobes,
		  
		  is_tube => sw2_dips(2)   --adjust timing for display via options dip3

	);	

-- display decoder
--SN7448 'with h segment'
sn7448_1: entity work.sn7448_wh
port map(   
	Din 	=> display_group_A,
	Dout  => game_disp_seg_A
);


sn7448_2: entity work.sn7448_wh
port map(   
	Din 	=> display_group_B,
	Dout  => game_disp_seg_B
);

---------------------
-- SD card stuff
----------------------
SD_CARD: entity work.SD_Card
port map(
		
	i_clk		=> clk_50,	
	-- Control/Data Signals,
   i_Rst_L  => reset_sw_stable,     -- FPGA Reset 
	-- PMOD SPI Interface
   o_SPI_Clk  => SDcard_CLK,
   i_SPI_MISO => MISO,
   o_SPI_MOSI => SDcard_MOSI,
   o_SPI_CS_n => CS_SDcard,	
	-- selection	
	selection => "0000" & not sw1_dips,
	-- data
	address_sd_card => address_sd_card,
	data_sd_card => data_sd_card,
	wr_rom => wr_rom,
	-- control CPU & rest of HW
	cpu_reset_l => reset_l,
	-- feedback
	SDcard_error => SDcard_error
);	
	
----------------------
-- read eeprom, read/write to ram
----------------------
EEprom: entity work.EEprom
port map(
	i_clk => clk_50,
	address_eeprom	=> address_eeprom,
	data_eeprom	=> data_eeprom,
	wr_ram => wr_ram,
	q_ram => r5101_dout_8bit,
	-- Control/Data Signals,   
	i_Rst_L  => reset_l,
	-- PMOD SPI Interface
   o_SPI_Clk  => EEprom_CLK,
   i_SPI_MISO => MISO,
   o_SPI_MOSI => EEprom_MOSI,
   o_SPI_CS_n => CS_EEprom,
	-- selection
	--selection => "0000" & not sw1_dips,
	selection => "00000000", --v303 workaround as some games do not save correct (e.g. torch) -> position depending
	-- write trigger
	w_trigger(3) => game_over_relay,
	w_trigger(2) => test_sw,
	w_trigger(1) => credit_sw,
	w_trigger(0) => '0', -- as trigger for testing, not used
	-- init trigger (no read, RAM will be zero)
	i_init_Flag => sw2_dips(0), -- 0 if option Dip1 is set 
	-- signal to outside
	is_active => EEprom_active
	);	
	
-- Trigger	
test_sw <= sw_strobe(0) and sw_return_stable(0);

-- detect credit and test_switch for trigger
-- credit switch trigger with timer
detect_credit_sw_trigger: entity work.detect_sw_trigger
port map(
	clk    => cpu_clk,
	sw_strobe => sw_strobe(3),
	sw_return => sw_return_stable(0),	
	trigger => credit_sw,	
	rst 	=> game_running
);


----------------------
-- 5101 ram (dual port)
----------------------
Z33: entity work.R5101 -- 5101 RAM 128Byte (256 * 4bit) 
	port map(
		address_a	=> r5101_addr,
		address_b   => address_eeprom,
		clock			=> clk_50,
		data_a		=> r5101_din, -- 4bit
		data_b		=> data_eeprom, --8bit
		wren_a 		=> ram_WR and ram_E2,
		wren_b 		=> wr_ram,
		q_a			=> r5101_dout_4bit,
		q_b			=> r5101_dout_8bit
);

---------------------
-- detection game over relay (Q1)
----------------------
clk_Z1 <= '1' when game_ds = "0001" else '0'; --DS1
sn74175_Game_O: entity work.sn74175 
port map(   
   Clock => clk_50,
	clk => clk_Z1,
	clear	=> '1',
	D => game_ld,
	Q => open,
	Qn(0) => game_over_relay,
	Qn(1) => tilt_relay,
	Qn(2) => HSTD
);

---------------------
-- freeplay
----------------------
sw_return_intern <= sw_return_stable or sw_freeplay;

-- simulate coin chute #1 ( strobe 1 / return 0 )
Freeplay: process(sim_coin)
 begin 
    if (( sim_coin = '1') and (sw_strobe(1) = '1') and (sw2_dips(1) = '0')) then --option DIP2 activates freeplay
		sw_freeplay <= "00000001";
	 else	
		sw_freeplay <= "00000000";
 end if;	
end process;  

detect_credit_sw: entity work.detect_sw
port map(
	clk    => cpu_clk,
	sw_strobe => sw_strobe(3),
	sw_return => sw_return_stable(0),		
	short_push => open,
	long_push => sim_coin,
	rst 	=> game_running
);

META1: entity work.Cross_Slow_To_Fast_Clock
port map(
   i_D => reset_sw,
	o_Q => reset_sw_stable,
   i_Fast_Clk => clk_50
	); 

META2: entity work.Cross_Slow_To_Fast_Clock_Bus
port map(
   i_D => sw_return,
	o_Q => sw_return_stable,
   i_Fast_Clk => clk_50
	);

---------------------
-- attract mode - actvated with Gottlieb Switch #24
----------------------		
game_gtb_dips <= GTB_dips when gtb_dips_save(23)='1' else
					  gtb_dips_save(7 downto 0) when game_ds = "0000" else
					  gtb_dips_save(15 downto 8) when game_ds = "0001" else
					  gtb_dips_save(23 downto 16) when game_ds = "0010" else
					  "11111111";

ld <= attract_ld when (attract_running='1' and gtb_dips_save(23)='0') else game_ld;

ds <= gtb_dips_ds when gtb_dips_red='0' else
	   attract_ds when (attract_running='1' and gtb_dips_save(23)='0')
		else game_ds;

A_ROM: entity work.attract -- 4K commands for attract mode
port map(
	address	=> A_rom_addr,
	clock		=> clk_50, 
	data => data_sd_card,
	wren => wr_A_rom,		
	q			=> A_rom_dout
	);	

A_CMD: entity work.attract_cmd
port map(
	clk	 => cpu_clk, 
	reset  => reset_l,	
	game_over_relay => not game_over_relay,
	HSTD => HSTD,
	address	=> attract_addr,
	data => A_rom_dout,
	ld => attract_ld,
	ds => attract_ds,
	ctrl => attract_running
	);	
	

A_DIPS: entity work.read_sys1_dips
port map(
	clk	 => cpu_clk, 
	reset  => reset_l,	
	dips   =>	gtb_dips,	
	ds     => gtb_dips_ds,
	gtb_dips	=> gtb_dips_save,
	done  => gtb_dips_red
	);	

B_DIPS: entity work.read_SB_dips
port map(
	clk_in		=> sb_cpu_clk,
	i_Rst_L  => reset_sw_stable,
	--output 
	sb_option	=> sb_option,
	-- strobes
	dip_strobe => sb_dip_strobe,
	-- input
	return_sig => sb_dip_Return,
	-- signal when finished
	done	=> open -- set to '1' when reading dips is done
	);	
		
LED_0 <= sb_dip_strobe(0);
LED_1 <= sb_dip_strobe(1);
LED_2 <= sb_dip_strobe(2);

------------------------------------------------
-------------- S O U N D -----------------------	
------------------------------------------------
SYS1_Sound: entity work.Multi_Sound
port map(
	cpu_clk => SB_cpu_clk,
	clk_50 => clk_50,
	reset_l => reset_l,
	-- signals are active high because of inverter on original SB
	S_1000 => not Sound_1K,
	S_100 => not Sound_100,
	S_10 => not Sound_10,
	S_Tilt => not tilt_relay,
	S_Game_Over => SB_game_over,
	Test => '1', --SB_Test,
	Sound_Tones => not SB_option(1), --sound_tones, 
	Attract => not SB_option(2), --attract,
	Audio_o => sound_multi,
	cpu_addr => SB_cpu_addr,
	rom1_dout => SB_rom1_dout,
	rom2_dout => SB_rom2_dout,
	game_sel => sw1_dips
	);
-- generate tones via FPGA
GENTONES: entity work.gentones
port map(
	hiclk => clk_50,	
   tonesel(0) => Sound_10,
	tonesel(1) => Sound_100,
	tonesel(2) => Sound_1K,
   soundout => sound_3tone
	);	
-- switch sound according to selected game	
-- with game 9 (totem) sys1 changed to Multisound
audio_o <= sound_3tone when unsigned(not sw1_dips) <= 8 else sound_multi;

-- inverter in original design
solenoids <= not solenoids_intern;

--test integrated soundboard	
SB_Test_SYS1: entity work.SB_Test_SYS1
port map( 
	  clk   => dfp_clk,
	  	reset  => game_running, --reset_l,	
     button  => SB_Test,
      	  
	  Sound_10 => SB_Test_Sound_10,
	  Sound_100 => SB_Test_Sound_100,
	  Sound_1K => SB_Test_Sound_1K,
	  Sound_BG => SB_Test_Sound_BG,	  
	  	  
	  test_active  => sb_test_active
	  );
	  
Sound_10 <= solenoids_intern(2) when sb_test_active='0' else SB_Test_Sound_10;
Sound_100 <= solenoids_intern(3) when sb_test_active='0' else SB_Test_Sound_100;
Sound_1K <= solenoids_intern(4) when sb_test_active='0' else SB_Test_Sound_1K;
SB_game_over <= not game_over_relay when sb_test_active='0' else not sb_test_active;

-- cpu clock 
clock_gen2: entity work.SB_cpu_clk_gen 
port map(   
	clk_in => clk_50,
	clk_out	=> SB_cpu_clk,
	clk_adj => "000"
);

-- 9600 baud send clock
dfp_clk_g: entity work.dfp_clk_gen 
port map(   
	clk_in => clk_50,
	dfp_clk_out	=> dfp_clk
);
-- sound/music via MP3 player	
DFP_send: entity work.DFPlayer_Mini_CMD 
port map(   
			trigger => (game_over_relay and SB_option(3) and game_running) or SB_Test_Sound_BG,
         clk => dfp_clk,
			start_new => not gtb_dips_save(15), -- Gottlieb DIP16 as option, with ON restart music each game
         rst => reset_l,
         txd => Audio_RX		
);
	
end rtl;
		
