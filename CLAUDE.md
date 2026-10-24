# CLAUDE.md — GottFA1_PLuS

Leitfaden für KI-Assistenten in diesem Repository.

## Was das ist

VHDL-Emulation der **Gottlieb-System-1**-MPU für die DIY-Platine **GottFA1_PLuS**.
Werkzeug: **Intel Quartus Prime Lite 22.1std.2**. Top-Level-Entity: `SYS1`
(`top/SYS1.vhd`). Es gibt **keine automatisierten Tests** — „bauen" heißt hier: eine
Quartus-Kompilierung, verglichen gegen `scripts/baseline.csv`.

**Vier Boards, ein Quellstand.** Seit dem Umbau vom 13.08.2026 gibt es genau ein
Top-Level und einen Satz Module; die Varianten unterscheiden sich nur noch in
Pinbelegung, FPGA-Typ und einer Board-Kennung.

| Variante | FPGA | Board-ID | Anzeige |
|---|---|---|---|
| `hw21x_cyclone_10` | 10CL006YE144C8G | 9 | `V 903` |
| `hw21x_cyclone_iv_v4` | EP4CE6E22C8 (144-EQFP) | 8 | `V 803` |
| `hw20x_cyclone_iv_v4` | EP4CE6E22C8 (144-EQFP) | 7 | `V 703` |
| `hw21x_cyclone_iv_v3` | EP4CE6F17C8 (256-FBGA) | 6 | `V 603` |
| `hw20x_cyclone_iv_v7` | EP4CE6F17C8 (256-FBGA) | 4 | `V 430` – Board v7 mit ESP32-C3 auf X7, **einzige Variante mit FA-Control** (`HAS_ESP32`), siehe unten |
| `hw20x_cyclone_iv_v3` | EP4CE6F17C8 (256-FBGA) | 5 | `V 530` – seit x.30, Pinout aus `hw20x_cyclone_iv_v4` über `Altera_dev_board\pins_Cyclone_II_IV_10.xlsx` umgesetzt, 5.30 auf Hardware erfolgreich getestet |

## Verzeichnisrollen

- `top/SYS1.vhd` — **das eine** Top-Level. Vorher lag es viermal vor, einmal je
  Projektordner, und die Kopien liefen auseinander.
- `rtl/common/` — geteilte Module: PPS/4-2- und T65-CPU, RIOT R6530, Display-,
  Schalter- und Solenoid-Logik, SD-Karte, EEPROM, DFPlayer-Sound. Dazu
  `version_pkg.vhd` und `SYS1.sdc` (in allen Varianten identisch).
- `rtl/cyclone_10/`, `rtl/cyclone_iv/` — Intel-Megafunctions je Chipfamilie.
  **Gleiche Entity-Namen, gleiche Portlisten**; ausgewählt über `RtlFamily` in
  `variant.psd1`.
- `variants/<name>/` — je Board: `variant_pkg.vhd`, `variant.psd1`, `device.tcl`,
  `pins.tcl`, `SYS1.qpf`, `SYS1.cof` — und die **erzeugte** `SYS1.qsf`.
- `scripts/` — `gen_qsf.ps1`, `check.ps1`, `build.ps1`, `release.ps1`,
  `baseline.csv`, die `.tcl`-Fragmente.
- `bin/` — ausgelieferte Stände. `archive/` — Historisches, in keinem Build.

## Regeln

**`variants/<name>/SYS1.qsf` ist erzeugt.** Nie von Hand ändern. Quartus schreibt
selbst hinein, sobald das Projekt in der IDE offen war; `check.ps1` und `build.ps1`
erzeugen sie deshalb vor jedem Lauf neu. Änderungen gehören in die Fragmente unter
`scripts/` bzw. `variants/<name>/`.

**Pfade sind relativ zum Quartus-Projektverzeichnis**, und das ist `variants/<name>/`
— also `../../rtl/…`, `../../top/…`. Ausnahme: die `.qip` referenzieren ihre Dateien
über `[file join $::quartus(qip_path) …]` und sind ortsunabhängig — nicht anfassen.

**Die Version steht an genau einer Stelle:** `SW_SUB` in
`rtl/common/version_pkg.vhd`, dazu `BOARD_ID` je Variante. Ein Release ändert eine
Zahl, alle Boards folgen. Nie wieder ein Versionsliteral ins Top-Level schreiben.

**Optionale Ports bleiben deklariert und werden getrieben.** `LED_Test`, `USB_Rx` und
`USB_Tx` gibt es nur auf HW v2.0x; auf den HW-v2.1x-Boards sind sie `VIRTUAL_PIN`
(aus `VirtualPins` in `variant.psd1`). Für Quartus ist ein deklarierter Ausgangsport
ohne Location ein **benutzter** Pin — `RESERVE_ALL_UNUSED_PINS` greift dort nicht.
`USB_Tx` hat bewusst keinen Verbraucher; der Pin ist für die CH340-Anbindung
reserviert, `Warning 15610/21074` ist dort erwartet.

**Kein `SEARCH_PATH`.** Jede Datei steht explizit in genau einer `.tcl`-Liste.

