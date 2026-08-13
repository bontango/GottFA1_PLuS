# GottFA1_PLuS

FPGA reimplementation of the **Gottlieb System 1** pinball MPU for the
**GottFA1_PLuS** DIY board. The original Rockwell PPS/4-2 based CPU board and its
peripherals are emulated in VHDL on an Intel/Altera FPGA.

Project page & background: <https://lisy.dev/gottfa1_plus.html>

## Board variants

All variants are built from **one shared source tree**: a single top level, one set
of modules, one `.sdc`. A board differs only in its pin assignment, its FPGA and a
board id — nothing else.

| Variant | Board | FPGA | Board id | Version shown |
|---|---|---|---|---|
| `hw21x_cyclone_10` | hardware v2.1x | `10CL006YE144C8G` (Cyclone 10 LP) | 9 | `V 903` |
| `hw21x_cyclone_iv_v4` | hardware v2.1x | `EP4CE6E22C8` (Cyclone IV E, 144-EQFP) | 8 | `V 803` |
| `hw20x_cyclone_iv_v4` | hardware v2.0x | `EP4CE6E22C8` (Cyclone IV E, 144-EQFP) | 7 | `V 703` |
| `hw21x_cyclone_iv_v3` | hardware v2.1x | `EP4CE6F17C8` (Cyclone IV E, 256-FBGA) | 6 | `V 603` |

The boot display shows `V <board id><software version>`. The **board id** lives in
`variants/<name>/variant_pkg.vhd`, the **software version** in
`rtl/common/version_pkg.vhd` — one release changes exactly one number and every board
follows.

Hardware v2.0x additionally carries `LED_Test` and a CH340 USB serial header
(`USB_Rx` / `USB_Tx`). Those ports stay in the shared top level and are marked
`VIRTUAL_PIN` on the v2.1x boards.

## Layout

| Directory | Contents |
|---|---|
| `top/` | `SYS1.vhd` — the single top level entity |
| `rtl/common/` | Shared VHDL: PPS/4-2 & T65 CPU cores, RIOT R6530, display/switch/solenoid logic, SD card, EEPROM, DFPlayer sound, `version_pkg.vhd`, `SYS1.sdc` |
| `rtl/cyclone_10/`, `rtl/cyclone_iv/` | Intel IP per FPGA family (ROM/RAM megafunctions). Same entity names, same port lists — the `.qsf` picks one |
| `variants/<name>/` | Per board: `variant_pkg.vhd`, `variant.psd1`, `device.tcl`, `pins.tcl`, `SYS1.qpf`, `SYS1.cof`, and the **generated** `SYS1.qsf` |
| `scripts/` | `gen_qsf.ps1`, `check.ps1`, `build.ps1`, `release.ps1`, `baseline.csv` and the `.tcl` fragments |
| `docs/` | `Hardware.md` (hardware reference), `WORKFLOW.md` (how to work in this tree) |
| `bin/` | Released programming files per board |

> **`variants/<name>/SYS1.qsf` is generated.** Do not edit it — change `pins.tcl`,
> `device.tcl`, `variant.psd1` or the file lists under `scripts/` and rerun
> `gen_qsf.ps1`. Quartus writes into the file by itself once the project has been
> open in the IDE, which is why the build scripts regenerate it first.

## Build

Requires **Quartus Prime Lite 22.1std.2** (all four variants build with it — two chip
families do not mean two Quartus versions here).

```powershell
# Analysis & synthesis of every variant - fast, catches syntax and elaboration errors
.\scripts\check.ps1

# Full: fitter + timing, compared against scripts\baseline.csv
.\scripts\check.ps1 -Fit

# Build one variant including the .jic for the EPCS16 configuration device
.\scripts\build.ps1 hw21x_cyclone_10

# Build every board at the same version and copy the artefacts to bin\
.\scripts\release.ps1 -Note "what this release is for"
```

Opening `variants/<name>/SYS1.qpf` in the Quartus IDE works as usual; just rerun
`gen_qsf.ps1` afterwards, or let `check.ps1` / `build.ps1` do it.

Build artifacts (`db/`, `output_files/`, …) are not tracked.

See [`docs/WORKFLOW.md`](docs/WORKFLOW.md) for what to change where, how the baseline
check works and the pitfalls that have already bitten here.

## License

Released under the **GNU General Public License v3.0** — see [`LICENSE`](LICENSE).

© bontango
