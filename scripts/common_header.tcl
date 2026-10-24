# common_header.tcl - globale Assignments, die in JEDER GottFA1_PLuS-Variante
# gleich sind. Werden von scripts\gen_qsf.ps1 in jede erzeugte SYS1.qsf gemischt.
#
# NICHT hier: FAMILY / DEVICE / LAST_QUARTUS_VERSION - die stehen in
# variants\<name>\device.tcl. TOP_LEVEL_ENTITY schreibt gen_qsf.ps1 selbst.
#
# Vor dem Umbau unterschieden sich die vier .qsf ausserhalb von Pins und
# Dateiliste in GENAU ZWEI Zeilen (FAMILY und DEVICE). Alles hier war schon
# ueberall identisch - deshalb ist dieser Block eine reine Uebernahme, keine
# Vereinheitlichung.
#
# NUM_PARALLEL_PROCESSORS ist eine Eigenschaft der Maschine, nicht des Boards,
# und gehoert deshalb hierher. 14 ist Absicht: Quartus erkennt auf dieser
# Maschine 14 Prozessoren (Windows meldet 20 logische), und alles darueber
# loest Warning 20031 aus.
set_global_assignment -name ORIGINAL_QUARTUS_VERSION "13.0 SP1"
set_global_assignment -name PROJECT_CREATION_TIME_DATE "15:47:39  AUGUST 26, 2020"
set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files
set_global_assignment -name MIN_CORE_JUNCTION_TEMP 0
set_global_assignment -name MAX_CORE_JUNCTION_TEMP 85
set_global_assignment -name ERROR_CHECK_FREQUENCY_DIVISOR 1
set_global_assignment -name NUM_PARALLEL_PROCESSORS 14
set_global_assignment -name USE_CONFIGURATION_DEVICE ON
set_global_assignment -name RESERVE_ALL_UNUSED_PINS "AS INPUT TRI-STATED WITH WEAK PULL-UP"
set_global_assignment -name PARTITION_NETLIST_TYPE SOURCE -section_id Top
set_global_assignment -name PARTITION_FITTER_PRESERVATION_LEVEL PLACEMENT_AND_ROUTING -section_id Top
set_global_assignment -name PARTITION_COLOR 16764057 -section_id Top
set_global_assignment -name STRATIX_DEVICE_IO_STANDARD "3.3-V LVTTL"
set_global_assignment -name CYCLONEII_RESERVE_NCEO_AFTER_CONFIGURATION "USE AS REGULAR IO"
set_global_assignment -name RESERVE_ASDO_AFTER_CONFIGURATION "USE AS REGULAR IO"
# Since x.30 the configuration flash is the second source of the game ROMs
# (rtl/common/Flash_ROM.vhd), so its pins become ordinary I/O once the FPGA is
# configured. All four boards carry an EPCS16. ASDO is released above.
set_global_assignment -name RESERVE_DATA0_AFTER_CONFIGURATION "USE AS REGULAR IO"
set_global_assignment -name RESERVE_DATA1_AFTER_CONFIGURATION "USE AS REGULAR IO"
set_global_assignment -name RESERVE_FLASH_NCE_AFTER_CONFIGURATION "USE AS REGULAR IO"
set_global_assignment -name RESERVE_DCLK_AFTER_CONFIGURATION "USE AS REGULAR IO"
set_global_assignment -name POWER_PRESET_COOLING_SOLUTION "23 MM HEAT SINK WITH 200 LFPM AIRFLOW"
set_global_assignment -name POWER_BOARD_THERMAL_MODEL "NONE (CONSERVATIVE)"

# Taster und Dip-Rueckleitungen liegen offen und brauchen den internen Pull-up.
# In allen vier Ausgangsprojekten identisch.
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to sw_reset
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to reset_sw
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to Button_Test
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to SB_Dip_Return
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to SB_Test
# x.30: without a card MISO floats. With the pull-up it reads FF, CMD0 fails for sure
# and the flash fallback starts.
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to MISO

set_instance_assignment -name PARTITION_HIERARCHY root_partition -to | -section_id Top
