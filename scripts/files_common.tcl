# Gemeinsame Quellen - Bestandteil JEDER GottFA1_PLuS-Variante.
#
# Die Pfade sind relativ zum Quartus-Projektverzeichnis, und das ist
# variants\<name>\. Deshalb ../../rtl/... und nicht ../lib_common/... wie frueher.
#
# Reihenfolge unveraendert aus den alten SYS1.qsf uebernommen. Nicht alphabetisch
# sortieren - der Umbau soll sich Assignment fuer Assignment gegen den alten Stand
# halten lassen.
#
# KEIN SEARCH_PATH. Jede Datei steht genau einmal explizit in genau einer Liste.
# Genau das war der Grund fuer den Umbau: eine neue .vhd konnte vorher in drei von
# vier Projekten fehlen, ohne dass es jemandem auffiel.
#
# Die beiden Packages stehen ZUERST, damit der Analyzer die Reihenfolge nie raten
# muss. variant_pkg.vhd liegt im Variantenordner - es ist die einzige Quelldatei,
# die nicht geteilt wird.
set_global_assignment -name VHDL_FILE variant_pkg.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/version_pkg.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/SB_Test_SYS1.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/T65/T65_Pack.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/T65/T65_MCode.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/T65/T65_ALU.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/T65/T65.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/RIOT/R6530.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/gentones.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/DFPlayer_Mini_CMD.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/dfp_clk_gen.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/read_SB_dips.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/dac.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/SB_cpu_clk_gen.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/Multi_Sound.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/read_sys1_dips.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/attract_cmd.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/detect_sw_sys1.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/detect_sw_trigger_sys1.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/slow_to_fast_clock_bus.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/boot_message_alpha.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/slow_to_fast_clock.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/SN74175.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/SD_Card.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/Flash_ROM.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/input_filter.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/SPI_Master.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/EEprom.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/count_to_zero.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/byte_to_decimal.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/SN7448_wh.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/r10696.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/rA17xx.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/r10788.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/cpu_clk_gen.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/PPS4_2.vhd
set_global_assignment -name VHDL_FILE ../../top/SYS1.vhd
# Bewusst NICHT gelistet: rtl/common/crc16_ccitt.vhd. Die Datei ist versioniert,
# stand aber in keiner der vier alten .qsf und wird also nicht gebaut. Sie bleibt
# als Quelle liegen; wer sie braucht, traegt sie hier ein.
#
# Die .sdc ist in allen vier Ausgangsprojekten byte-identisch (md5 bc92029915cc...)
# und nennt ausschliesslich Hierarchienamen (cpu_clk_gen:clock_gen|cpu_clk_out),
# die in jeder Variante gleich heissen. Deshalb EINE gemeinsame Datei. Sobald eine
# Variante ein eigenes TopEntity bekaeme, braeuchte sie eine eigene .sdc mit
# Praefix - dann hierher zurueckkommen.
set_global_assignment -name SDC_FILE ../../rtl/common/SYS1.sdc
