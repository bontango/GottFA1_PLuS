# device.tcl - was an DIESEM Board spezifisch ist, ausser den Pinlagen.
# Wird von scripts\gen_qsf.ps1 in SYS1.qsf gemischt. Von Hand gepflegt.
set_global_assignment -name FAMILY "Cyclone IV E"
set_global_assignment -name DEVICE EP4CE6F17C8
set_global_assignment -name LAST_QUARTUS_VERSION "22.1std.2 Lite Edition"
# .rbf fuer das Schreiben ueber den ESP32 (FA_Control, Kachel 09 FPGA bzw.
# POST /api/fpgaup). Nur eine Ausgabe des Assemblers, die Netzliste aendert sich nicht.
set_global_assignment -name GENERATE_RBF_FILE ON
