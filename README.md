# GottFA1_PLuS

FPGA reimplementation of the **Gottlieb System 1** pinball MPU for the
**GottFA1_PLuS** DIY board. The original Rockwell PPS/4-2 based CPU board and its
peripherals are emulated in VHDL on an Intel/Altera FPGA.

Project page & background: <https://lisy.dev/gottfa1_plus.html>

## Scope

This repository currently contains the variant for **hardware v2.1x** with an
**Intel Cyclone 10 LP `10CL006YE144C8G`** FPGA. Further hardware/FPGA variants may
be added later as sibling directories.

## Layout

| Directory                      | Contents                                                                 |
| ------------------------------ | ------------------------------------------------------------------------ |
| `GottFA1_PLuS_HW21x_Cyclone10` | Quartus project (top entity `SYS1`): `*.qpf`, `*.qsf`, `*.sdc`, `SYS1.vhd` |
| `lib_common`                   | Shared VHDL: PPS/4-2 & T65 CPU cores, RIOT R6530, display/switch/solenoid logic, SD card, EEPROM, DFPlayer sound |
| `lib_cyclone_10`               | Cyclone-10 specific Intel IP (ROM/RAM megafunctions: `*.qip` / `*.vhd` / `*.cmp`) |

> **Note:** `SYS1.qsf` references the libraries via relative paths
> (`../lib_common`, `../lib_cyclone_10`). Keep the three directories as siblings.

## Build & flash

1. Install **Quartus Prime Lite 22.1**.
2. Open `GottFA1_PLuS_HW21x_Cyclone10/SYS1.qpf` and run a full compilation.
3. Program the generated bitstream into the board's EPCS16 configuration device.

Build artifacts (`db/`, `output_files/`, …) are intentionally not tracked; the
generated programming files are produced locally by the Quartus compile.

## License

Released under the **GNU General Public License v3.0** — see [`LICENSE`](LICENSE).

© bontango
