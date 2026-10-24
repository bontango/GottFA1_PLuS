@{
    Name        = 'hw21x_cyclone_10'
    Title       = "GottFA1_PLuS HW v2.1x mit dem Cyclone-10-Board (10CL006YE144C8G)"
    BoardId     = '9'
    RtlFamily   = 'cyclone_10'
    Options     = @()
    BinFolder   = 'HW21x_Cyclone10'
    ReleaseArtifact = 'jic'
    Dormant     = $false
    # Diese drei Ports gibt es nur auf der HW-v2.0x-Platine. Sie bleiben in der
    # gemeinsamen Portliste, damit alle Varianten dasselbe Top-Level benutzen;
    # VIRTUAL_PIN haelt Quartus davon ab, sie auf echte Pins zu legen und zu treiben.
    VirtualPins = @('LED_Test', 'USB_Rx', 'USB_Tx', 'FA_RXD', 'FA_TXD', 'FA_CTRL_REQ')
    Notes       = 'Leitvariante - hier wird entwickelt und auf Hardware getestet. Ausgeliefert als v901 (bin/GottFA1_PLuS_HW21x_v901.jic).'
}
