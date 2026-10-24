@{
    Name        = 'hw21x_cyclone_iv_v3'
    Title       = "GottFA1_PLuS HW v2.1x mit dem Cyclone-IV-Board v3 (EP4CE6F17C8, 256-FBGA)"
    BoardId     = '6'
    RtlFamily   = 'cyclone_iv'
    Options     = @()
    BinFolder   = 'HW21x_CycloneIV_v3'
    ReleaseArtifact = 'jic'
    Dormant     = $false
    VirtualPins = @('LED_Test', 'USB_Rx', 'USB_Tx', 'FA_RXD', 'FA_TXD', 'FA_CTRL_REQ')
    # BoardId war frueher '9' und kollidierte damit mit der Cyclone-10-Variante:
    # der Ordner zeigte "V 901", hatte aber nur den 8.01-Code, und das
    # ausgelieferte bin/GottFA1_PLuS_HW21x_v901.jic ist an seiner Dateigroesse
    # (2.097.377 B = Cyclone 10; Cyclone IV liefert 2.097.375 B) nachweislich der
    # Cyclone-10-Build. Diese Variante wurde nie released -> neue ID '6'.
    Notes       = 'NIE in Hardware getestet, nie ausgeliefert. Pinout nie gegen die Platine geprueft. Einziges Board mit 256-FBGA - alle 85 Pinlagen weichen von den anderen Varianten ab.'
}
