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
--
-- Ab hier EIN gemeinsames Top-Level fuer alle vier Boards (Umbau 13.08.2026).
-- Die angezeigte Version setzt sich jetzt zusammen aus
--     BOARD_ID  aus variants/<name>/variant_pkg.vhd   (6/7/8/9)
--     SW_SUB    aus rtl/common/version_pkg.vhd        (fuer alle Boards gleich)
-- Board-Kennungen: 5 = HW v2.0x Cyclone IV v3 (seit x.30),
--                  6 = HW v2.1x Cyclone IV v3, 7 = HW v2.0x Cyclone IV v4,
--                  8 = HW v2.1x Cyclone IV v4, 9 = HW v2.1x Cyclone 10.
-- Ein Release aendert damit genau eine Zahl, und zwar in version_pkg.vhd.
--
-- Version x.30 -- game ROMs from the configuration flash when no SD card answers
--                 (Flash_ROM.vhd, same 16 KByte per game as on the card, no CRC),
--                 reset_sw filtered (50 ms), slam/outhole/reset switch filtered (1 ms),
--                 diagnostic counters for reset and dropped reset pulses on the boot
--                 display ("R01G37"). See docs/Stoerimpulse_Resets.md.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
-- Was dieses Board ist, und welche Software darauf laeuft:
use work.variant_pkg.all;   -- BOARD_ID
use work.version_pkg.all;   -- SW_SUB
use work.fa_control_pkg.all;  -- fa_nibble_array_t, rtl/fa_control/

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
		LED_Test : out STD_LOGIC;                -- nur HW v2.0x, sonst VIRTUAL_PIN
		
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
		
		audio_RX			: 	out 	std_logic; -- Miniplayer
		
		-- USB serial CH340 - nur HW v2.0x, sonst VIRTUAL_PIN
		USB_Rx			: 	buffer 	std_logic;
		USB_Tx			: 	in 	std_logic;

		-- configuration flash EPCS16 as second source of the game ROMs, when no SD
		-- card answers. Dual purpose pins, released as regular I/O after configuration
		-- (scripts/common_header.tcl). See rtl/common/Flash_ROM.vhd.
		FLASH_DCLK		: 	out 	std_logic;
		FLASH_NCS		: 	out 	std_logic;
		FLASH_ASDO		: 	out 	std_logic;	-- data into the flash
		FLASH_DATA0		: 	in 	std_logic;	-- data out of the flash

		-- FA-Control: ESP32-C3 Supermini on X7 of the Cyclone IV board v7. Only
		-- hw20x_cyclone_iv_v7 has it (HAS_ESP32); everywhere else VIRTUAL_PIN.
		FA_RXD			:	in		std_logic;	-- R3, from the ESP's TX (GPIO7)
		FA_TXD			:	out	std_logic;	-- T2, to the ESP's RX (GPIO6)
		FA_CTRL_REQ		:	in		std_logic	-- N3, active low, weak pull-up


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

-- the ROM write port comes from the SD card, or from the configuration flash when
-- no card answered (use_flash)
signal sd_address		:  std_logic_vector(13 downto 0);
signal sd_data			:  std_logic_vector(7 downto 0);
signal sd_wr_rom		:  std_logic;
signal sd_cpu_reset_l	:  std_logic;
signal sd_error		:  std_logic;
signal sd_no_card		:  std_logic;
signal fl_address		:  std_logic_vector(13 downto 0);
signal fl_data			:  std_logic_vector(7 downto 0);
signal fl_wr_rom		:  std_logic;
signal fl_cpu_reset_l	:  std_logic;
signal fl_error		:  std_logic;
signal use_flash		:  std_logic;

-- filtered inputs (input_filter.vhd)
signal reset_sw_glitch	:  std_logic; -- a pulse on reset_sw was too short and dropped
signal reset_sw_prev		:  std_logic := '0';
signal sw_reset_f			:  std_logic;
signal sw_outhole_f		:  std_logic;
signal sw_slam_f			:  std_logic;

