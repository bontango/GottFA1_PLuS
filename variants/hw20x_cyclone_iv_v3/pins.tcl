# pins.tcl - Pinlagen des Boards hw20x_cyclone_iv_v3 (HW v2.0x mit dem Cyclone-IV-Board v3, EP4CE6F17C8).
# Erzeugt am 24.10.2026 aus variants\hw20x_cyclone_iv_v4\pins.tcl: jede E22-Pinlage ueber die
# Steckerbelegung in N:\Projekte\Altera_dev_board\pins_Cyclone_II_IV_10.xlsx (Blatt
# "pin locations complete", Spalten Cyclone IV board 4.x / 3.x) auf das F17-Board umgesetzt.
# Gegenprobe: alle 84 Pins, die hw21x_cyclone_iv_v4 und hw21x_cyclone_iv_v3 gemeinsam haben,
# stimmen mit dieser Tabelle ueberein. Nur HW v2.0x hat LED_Test (E99 -> F16), USB_Rx (E75 -> R16),
# USB_Tx (E84 -> N14) und SB_Test auf E85 -> L14 - diese vier sind NIE auf Hardware geprueft.
# Wird von scripts\gen_qsf.ps1 in SYS1.qsf gemischt. Von Hand gepflegt.
set_location_assignment PIN_E1 -to clk_50
set_location_assignment PIN_D9 -to LED_0
set_location_assignment PIN_C9 -to LED_1
set_location_assignment PIN_C6 -to LED_2
set_location_assignment PIN_R1 -to CLK
set_location_assignment PIN_P1 -to CS_EEprom
set_location_assignment PIN_K1 -to CS_SDcard
set_location_assignment PIN_T8 -to disp_seg_A[1]
set_location_assignment PIN_R9 -to disp_seg_A[2]
set_location_assignment PIN_T9 -to disp_seg_A[3]
set_location_assignment PIN_R10 -to disp_seg_A[4]
set_location_assignment PIN_T10 -to disp_seg_A[5]
set_location_assignment PIN_T7 -to disp_seg_A[6]
set_location_assignment PIN_R8 -to disp_seg_A[7]
set_location_assignment PIN_T14 -to disp_seg_A[8]
set_location_assignment PIN_R12 -to disp_seg_B[1]
set_location_assignment PIN_T12 -to disp_seg_B[2]
set_location_assignment PIN_R13 -to disp_seg_B[3]
set_location_assignment PIN_T13 -to disp_seg_B[4]
set_location_assignment PIN_R14 -to disp_seg_B[5]
set_location_assignment PIN_R11 -to disp_seg_B[6]
set_location_assignment PIN_T11 -to disp_seg_B[7]
set_location_assignment PIN_T15 -to disp_seg_B[8]
set_location_assignment PIN_G15 -to ds[0]
set_location_assignment PIN_L15 -to ds[1]
set_location_assignment PIN_L16 -to ds[2]
set_location_assignment PIN_B13 -to ds[3]
set_location_assignment PIN_T3 -to GTB_dips[7]
set_location_assignment PIN_R4 -to GTB_dips[6]
set_location_assignment PIN_T4 -to GTB_dips[5]
set_location_assignment PIN_R5 -to GTB_dips[4]
set_location_assignment PIN_T5 -to GTB_dips[3]
set_location_assignment PIN_R6 -to GTB_dips[2]
set_location_assignment PIN_T6 -to GTB_dips[1]
set_location_assignment PIN_R7 -to GTB_dips[0]
set_location_assignment PIN_D16 -to ld[3]
set_location_assignment PIN_D15 -to ld[2]
set_location_assignment PIN_C16 -to ld[1]
set_location_assignment PIN_C15 -to ld[0]
set_location_assignment PIN_P2 -to MISO
set_location_assignment PIN_L2 -to MOSI
set_location_assignment PIN_E11 -to solenoids[7]
set_location_assignment PIN_E10 -to solenoids[6]
set_location_assignment PIN_A15 -to solenoids[5]
set_location_assignment PIN_B16 -to solenoids[4]
set_location_assignment PIN_A14 -to solenoids[3]
set_location_assignment PIN_A13 -to solenoids[2]
set_location_assignment PIN_A12 -to solenoids[1]
set_location_assignment PIN_B14 -to solenoids[0]
set_location_assignment PIN_L1 -to sw1_dips[3]
set_location_assignment PIN_D1 -to sw1_dips[2]
set_location_assignment PIN_C3 -to sw1_dips[1]
set_location_assignment PIN_B1 -to sw1_dips[0]
set_location_assignment PIN_A5 -to sw_outhole
set_location_assignment PIN_B12 -to sw_reset
set_location_assignment PIN_B6 -to sw_slam
set_location_assignment PIN_B5 -to sw_return[7]
set_location_assignment PIN_A4 -to sw_return[6]
set_location_assignment PIN_A9 -to sw_return[5]
set_location_assignment PIN_A10 -to sw_return[4]
set_location_assignment PIN_A11 -to sw_return[3]
set_location_assignment PIN_A8 -to sw_return[2]
set_location_assignment PIN_A7 -to sw_return[1]
set_location_assignment PIN_A6 -to sw_return[0]
set_location_assignment PIN_B7 -to sw_strobe[4]
set_location_assignment PIN_B8 -to sw_strobe[3]
set_location_assignment PIN_B11 -to sw_strobe[2]
set_location_assignment PIN_B10 -to sw_strobe[1]
set_location_assignment PIN_B9 -to sw_strobe[0]
set_location_assignment PIN_D8 -to LED_active
set_location_assignment PIN_C8 -to LED_SD_Error
set_location_assignment PIN_P15 -to disp_strobes[0]
set_location_assignment PIN_P16 -to disp_strobes[1]
set_location_assignment PIN_N15 -to disp_strobes[2]
set_location_assignment PIN_N16 -to disp_strobes[3]
set_location_assignment PIN_B4 -to reset_sw
set_location_assignment PIN_F16 -to LED_Test
set_location_assignment PIN_F15 -to Button_Test
set_location_assignment PIN_G16 -to sw2_dips[3]
set_location_assignment PIN_J15 -to sw2_dips[2]
set_location_assignment PIN_J16 -to sw2_dips[1]
set_location_assignment PIN_K16 -to sw2_dips[0]
set_location_assignment PIN_N14 -to USB_Tx
set_location_assignment PIN_R16 -to USB_Rx
set_location_assignment PIN_L14 -to SB_Test
set_location_assignment PIN_C2 -to SB_Dip_Return
set_location_assignment PIN_N2 -to audio_RX
set_location_assignment PIN_N1 -to audio_o

# Configuration flash EPCS16 (x.30, rtl/common/Flash_ROM.vhd). The dedicated configuration
# pins of the 256-FBGA: DCLK H1, DATA0 H2, nCSO D2, ASDO C1 - same as hw21x_cyclone_iv_v3.
set_location_assignment PIN_H1 -to FLASH_DCLK
set_location_assignment PIN_D2 -to FLASH_NCS
set_location_assignment PIN_C1 -to FLASH_ASDO
set_location_assignment PIN_H2 -to FLASH_DATA0
