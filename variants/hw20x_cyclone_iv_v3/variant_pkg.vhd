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
end package variant_pkg;