**Textersetzungen nur über PowerShell** mit `[System.IO.File]::WriteAllText` und
`New-Object System.Text.UTF8Encoding($false)`. `sed -i` aus der Git-Bash zerstört die
CRLF dieses Baums.

**In PowerShell 5.1 niemals `2>&1` auf `quartus_*.exe`** — das verpackt jede
stderr-Zeile in einen ErrorRecord und setzt `$?` auf `$false`, auch bei Exitcode 0.
`$LASTEXITCODE` gilt.

**Nichts löschen oder verschieben ohne ausdrückliche Freigabe** (Projektregel aus
`N:\Projekte\CLAUDE.md`). Ausgemustertes geht nach `archive/`.

## Abnahmekriterium

`map.rpt` → *Total combinational functions*, *Total registers*, *Total memory bits*.
Diese drei sind eine Eigenschaft des Designs und werden exakt verglichen.

**Die LE-Zahl des Fitters taugt dafür nicht** und wird nur mitgeführt — ein einzelner
zusätzlicher Knoten reicht, damit der Fitter anders packt.

**Slack nie exakt** (1,5 ns Toleranz). Der absolute Boden liegt bei **0,05 ns** und
ist an diesem Design gemessen: der schlechteste Wert ist ein **Hold**-Slack von
0,136–0,151 ns, während Setup bei 5,9–7,8 ns liegt. Der AtariFA-Wert von 1,0 ns hätte
hier bei jedem Lauf gefeuert.

Statt einer Warnungs-Zeilenliste führt `check.ps1` einen **Fingerabdruck**
`code:anzahl,…`. Dieses Design ist gewachsener Bestand und erzeugt 27–31 Warnungen je
Lauf; eine Zeilenliste wäre nur Lärm. Eine neue Warnungsklasse oder eine geänderte
Anzahl fällt trotzdem sofort auf.

## Altlasten, die dokumentiert bleiben sollen

- **`bin/GottFA1_PLuS_HW21x_v901.jic` ist der Cyclone-10-Build**, nicht der von
  CycloneIV_v3 — nachweisbar an der Dateigröße 2.097.377 B (gerätetypisch für
  10CL006Y; EP4CE6 liefert 2.097.375 B). v3 zeigte trotzdem `V 901` und hatte dabei
  nur den Code-Stand 8.01. Deshalb hat v3 jetzt Board-ID 6.
- **Das eigene Repo von v3** (`github.com/bontango/GottFA1_PLuS_HW21x_CycloneIV_v3`)
  ist durch den Umbau verwaist. Von dort nicht mehr committen oder pushen.
- **`rtl/*/R5101.vhd` enthält einen toten MegaWizard-Kommentar**
  `MIFfilename STRING "../roms/5101_init.hex"`. Der Pfad war schon vor dem Umzug
  nicht auflösbar und ist wirkungslos — aber beim Öffnen des IP im MegaWizard eine
  Stolperfalle.
- **`rtl/common/crc16_ccitt.vhd`** ist versioniert, stand aber in keiner der vier
  alten `.qsf` und wird nicht gebaut.

## Was ein grüner Lauf nicht beweist

Eine unveränderte Netzliste beweist, dass sich nichts geändert hat — **nicht, dass es
funktioniert.** Welches Board zuletzt wirklich auf Hardware lief, steht in
`VARIANTEN.md`. Besonders bei Reset-Pfaden, Display-Blanking und Solenoid-Ansteuerung:
ein falsches Pinout kann Hardware beschädigen, und `hw21x_cyclone_iv_v3` hat sein
Pinout noch nie gegen die Platine gesehen.

## Konfigurationsflash als zweite ROM-Quelle (seit x.30, nach WillFA7)

Antwortet keine SD-Karte (`SD_Card` endet im Fehlerzustand, Ausgang `o_no_card`),
liest `rtl/common/Flash_ROM.vhd` dieselben 16 KByte aus dem EPCS16 und übernimmt
ROM-Schreibport, `reset_l` und `LED_SD_Error`. Auf allen vier Boards, keine Konstante.

```
EPCS16   0x000000 - 0x07FFFF   Bitstream (EP4CE6/10CL006 ca. 360 KByte) + Reserve
         0x080000 + n*0x4000   Spiel n, 16 KByte, byte-gleich zum SD-Slot
                               (Sektor 660 + n*32) -> Spiel 0..15 bis 0x0BFFFF
```

- **Keine CRC**, weder auf der Karte noch im Flash. Geprüft wird nur gegen leeren
  Flash: das erste Byte des Slots (U5-Adresse 0) darf nicht FF sein, sonst `ERROR`
  und die CPU startet nicht.
