@{
    Name        = 'hw20x_cyclone_iv_v3'
    Title       = "GottFA1_PLuS HW v2.0x mit dem Cyclone-IV-Board v3 (EP4CE6F17C8, 256-FBGA)"
    BoardId     = '5'
    RtlFamily   = 'cyclone_iv'
    Options     = @()
    BinFolder   = 'HW20x_CycloneIV_v3'
    ReleaseArtifact = 'jic'
    Dormant     = $false
    # Wie hw20x_cyclone_iv_v4: HW v2.0x hat LED_Test, USB_Rx und USB_Tx wirklich auf
    # Pins - deshalb keine virtuellen Pins.
    VirtualPins = @()
    Notes       = 'Neu seit x.30 (24.10.2026). Pinout aus hw20x_cyclone_iv_v4 ueber die Steckerbelegung der beiden FPGA-Boards umgesetzt; nie auf Hardware getestet.'
}
