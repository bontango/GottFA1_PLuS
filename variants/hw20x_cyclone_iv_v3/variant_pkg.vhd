-- variant_pkg.vhd - was dieses Board ist, als VHDL-Konstante.
-- Variante: hw20x_cyclone_iv_v3 (GottFA1_PLuS HW v2.0x, Cyclone IV v3, EP4CE6F17C8)
--
-- Diese Datei liegt im Variantenordner, nicht in rtl/common/, und ist der ERSTE
-- Eintrag der erzeugten SYS1.qsf. Alles andere im Design ist gemeinsam.
library ieee;
use ieee.std_logic_1164.all;

package variant_pkg is
	-- Ergibt mit SW_SUB aus rtl/common/version_pkg.vhd die Anzeige "V 530 ".
	-- Neu seit x.30; 5 war die naechste freie Kennung unter 6..9.
	constant BOARD_ID : character := '5';
	-- ESP32-C3 mit FA-Control (rtl/fa_control). Nur das Cyclone-IV-Board v7 traegt
	-- das Modul (X7); alle anderen bauen gen_no_fa_control, FA_RXD/FA_TXD/FA_CTRL_REQ
	-- sind dort VIRTUAL_PIN.
	constant HAS_ESP32 : boolean := false;
end package variant_pkg;
