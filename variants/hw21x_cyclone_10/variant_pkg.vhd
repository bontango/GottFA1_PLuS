-- variant_pkg.vhd - was dieses Board ist, als VHDL-Konstante.
-- Variante: hw21x_cyclone_10 (GottFA1_PLuS HW v2.1x, Cyclone 10, 10CL006YE144C8G)
--
-- Diese Datei liegt im Variantenordner, nicht in rtl/common/, und ist der ERSTE
-- Eintrag der erzeugten SYS1.qsf. Alles andere im Design ist gemeinsam.
library ieee;
use ieee.std_logic_1164.all;

package variant_pkg is
	-- Fuehrende Ziffer der Version auf der Boot-Anzeige. Zusammen mit SW_SUB aus
	-- rtl/common/version_pkg.vhd ergibt das "V " & BOARD_ID & SW_SUB & " ".
	-- Hier also "V 903 " - Zeichen fuer Zeichen dasselbe, was vorher als Literal
	-- im Top-Level dieser Variante stand.
	constant BOARD_ID : character := '9';
end package variant_pkg;