-- diagnostic counters, two decimal digits each, saturating at 99. Only the power-up
-- value clears them - a reset through reset_sw does not. So after an unexpected
-- restart the boot display tells: R counted up -> the reset pin was low for 50 ms;
-- R00 G00 -> the FPGA was configured again (supply dip, nCONFIG spike).
signal rst_d1, rst_d0	:  integer range 0 to 9 := 0; -- resets through reset_sw
signal glt_d1, glt_d0	:  integer range 0 to 9 := 0; -- dropped pulses on reset_sw

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
-- ---------------------------------------------------------------------------
-- FA-Control (rtl/fa_control): LISY slave for the ESP32-C3 on X7 of board v7.
-- BUILT ONLY WHERE HAS_ESP32 IS TRUE (variant_pkg). Everywhere else
-- gen_no_fa_control ties fa_active to '0', synthesis removes every mux below and
-- the netlist stays as it was - that is the acceptance criterion.
--
-- While the ESP has control, the PPS/4 CPU alone is held in reset; the I/O chips
-- keep running, so r10788 goes on scanning the displays. Lamps, solenoids, sound
-- and the switch strobes come from here instead. Releasing control restarts the
-- game. Taking over needs nothing at the machine: no option DIP is free on
-- GottFA1 (all four S2 and all three sound DIPs are in use), so ctrl_allow = '1'.
--
-- Numbering as LISY1 (lisy_5_28/src/lisy/lisy1.c), i.e. as the machine's manual:
--   lamps    0..35  = Q1..Q36, latch DS1..DS9, lamp n on DS(n/4+1) bit n mod 4;
--                     DS1 carries the relays (Q1 game over, Q2 tilt, ...)
--   switches 10*return + strobe: 00..04, 10..14, ... 70..74 (gaps stay open)
--   coils    1..8   = solenoids(0..7); 3/4/5 double as the 10/100/1000 sound lines
--   sounds   1..7   = Sound_10/100/1K as bit 0/1/2 of the sound number
-- ---------------------------------------------------------------------------
constant FA_N_LAMPS	: integer := 36;
constant FA_N_SOL	: integer := 8;
constant FA_N_SW	: integer := 75;	-- 10 * 7 + 4 + 1
constant FA_N_DISP	: integer := 5;		-- 0 = status (4 digits), 1..4 = player
constant FA_DIGITS	: integer := 6;
signal fa_active	: std_logic;
signal fa_sw_state	: std_logic_vector(FA_N_SW - 1 downto 0) := (others => '0');
signal fa_lamp_ovr	: std_logic_vector(FA_N_LAMPS - 1 downto 0);
signal fa_sol_ovr	: std_logic_vector(FA_N_SOL - 1 downto 0);
signal fa_disp_ovr	: fa_nibble_array_t(0 to FA_N_DISP * FA_DIGITS - 1);
signal fa_snd_ovr	: std_logic_vector(3 downto 0);
signal fa_snd_en	: std_logic;
signal fa_ld		: std_logic_vector(3 downto 0);
signal fa_ds		: std_logic_vector(3 downto 0);
signal fa_sw_strobe	: std_logic_vector(4 downto 0);
signal fa_disp_A	: std_logic_vector(3 downto 0);
signal fa_disp_B	: std_logic_vector(3 downto 0);
signal game_sw_strobe	: std_logic_vector(4 downto 0);
signal cpu_reset_l	: std_logic;
signal disp_blank	: std_logic;
signal disp_in_A	: std_logic_vector(3 downto 0);
signal disp_in_B	: std_logic_vector(3 downto 0);
signal Sound_10_g	: std_logic;
signal Sound_100_g	: std_logic;
signal Sound_1K_g	: std_logic;
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
LED_Test <= not sb_test_active; --LED ON when SB test running
USB_Rx <= '1';                  --UART-Ruhepegel, solange die CH340-Anbindung nicht benutzt wird


