# GottFA1_PLuS – Resets mitten im Spiel durch Spulen-Störimpulse

Stand 24.10.2026, Software x.30 (Anzeige `V 630` / `V 730` / `V 830` / `V 930`).

## Das Problem

Aus dem Feld kommt immer wieder die Meldung, dass ein GottFA1_PLuS-Board mitten im Spiel
neu startet. In fast allen Fällen lässt sich das auf fehlende oder defekte Freilaufdioden an
Spulen im Gerät zurückführen: Beim Abschalten der Spule entsteht ohne Diode eine
Spannungsspitze, die über die Verkabelung und die Platinenmasse in die Logik einkoppelt.

Die Freilaufdiode bleibt die eigentliche Ursache und sollte immer zuerst geprüft werden. Die
Platine sollte aber nicht schon an einem einzelnen Störimpuls scheitern. Diese Auswertung
beschreibt, warum sie das bis x.03 tat, was x.30 dagegen tut und was die Hardware noch
beitragen kann.

Grundlage: `top/SYS1.vhd`, `rtl/common/SD_Card.vhd`, `scripts/common_header.tcl` und der
Schaltplan `Target/PLuS/GottFA1_PLus_230_Main_SCH.PDF` (HW 2.30).

## Befund

### 1. Hauptverdacht: der Reset-Taster-Eingang war völlig ungefiltert

**Hardware.** Der Taster S8 zieht `SW_Reset` (Header-Pin 144) direkt nach GND. Es gibt
keinen externen Pull-up und keinen Kondensator, nur den internen Weak-Pull-up des FPGA
(`common_header.tcl`, beim Cyclone IV etwa 25–40 kΩ). Ein so hochohmiger Knoten mit einer
Leiterbahn zum Taster wirkt wie eine Antenne.

**FPGA bis x.03.** `reset_sw` lief nur durch zwei Flipflops (`Cross_Slow_To_Fast_Clock`)
und dann direkt auf `SD_Card.i_Rst_L`, von dort auf `cpu_reset_l` und damit `reset_l`.

**Folge.** Ein einziger Low-Takt von 20 ns bei 50 MHz reichte für einen kompletten Neustart:
Boot-Meldung, ROMs neu von der SD-Karte, EEPROM neu laden. Das ist genau das Bild
„resettet mitten im Spiel“.

### 2. nCONFIG läuft über die Hauptplatine

Die Konfigurationsleitungen (NCONF, DCLK, DATA0, nCE, ASDO) gehen über die Hauptplatine zum
Programmierstecker K1. Ein Spike von mindestens 500 ns auf nCONFIG lädt das FPGA neu. Für den
Kunden sieht das genauso aus wie ein Reset.

### 3. Einbruch der Versorgung

12 V entstehen aus 11,5 V AC (D1/D2, C4 2,2 mF), daraus macht der LM2576 5 V, das FPGA-Modul
daraus 3,3 V und 1,2 V. Am Eingang sitzt kein TVS. Ein Spike oder Einbruch kann am FPGA einen
Power-on-Reset auslösen, also ebenfalls eine Neukonfiguration.

### 4. Slam, Outhole und Gottlieb-Reset-Schalter

`sw_slam`, `sw_outhole` und `sw_reset` liefen bis x.03 ungefiltert in U3 (`r10696`). Auf der
Platine sind immerhin 4,7 kΩ und 470 pF vorhanden. Ein Slam-Glitch beendet das Spiel, und das
halten Kunden leicht für einen Reset.

### 5. Kein lokaler Schutz an den Treibern

Die Spulentreiber T5–T12 (IRL540) und die Relais-/Lampentreiber Q1–Q4 (BSP295 an 28V_RET)
haben keinen Klemmschutz. Fehlt die Diode an der Spule, bricht der MOSFET bei etwa 100 V im
Avalanche durch. Die steile Flanke koppelt kapazitiv in Nachbarleitungen ein, und der Strom
fließt über die Logikmasse zurück.

## Was x.30 dagegen tut (Software)

