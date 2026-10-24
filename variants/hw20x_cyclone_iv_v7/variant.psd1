@{
    Name        = 'hw20x_cyclone_iv_v7'
    Title       = "GottFA1_PLuS HW v2.0x mit dem Cyclone-IV-Board v7 (EP4CE6F17C8, 256-FBGA, ESP32-C3 auf X7)"
    BoardId     = '4'
    RtlFamily   = 'cyclone_iv'
    Options     = @()
    BinFolder   = 'HW20x_CycloneIV_v7'
    ReleaseArtifact = 'jic'
    Dormant     = $false
    # Wie hw20x_cyclone_iv_v3: LED_Test, USB_Rx, USB_Tx liegen auf echten Pins.
    # FA_RXD/FA_TXD/FA_CTRL_REQ ebenfalls - nur dieses Board hat den ESP32.
    VirtualPins = @()
    Notes       = 'Neu seit 24.10.2026: wie hw20x_cyclone_iv_v3 plus FA-Control (HAS_ESP32). 4 war die naechste freie Kennung unter 5..9. Board v7 = v3 ohne CH340/JTAG-Stecker, dafuer ESP32-C3 Supermini auf X7, das auch das EPCS beschreibt (N:\Projekte\FA_Control).'
}