----------------------
-- boot message
----------------------
bm_st1_display2 <= "BY BON" when reset_l = '0' else string'("V ") & BOARD_ID & SW_SUB & " ";
bm_st1_display3 <= "TANGO " when reset_l = '0' else "READFL" when use_flash = '1' else "READSD";
-- diagnostic counters instead of the year, see rst_d1 above
bm_st1_display4 <= "ERROR " when sdcard_error = '0' else
						 string'("R") & character'val(rst_d1 + 48) & character'val(rst_d0 + 48)
						 & "G" & character'val(glt_d1 + 48) & character'val(glt_d0 + 48);

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
disp_seg_A <= bm_disp_seg_A when game_running = '0' and fa_active = '0' else game_disp_seg_A;
disp_seg_B <= bm_disp_seg_B when game_running = '0' and fa_active = '0' else game_disp_seg_B;
disp_strobes <= bm_disp_strobes when game_running = '0' and fa_active = '0' else game_disp_strobes;
	
CONVB: entity work.byte_to_decimal
port map(
	clk_in	=> clk_50, 	
	mybyte	=> "1111" & sw1_dips,
	dig0 => dig0,
	dig1 => dig1,
	dig2 => dig2
	);

-- options
sw_slam_intern <= '1' when sw2_dips(3) = '0' else sw_slam_f; --slam deactivate with option Dip4 ON


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
	clk_fast => clk_50,
	clk     			=> cpu_clk,
	reset   			=> cpu_reset_l,	-- reset_l, plus held while FA-Control is in charge
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
		  group_C_in(1) => not sw_reset_f,		  -- no inverter on GottFA1 PCB here
		  group_C_in(2) => sw_outhole_f,
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
		  io_port_out( 4 downto 0) => game_sw_strobe,
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
		  blank_o => disp_blank,
		  
		  is_tube => sw2_dips(2)   --adjust timing for display via options dip3

	);	

-- display decoder
--SN7448 'with h segment'
sn7448_1: entity work.sn7448_wh
port map(   
	Din 	=> disp_in_A,
	Dout  => game_disp_seg_A
);


sn7448_2: entity work.sn7448_wh
port map(   
	Din 	=> disp_in_B,
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
	address_sd_card => sd_address,
	data_sd_card => sd_data,
	wr_rom => sd_wr_rom,
	-- control CPU & rest of HW
	cpu_reset_l => sd_cpu_reset_l,
	-- feedback
	SDcard_error => sd_error,
	o_no_card => sd_no_card
);

----------------------
-- configuration flash as fallback
----------------------
-- No card answered (SD_Card in its error state) -> read the same 16 KByte from the
-- flash and take over the ROM write port, the CPU reset and the error LED. Flash
-- layout in rtl/common/Flash_ROM.vhd, the hex file comes from
-- scripts/make_flash_hex.ps1. A released .jic without ROMs leaves the slot empty:
-- the board then shows ERROR exactly as before.
use_flash <= sd_no_card;

FLASH_ROM: entity work.Flash_ROM
port map(
	i_Clk => clk_50,
	i_Rst_L => sd_no_card,
	o_Flash_Clk  => FLASH_DCLK,
	o_Flash_CS_n => FLASH_NCS,
	o_Flash_MOSI => FLASH_ASDO,
	i_Flash_MISO => FLASH_DATA0,
	selection => "0000" & not sw1_dips,
	address_rom => fl_address,
	data_rom => fl_data,
	wr_rom => fl_wr_rom,
	cpu_reset_l => fl_cpu_reset_l,
	Flash_error => fl_error
);

address_sd_card <= fl_address when use_flash = '1' else sd_address;
data_sd_card    <= fl_data when use_flash = '1' else sd_data;
wr_rom          <= fl_wr_rom when use_flash = '1' else sd_wr_rom;
reset_l         <= fl_cpu_reset_l when use_flash = '1' else sd_cpu_reset_l;
SDcard_error    <= fl_error when use_flash = '1' else sd_error;
	
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

