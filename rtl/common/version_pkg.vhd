-- version_pkg.vhd - die Software-Version, gemeinsam fuer alle GottFA1_PLuS-Varianten.
-- (c)2026 bontango
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
-- Die Version auf der Boot-Anzeige (Display 2, waehrend reset_l = '1') ist
--
--     "V " & BOARD_ID & SW_SUB & " "
--
-- also z. B. "V 903 ". BOARD_ID kommt aus variants/<name>/variant_pkg.vhd.
-- Ein Release aendert damit GENAU EINE Zahl - hier - und alle Boards folgen.
--
-- Vorher stand die komplette Zeichenkette als Literal in jeder der vier Kopien des
-- Top-Levels. Genau das hat die Varianten auseinanderlaufen lassen: CycloneIV_v3
-- zeigte "V 901", hatte aber nur den Code-Stand 8.01, und kollidierte damit mit dem
-- ausgelieferten Cyclone-10-Build derselben Nummer.
--
-- Board-Kennungen (historisch gewachsen, beim Umbau nur festgeschrieben):
--   6 = HW v2.1x Cyclone IV v3 (EP4CE6F17C8)   -- war faelschlich 9
--   7 = HW v2.0x Cyclone IV v4 (EP4CE6E22C8)
--   8 = HW v2.1x Cyclone IV v4 (EP4CE6E22C8)
--   9 = HW v2.1x Cyclone 10    (10CL006YE144C8G)
library ieee;
use ieee.std_logic_1164.all;

package version_pkg is
	-- Zwei Ziffern, weil die Anzeige "V bss " genau sechs Zeichen breit ist.
	-- Die Schrittfolge ist ueber alle Boards dieselbe: x.01 war "test button
	-- produces sound", x.02 "dfp player activated with active signal",
	-- x.03 "moved Button_Test to SB_Test".
	constant SW_SUB : string(1 to 2) := "03";
end package version_pkg;
