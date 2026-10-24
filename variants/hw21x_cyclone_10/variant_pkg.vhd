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
	-- ESP32-C3 mit FA-Control (rtl/fa_control). Nur das Cyclone-IV-Board v7 traegt
	-- das Modul (X7); alle anderen bauen gen_no_fa_control, FA_RXD/FA_TXD/FA_CTRL_REQ
	-- sind dort VIRTUAL_PIN.
	constant HAS_ESP32 : boolean := false;
end package variant_pkg;