-- reset button: low for 50 ms before the board restarts. Up to x.03 a single 20 ns
-- low sample (a coil spike on the open, weakly pulled up pin) restarted everything.
-- Init '0': the same filter is the power-on reset, see input_filter.vhd.
META1: entity work.input_filter
generic map(
	Filter_Cycles => 2500000,  -- 50 ms
	Init_Value => '0'
	)
port map(
	i_Clk => clk_50,
	i_D => reset_sw,
	o_Q => reset_sw_stable,
	o_glitch => reset_sw_glitch
	);

-- the special switches read by U3: 1 ms, the CPU samples them much slower anyway
FILT_RESET: entity work.input_filter
generic map( Filter_Cycles => 50000, Init_Value => '1' )
port map( i_Clk => clk_50, i_D => sw_reset, o_Q => sw_reset_f, o_glitch => open );

FILT_OUTHOLE: entity work.input_filter
generic map( Filter_Cycles => 50000, Init_Value => '0' )
port map( i_Clk => clk_50, i_D => sw_outhole, o_Q => sw_outhole_f, o_glitch => open );

FILT_SLAM: entity work.input_filter
generic map( Filter_Cycles => 50000, Init_Value => '0' )
port map( i_Clk => clk_50, i_D => sw_slam, o_Q => sw_slam_f, o_glitch => open );

-- diagnostic counters, see the declaration of rst_d1. No reset on purpose.
DIAG: process(clk_50)
begin
	if rising_edge(clk_50) then
		reset_sw_prev <= reset_sw_stable;
		-- falling edge of the filtered reset = a reset that went through
		if reset_sw_prev = '1' and reset_sw_stable = '0' then
			if rst_d0 /= 9 then
				rst_d0 <= rst_d0 + 1;
			elsif rst_d1 /= 9 then
				rst_d0 <= 0;
				rst_d1 <= rst_d1 + 1;
			end if;
		end if;
		if reset_sw_glitch = '1' then
			if glt_d0 /= 9 then
				glt_d0 <= glt_d0 + 1;
			elsif glt_d1 /= 9 then
				glt_d0 <= 0;
				glt_d1 <= glt_d1 + 1;
			end if;
		end if;
	end if;
end process;

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

ld <= fa_ld when fa_active = '1' else
      attract_ld when (attract_running='1' and gtb_dips_save(23)='0') else game_ld;

ds <= fa_ds when fa_active = '1' else
	   gtb_dips_ds when gtb_dips_red='0' else
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
solenoids <= not fa_sol_ovr when fa_active = '1' else not solenoids_intern;

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
	  
Sound_10_g <= solenoids_intern(2) when sb_test_active='0' else SB_Test_Sound_10;
Sound_100_g <= solenoids_intern(3) when sb_test_active='0' else SB_Test_Sound_100;
Sound_1K_g <= solenoids_intern(4) when sb_test_active='0' else SB_Test_Sound_1K;
Sound_10  <= fa_snd_ovr(0) and fa_snd_en when fa_active = '1' else Sound_10_g;
Sound_100 <= fa_snd_ovr(1) and fa_snd_en when fa_active = '1' else Sound_100_g;
Sound_1K  <= fa_snd_ovr(2) and fa_snd_en when fa_active = '1' else Sound_1K_g;
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
	
------------------------------------------------------------------------------
-- FA-Control. The muxes above are unconditional on purpose: without the ESP,
-- fa_active is the constant '0' and synthesis removes them.
------------------------------------------------------------------------------
cpu_reset_l <= reset_l and not fa_active;
sw_strobe   <= fa_sw_strobe when fa_active = '1' else game_sw_strobe;

disp_in_A <= "1111" when fa_active = '1' and disp_blank = '1' else
             fa_disp_A when fa_active = '1' else display_group_A;
