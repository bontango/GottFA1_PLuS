--
-- input_filter.vhd
-- synchronizer plus glitch filter for slow inputs (buttons, special switches)
-- part of GottFA1
-- bontango 10.2026
--
-- v01 first version: the input is synchronized with two flip flops (as in
--     Cross_Slow_To_Fast_Clock) and o_Q only follows when the synchronized input
--     has been stable for Filter_Cycles clocks. A pulse that is shorter is dropped,
--     and o_glitch is high for one clock, so it can be counted.
--
-- Background: pinball coils without (or with a broken) flyback diode put spikes on
-- the cabling. Without this filter a single 20 ns low sample on reset_sw restarted
-- the whole board in the middle of a game. See docs/Stoerimpulse_Resets.md.
--
-- o_Q starts as Init_Value. With Init_Value '0' on reset_sw this is at the same time
-- the power-on reset: o_Q only goes high once the pin has been high for Filter_Cycles.

library IEEE;
use IEEE.std_logic_1164.all;

entity input_filter is
	generic (
		Filter_Cycles : integer := 50000;   -- 1 ms at 50 MHz
		Init_Value    : std_logic := '0'
	);
	port(
		i_Clk    : in std_logic;
		i_D      : in std_logic;
		o_Q      : out std_logic;
		o_glitch : out std_logic           -- one clock high: a pulse was dropped
	);
end input_filter;

architecture Behavioral of input_filter is
	signal r1_Data : std_logic := Init_Value;
	signal r2_Data : std_logic := Init_Value;
	signal q       : std_logic := Init_Value;
	signal count   : integer range 0 to Filter_Cycles := 0;
begin

	o_Q <= q;

	process(i_Clk)
	begin
		if rising_edge(i_Clk) then
			-- r1_Data is METASTABLE, r2_Data is stable
			r1_Data <= i_D;
			r2_Data <= r1_Data;
			o_glitch <= '0';

			if r2_Data = q then
				-- back to the old level before the time was up: that was a glitch
				if count /= 0 then
					o_glitch <= '1';
				end if;
				count <= 0;
			elsif count = Filter_Cycles - 1 then
				q <= r2_Data;
				count <= 0;
			else
				count <= count + 1;
			end if;
		end if;
	end process;

end Behavioral;
