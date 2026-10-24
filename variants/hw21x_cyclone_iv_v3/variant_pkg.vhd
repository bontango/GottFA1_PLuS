-- variant_pkg.vhd - was dieses Board ist, als VHDL-Konstante.
-- Variante: hw21x_cyclone_iv_v3 (GottFA1_PLuS HW v2.1x, Cyclone IV v3, EP4CE6F17C8)
--
-- Diese Datei liegt im Variantenordner, nicht in rtl/common/, und ist der ERSTE
-- Eintrag der erzeugten SYS1.qsf. Alles andere im Design ist gemeinsam.
library ieee;
use ieee.std_logic_1164.all;

package variant_pkg is
	-- Ergibt mit SW_SUB aus rtl/common/version_pkg.vhd die Anzeige "V 603 ".
	--
	-- ACHTUNG, hier wurde eine Kennung GEAENDERT: dieses Board zeigte vorher
	-- "V 901" und kollidierte damit mit dem Cyclone-10-Build. Nachweis, dass die
	-- 9 dem Cyclone 10 gehoert: bin/GottFA1_PLuS_HW21x_v901.jic ist 2.097.377 Byte
	-- gross, und diese Groesse ist geraetetypisch fuer 10CL006Y - Cyclone IV
	-- (EP4CE6) liefert 2.097.375 Byte. Von diesem Board wurde nie etwas
	-- ausgeliefert, die neue Kennung bricht also keine Historie.
	constant BOARD_ID : character := '6';
	-- ESP32-C3 mit FA-Control (rtl/fa_control). Nur das Cyclone-IV-Board v7 traegt
	-- das Modul (X7); alle anderen bauen gen_no_fa_control, FA_RXD/FA_TXD/FA_CTRL_REQ
	-- sind dort VIRTUAL_PIN.
	constant HAS_ESP32 : boolean := false;
end package variant_pkg;
