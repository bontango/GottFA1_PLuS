--
-- Flash_ROM.vhd
-- read the game ROMs from the FPGA configuration flash (EPCS16) instead of the SD card
-- fallback for GottFA1, started by SD_Card when no card answers (o_no_card)
-- ported from WillFA7 Flash_ROM v02 (github.com/bontango/WillFA7)
-- bontango 10.2026
--
-- v01 first version for GottFA1: 16 KByte slot, the same image as on the SD card.
--
-- Flash layout (written by scripts/make_flash_hex.ps1 into a local .jic, see
-- gottfa1_roms.cof of the variant):
--     0x000000 - 0x07FFFF   bitstream plus reserve (EP4CE6 / 10CL006 ca. 360 KByte)
--     Base_Addr + n * Slot_Bytes
--                           game n, 16 KByte, byte for byte the SD card slot:
--                           0x0000 U5 rom, 0x0800 U4 rom, 0x1000 PGOL, 0x1400 SB rom1,
--                           0x1800 SB rom2, 0x3000 attract mode
--
-- No CRC. The flash has no contacts and no file system, and the data is verified by
-- the programmer when it is written. What is left is a check against an EMPTY flash
-- (the released .jic carries no ROMs, erased = FF): the first byte of the slot, U5 rom
-- address 0 where the PPS/4 starts, must not read FF. Otherwise Flash_error stays
-- active and the CPU is not released - running FF would be worse than showing ERROR.
--
-- Same output side as SD_Card (address, data, wr_rom, cpu_reset_l, error LED), so the
-- top level only has to switch between the two.
--
-- SPI mode 0, READ (03h) with a 24 bit address, then one continuous stream. Own small
-- shifter on purpose - SPI_Master.vhd is not touched.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

	entity Flash_ROM is
		generic (
			Read_Bytes : integer := 16384;
			-- where game 0 starts in the flash, and how far apart the games are
			Base_Addr  : integer := 16#080000#;
			Slot_Bytes : integer := 16384;
			-- SPI clock half period in i_Clk cycles. 2 at 50 MHz = 12.5 MHz, the
			-- EPCS16 allows 20 MHz for READ (03h).
			Half_Period : integer := 2
		);
		port(
		i_Clk		: in std_logic;
		i_Rst_L	: in std_logic;     -- '0' holds the loader, '1' starts it
		-- configuration flash, dual purpose pins of the FPGA
		o_Flash_Clk  : out std_logic;   -- DCLK
		o_Flash_CS_n : out std_logic;   -- nCSO
		o_Flash_MOSI : out std_logic;   -- ASDO, data into the flash
		i_Flash_MISO : in std_logic;    -- DATA0, data out of the flash
		-- selection
		selection : in std_logic_vector(7 downto 0);
		-- rom write port, same meaning as at SD_Card
		address_rom	: buffer std_logic_vector(13 downto 0);
		data_rom		: buffer std_logic_vector(7 downto 0);
		wr_rom		: buffer std_logic;
		-- start CPU
		cpu_reset_l : out std_logic;
		-- feedback
		Flash_error : out std_logic     -- active low, like SDcard_error
		);
    end Flash_ROM;

   architecture Behavioral of Flash_ROM is
		type STATE_T is ( start, bit_low, bit_high, write_byte, inc_addr, check_first,
								all_done, error );
		signal state : STATE_T;

		signal tx_sr    : std_logic_vector(31 downto 0); -- command and address
		signal rx_sr    : std_logic_vector(7 downto 0);
		signal bit_cnt  : integer range 0 to 31;
		signal in_cmd   : std_logic;                     -- '1' while the 32 command bits go out
		signal div      : integer range 0 to Half_Period - 1;
		signal first_ok : std_logic;                     -- first byte of the slot was not FF
	begin

		-- The byte goes to the ROM straight out of the shift register: it does not move
		-- between the last bit and wr_rom, the next bit only starts after inc_addr.
		data_rom <= rx_sr;

		Flash: process (i_Clk)
		begin
		if rising_edge(i_Clk) then
			if i_Rst_L = '0' then
				o_Flash_Clk <= '0';
				o_Flash_CS_n <= '1';
				o_Flash_MOSI <= '0';
				cpu_reset_l <= '0';
				wr_rom <= '0';
				address_rom <= (others => '0');
				Flash_error <= '1'; -- active low
				first_ok <= '0';
				div <= 0;
				bit_cnt <= 0;
				in_cmd <= '0';
				state <= start;
			else
				case state is
				when start =>
					-- READ (03h) plus 24 bit address of the slot
					tx_sr <= x"03" & std_logic_vector( to_unsigned(Base_Addr, 24)
							 + unsigned(selection) * to_unsigned(Slot_Bytes, 16) );
					o_Flash_CS_n <= '0';
					bit_cnt <= 31;
					in_cmd <= '1';
					div <= 0;
					state <= bit_low;

				-- one SPI bit: clock low half, then clock high half. The flash takes
				-- MOSI on the rising edge and shifts its data out on the falling one,
				-- so MISO is sampled together with the rising edge.
				when bit_low =>
					o_Flash_MOSI <= tx_sr(31);
					if div = Half_Period - 1 then
						div <= 0;
						o_Flash_Clk <= '1';
						rx_sr <= rx_sr(6 downto 0) & i_Flash_MISO;
						state <= bit_high;
					else
						div <= div + 1;
					end if;

				when bit_high =>
					if div = Half_Period - 1 then
						div <= 0;
						o_Flash_Clk <= '0';
						tx_sr <= tx_sr(30 downto 0) & '0';
						if bit_cnt = 0 then
							if in_cmd = '1' then
								-- command and address are out, data follows
								in_cmd <= '0';
								bit_cnt <= 7;
								state <= bit_low;
							else
								state <= write_byte;
							end if;
						else
							bit_cnt <= bit_cnt - 1;
							state <= bit_low;
						end if;
					else
						div <= div + 1;
					end if;

				-- address and data are stable here, one clock of wr_rom like SD_Card.
				-- The SPI clock just pauses meanwhile.
				when write_byte =>
					wr_rom <= '1';
					if unsigned(address_rom) = 0 and data_rom /= x"FF" then
						first_ok <= '1';
					end if;
					state <= inc_addr;

				when inc_addr =>
					wr_rom <= '0';
					if unsigned(address_rom) = to_unsigned(Read_Bytes - 1, address_rom'length) then
						o_Flash_CS_n <= '1';
						state <= check_first;
					else
						address_rom <= std_logic_vector(unsigned(address_rom) + 1);
						bit_cnt <= 7;
						state <= bit_low;
					end if;

				when check_first =>
					if first_ok = '1' then
						cpu_reset_l <= '1';
						state <= all_done;
					else
						-- empty flash
						state <= error;
					end if;

				when all_done =>
					Flash_error <= '1'; --active low

				when error =>
					Flash_error <= '0'; --active low

				end case;
			end if; --rst
		end if; --rising edge
		end process;

    end Behavioral;
