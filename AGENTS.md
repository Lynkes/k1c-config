# K1C Klipper Config — Agent Instructions

## Project Overview

Klipper firmware configuration for a **Creality K1C** FDM 3D printer.  
Print area: 220×220×250 mm. No build system — changes are deployed by copying files to the printer.

## Hardware

| MCU alias | Chip | Role |
|---|---|---|
| `mcu` | GD32F303RET6 | Main controller |
| `nozzle_mcu` | GD32F303CBT6 | Nozzle heater + model/throat fans |
| `leveling_mcu` | GD32E230F8P6 | Bed leveling probe |
| `rpi` | Host MCU | I2C (EEPROM), camera, shell commands |

Printer serial paths: main `/dev/ttyS7`, nozzle `/dev/ttyS1`, leveling `/dev/ttyS9`.

## Config Structure

Entry point is [`config/printer.cfg`](config/printer.cfg) — all other files are loaded via `[include]`.

| Path | Purpose |
|---|---|
| `config/printer_params.cfg` | Hardware limits, default temps, bed dimensions |
| `config/gcode_macro.cfg` | Core macros; `PRINTER_PARAM` is the global variable store |
| `config/sensorless.cfg` | Sensorless homing state machine |
| `config/box.cfg` | Resonance/chamber config |
| `config/moonraker.conf` | Moonraker API server |
| `config/Maurer-Script/` | **All user customisations live here** — owns fans, macros, GuppyScreen commands, resonance workflow, etc. |
| `config/Helper-Script/` | Creality Helper Script macros (upstream: [Guilouz/Creality-Helper-Script](https://github.com/Guilouz/Creality-Helper-Script)) — **read-only, do not modify** |
| `config/Helper-Script/timelapse.cfg` | Exception: upstream timelapse library included directly (DO NOT CHANGE ANY MACRO) |
| `config/Helper-Script/KAMP/` | KAMP adaptive meshing & purging; settings hub: `KAMP_Settings.cfg` |
| `config/GuppyScreen/` | GuppyScreen touchscreen UI — **read-only**; Python scripts in `scripts/` are referenced by absolute path |

## Key Conventions

**Customised vs upstream files**  
All user customisations live in `config/Maurer-Script/`. The upstream folders (`Helper-Script/`, `GuppyScreen/`) are read-only — do not modify them directly.  
Exception: `Helper-Script/KAMP/KAMP_Settings.cfg` is the designated settings hub for KAMP tuning — editing it directly is intentional.  
User-customised lines within shared files are marked with `# #Maurer` inline comments.

**Global state (`PRINTER_PARAM`)**  
The `[gcode_macro PRINTER_PARAM]` in `gcode_macro.cfg` holds printer-wide variables (max positions, fan min-PWM thresholds, hotend temp cache, etc.). Read state via `printer['gcode_macro PRINTER_PARAM'].<var>`.

**Fan addressing**  
Use the `P` parameter in `M106`/`M107` to select the fan:
- `P0` — model cooling fan (`nozzle_mcu`)
- `P1` — electronics/backplane fan
- `P2` — aux/chamber fan (minimum PWM: `fan2_min: 180`)

`duplicate_pin_override` in `fans-control-Maurer.cfg` is required because some pins are referenced by multiple sections — do not remove it.

**User-facing confirmation dialogs**  
Macros that perform destructive or irreversible actions use Mainsail/Fluidd prompt actions:
```gcode
RESPOND TYPE=command MSG="action:prompt_begin <title>"
RESPOND TYPE=command MSG="action:prompt_text <message>"
RESPOND TYPE=command MSG="action:prompt_footer_button CANCEL|RESPOND TYPE=command MSG="action:prompt_end"|error"
RESPOND TYPE=command MSG="action:prompt_footer_button CONFIRM|_INTERNAL_MACRO|primary"
RESPOND TYPE=command MSG="action:prompt_show"
```
The real work goes in a private `_MACRO_NAME` helper; the public macro only shows the dialog.

**KAMP settings**  
All KAMP tuning (purge amount, mesh margin, park height, etc.) is done exclusively in [`config/Helper-Script/KAMP/KAMP_Settings.cfg`](config/Helper-Script/KAMP/KAMP_Settings.cfg) via the `_KAMP_Settings` macro variables.

## Deployment

There is no build or test step. To apply changes:
1. Copy modified files to `/usr/data/printer_data/config/` on the printer (via SSH or Mainsail file upload).
2. Issue `FIRMWARE_RESTART` from the Mainsail/Fluidd console, or use the restart button.

Shell commands on the printer run from `/usr/data/helper-script/files/scripts/`.

## Common Pitfalls

- **Duplicate `[include]` entries in `printer.cfg`**: `sensorless.cfg`, `gcode_macro.cfg`, and `printer_params.cfg` are included twice in the current file — this is a known quirk; Klipper deduplicates them but avoid adding more.
- **`[respond]` needed for KAMP**: The `[respond]` section must be active for KAMP macros to output status messages. It is declared in `fans-control-Maurer.cfg` and `KAMP_Settings.cfg`.
- **Chinese comments**: Some upstream Creality files contain Chinese comments — this is expected, do not remove them.
- **`FORCE_MOVE` requires `enable_force_move: true`**: Set in `sensorless.cfg`; needed for the Z-homing safety move.