disp_in_B <= "1111" when fa_active = '1' and disp_blank = '1' else
             fa_disp_B when fa_active = '1' else display_group_B;

gen_fa_control: if HAS_ESP32 generate

	signal lamp_cnt   : integer range 0 to 4999 := 0;	-- 100 us per phase
	signal lamp_phase : integer range 0 to 2 := 0;
	signal lamp_latch : integer range 1 to 9 := 1;
	signal sw_cnt     : integer range 0 to 49999 := 0;	-- 1 ms per strobe
	signal sw_slot    : integer range 0 to 4 := 0;
	signal game_no    : integer range 0 to 15;
	signal game_bcd   : std_logic_vector(11 downto 0);

begin

FAC: entity work.fa_control
generic map(
	CLKS_PER_BIT => 434,		-- 50 MHz / 115200 baud
	HW_NAME      => "GottFA1",
	API_VER      => "0.12",
	N_LAMPS      => FA_N_LAMPS,
	N_SOL        => FA_N_SOL,
	N_SOUNDS     => 8,
	N_SW         => FA_N_SW,
	N_DISP       => FA_N_DISP,
	DISP_TYPE    => 1,		-- BCD7
	DISP_DIGITS  => (4, 6, 6, 6, 6, 0, 0),
	MAX_LAMPS    => FA_N_LAMPS,
	MAX_SOL      => FA_N_SOL,
	MAX_SW       => FA_N_SW,
	MAX_DIGITS   => FA_DIGITS,
	GAME_DIGITS  => 3		-- FA-Control files names/roms under GottFA1/<nnn>
	)
