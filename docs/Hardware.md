# GottFA1_PLuS — Hardware Reference

A description of the **GottFA1_PLuS** board as seen from the FPGA design in this
repository (HW v2.1x, Intel Cyclone 10 LP `10CL006YE144C8G`). It is intended as a
reference for working on the gateware — in particular as the basis for a built-in
**hardware test routine** that drives and reads the displays, switch matrix, lamps,
solenoids and sound.

> ⚠️ **Safety**: GottFA1_PLuS switches real pinball voltages — the high-voltage
> display rails (42 V / 60 V DC) and the solenoid/lamp coils. Misusing it —
> especially energizing solenoid coils for too long — can damage coils, drivers or
> the playfield. This is a private, non-commercial
> project provided **without any warranty**; use at your own risk.

**Sources.** This document is compiled from the VHDL source (`SYS1.vhd` port list /
comments and the `lib_common` peripheral cores), the FPGA pin assignment in
`SYS1.qsf`, the project page <https://lisy.dev/gottfa1_plus.html>, the
[user manual](https://lisy.dev/swrep/GottFA1/manual/GottFA1_PLuS_user%20manual_v1.00.pdf),
and the v2.30 schematics (see [References](#16-references)).

---

## 1. Overview

GottFA1_PLuS is an **all-in-one replacement MPU** for **Gottlieb System 1** pinball
machines. A single board replaces the original:

- Main CPU board (Rockwell PPS/4-2 based)
- Power supply
- Driver board (lamps & solenoids)
- Sound card

The original Rockwell parts are re-implemented in VHDL on a small FPGA dev board.
The emulated chip set (see `SYS1.vhd`) is:

| Ref | Original part | Function | VHDL core (`lib_common`) |
|-----|---------------|----------|--------------------------|
| U1  | PPS/4-2       | CPU                                              | `PPS4_2.vhd` |
| U2  | 10696 GPIO (dev 0x06) | NVRAM data in/out                        | `r10696.vhd` |
| U3  | 10696 GPIO (dev 0x03) | Lamps, strobe, dip switches, PGOL addr bits 8/9 | `r10696.vhd` |
| U4  | A1753 RRIO (dev 0x04) | Solenoids, NVRAM R/W & enable            | `rA17xx.vhd` |
| U5  | A1752 RRIO (dev 0x02) | Switch matrix                            | `rA17xx.vhd` |
| U6  | 10788 GPKD (dev 0x0d) | Display                                  | `r10788.vhd` |
| Z22 | 5101          | NVRAM (256×4)                                    | `R5101` (Cyclone IP) |
| Z23 | PGOL          | 1 KB game PROM                                   | `PGOL_ROM` (Cyclone IP) |

The top-level entity is `SYS1` (`SYS1.vhd`). The version documented here is **v9.03**.

License: **GPLv3** (see `LICENSE`).

---

## 2. Hardware versions & FPGA options

The GottFA1_PLuS PCB exists in several revisions:

| PCB rev | Notes |
|---------|-------|
| v2.10   | Early production; lamp-driver MOSFETs could fail over time |
| v2.20   | Protected MOSFETs for the lamp drivers |
| v2.30   | Standard MOSFETs, cost-optimized (current design) |

The FPGA itself is a separately sourced **dev board**, programmed via USB Blaster.
Two FPGA families are supported by the project; **this repository targets**:

- **Intel Cyclone 10 LP `10CL006YE144C8G`** (HW v2.1x), Quartus Prime Lite **22.1**.

> **Pin numbering caveat.** The published v2.30 schematics are drawn around an
> **EP2C5/Cyclone II** dev board (connector `X1P`), so the pin numbers printed on
> them differ from the Cyclone 10 build. **The authoritative FPGA pin assignment is
> `SYS1.qsf`** (reproduced in [§14](#14-fpga-pin-map)). The schematics remain the
> reference for *signal names* and the board-level routing (level shifters, drivers,
> connectors, power).

---

## 3. System block diagram

```
                 Gottlieb System 1 backbox / playfield (5 V logic, 42/60 V displays)
                 ┌──────────────────────────────────────────────────────────────┐
   Returns/Slam/ │   Displays      Switch matrix     Lamp matrix     Solenoids   │
   Outhole (5V)  │  (2 groups,      5 strobe ×        4 data ×        8 coils     │
                 │   4 strobes)     8 return          ~9 strobe       (low-side)  │
                 └───▲────────────────▲──────────────────▲───────────────▲───────┘
        74HC4049 →3V3│      74HCT240/244 ↑5V   74HC154+74HC240↑   driver MOSFETs ↑
                 ┌───┴────────────────┴──────────────────┴───────────────┴───────┐
                 │                     GottFA1_PLuS board                         │
                 │   level shifters · buffers · lamp/solenoid drivers · power     │
                 │   TDA7267 audio amp · microSD socket · FRAM · DFPlayer-Mini    │
                 └───────────────────────────▲───────────────────────────────────┘
                                              │ 3.3 V I/O
                 ┌────────────────────────────┴───────────────────────────────────┐
                 │  FPGA dev board (Cyclone 10 LP 10CL006YE144C8G)                  │
                 │  SYS1: PPS/4-2 CPU + 10696/A175x/10788 IO + ROM/RAM + sound      │
                 └─────────────────────────────────────────────────────────────────┘
```

Logic flow: the emulated CPU runs the original Gottlieb game ROM (loaded from SD
card into FPGA block RAM) and drives the same I/O devices as the original MPU. FPGA
pins are 3.3 V; inputs from the machine are shifted down by **74HC4049**, outputs are
buffered up to 5 V by **74HCT240 / 74HCT244**, and lamp/solenoid lines are switched
**low-side** by the driver-stage N-channel MOSFETs (to GND). The 42 V / 60 V rails
feed the high-voltage gas-discharge displays only.

---

## 4. Power supply

Inputs taken from the Gottlieb harness (per the v2.30 power schematic): **60 V AC**,
**14 V AC** (×2), **11.5 V AC** (×2) and **12 V DC**; the original power connector
also carries +8 V / +4 V / 42 V / 60 V DC.

On-board rails:

| Rail | Source | Used for |
|------|--------|----------|
| +5 V | `LM2576-5.0` switching regulator | board logic (74HCxx), pull-ups, audio amp |
| +12 V | from 12 V DC input | analog / amp supply |
| 60 V DC | `TL783CKC` HV regulator (from ~90 V rectified) | the four **player** score displays |
| 42 V DC | derived | the **status / credit** display |
| +3.3 V / +1.2 V | FPGA dev board regulators | FPGA core & I/O |

> **Note:** the 42 V / 60 V rails exclusively feed the Gottlieb gas-discharge display
> panels (which need these high voltages — 60 V for the four player displays, 42 V for
> the status/credit display). **Solenoids and lamps are *not* powered from these
> rails**: they are switched **low-side** by N-channel MOSFETs to GND, with the coil
> supply coming from the machine's solenoid/lamp supply.

Test points: **TP1 = GND, TP2 = +12 V, TP3 = +5 V, TP4 = 42 V, TP5 = 60 V**.
Power connectors **P3 / P6** (Molex). Audio power amplifier: **TDA7267**.

---

## 5. FPGA I/O & voltage levels

- FPGA I/O standard: **3.3-V LVTTL** (`SYS1.qsf`), device `10CL006YE144C8G`.
- **Inputs** from the machine (`sw_return[7:0]`, `sw_slam`, `sw_outhole`) pass
  through **74HC4049** hex inverters/level-shifters (5 V → 3.3 V). RC filters
  (470 pF + pull-up) debounce the return lines on-board.
- **Outputs** to the machine are buffered to 5 V by **74HCT240** (`sw_strobe`,
  display segments, lamp/solenoid pre-drivers) and **74HCT244** (J2 I/O bus).
- The display digit select uses a **74HC154** 4→16 decoder; the lamp strobe select
  uses another **74HC154** (the original `Z30 74154`).
- Several FPGA outputs are **active-low at the pin** — most importantly the solenoid
  bus (see [§9](#9-solenoids)).

---

## 6. Displays

Gottlieb System 1 uses multiplexed 7-segment displays: four **player score**
displays plus a **status / credit** display. In the gateware the display controller
is the **10788 GPKD** emulation (`U6`, `r10788.vhd`); its BCD output is converted to
7-segment by two `SN7448_wh` decoders (a 7448 variant *with* the extra `h` segment).

FPGA signals:

| Signal | Dir | Width | Description |
|--------|-----|-------|-------------|
| `disp_seg_A[1..8]` | out | 8 | Segment group **A** (`[8]` = `h` segment) |
| `disp_seg_B[1..8]` | out | 8 | Segment group **B** (`[8]` = `h` segment) |
| `disp_strobes[3:0]` | out | 4 | Digit strobe select |

Board side: the 4 strobes feed a **74HC154** (IC23) → up to 16 digit lines
(`Dis_D1..D16`); the segment groups are buffered by **74HC240** (IC25/IC26). Display
refresh timing is selectable for gas-discharge "tube" vs LED displays via option DIP
(`sw2_dips(2)`, see [§11](#11-dip-switches)) — this is fed to `r10788` as `is_tube`.

The Gottlieb display panels are gas-discharge (plasma) tubes and need high drive
voltages supplied by the board: **60 V for the four player score displays and 42 V
for the status / credit display** (see [§4](#4-power-supply)).

During boot a banner ("GOTTFA / BY BON / TANGO / 2022", then version / "readSD") is
shown via the `boot_message` core before the game takes over.

**Testing.** Drive `disp_seg_A`/`disp_seg_B` with a fixed segment pattern while
cycling `disp_strobes` through `0001/0010/0100/1000` to light each digit column in
turn; verify all segments and all digit positions on both groups.

---

## 7. Switch matrix

The original A1752 RRIO (`U5`, `rA17xx.vhd`) scans the switch matrix.

| Signal | Dir | Width | Description |
|--------|-----|-------|-------------|
| `sw_strobe[4:0]` | out (buffer) | 5 | Matrix strobe (column drive) |
| `sw_return[7:0]` | in | 8 | Matrix return (row sense) |
| `sw_outhole` | in | 1 | Dedicated outhole switch |
| `sw_slam` | in | 1 | Dedicated slam switch (can be disabled via option DIP4) |
| `sw_reset` | in | 1 | Dedicated reset / GTB reset switch (weak pull-up) |

→ a **5 × 8 matrix (40 switches)** plus three dedicated switches. Returns are level
shifted by 74HC4049 and de-bounced internally (`Cross_Slow_To_Fast_Clock_Bus`
metastability sync, plus per-line RC). `sw_strobe(0) & sw_return(0)` is also used as
the internal "test" trigger, and `sw_strobe(3)/sw_return(0)` as the credit switch.

**Testing.** Assert one `sw_strobe` line at a time and read `sw_return[7:0]`; a
closed matrix switch at (strobe, return) pulls the corresponding return active.
Also read `sw_outhole`, `sw_slam`, `sw_reset` directly.

---

## 8. Lamps

The lamp matrix is driven from the 10696 GPIO (`U3`, `r10696.vhd`).

| Signal | Dir | Width | Description |
|--------|-----|-------|-------------|
| `ld[3:0]` | out | 4 | Lamp **data** lines (LD1..LD4) |
| `ds[3:0]` | out | 4 | Lamp **strobe** select |

Board side: `ds[3:0]` drives a **74HC154** (IC15, the original `Z30 74154`) producing
strobe lines `DS0..DS9`, buffered by 74HC240 (IC14); together with the 4 data lines
this addresses up to **36 playfield lamps** (4 × 9). Lamps are switched **low-side**
by the lamp-driver N-channel MOSFETs (like the solenoids); they are **not** fed from
the 42 V / 60 V display rails.

Note: internally `ds` (as `game_ds`) is multiplexed for two extra jobs — reading the
24 Gottlieb DIPs at boot and detecting the game-over / tilt / HSTD relay states
(`game_ds = "0001"` clocks the 74175 relay latch). In **attract mode** the lamp
outputs are sourced from the attract controller instead of the game.

**Testing.** For each strobe value on `ds` (selecting one DS column) set a pattern on
`ld[3:0]`; step through all DS columns to exercise every lamp. Keep in mind the
relay-detect / dip-read overloading of `ds` when testing outside normal game flow.

---

## 9. Solenoids

Eight solenoid drivers, from the A1753 RRIO (`U4`, `rA17xx.vhd`). The FPGA bus is
**active-low at the pin**: `solenoids <= not solenoids_intern` (`SYS1.vhd:896`), i.e.
the board inverts it back. On the board each output drives the gate of an **N-channel
MOSFET that switches the coil's ground return (low-side)**; the coil's supply side
comes from the machine's solenoid supply, not from the 42 V / 60 V display rails.
Bit→function mapping (VHDL + v2.30 driver schematic, and matching the standard
System 1 layout):

| `solenoids` bit | Function | Notes |
|-----------------|----------|-------|
| `[0]` | Outhole          | |
| `[1]` | Knocker          | |
| `[2]` | 10-point chime   | also `Sound_10` trigger (`SYS1.vhd:913`) |
| `[3]` | 100-point chime  | also `Sound_100` trigger (`SYS1.vhd:914`) |
| `[4]` | 1000-point chime | also `Sound_1K` trigger (`SYS1.vhd:915`) |
| `[5]` | Solenoid 6       | game-specific |
| `[6]` | Solenoid 7       | game-specific |
| `[7]` | Solenoid 8       | game-specific |

Because bits **2/3/4 double as the chime/sound triggers**, energizing those outputs
in a test will also produce the corresponding chime tone (see [§10](#10-sound)).

**Testing.** Pulse one solenoid bit at a time. ⚠️ Solenoid coils are **not rated for
continuous on**: keep activation brief (short pulse) to avoid overheating the coil
and driver. The knocker (`[1]`) is a good audible single-fire test.

---

## 10. Sound

Two independent audio paths:

1. **Chimes / tones / multisound** → `audio_o` (out). For games ≤ 8 (3-tone chime
   board era) the FPGA synthesizes the three chime tones (`gentones.vhd`); from game
   9 (Totem) on it uses the Gottlieb **Multisound** emulation (`Multi_Sound.vhd`).
   The selected mix is `audio_o`, driven into the on-board **TDA7267** amplifier and
   out to the cabinet speaker. The chime triggers are the solenoid lines
   `Sound_10/100/1K` = `solenoids_intern(2/3/4)`.
2. **Background music / MP3** → `audio_RX` (out): a 9600-baud serial command stream
   to a **DFPlayer-Mini** MP3 module (`DFPlayer_Mini_CMD.vhd`), connector `Audio1`.
   Music files live in folder `02` on the (separate) DFPlayer SD card and are played
   randomly during gameplay when enabled.

Sound-board controls:

| Signal | Dir | Description |
|--------|-----|-------------|
| `SB_Test` | in | Integrated sound-board test button (also the GottFA test input in v9.03) |
| `SB_Dip_Return` | in | Return line for the sound-option DIP read |
| `LED_0/1/2` | out | Drive the SB-DIP read strobes (`sb_dip_strobe`) |

Sound option DIPs: **1** = Sound vs Tones, **2** = attract sounds, **3** = background
music via MP3 (same semantics as the original Multisound card). See
[§11](#11-dip-switches).

**Testing.** Trigger `Sound_10/100/1K` to sound each chime; assert `SB_Test` to run
the integrated sound self-test (`SB_Test_SYS1.vhd`, which exercises the three chimes
+ background); send a DFPlayer command on `audio_RX` to verify the MP3 path.

---

## 11. DIP switches

| Bank | FPGA signal | Bits | Purpose |
|------|-------------|------|---------|
| **S1** game select | `sw1_dips[3:0]` | 4 | Selects which game ROM (from SD) runs; shown decimal on the status display at boot |
| **S2** options | `sw2_dips[3:0]` | 4 | See below |
| **Gottlieb** banks | `GTB_dips[7:0]` | 24 logical | The original game-adjustment dips S1…S24 (banks S3/S4/S5), read multiplexed |
| **Sound (SB)** | via `SB_Dip_Return` + strobes | 3 | Sound options (read serially) |

**S2 options** (`sw2_dips`):

| Bit | ON meaning |
|-----|------------|
| `sw2_dips(0)` (DIP1) | Initialize NVRAM to zero on boot (reset all RAM — recommended on first start) |
| `sw2_dips(1)` (DIP2) | Freeplay (press-and-hold credit button > 2 s simulates left coin chute) |
| `sw2_dips(2)` (DIP3) | LED-display refresh timing (vs gas "tube" timing) → `r10788 is_tube` |
| `sw2_dips(3)` (DIP4) | Disable Gottlieb slam detection (recommended) |

**Gottlieb dips** behave as on a real MPU; two pins are repurposed by GottFA1:
**DIP16** = background-music option (restart each game vs resume), **DIP24** = enable
attract mode. Manual's "smooth start" suggestion: S1–S8 OFF, S9–S16 ON, S17–S24 ON
except DIP19 OFF.

---

## 12. Storage

Two SPI devices share the bus `MOSI` / `MISO` / `CLK`, selected by separate chip
selects:

- **microSD card** (`CS_SDcard`, socket `TF-01A`): holds the game image. The first
  16 KB are read into FPGA RAM at boot with this layout
  (`SYS1.vhd` address decoding):

  | Offset | Size | Content |
  |--------|------|---------|
  | 0x0000 | 2 KB | U5 system ROM |
  | 0x0800 | 2 KB | U4 system ROM |
  | 0x1000 | 1 KB | PGOL game PROM |
  | 0x1400 | 1 KB | Sound ROM 1 |
  | 0x1800 | 1 KB | Sound ROM 2 (mask) |
  | 0x3000 | 4 KB | Attract-mode command "ROM" |

  Game ROMs are not included (copyright). The game is chosen by `sw1_dips`.
- **FRAM `FM25CL64B`** (`CS_EEprom`): non-volatile store that replaces the original
  battery-backed RAM; the emulated 5101 NVRAM content is saved here on triggers
  (game over / test / credit).

The shared SPI bus is muxed in `SYS1.vhd`: SD card is used only during boot
(`reset_l = '0'`), the FRAM afterwards.

---

## 13. LEDs & test button

| Signal | Dir | Meaning |
|--------|-----|---------|
| `LED_active` | out | Lit while a game is running (`not game_running`) |
| `LED_SD_Error` | out | Lit on SD-card read error |
| `LED_0/1/2` | out | SB-DIP read strobes (`sb_dip_strobe(0..2)`) |
| `Button_Test` | in | GottFA test switch (weak pull-up) |
| `reset_sw` | in | Master reset (weak pull-up) |

---

## 14. FPGA pin map

Authoritative assignment from `SYS1.qsf` (device `10CL006YE144C8G`, 3.3-V LVTTL).

| Signal | Dir | FPGA pin | Subsystem |
|--------|-----|----------|-----------|
| `clk_50` | in | PIN_23 | 50 MHz clock |
| `reset_sw` | in | PIN_144 | Reset (pull-up) |
| `LED_0` | out | PIN_1 | SB-DIP strobe 0 |
| `LED_1` | out | PIN_3 | SB-DIP strobe 1 |
| `LED_2` | out | PIN_10 | SB-DIP strobe 2 |
| `LED_active` | out | PIN_2 | Game-running LED |
| `LED_SD_Error` | out | PIN_7 | SD-error LED |
| `disp_seg_A[1]` | out | PIN_58 | Display group A seg 1 |
| `disp_seg_A[2]` | out | PIN_59 | Display group A seg 2 |
| `disp_seg_A[3]` | out | PIN_60 | Display group A seg 3 |
| `disp_seg_A[4]` | out | PIN_75 | Display group A seg 4 |
| `disp_seg_A[5]` | out | PIN_65 | Display group A seg 5 |
| `disp_seg_A[6]` | out | PIN_54 | Display group A seg 6 |
| `disp_seg_A[7]` | out | PIN_55 | Display group A seg 7 |
| `disp_seg_A[8]` | out | PIN_73 | Display group A seg h |
| `disp_seg_B[1]` | out | PIN_68 | Display group B seg 1 |
| `disp_seg_B[2]` | out | PIN_69 | Display group B seg 2 |
| `disp_seg_B[3]` | out | PIN_70 | Display group B seg 3 |
| `disp_seg_B[4]` | out | PIN_71 | Display group B seg 4 |
| `disp_seg_B[5]` | out | PIN_72 | Display group B seg 5 |
| `disp_seg_B[6]` | out | PIN_66 | Display group B seg 6 |
| `disp_seg_B[7]` | out | PIN_67 | Display group B seg 7 |
| `disp_seg_B[8]` | out | PIN_74 | Display group B seg h |
| `disp_strobes[0]` | out | PIN_76 | Display digit strobe 0 |
| `disp_strobes[1]` | out | PIN_77 | Display digit strobe 1 |
| `disp_strobes[2]` | out | PIN_80 | Display digit strobe 2 |
| `disp_strobes[3]` | out | PIN_83 | Display digit strobe 3 |
| `sw_strobe[0]` | out | PIN_129 | Switch matrix strobe 0 |
| `sw_strobe[1]` | out | PIN_127 | Switch matrix strobe 1 |
| `sw_strobe[2]` | out | PIN_125 | Switch matrix strobe 2 |
| `sw_strobe[3]` | out | PIN_133 | Switch matrix strobe 3 |
| `sw_strobe[4]` | out | PIN_136 | Switch matrix strobe 4 |
| `sw_return[0]` | in | PIN_137 | Switch matrix return 0 |
| `sw_return[1]` | in | PIN_135 | Switch matrix return 1 |
| `sw_return[2]` | in | PIN_132 | Switch matrix return 2 |
| `sw_return[3]` | in | PIN_124 | Switch matrix return 3 |
| `sw_return[4]` | in | PIN_126 | Switch matrix return 4 |
| `sw_return[5]` | in | PIN_128 | Switch matrix return 5 |
| `sw_return[6]` | in | PIN_143 | Switch matrix return 6 |
| `sw_return[7]` | in | PIN_142 | Switch matrix return 7 |
| `sw_outhole` | in | PIN_141 | Outhole switch |
| `sw_slam` | in | PIN_138 | Slam switch |
| `ld[0]` | out | PIN_85 | Lamp data 0 |
| `ld[1]` | out | PIN_106 | Lamp data 1 |
| `ld[2]` | out | PIN_105 | Lamp data 2 |
| `ld[3]` | out | PIN_84 | Lamp data 3 |
| `ds[0]` | out | PIN_98 | Lamp strobe select 0 |
| `ds[1]` | out | PIN_87 | Lamp strobe select 1 |
| `ds[2]` | out | PIN_86 | Lamp strobe select 2 |
| `ds[3]` | out | PIN_119 | Lamp strobe select 3 |
| `solenoids[0]` | out | PIN_114 | Outhole |
| `solenoids[1]` | out | PIN_120 | Knocker |
| `solenoids[2]` | out | PIN_115 | 10-point chime / Sound_10 |
| `solenoids[3]` | out | PIN_113 | 100-point chime / Sound_100 |
| `solenoids[4]` | out | PIN_111 | 1000-point chime / Sound_1K |
| `solenoids[5]` | out | PIN_112 | Solenoid 6 |
| `solenoids[6]` | out | PIN_101 | Solenoid 7 |
| `solenoids[7]` | out | PIN_103 | Solenoid 8 |
| `GTB_dips[0]` | in | PIN_53 | Gottlieb dip read |
| `GTB_dips[1]` | in | PIN_52 | Gottlieb dip read |
| `GTB_dips[2]` | in | PIN_51 | Gottlieb dip read |
| `GTB_dips[3]` | in | PIN_50 | Gottlieb dip read |
| `GTB_dips[4]` | in | PIN_49 | Gottlieb dip read |
| `GTB_dips[5]` | in | PIN_46 | Gottlieb dip read |
| `GTB_dips[6]` | in | PIN_44 | Gottlieb dip read |
| `GTB_dips[7]` | in | PIN_43 | Gottlieb dip read |
| `sw1_dips[0]` | in | PIN_24 | Game select bit 0 |
| `sw1_dips[1]` | in | PIN_25 | Game select bit 1 |
| `sw1_dips[2]` | in | PIN_22 | Game select bit 2 |
| `sw1_dips[3]` | in | PIN_32 | Game select bit 3 |
| `sw2_dips[0]` | in | PIN_88 | Option DIP1 (init NVRAM) |
| `sw2_dips[1]` | in | PIN_89 | Option DIP2 (freeplay) |
| `sw2_dips[2]` | in | PIN_90 | Option DIP3 (LED timing) |
| `sw2_dips[3]` | in | PIN_91 | Option DIP4 (slam off) |
| `CS_SDcard` | out (buffer) | PIN_31 | SD card chip select |
| `CS_EEprom` | out (buffer) | PIN_38 | FRAM chip select |
| `MOSI` | out | PIN_42 | SPI MOSI (shared) |
| `MISO` | in | PIN_34 | SPI MISO (shared) |
| `CLK` | out | PIN_39 | SPI clock (shared) |
| `Button_Test` | in | PIN_100 | GottFA test switch (pull-up) |
| `audio_o` | out | PIN_33 | Audio out → TDA7267 |
| `SB_Test` | in | PIN_99 | Sound-board test button (pull-up) |
| `SB_Dip_Return` | in | PIN_11 | Sound-board DIP return (pull-up) |
| `audio_RX` | out | PIN_28 | DFPlayer-Mini serial (9600 baud) |

---

## 15. Connectors (functional)

| Connector | Type | Carries |
|-----------|------|---------|
| `J2` | header (via 74HCT244 buffers) | Buffered FPGA I/O to backbox (displays / matrix lines) |
| `K1` | 10-pin (`WANNENSTECKER-10-ST`) | FPGA configuration / AS programming signals |
| `Audio1` | 16-pin | DFPlayer-Mini MP3 module (`audio_RX`, DAC, speaker) |
| `J1a` | microSD socket (`TF-01A`) | Game ROM image card |
| `P3` / `P6` | Molex | Power / high-voltage display rails (42 V / 60 V DC, 60 V AC etc.) |
| `SP1` | — | Cabinet speaker (from TDA7267) |

> Exact connector pin numbers are **not reproduced here** because the published v2.30
> schematics number them for the EP2C5/Cyclone II dev board (see the caveat in
> [§2](#2-hardware-versions--fpga-options)). Use the schematic PDFs for pin-level
> wiring and `SYS1.qsf` for the Cyclone 10 FPGA pins.

---

## 16. References

- Project page: <https://lisy.dev/gottfa1_plus.html>
- User manual (v1.00): <https://lisy.dev/swrep/GottFA1/manual/GottFA1_PLuS_user%20manual_v1.00.pdf>
- Schematics (v2.30):
  - Main: <https://lisy.dev/swrep/GottFA1/PLuS/GottFA1_PLus_230_Main_SCH.PDF>
  - Power: <https://lisy.dev/swrep/GottFA1/PLuS/GottFA1_PLus_230_Power_SCH.PDF>
  - Driver: <https://lisy.dev/swrep/GottFA1/PLuS/GottFA1_PLus_230_Driver_SCH.PDF>
- Source of truth in this repo: `GottFA1_PLuS_HW21x_Cyclone10/SYS1.vhd`,
  `…/SYS1.qsf`, and the cores under `lib_common/`.

---

## 17. Relevance for the hardware test routine

The planned built-in test routine needs to drive/observe these signals:

| Subsystem | Drive (outputs) | Observe (inputs) |
|-----------|-----------------|------------------|
| **Displays** | `disp_seg_A[1..8]`, `disp_seg_B[1..8]`, `disp_strobes[3:0]` | — |
| **Switches** | `sw_strobe[4:0]` | `sw_return[7:0]`, `sw_outhole`, `sw_slam`, `sw_reset` |
| **Lamps** | `ld[3:0]`, `ds[3:0]` | — |
| **Solenoids** | `solenoids[7:0]` (active-low; pulse only!) | — |
| **Sound** | `Sound_10/100/1K` (= `solenoids_intern(2/3/4)`), `audio_RX` | `SB_Test` |

Watch-outs when bypassing normal game flow:
- `solenoids` is **active-low at the pin** and inverted on board; coils are switched
  low-side (N-channel MOSFET to GND). Pulse coils briefly only.
- `ds` is internally reused for Gottlieb-DIP reading and relay detection.
- Solenoid bits **2/3/4 also fire the chimes** — useful for a combined solenoid+sound
  check, but expect tones.
- Inputs are level-shifted/inverted (74HC4049) and metastability-synchronized.
