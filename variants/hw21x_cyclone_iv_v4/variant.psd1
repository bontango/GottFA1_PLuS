@{
    Name        = 'hw21x_cyclone_iv_v4'
    Title       = "GottFA1_PLuS HW v2.1x mit dem Cyclone-IV-Board v4 (EP4CE6E22C8, 144-EQFP)"
    BoardId     = '8'
    RtlFamily   = 'cyclone_iv'
    Options     = @()
    BinFolder   = 'HW21x_CycloneIV_v4'
    ReleaseArtifact = 'jic'
    Dormant     = $false
    VirtualPins = @('LED_Test', 'USB_Rx', 'USB_Tx')
    Notes       = 'Ausgeliefert als v801 (bin/GottFA1_PLuS_HW21x_v801.jic), Stand 8.01. Bekommt mit dem Umbau die Testtaster-Verdrahtung aus v9.03 neu - dort zuerst pruefen.'
}
