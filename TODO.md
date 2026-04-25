# TODO — Maurer-Script: independência total do Helper-Script

Objetivo: `Maurer-Script/` funcionar sem qualquer ficheiro do `Helper-Script/` instalado na printer.

---

## Dependências runtime ainda por resolver

### 1. `beep.mp3`
- **Usado por**: `Maurer-Script/buzzer-support.cfg`
- **Caminho actual**: `aplay /usr/data/helper-script/files/buzzer-support/beep.mp3`
- **O que fazer**:
  - [ ] Copiar `Helper-Script/files/buzzer-support/beep.mp3` → `Maurer-Script/assets/beep.mp3`
  - [ ] Atualizar caminho em `buzzer-support.cfg` para `/usr/data/printer_data/config/Maurer-Script/assets/beep.mp3`

### 2. `useful_macros.sh`
- **Usado por**: `Maurer-Script/useful-macros.cfg` (backup/restore Klipper + Moonraker)
- **Caminho actual**: `/usr/data/helper-script/files/scripts/useful_macros.sh`
- **O que fazer**:
  - [ ] Criar `Maurer-Script/scripts/useful_macros.sh` — copiar o conteúdo do original (é simples: só tar backup/restore + reload camera)
  - [ ] Atualizar os 5 `[gcode_shell_command]` em `useful-macros.cfg` para o novo caminho
  - [ ] O script precisará de `chmod +x` no deploy

### 3. `guppy-update.sh`
- **Usado por**: `Maurer-Script/guppy-update.cfg`
- **Caminho actual**: `/usr/data/helper-script/files/guppy-screen/guppy-update.sh`
- **Dependência extra**: o script usa `/usr/data/helper-script/files/fixes/curl` (binário curl customizado do Helper-Script)
- **O que fazer**:
  - [ ] Avaliar se `curl` do sistema (`/usr/bin/curl`) funciona na K1 — se sim, não precisa de curl externo
  - [ ] Criar `Maurer-Script/scripts/guppy-update.sh` com o curl correto
  - [ ] Atualizar caminho em `guppy-update.cfg`

---

## Deploy / instalação

Atualmente não há forma automatizada de copiar os ficheiros de `Maurer-Script/` para a printer.  
O Helper-Script faz isso via `helper.sh` + scripts bash. Precisamos do equivalente.

- [ ] Criar `Maurer-Script/install.sh` — script de deploy que:
  - Copia `scripts/*.sh` para `/usr/data/printer_data/config/Maurer-Script/scripts/`
  - Copia `assets/beep.mp3` para o destino correto
  - Faz `chmod +x` em todos os `.sh` e `.py`
  - Cria `variables.cfg` se não existir
  - Recarrega Klipper no fim

---

## Limpeza final (depois dos pontos acima resolvidos)

- [ ] Verificar que nenhum ficheiro em `Maurer-Script/` aponta para caminhos `/usr/data/helper-script/`
- [ ] `printer.cfg`: confirmar que `Helper-Script/timelapse.cfg` é a única inclusão upstream restante
- [ ] Atualizar AGENTS.md: remover menção a dependências runtime do Helper-Script

---

## Estado atual das pastas

| Pasta | Estado |
|---|---|
| `Maurer-Script/*.cfg` | ✅ Todos criados e incluídos em printer.cfg |
| `Maurer-Script/KAMP/` | ✅ Criado, independente |
| `Maurer-Script/scripts/*.py` | ✅ Copiados de GuppyScreen/scripts/ |
| `Maurer-Script/scripts/useful_macros.sh` | ❌ Ainda do Helper-Script |
| `Maurer-Script/scripts/guppy-update.sh` | ❌ Ainda do Helper-Script |
| `Maurer-Script/assets/beep.mp3` | ❌ Ainda do Helper-Script |
| `Helper-Script/timelapse.cfg` | ⚠️ Mantido intencionalmente (biblioteca terceiros) |
