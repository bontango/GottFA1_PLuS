# Megafunctions, erzeugt fuer die Familie Cyclone 10 LP. Ausgewaehlt ueber den
# Schluessel RtlFamily in variants\<name>\variant.psd1.
#
# rtl\cyclone_10\ und rtl\cyclone_iv\ enthalten dieselben sieben Entity-Namen mit
# denselben Portlisten. Geprueft beim Umbau: die .cmp sind byte-gleich, .qip und
# .vhd unterscheiden sich in genau vier Zeilen, und die tragen ausschliesslich den
# Family-String. Es gibt hier KEINE getarnte Parameterdivergenz - wer eine der
# Megafunctions neu erzeugt, muss das fuer beide Familien tun und danach wieder
# genau diese vier Zeilen als einzigen Unterschied vorfinden.
#
# Die .qip selbst brauchen beim Verschieben des Baums keine Anpassung: sie
# referenzieren ihre Dateien ueber [file join $::quartus(qip_path) ...] und sind
# ortsunabhaengig.
set_global_assignment -name QIP_FILE ../../rtl/cyclone_10/attract.qip
set_global_assignment -name QIP_FILE ../../rtl/cyclone_10/R5101.qip
set_global_assignment -name QIP_FILE ../../rtl/cyclone_10/U5_ROM.qip
set_global_assignment -name QIP_FILE ../../rtl/cyclone_10/U4_ROM.qip
set_global_assignment -name QIP_FILE ../../rtl/cyclone_10/PGOL_ROM.qip
set_global_assignment -name QIP_FILE ../../rtl/cyclone_10/SB_RAM.qip
set_global_assignment -name QIP_FILE ../../rtl/cyclone_10/SB_ROM.qip