- Flash-Boot erkennt man an `READFL` statt `READSD` auf Spieler 3.
- **ROM-Jic:** `scripts\make_flash_hex.ps1 -Image <Kartenimage> -Out
  variants\<name>\output_files\gottfa1_roms.hex`, dann im Variantenordner
  `quartus_cpf -c gottfa1_roms.cof` → `output_files\gottfa1_roms.jic`. In `bin\` als
  `GottFA1_PLuS_v<nnn>_roms.jic`. `*_roms.jic`/`*_roms.hex` sind in `.gitignore` –
  urheberrechtlich geschützte ROMs gehen nie zu GitHub.
- Pins: E144 DCLK 12, DATA0 13, nCSO 8, ASDO 6; F17 (`hw21x_cyclone_iv_v3`, `hw20x_cyclone_iv_v3`) H1/H2/D2/C1,
  in `pins.tcl`. Freigabe als normale I/O in `scripts/common_header.tcl`.
- `MISO` hat seit x.30 den Weak-Pull-up: ohne Karte liest es sicher FF.

## Eingangsfilter und Diagnosezähler (seit x.30)

`rtl/common/input_filter.vhd`: Synchronisierung plus „N Takte stabil“. `reset_sw`
50 ms (zugleich Power-on-Reset, `Init_Value '0'`), `sw_slam`/`sw_outhole`/`sw_reset`
1 ms. **Die Switch-Matrix-Returns nicht filtern** – Strobe-Timing. Die Zähler `R`/`G`
auf Spieler 4 der Bootanzeige werden nur beim Laden des FPGA gelöscht. Hintergrund
und Lesart: `docs/Stoerimpulse_Resets.md`.

## FA-Control (seit 24.10.2026, nur `hw20x_cyclone_iv_v7`)

LISY-Slave für den ESP32-C3 (`N:\Projekte\FA_Control`). `rtl/fa_control/` ist eine
Kopie aus SternFA. Wer dort am Modul etwas ändert, zieht es hier nach.

- **`HAS_ESP32`** in `variant_pkg.vhd` wählt zwischen `gen_fa_control` und
  `gen_no_fa_control`. Die Muxe im Top-Level sind bewusst unbedingt: Ohne ESP ist
  `fa_active` konstant `'0'`, und die Netzliste bleibt exakt die alte. **Das ist das
  Abnahmekriterium** für jede Änderung an diesem Teil (`check.ps1` auf den fünf anderen:
  `=`).
- Die Quellen stehen in `files_common.tcl` für alle Varianten. Quartus löst Entities auch
  im nicht genommenen Generate-Zweig auf (Error 10481).
- `FA_RXD`/`FA_TXD`/`FA_CTRL_REQ` stehen in allen anderen `variant.psd1` als `VirtualPins`.
- **Ablauf:** Während der Übernahme steht nur die PPS-4-CPU im Reset (`cpu_reset_l`). Die
  I/O-Bausteine laufen weiter, `r10788` scannt die Displays. Lampen-Scan,
  Schalter-Strobes, Spulen und Sound kommen aus `gen_fa_control`. Nach der Freigabe
  startet das Spiel neu.
- **`ctrl_allow = '1'`:** Alle vier S2-DIPs und alle drei Sound-DIPs sind belegt.
- **Nummerierung wie LISY1:** Lampen 0–35 (DS1–9, LD invertiert), Schalter 10×Return +
  Strobe (`N_SW = 75` mit Lücken), Spulen 1–8, Sound = Bits für 10/100/1000.
- **`.rbf` für den ESP:** `GENERATE_RBF_FILE ON` in `device.tcl` der v7, dazu
  `ExtraArtifacts = @('rbf')` in `variant.psd1`. `build.ps1` prüft, dass die Datei aus
  dem aktuellen Compile stammt, `release.ps1` legt sie neben die `.jic` nach
  `bin\HW20x_CycloneIV_v7\GottFA1_PLuS_v4<SW_SUB>.rbf`. Der Assembler schreibt sie
  **komprimiert** (~156 KB statt 368 KB). Das Cyclone IV entpackt sie im AS-Modus
  selbst, am 24.10.2026 über den ESP geschrieben und gebootet. Eingespielt wird sie in
  FA-Control über Kachel 09 FPGA (REVERSE BITS an) oder
  `curl --data-binary @SYS1.rbf http://<esp>/api/fpgaup`.
- **Platz:** v7 steht bei 95 % LE. Das ging nur, weil das PPS4-RAM in einem M9K liegt
  (`PPS4_2.vhd` v0.7). Vorher hätte FA-Control nicht gepasst.

## Handbücher (seit 24.10.2026)

`docs/GottFA1_PLuS_user_manual.html` (Leitfassung), `_Bedienungsanleitung.html`,
`_manuel_utilisateur.html` – je eine Datei, CSS und Bilder eingebettet, **das HTML ist
die Quelle**. Änderungen in allen drei Sprachen nachziehen, Kapitelnummern gleich.
Ändern über den Skill `projekt-doku-pages` (`html_to_md.ps1` → bearbeiten →
`make_manual.ps1`). Online: <https://bontango.github.io/GottFA1_PLuS/>, Startseite
`docs/index.html` aus `make_index.ps1`. Entstanden aus
`N:\Projekte\FPGA System1\doc\GottFA1_PLuS_user manual_v1.00.docx` (Stand SW 7.00).

## Lizenz

GNU General Public License v3.0 (`LICENSE`); die Quelldateien tragen den
GPLv3-Header.
