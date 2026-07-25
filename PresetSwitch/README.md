# PresetSwitch - Palworld Remote Pal Preset Switcher (UE4SS)

**PresetSwitch** is a high-performance, UI-free UE4SS Lua mod for Palworld that enables instant remote switching across native in-game Pal presets using configurable hotkeys (**Alt+5**, **Alt+6**, **Alt+7**, **Alt+8**, **Alt+9**).

---

## Key Features

- ⚡ **Zero UI Interruption**: Switches Pal presets remotely without opening the Pal Box or interrupting gameplay, movement, or combat.
- 🎮 **Native In-Game Presets**: Integrates directly with Palworld's native in-game preset memory (`Local_OtomoLoadoutSaveData`).
- ⌨️ **Fully Configurable Keybinds**: Remap hotkeys for Presets 1 through 5 and customize global modifiers (**ALT**, **CTRL**, **SHIFT**, or **NONE**).
- ⚙️ **Standard AppData Configuration**: Saved directly to `%LOCALAPPDATA%\Pal\Saved\Mods\PresetSwitch\config.json` for full compatibility with `ModConfigurator`.
- 🎨 **Sleek HUD Toast Notifications**: On-screen popup notification confirms active preset slot and preset name.

---

## Default Keybindings

| Action | Default Hotkey | Configurable Key |
| :--- | :--- | :--- |
| **Switch to Preset 1** | `ALT + 5` | `KeyBinds.SwitchPreset1` |
| **Switch to Preset 2** | `ALT + 6` | `KeyBinds.SwitchPreset2` |
| **Switch to Preset 3** | `ALT + 7` | `KeyBinds.SwitchPreset3` |
| **Switch to Preset 4** | `ALT + 8` | `KeyBinds.SwitchPreset4` |
| **Switch to Preset 5** | `ALT + 9` | `KeyBinds.SwitchPreset5` |

---

## Configuration (`config.json`)

Primary configuration file path: `%LOCALAPPDATA%\Pal\Saved\Mods\PresetSwitch\config.json`

```json
{
  "Enabled": true,
  "Debug": false,
  "KeyBinds": {
    "Modifier": "ALT",
    "SwitchPreset1": "FIVE",
    "SwitchPreset2": "SIX",
    "SwitchPreset3": "SEVEN",
    "SwitchPreset4": "EIGHT",
    "SwitchPreset5": "NINE"
  }
}
```

### Supported Global Modifiers
- `"ALT"` (Default)
- `"CTRL"`
- `"SHIFT"`
- `"NONE"` (No modifier required)

---

## Installation

1. Copy the `PresetSwitch` folder into your Palworld UE4SS `Mods` directory:
   `Palworld\Pal\Binaries\Win64\Mods\PresetSwitch\`
2. Ensure UE4SS is enabled in `mods.txt`:
   `PresetSwitch : 1`
3. Launch Palworld!
