# Arbeiten in diesem Baum

Vier Boards, ein Quellstand. Was du änderst, gilt für alle vier — das ist der Zweck
der Struktur und gleichzeitig die Sache, an die man sich gewöhnen muss.

## Was ändern → wo

| Du willst … | Datei |
|---|---|
| Logik ändern, ein Modul anfassen | `rtl/common/…` — gilt sofort für alle Boards |
| das Top-Level ändern | `top/SYS1.vhd` — es gibt nur noch dieses eine |
| die Software-Version erhöhen | `rtl/common/version_pkg.vhd`, Konstante `SW_SUB` |
| einen Pin umlegen | `variants/<name>/pins.tcl` |
| FPGA-Typ oder Familie ändern | `variants/<name>/device.tcl` |
| Board-Kennung, virtuelle Pins, Release-Ordner | `variants/<name>/variant.psd1` |
| die Board-Ziffer der Anzeige | `variants/<name>/variant_pkg.vhd`, `BOARD_ID` |
| eine neue `.vhd` in den Build nehmen | `scripts/files_common.tcl` (oder `files_<familie>.tcl`) |
| ein globales Quartus-Assignment | `scripts/common_header.tcl` |
| Timing-Constraints | `rtl/common/SYS1.sdc` — eine Datei für alle |

**Was du NIE von Hand änderst:** `variants/<name>/SYS1.qsf`. Die Datei wird erzeugt.
Quartus schreibt selbst hinein, sobald das Projekt in der IDE offen ist — deshalb
erzeugen `check.ps1` und `build.ps1` sie vor jedem Lauf neu, und deine Änderung wäre
weg. Trag sie stattdessen in das passende Fragment ein.

## Befehle

```powershell
# Schnellprüfung: nur Analysis & Synthesis, fängt Syntax- und Elaborationsfehler
.\scripts\check.ps1

# Vollständig: Fitter + Timing, Vergleich gegen scripts\baseline.csv
.\scripts\check.ps1 -Fit

# Nur eine Variante
.\scripts\check.ps1 -Variants hw21x_cyclone_10 -Fit

# Prüfen, ob die .qsf noch zu den Fragmenten passen (schreibt nichts)
.\scripts\gen_qsf.ps1 -Check

# Eine Variante voll bauen, inklusive .jic
.\scripts\build.ps1 hw21x_cyclone_10

# Alle Boards mit derselben Version bauen und nach bin\ legen
.\scripts\release.ps1 -Note "wofür dieses Release gut ist"
```

`check.ps1` endet mit **0** (sauber), **1** (Build-Fehler) oder **2** (Baseline-Abweichung).

## Die Baseline verstehen

`scripts/baseline.csv` hält je Variante fest: `Comb`, `Reg`, `Mem`, `Slack` und einen
Warnungs-Fingerabdruck. Verglichen wird **exakt** — das sind Eigenschaften des Designs.

**Die LE-Zahl des Fitters wird NICHT verglichen.** Sie wird nur mitgeführt. Ein
einziger zusätzlicher Knoten reicht, damit der Fitter die LEs anders packt; ein
exakter Test darauf meldet Änderungen, die es nicht gibt.

**Slack wird großzügig verglichen** (1,5 ns Toleranz). Er hängt von der Platzierung
ab und schwankt bei unveränderten Quellen. Der absolute Boden liegt bei 0,05 ns und
ist an diesem Design gemessen: der schlechteste Wert ist hier ein **Hold**-Slack von
0,136–0,151 ns, während der Setup-Slack bei 5,9–7,0 ns liegt. Ein Boden von 1,0 ns
(wie bei AtariFA) würde bei jedem Lauf feuern.

Nach einer bewussten Änderung die neuen Zahlen in `baseline.csv` eintragen — und in
die `Note`-Spalte schreiben, **warum** sie sich bewegt haben. Diese Spalte ist die
eigentliche Dokumentation.

## Eine neue Variante aufnehmen

1. `variants/<name>/` anlegen mit `variant.psd1`, `device.tcl`, `pins.tcl`,
   `variant_pkg.vhd` und einer Kopie einer bestehenden `SYS1.qpf` und `SYS1.cof`.
2. Eine freie `BOARD_ID` wählen — belegt sind 6, 7, 8, 9. In `variant.psd1` **und**
   `variant_pkg.vhd` eintragen, `release.ps1` prüft, dass beide übereinstimmen.
3. Ports, die es auf dem Board nicht gibt, in `VirtualPins` aufnehmen.
4. Neue Chipfamilie? Dann `rtl/<familie>/` mit **denselben Entity-Namen** und ein
   `scripts/files_<familie>.tcl` daneben.
5. `.\scripts\gen_qsf.ps1` und `.\scripts\check.ps1 -Fit`, dann die Zeile in
   `baseline.csv` ergänzen.

## Fallstricke, die hier schon zugeschlagen haben

- **Ein Ausgangsport ohne Pin-Location ist für Quartus ein *benutzter* Pin.**
  `RESERVE_ALL_UNUSED_PINS` greift bei deklarierten Ports nicht. Deshalb `VirtualPins`.
- **Pfade sind relativ zum Quartus-Projektverzeichnis**, und das ist
  `variants/<name>/` — also `../../rtl/…`. Die `.qip` sind davon ausgenommen, sie
  nutzen `[file join $::quartus(qip_path) …]` und sind ortsunabhängig.
- **`sed -i` aus der Git-Bash zerstört die CRLF** dieses Baums; eine
  Drei-Zeilen-Änderung sieht danach aus wie ein Totalumbau. Textersetzungen über
  PowerShell mit `[System.IO.File]::WriteAllText` und `UTF8Encoding($false)`.
- **In PowerShell 5.1 niemals `2>&1` auf `quartus_*.exe`.** Jede stderr-Zeile wird
  sonst in einen ErrorRecord verpackt und setzt `$?` auf `$false`, auch bei Exitcode 0
  — Quartus schreibt dort eine harmlose TBBmalloc-Notiz hin. `$LASTEXITCODE` gilt.
- **`.cof` mit absolutem Pfad flasht das falsche Board.** Genau das war vor dem Umbau
  der Fall: die `.cof` von `CycloneIV_v3` zeigte auf die `.sof` von `v4`. Gegenprobe
  über die `.jic`-Größe — sie ist gerätetypisch (EP4CE6: 2.097.375 B,
  10CL006Y: 2.097.377 B).

## Und was ein grüner Lauf *nicht* beweist

Gleiche Netzliste heißt: es hat sich nichts geändert. Es heißt **nicht**, dass es
funktioniert. Welches Board zuletzt wirklich auf Hardware lief, steht in
`VARIANTEN.md` — dort eintragen, nicht in einem Commit-Text.
