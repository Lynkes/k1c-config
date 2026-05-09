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
| `config/sensorless.cfg` | Sensorless homing state machine — **user-editable** (not upstream read-only) |
| `config/box.cfg` | Resonance/chamber config |
| `config/moonraker.conf` | Moonraker API server |
| `config/Maurer-Script/` | **All user customisations live here** — owns fans, macros, GuppyScreen commands, resonance workflow, etc. |
| `config/Helper-Script/` | Creality Helper Script macros (upstream: [Guilouz/Creality-Helper-Script](https://github.com/Guilouz/Creality-Helper-Script)) — **read-only, do not modify** |
| `config/Helper-Script/timelapse.cfg` | Exception: upstream timelapse library included directly (DO NOT CHANGE ANY MACRO) |
| `config/Helper-Script/KAMP/` | Upstream KAMP — **read-only**; não incluído em `printer.cfg` |
| `config/Maurer-Script/KAMP/` | KAMP com todas as nossas customizações; settings hub: `KAMP_Settings.cfg` |
| `config/Maurer-Script/scripts/` | Scripts Python de resonância (`calibrate_shaper.py`, `graph_belts.py`, etc.) — copiados do GuppyScreen |
| `config/GuppyScreen/` | GuppyScreen touchscreen UI — **read-only**; scripts já copiados para `Maurer-Script/scripts/` |

## Key Conventions

**Customised vs upstream files**  
All user customisations live in `config/Maurer-Script/`. The upstream folders (`Helper-Script/`, `GuppyScreen/`) are read-only — do not modify them directly.  
Exception: `Helper-Script/timelapse.cfg` é o único include upstream que permanece em `printer.cfg` (biblioteca de terceiros, "DO NOT CHANGE ANY MACRO").  
`Maurer-Script/KAMP/KAMP_Settings.cfg` é o settings hub para KAMP — editar aqui, nunca em `Helper-Script/KAMP/`.  
User-customised lines within shared files are marked with `# #Maurer` inline comments.

**Global state (`PRINTER_PARAM`)**  
The `[gcode_macro PRINTER_PARAM]` in `gcode_macro.cfg` holds printer-wide variables (max positions, fan min-PWM thresholds, hotend temp cache, etc.). Read state via `printer['gcode_macro PRINTER_PARAM'].<var>`.  
`PRINTER_PARAM` is the **single source of truth** for bed dimensions (`max_x_position: 220`, `max_y_position: 220`, `max_z_position: 250`). The old `[gcode_macro product_param]` has been removed — do not re-add it.

**Fan addressing**  
Use the `P` parameter in `M106`/`M107` to select the fan:
- `P0` — model cooling fan (`nozzle_mcu`)
- `P1` — electronics/backplane fan
- `P2` — aux/chamber fan (minimum PWM: `fan2_min: 180`)

`duplicate_pin_override` in `Maurer-Script/fans-control.cfg` is required because some pins are referenced by multiple sections — do not remove it.

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
All KAMP tuning (purge amount, mesh margin, park height, etc.) is done exclusively in [`config/Maurer-Script/KAMP/KAMP_Settings.cfg`](config/Maurer-Script/KAMP/KAMP_Settings.cfg) via the `_KAMP_Settings` macro variables. O ficheiro `Helper-Script/KAMP/KAMP_Settings.cfg` existe no disco mas **não é incluído** — não editar.

**Sensorless homing sequence (`sensorless.cfg`)**  
The `[homing_override]` runs a **double-pass X→Y→X→Y** before homing Z. The first X→Y clears any mechanical slack; the second X→Y gives a clean reference after the axes have settled. State is tracked via `xyz_ready` flags in `PRINTER_PARAM` (`x_ready`, `y_ready`, `z_ready`). Always reset these flags when restarting or when homing fails mid-sequence.

**Inline comment language**  
All user-added inline comments in macros (`sensorless.cfg`, `gcode_macro.cfg`, `Maurer-Script/`) are written in **Portuguese (PT-BR)**. Do not switch to English when adding or editing comments in these files.

## Deployment

There is no build or test step. To apply changes:
1. Copy modified files to `/usr/data/printer_data/config/` on the printer (via SSH or Mainsail file upload).
2. Issue `FIRMWARE_RESTART` from the Mainsail/Fluidd console, or use the restart button.

Shell commands dos nossos macros correm de `/usr/data/printer_data/config/Maurer-Script/scripts/` (Python) e ainda de `/usr/data/helper-script/files/scripts/` para `useful_macros.sh` e `guppy-update.sh` — estas duas são dependências runtime pendentes do Helper-Script (ver [TODO.md](TODO.md)).

## Firmware Build

The `K1_Series_Klipper-main/` folder contains the Creality fork of Klipper source code for the K1 series MCUs. A build script was created at [`K1_Series_Klipper-main/build_k1c.sh`](K1_Series_Klipper-main/build_k1c.sh) to compile all three K1C MCU firmwares from source.

**Chip → defconfig mapping:**

| MCU alias | Chip | Klipper MCU string | Defconfig |
|---|---|---|---|
| `mcu` | GD32F303RET6 @ 120 MHz | `gd32f303xe` (same die, different package) | `K1_mcu0_120_G32_defconfig` |
| `nozzle_mcu` | GD32F303CBT6 @ 120 MHz | `gd32f303xb` (CB = XB package) | `K1_noz0_120_G30_defconfig` |
| `leveling_mcu` | GD32E230F8P6 @ 72 MHz | `gd32e230x8` (F8 = X8 package) | `K1_bed0_110_G21_defconfig` |

**Output binaries** are written to `K1_Series_Klipper-main/fw/K1/` with Creality's naming scheme (`mcu0_120_G32-mcu0_004_000.bin`, etc.).

**Build requirements (WSL/Linux):** `gcc-arm-none-eabi`, `python3`, `make`.

```bash
sudo apt install -y gcc-arm-none-eabi python3 make
cd /mnt/c/GIT/k1c-config/K1_Series_Klipper-main
bash build_k1c.sh
```

The Makefile already enables LTO (`-flto -fwhole-program`) and dead-code elimination (`-ffunction-sections -fdata-sections -Wl,--gc-sections`) at `-O2`.

## Common Pitfalls

- **Duplicate `[include]` entries in `printer.cfg`**: `sensorless.cfg`, `gcode_macro.cfg`, and `printer_params.cfg` are included twice in the current file — this is a known quirk; Klipper deduplicates them but avoid adding more.
- **`[respond]` needed for KAMP**: The `[respond]` section must be active for KAMP macros to output status messages. It is declared in `fans-control-Maurer.cfg` and `KAMP_Settings.cfg`.
- **Chinese comments**: Some upstream Creality files contain Chinese comments — this is expected, do not remove them.
- **`FORCE_MOVE` requires `enable_force_move: true`**: Set in `sensorless.cfg`; needed for the Z-homing safety move.
- **`fan0_pin` duplicate in `[fan_feedback]`** (`printer_params.cfg`): two `fan0_pin` lines exist (PB3 model fan, PB4 throat fan) — Klipper silently uses only the last one (PB4). This is a Creality quirk; do not attempt to fix it as `[fan_feedback]` is a proprietary module.
- **`homing_speed` only affects `G28`**: The `homing_speed: 20` in `[stepper_x/y]` controls the StallGuard detection move speed only. `G1` moves inside macros (e.g. park/approach) use their own `F` values and are independent.
- **Creality firmware builtins** — the following commands are compiled into the firmware and **cannot be redefined** in `.cfg` files: `CX_ROUGH_G28`, `CX_NOZZLE_CLEAR`, `CX_PRINT_DRAW_ONE_LINE`, `CX_PRINT_LEVELING_CALIBRATION`, `ACCURATE_G28`, `ACCURATE_HOME_Z`, `WAIT_TEMP_END`, `PRINT_PREPARE_CLEAR`. `ACCURATE_HOME_Z` performs a slow double-tap Z probe (multi-sample average via prtouch_v2) and is called after heat soak for precision homing.
- **Bed center for Z probe**: Use `PRINTER_PARAM.max_x_position / 2` = 110 and `max_y_position / 2` = 110 — **not** `stepper_x.position_max / 2` (= 114.5) which includes the endstop mechanical offset beyond the print area.
- **`M107` sem `P` não deve tocar no fan2**: O fan2 (câmara) é independente do ciclo de impressão. `M107` sem parâmetro `P` deve desligar apenas fan0 — fan2 tem ciclo de vida próprio gerido por `M141`/`M191`.
- **Park position X usa `max_x_position - 10`, nunca `+ N`**: O limite físico é 220mm. Qualquer park acima desse valor pode causar erro de limites. Todos os macros de park devem usar `max_x_position - 10.0` (= 210mm).
- **`BED_MESH_PROFILE LOAD` deve sempre ter guard**: Antes de qualquer `BED_MESH_PROFILE LOAD=<nome>`, verificar se o perfil existe com `{% if printer.configfile.config["bed_mesh <nome>"] is defined %}`. Sem isso, G28 e START_PRINT crasham em impressoras sem perfil gravado.
- **`max_accel_to_decel` NÃO está deprecado neste fork**: A Creality mantém `max_accel_to_decel` / `requested_accel_to_decel` activamente em `toolhead.py` para o sistema **Qmode** (modos Silent/Standard/Ultrafast). Não remover nem substituir por `minimum_cruise_ratio`. O valor configurado é `max_accel_to_decel: 12000` em `printer.cfg`.
- **Klipper version**: A impressora corre um fork privado Creality pós-`V1.3.3.5` (hash `09faed31-dirty`). O último tag público é `V1.3.3.5` (commit `b003d41`, Março 2024) no repo `CrealityOfficial/K1_Series_Klipper`.
- **`G29` PROBE_COUNT**: O parâmetro deve ser concatenado com `=`: `'PROBE_COUNT=' + params.PROBE_COUNT`. Sem o `=`, o Klipper recebe `PROBE_COUNT5` em vez de `PROBE_COUNT=5` e ignora o parâmetro.
- **`RESUME` macro reaquece bico**: O `[gcode_macro RESUME]` usa `hotend_temp` guardado em `PRINTER_PARAM` no momento do PAUSE. Se `hotend_temp > extruder.temperature`, bloqueia com `M109`; senão apenas define com `M104`. Não comentar nem remover este bloco — sem ele o bico fica frio no resume.
- **Qmode `SET_GCODE_VARIABLE fan*_value` redundante**: No início do `Qmode`, os três `SET_GCODE_VARIABLE` com `printer['output_pin fan*'].value` (escala 0-1) são imediatamente sobrescritos por `value * 255` mais abaixo. Não re-adicionar essas linhas redundantes.
- **`variable_safe_z` em `xyz_ready` é variável morta**: O safe-Z real do homing vem de `printer["gcode_macro PRINTER_PARAM"].z_safe_g28`. Não re-adicionar `variable_safe_z` à macro `xyz_ready`.
- **Posições em `_HOME_Z` devem usar `|float`**: `printer.toolhead.position.x|int` trunca para inteiro podendo descentrar o probe até ~1mm. Usar sempre `|float` para cálculos de posição contínua.
- **`[save_variables]` aponta para `Maurer-Script/variables.cfg`**: O ficheiro `Helper-Script/variables.cfg` já não é usado. Se a printer nunca arrancou com o novo path, Klipper cria o ficheiro automaticamente. Se já havia z-offset gravado, copiar manualmente antes do restart.
- **Scripts Python de ressonância estão em `Maurer-Script/scripts/`**: `calibrate_shaper.py`, `graph_belts.py`, `shaper_calibrate.py`, `shaper_defs.py` — copiados do `GuppyScreen/scripts/`. Os shell commands em `guppy-cmd.cfg` apontam para este caminho. No deploy, fazer `chmod +x /usr/data/printer_data/config/Maurer-Script/scripts/*.py`.
- **Dependências runtime pendentes do Helper-Script** (ver TODO.md): `beep.mp3` (buzzer), `useful_macros.sh` (backup/restore), `guppy-update.sh` (update GuppyScreen). Enquanto não forem migradas, o Helper-Script precisa de estar instalado na printer para estes macros funcionarem.