| Maßnahme | Wo | Wirkung |
|---|---|---|
| Reset-Taster muss **50 ms** stabil low sein | `rtl/common/input_filter.vhd`, Instanz `META1` in `top/SYS1.vhd` | Störimpulse auf dem Reset-Pin lösen keinen Neustart mehr aus. Derselbe Filter ist zugleich der Power-on-Reset (startet low, geht erst nach 50 ms stabil high auf 1). |
| Slam, Outhole, Gottlieb-Reset: **1 ms** Filter | `FILT_SLAM`, `FILT_OUTHOLE`, `FILT_RESET` in `top/SYS1.vhd` | Einzelne Spikes erreichen die Spielsoftware nicht mehr. Die CPU tastet diese Eingänge ohnehin viel langsamer ab. |
| **Diagnosezähler** auf der Boot-Anzeige | Prozess `DIAG` in `top/SYS1.vhd` | Spieler-4-Anzeige zeigt `R..G..` statt `2022`, siehe unten. |
| Weak-Pull-up auf `MISO` | `scripts/common_header.tcl` | Ohne SD-Karte liest MISO sicher FF; nötig für den Flash-Rückfall. |

Die Switch-Matrix-Returns sind bewusst **nicht** gefiltert: das Strobe-Timing der
Matrix verträgt keine zusätzliche Latenz, und auf der Platine liegen dort bereits
4,7 kΩ / 470 pF und der 74HC4049.

### Die Diagnosezähler lesen

Die Spieler-4-Anzeige zeigt während des Bootens z. B. `R01G37`:

- **R** = Resets, die über den Reset-Pin durchgekommen sind (Pin ≥ 50 ms low).
- **G** = verworfene Kurzimpulse auf dem Reset-Pin.

Beide Zähler stehen nur beim Laden des FPGA (Einschalten, Neukonfiguration) auf 0; ein Reset
über den Taster löscht sie nicht. Sie bleiben bei 99 stehen.

| Anzeige nach einem unerwarteten Neustart | Bedeutung |
|---|---|
| `R00G00` | Das FPGA wurde neu geladen: Spannungseinbruch oder Spike auf nCONFIG. Hardware prüfen (Punkte 2, 3, 5 unten). |
| `R` hochgezählt | Der Reset-Pin war mindestens 50 ms low: Taster gedrückt oder eine sehr massive Störung. |
| `G` > 0 | Störimpulse erreichen den Reset-Pin, der Filter hat sie abgefangen. Ein Tasterdruck zählt wegen Prellen ebenfalls ein paar `G`. |

Zeigt die Anzeige `ERROR`, konnte weder SD-Karte noch Flash ein Spiel liefern.

## Was die Hardware noch beitragen kann

Für die nächste Platinenrevision, teilweise nachrüstbar:

1. **Reset-Eingang:** 4,7 kΩ Pull-up nach 3,3 V und 100 nF nach GND direkt am FPGA-Header,
   optional 1 kΩ in Serie zum Taster. Nachrüsten bei vorhandenen Boards: 100 nF parallel zu S8.
   Dasselbe gilt für `TEST_Button`, `SB_Test` und `SB_Dip_Ret`.
2. **nCONFIG:** 10 kΩ Pull-up plus 1–10 nF nach GND nahe am Modul. Programmierung per
   USB-Blaster bleibt möglich, der treibt nCONFIG aktiv.
3. **TVS an jedem Spulen- und Relaistreiber:** Drain nach GND, etwa SMBJ36A oder SMBJ43A je
   nach Spulenspannung. Das klemmt die Spitze und begrenzt dV/dt auch dann, wenn an der Spule
   die Diode fehlt. Energie prüfen (½·L·I², bei Flipperspulen typisch einige 10 mJ).
4. **Masseführung:** Source der IRL540/BSP295 auf eine eigene Leistungsmasse, die nur am
   Steckverbinder sternförmig mit der Logikmasse verbunden ist. Der Rückstrom der Spule soll
   nicht unter dem FPGA-Modul durchlaufen.
5. **Versorgung:** TVS am 12-V-Eingang (SMBJ18A), 100 nF plus Elko direkt an den 5-V-Pins des
   Moduls, optional ein Ferrit davor.
6. **Kundenhinweis:** Prüfanleitung für die Freilaufdioden (Gottlieb-Spulen haben eine 1N4004
   direkt an der Spule) – bleibt die wichtigste Maßnahme.

## Prüfen

1. Bench-Test: Reset-Taster kurz antippen (< 50 ms) → kein Reset, `G` steigt. Lang drücken →
   Reset, `R` steigt, Boot-Meldung korrekt.
2. Störtest am Gerät: eine Spule mit bewusst abgeklemmter Freilaufdiode feuern (Testmenü),
   x.03 gegen x.30 vergleichen. Oszi an `SW_Reset`, nCONFIG und 3,3 V.
3. Nach jedem Feld-Reset die Boot-Anzeige notieren lassen (`R..G..`).

Stand x.30: **7.30 (HW v2.0x) am 24.10.2026 erfolgreich in Hardware getestet**, 9.30, 8.30
und 6.30 noch nicht.
