# Megafunctions, erzeugt fuer die Familie Cyclone IV E. Ausgewaehlt ueber den
# Schluessel RtlFamily in variants\<name>\variant.psd1.
#
# Gleiche Entity-Namen und Portlisten wie rtl\cyclone_10\ - siehe den laengeren
# Kommentar in files_cyclone_10.tcl. Die Reihenfolge ist bewusst dieselbe wie
# dort, damit sich die beiden Dateien Zeile fuer Zeile gegenueberstellen lassen.
set_global_assignment -name QIP_FILE ../../rtl/cyclone_iv/attract.qip
set_global_assignment -name QIP_FILE ../../rtl/cyclone_iv/R5101.qip
set_global_assignment -name QIP_FILE ../../rtl/cyclone_iv/U5_ROM.qip
set_global_assignment -name QIP_FILE ../../rtl/cyclone_iv/U4_ROM.qip
set_global_assignment -name QIP_FILE ../../rtl/cyclone_iv/PGOL_ROM.qip
set_global_assignment -name QIP_FILE ../../rtl/cyclone_iv/SB_RAM.qip
set_global_assignment -name QIP_FILE ../../rtl/cyclone_iv/SB_ROM.qip
