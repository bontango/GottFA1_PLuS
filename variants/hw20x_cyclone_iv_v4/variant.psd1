@{
    Name        = 'hw20x_cyclone_iv_v4'
    Title       = "GottFA1_PLuS HW v2.0x mit dem Cyclone-IV-Board v4 (EP4CE6E22C8, 144-EQFP)"
    BoardId     = '7'
    RtlFamily   = 'cyclone_iv'
    Options     = @()
    BinFolder   = 'HW20x_CycloneIV_v4'
    ReleaseArtifact = 'jic'
    Dormant     = $false
    # Die einzige Variante, die LED_Test, USB_Rx und USB_Tx wirklich auf Pins hat -
    # deshalb hier keine virtuellen Pins. Die HW-v2.1x-Platinen haben diese drei
    # Anschluesse nicht mehr.
    VirtualPins = @()
    Notes       = 'Aeltere Platine HW v2.0x. Ausgeliefert als v701 (bin/GottFA1_PLuS_HW20x_v701.jic), Stand 7.01. Bekommt mit dem Umbau die Testtaster-Verdrahtung aus v9.03 neu.'
}
