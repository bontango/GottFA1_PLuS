----------------------------------------------------------------------------------
-- Company: 
-- Engineer: garzol
-- 
-- Create Date: 09.05.2024 11:23:32
-- Design Name: 
-- Module Name: gentones - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
-- v0.2 bontango, for GottFA1 sounds
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity gentones is
    Port (
           hiclk       : in        STD_LOGIC;
           tonesel     : in        std_logic_vector(2 downto 0);
           soundout    : out       std_logic
          );
end gentones;

architecture Behavioral of gentones is

signal   tone_clk        : std_logic_vector(2 downto 0);
constant c_tens    : integer:=40000; --is 1250Hz for 20ns ticks
constant c_hund    : integer:=95057; --is 526Hz for 20ns ticks
constant c_thou    : integer:=320512; --is 156Hz for 20ns ticks


signal   s10p            : std_logic;
signal   s100p           : std_logic;
signal   s1000p          : std_logic;

begin
   
    
    s10p    <= not (tone_clk(0) and tonesel(0));
    s100p   <= not (tone_clk(1) and tonesel(1));
    s1000p  <= not (tone_clk(2) and tonesel(2));
    
    
    soundout <= not (s10p and s100p and s1000p );
        
    process(hiclk)
        variable     tickcnt_10 : integer range 0 to c_tens+1 := 0;
		  variable     tickcnt_100 : integer range 0 to c_hund+1 := 0;
		  variable     tickcnt_1000 : integer range 0 to c_thou+1 := 0;
    begin
        if (rising_edge(hiclk)) then
            tickcnt_10 := tickcnt_10+1;
				tickcnt_100 := tickcnt_100+1;
				tickcnt_1000 := tickcnt_1000+1;
            if tickcnt_10 >= c_tens then
                tickcnt_10 := 0;
                tone_clk(0) <= not tone_clk(0);
            end if;
            if tickcnt_100 >= c_hund then
                tickcnt_100 := 0;
                tone_clk(1) <= not tone_clk(1);
            end if;
            if tickcnt_1000 >= c_thou then
                tickcnt_1000 := 0;
                tone_clk(2) <= not tone_clk(2);
            end if;				
        end if;
    end process;

end Behavioral;