port map(
	clk         => clk_50,
	reset       => not reset_sw_stable,
	rxd         => FA_RXD,
	txd         => FA_TXD,
	ctrl_req    => FA_CTRL_REQ,
	ctrl_allow  => '1',		-- no option DIP left, see the constant block
	ctrl_active => fa_active,
	ver_main    => std_logic_vector(to_unsigned(character'pos(BOARD_ID) - 48, 4)),
	ver_sub1    => std_logic_vector(to_unsigned(character'pos(SW_SUB(1)) - 48, 4)),
	ver_sub2    => std_logic_vector(to_unsigned(character'pos(SW_SUB(2)) - 48, 4)),
	game_info   => game_bcd,
	sw_state    => fa_sw_state,
	lamp_ovr    => fa_lamp_ovr,
	sol_ovr     => fa_sol_ovr,
	disp_ovr    => fa_disp_ovr,
	snd_ovr     => fa_snd_ovr,
	snd_en      => fa_snd_en
	);

-- game number as selected with S1, the same index SD_Card and Flash_ROM use
game_no  <= to_integer(unsigned(not sw1_dips));
game_bcd <= "0000" & "0001" & std_logic_vector(to_unsigned(game_no, 4) - 10) when game_no >= 10 else
            "0000" & "0000" & std_logic_vector(to_unsigned(game_no, 4));

-- Lamps. A 74175 per DS line takes LD when its 74154 output goes back inactive,
-- so per latch: LD first with DS0 (no lamp latch), then DS = n, then DS0 again
-- while LD stays. LD is inverted on the way to the lamps: '0' = lamp on.
FA_LAMPS: process(clk_50)
	variable nib : std_logic_vector(3 downto 0);
begin
	if rising_edge(clk_50) then
		nib := (others => '0');
		for i in 0 to 8 loop
			if lamp_latch = i + 1 then
				nib := fa_lamp_ovr(4 * i + 3 downto 4 * i);
			end if;
		end loop;
		if lamp_cnt = 4999 then
			lamp_cnt <= 0;
			if lamp_phase = 2 then
				lamp_phase <= 0;
				if lamp_latch = 9 then
					lamp_latch <= 1;
				else
					lamp_latch <= lamp_latch + 1;
				end if;
			else
				lamp_phase <= lamp_phase + 1;
			end if;
		else
			lamp_cnt <= lamp_cnt + 1;
		end if;
		case lamp_phase is
			when 0 =>      fa_ld <= not nib; fa_ds <= "0000";
			when 1 =>      fa_ds <= std_logic_vector(to_unsigned(lamp_latch, 4));
			when others => fa_ds <= "0000";
		end case;
	end if;
end process;

-- Switch strobes while the CPU is halted: one strobe per millisecond.
FA_STROBES: process(clk_50)
begin
	if rising_edge(clk_50) then
		if sw_cnt = 49999 then
			sw_cnt <= 0;
			if sw_slot = 4 then
				sw_slot <= 0;
			else
				sw_slot <= sw_slot + 1;
			end if;
		else
			sw_cnt <= sw_cnt + 1;
		end if;
		for s in 0 to 4 loop
			if sw_slot = s then
				fa_sw_strobe(s) <= '1';
			else
				fa_sw_strobe(s) <= '0';
			end if;
		end loop;
	end if;
end process;

-- Switch state, read all the time (FA-Control shows it without control too):
-- whoever drives the strobes, the returns of an active strobe are taken over.
-- Exactly one strobe is active at a time, from the game as from FA_STROBES.
FA_SWITCHES: process(clk_50)
begin
	if rising_edge(clk_50) then
		for s in 0 to 4 loop
			if sw_strobe(s) = '1' then
				for r in 0 to 7 loop
					fa_sw_state(10 * r + s) <= sw_return_stable(r);
				end loop;
			end if;
		end loop;
	end if;
end process;

-- Displays, r10788 order: strobe s shows digit s (see boot_message_alpha.vhd).
--   s 0..5   A = player 1, B = player 3, rightmost digit first
--   s 8..13  A = player 2, B = player 4, rightmost digit first
--   s 6/7, 14/15  A = status, B dark
-- LISY digits arrive left to right: index 0 is the LEFT one.
-- HW-TUNABLE: the status order (which pair is credits) is a guess.
FA_DISP: process(game_disp_strobes, fa_disp_ovr)
	variable s : integer range 0 to 15;
begin
	s := to_integer(unsigned(game_disp_strobes));
	fa_disp_A <= "1111";
	fa_disp_B <= "1111";
	case s is
		when 0 to 5 =>
			fa_disp_A <= fa_disp_ovr(1 * FA_DIGITS + 5 - s);
			fa_disp_B <= fa_disp_ovr(3 * FA_DIGITS + 5 - s);
		when 8 to 13 =>
			fa_disp_A <= fa_disp_ovr(2 * FA_DIGITS + 13 - s);
			fa_disp_B <= fa_disp_ovr(4 * FA_DIGITS + 13 - s);
		when 15 =>     fa_disp_A <= fa_disp_ovr(0);
		when 14 =>     fa_disp_A <= fa_disp_ovr(1);
		when 7 =>      fa_disp_A <= fa_disp_ovr(2);
		when others => fa_disp_A <= fa_disp_ovr(3);	-- 6
	end case;
end process;

end generate;

------------------------------------------------------------------------------
-- Boards without the ESP32. FA_TXD has no pin here (VIRTUAL_PIN), but a declared
-- output nobody drives is a pin Quartus places and drives anyway; '1' is the idle
-- level of an UART line.
------------------------------------------------------------------------------
gen_no_fa_control: if not HAS_ESP32 generate
	fa_active    <= '0';
	FA_TXD       <= '1';
	fa_ld        <= (others => '0');
	fa_ds        <= (others => '0');
	fa_sw_strobe <= (others => '0');
	fa_sol_ovr   <= (others => '0');
	fa_snd_ovr   <= (others => '0');
	fa_snd_en    <= '0';
	fa_disp_A    <= (others => '1');
	fa_disp_B    <= (others => '1');
end generate;

end rtl;
		
