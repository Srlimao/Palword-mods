# Accessory Toggler

A client-side UI/Lua mod for Palworld that lets you instantly equip or unequip accessories (like the Ring of Mercy or thermal underwear) using hotkeys, without opening your inventory. Includes a customizable on-screen status HUD.

---

## Key Features

- **Quick Hotkey Swapping**: Toggle accessory slots 1 to 4 instantly using hotkeys (Default: `5`, `6`, `7`, and `8`).
- **Status HUD**: A clean, non-intrusive on-screen overlay displaying equipped accessories and their active status.
- **Interactive HUD Edit Mode**: Press **Alt + F7** to edit. Use Arrow Keys to move the HUD, `+` / `-` to scale it, and **Alt + R** to reset it.
- **Configuration Reload**: Press **Alt + R** outside edit mode to reload settings instantly from the configuration file.
- **Auto State-Saving**: Remembers your HUD position, scale, and disabled status across game sessions.
- **Localization**: Displays accessory names automatically in your game's language.

---

## In-Game Controls

- **5, 6, 7, 8**: Toggle Accessory Slots 1, 2, 3, 4.
- **Alt + F7**: Toggle HUD Edit Mode.
- **Alt + R**: Reset HUD position (in Edit Mode) or Reload configuration (outside Edit Mode).
- **Arrow Keys**: Move HUD (in Edit Mode).
- **+ / -**: Scale HUD (in Edit Mode).

---

## Requirements

- **UE4SS** (v3.0.0 or higher / compatible with the latest Palworld version)

---

## Installation (Manual)

1. Extract the `AccessoryToggler` folder into your game's UE4SS Mods folder:
   `...\UE4SS\Mods\`
2. Open `...\UE4SS\Mods\mods.txt` and add the following line at the bottom:
   `AccessoryToggler : 1`
3. Save `mods.txt` and launch the game.

---

## Configuration Path

- `%USERPROFILE%\Documents\My Games\Palworld\ModConfigs\AccessoryToggler\config.json`
*(Generated automatically on first load)*

---

## Chinese Description

饰品快捷装备切换模组，无需打开背包，即可使用快捷键瞬间装备或卸下饰品（如慈悲戒指、抗寒/抗热内衣）。包含游戏内状态 HUD 悬浮窗。

### 主要功能

- **快捷键切换**：使用快捷键瞬间切换饰品栏 1 到 4（默认快捷键：`5`、`6`、`7`、`8`）。
- **状态 HUD**：在屏幕上显示当前装备的饰品及其启用/禁用状态。
- **HUD 交互式调整模式**：按 **Alt + F7** 进入编辑模式，使用方向键移动 HUD，使用 `+` / `-` 调整大小，按 **Alt + R** 恢复默认位置。
- **配置重载**：在非编辑模式下按 **Alt + R** 从配置文件重载设置。
- **自动状态保存**：跨存档或重启自动记忆 HUD 的位置、缩放比例和饰品状态。
- **多语言支持**：根据游戏语言自动读取饰品中文名称。

### 快捷键

- **5, 6, 7, 8**：切换饰品栏 1、2、3、4。
- **Alt + F7**：开启/关闭 HUD 编辑模式。
- **Alt + R**：恢复 HUD 默认位置（编辑模式下）/ 重新加载配置（普通模式下）。
- **方向键**：移动 HUD 位置（编辑模式下）。
- **+ / -**：缩放 HUD 大小（编辑模式下）。

### 配置文件路径

- `%USERPROFILE%\Documents\My Games\Palworld\ModConfigs\AccessoryToggler\config.json`