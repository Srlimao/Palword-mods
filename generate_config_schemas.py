import os
import re
import json

# Define the rich metadata (descriptions, type overrides, ranges, and options) for each mod configuration option.
METADATA_HUD_LOCATOR = {
    # Global
    "Global": {
        "description": "Global settings for the HUD Locator mod."
    },
    "Global.Enabled": {
        "description": "Enable or disable HUD Locator globally.",
        "type": "boolean"
    },
    "Global.Language": {
        "description": "Language code for the UI labels (e.g. system, en, es, ja, zh-Hans, zh-Hant). 'system' will detect the game language.",
        "type": "enum",
        "options": ["system", "en", "es", "ja", "zh-Hans", "zh-Hant", "fr", "it", "de", "ko", "pt-BR", "ru", "th", "vi", "id", "tr", "pl", "es-MX"]
    },
    "Global.ScanIntervalMs": {
        "description": "Frequency of entity radar sweeps in milliseconds. Lower is more responsive, higher improves performance.",
        "type": "number",
        "min": 500,
        "max": 5000,
        "step": 250
    },
    "Global.Debug": {
        "description": "Show diagnostic messages in the UE4SS log console.",
        "type": "boolean"
    },
    "Global.KeyBinds": {
        "description": "Keybindings for navigating the in-game configuration menu."
    },
    "Global.KeyBinds.Modifier": {
        "description": "Modifier key required for utility shortcuts (ToggleMenu, ResetCoords).",
        "type": "enum",
        "options": ["ALT", "CTRL", "SHIFT", "NONE"]
    },
    "Global.KeyBinds.ToggleMenu": {
        "description": "Hotkey to toggle the configuration menu overlay (requires the configured Modifier).",
        "type": "keybind"
    },
    "Global.KeyBinds.ToggleEditMode": {
        "description": "Hotkey to toggle the interactive HUD repositioning mode.",
        "type": "keybind"
    },
    "Global.KeyBinds.ResetCoords": {
        "description": "Hotkey to reset HUD coordinates back to default position in edit mode.",
        "type": "keybind"
    },
    "Global.KeyBinds.MenuUp": {
        "description": "Hotkey to navigate up the configuration menu list.",
        "type": "keybind"
    },
    "Global.KeyBinds.MenuDown": {
        "description": "Hotkey to navigate down the configuration menu list.",
        "type": "keybind"
    },
    "Global.KeyBinds.MenuLeft": {
        "description": "Hotkey to decrease option values or navigate left.",
        "type": "keybind"
    },
    "Global.KeyBinds.MenuRight": {
        "description": "Hotkey to increase option values or navigate right.",
        "type": "keybind"
    },
    
    # Categories (Players, Relics, Chests, Eggs, Caves, Loot, Notes, Pals)
    "Players": { "description": "Configure tracking overlay for other Players." },
    "Relics": { "description": "Configure tracking overlay for Lifmunk Relics." },
    "Chests": { "description": "Configure tracking overlay for Treasure Chests." },
    "Eggs": { "description": "Configure tracking overlay for Pal Eggs." },
    "Caves": { "description": "Configure tracking overlay for Dungeon/Cave entrances." },
    "Loot": { "description": "Configure tracking overlay for dropped ground items." },
    "Notes": { "description": "Configure tracking overlay for Memo Journals / Notes." },
    "Pals": { "description": "Configure tracking overlay for Wild / Boss / Shiny Pals." },
    
    "Players.Enabled": { "description": "Show other players on HUD.", "type": "boolean" },
    "Players.MaxDistance": { "description": "Maximum tracking range for players (cm).", "type": "number", "min": 1000, "max": 100000, "step": 1000 },
    "Players.GraceRadiusM": { "description": "Radius (meters) within which player names are hidden to avoid screen clutter.", "type": "number", "min": 0, "max": 100, "step": 5 },
    
    "Relics.Enabled": { "description": "Show Lifmunk Relics on HUD.", "type": "boolean" },
    "Relics.MaxDistance": { "description": "Maximum tracking range for relics (cm).", "type": "number", "min": 1000, "max": 100000, "step": 1000 },
    
    "Chests.Enabled": { "description": "Show chests on HUD.", "type": "boolean" },
    "Chests.Filter": { "description": "Filter which chests to track: Both, Chests (locked/rare only), or Junk (common items).", "type": "enum", "options": ["Both", "Chests", "Junk"] },
    "Chests.GradeFilter": { "description": "Filter chests by tier/grade (All, Grade2+, Grade3+, Grade4+, Grade5+, Grade6Only, None).", "type": "enum", "options": ["All", "Grade2+", "Grade3+", "Grade4+", "Grade5+", "Grade6Only", "None"] },
    "Chests.MaxDistance": { "description": "Maximum tracking range for chests (cm).", "type": "number", "min": 1000, "max": 100000, "step": 1000 },
    
    "Eggs.Filter": { "description": "Filter which eggs to track: All, Large+ (Large, Huge), HugeOnly, or None.", "type": "enum", "options": ["All", "Large+", "HugeOnly", "None"] },
    "Eggs.MaxDistance": { "description": "Maximum tracking range for Pal eggs (cm).", "type": "number", "min": 1000, "max": 100000, "step": 1000 },
    
    "Caves.Enabled": { "description": "Show dungeons/caves on HUD.", "type": "boolean" },
    "Caves.MaxDistance": { "description": "Maximum tracking range for caves (cm).", "type": "number", "min": 1000, "max": 100000, "step": 1000 },
    
    "Loot.Enabled": { "description": "Show dropped ground items on HUD.", "type": "boolean" },
    "Loot.Filters": { "description": "Whitelist of item names or IDs to show (leave empty to show all dropped items).", "type": "array" },
    "Loot.MaxDistance": { "description": "Maximum tracking range for dropped loot (cm).", "type": "number", "min": 1000, "max": 100000, "step": 1000 },
    
    "Notes.Enabled": { "description": "Show Memo Journals/Notes on HUD.", "type": "boolean" },
    "Notes.MaxDistance": { "description": "Maximum tracking range for notes (cm).", "type": "number", "min": 1000, "max": 100000, "step": 1000 },

    "Pals.Enabled": { "description": "Show Pals on HUD.", "type": "boolean" },
    "Pals.MaxDistance": { "description": "Maximum tracking range for Pals (cm).", "type": "number", "min": 1000, "max": 100000, "step": 1000 },
    "Pals.FilterMode": { "description": "Filtering mode for Pal radar (AllPals, BossOnly, ShinyOnly, TrackerListOnly, PassivesThreshold).", "type": "enum", "options": ["AllPals", "BossOnly", "ShinyOnly", "TrackerListOnly", "PassivesThreshold"] },
    "Pals.ShowPassives": { "description": "Display passive skill names on the Pal HUD tag.", "type": "boolean" },
    "Pals.ShowOnlyMatchedPassives": { "description": "Display only the passive skills that matched tracking criteria.", "type": "boolean" },
    "Pals.ShowLevel": { "description": "Display Pal character level on the HUD tag.", "type": "boolean" },
    "Pals.IncludeOwned": { "description": "Include player-owned Pals and base camp workers in tracking.", "type": "boolean" },
    "Pals.TrackerPals": { "description": "List of specific Pals and passive criteria to track. Use '*' or empty palname to track any species with desired passives.", "type": "array" },

    "Completionist": { "description": "Configure regional collectables and progress tracker HUD card." },
    "Completionist.Enabled": { "description": "Enable scanning for regional completion data.", "type": "boolean" },
    "Completionist.ShowHUDTracker": { "description": "Display the active region progress tracker card on the HUD.", "type": "boolean" },
    "Completionist.ShowInMenu": { "description": "Show the regional completionist overview in the menu.", "type": "boolean" },
    "Completionist.AutoHighlightRegion": { "description": "Automatically detect and highlight the current world region.", "type": "boolean" },
    "Completionist.HUDAnchor": {
        "description": "Preset screen position anchor for the HUD progress tracker card.",
        "type": "enum",
        "options": ["TopRight", "TopLeft", "BottomRight", "BottomLeft", "Custom"]
    },
    "Completionist.HUDX": {
        "description": "Manual horizontal coordinate of the tracker card as a percentage of screen width (0 to 100).",
        "type": "number",
        "min": 0,
        "max": 100,
        "step": 0.1
    },
    "Completionist.HUDY": {
        "description": "Manual vertical coordinate of the tracker card as a percentage of screen height (0 to 100).",
        "type": "number",
        "min": 0,
        "max": 100,
        "step": 0.1
    },
    "Completionist.HUDScale": {
        "description": "Scale factor for the HUD progress tracker card.",
        "type": "number",
        "min": 0.5,
        "max": 2.0,
        "step": 0.05
    }
}

# Add common Category Style fields recursively to avoid boilerplate
for category in ["Players", "Relics", "Chests", "Eggs", "Caves", "Loot", "Notes", "Pals"]:
    METADATA_HUD_LOCATOR[f"{category}.Style"] = { "description": "Style customization for this category's overlay widgets." }
    METADATA_HUD_LOCATOR[f"{category}.Style.DrawBox"] = { "description": "Draw a background border box around the label.", "type": "boolean" }
    METADATA_HUD_LOCATOR[f"{category}.Style.FontScale"] = { "description": "Font size multiplier for the main label text.", "type": "number", "min": 0.5, "max": 3.0, "step": 0.1 }
    METADATA_HUD_LOCATOR[f"{category}.Style.SmallFontScale"] = { "description": "Font size multiplier for sub-text (e.g. distance/details).", "type": "number", "min": 0.5, "max": 3.0, "step": 0.1 }
    METADATA_HUD_LOCATOR[f"{category}.Style.TextOffsetZ"] = { "description": "Vertical offset (units) above the entity to position the HUD tag.", "type": "number", "min": -200, "max": 500, "step": 10 }
    METADATA_HUD_LOCATOR[f"{category}.Style.NameColor"] = { "description": "RGBA color of the name / label text.", "type": "color" }
    METADATA_HUD_LOCATOR[f"{category}.Style.DistColor"] = { "description": "RGBA color of the distance / details text.", "type": "color" }
    METADATA_HUD_LOCATOR[f"{category}.Style.BoxColor"] = { "description": "RGBA background fill color of the bounding box.", "type": "color" }
    METADATA_HUD_LOCATOR[f"{category}.Style.BorderColor"] = { "description": "RGBA border outline color of the bounding box.", "type": "color" }
    METADATA_HUD_LOCATOR[f"{category}.Style.BorderWidth"] = { "description": "Border line thickness.", "type": "number", "min": 0.5, "max": 5.0, "step": 0.1 }
    METADATA_HUD_LOCATOR[f"{category}.Style.BoxPadX"] = { "description": "Horizontal padding inside the bounding box.", "type": "number", "min": 0, "max": 50, "step": 1 }
    METADATA_HUD_LOCATOR[f"{category}.Style.BoxPadY"] = { "description": "Vertical padding inside the bounding box.", "type": "number", "min": 0, "max": 50, "step": 1 }
    METADATA_HUD_LOCATOR[f"{category}.Style.FontCharW"] = { "description": "Font width calibration value.", "type": "number", "min": 1, "max": 20, "step": 0.5 }
    METADATA_HUD_LOCATOR[f"{category}.Style.FontLineH"] = { "description": "Font line height calibration value.", "type": "number", "min": 1, "max": 30, "step": 0.5 }

METADATA_HUD_LOCATOR["Pals.Style.ShinyColor"] = { "description": "RGBA color of Shiny Pal labels.", "type": "color" }
METADATA_HUD_LOCATOR["Pals.Style.BossColor"] = { "description": "RGBA color of Alpha Boss Pal labels.", "type": "color" }
METADATA_HUD_LOCATOR["Pals.Style.UseRarityColors"] = { "description": "Render passive skills in distinct colors according to rarity tier (Gold for Legend/Tier 3, Blue for Tier 2, White for Tier 1, Red for Negative).", "type": "boolean" }


METADATA_ACCESSORY_TOGGLER = {
    "Enabled": {
        "description": "Enable or disable Accessory Toggler globally.",
        "type": "boolean"
    },
    "Language": {
        "description": "Language code for the UI labels (e.g. system, en, es, ja, zh-Hans, zh-Hant). 'system' will detect the game language.",
        "type": "enum",
        "options": ["system", "en", "es", "ja", "zh-Hans", "zh-Hant", "fr", "it", "de", "ko", "pt-BR", "ru", "th", "vi", "id", "tr", "pl", "es-MX"]
    },
    "SlotsToShow": {
        "description": "Number of accessory slots to display on the HUD (1 to 4).",
        "type": "number",
        "min": 1,
        "max": 4,
        "step": 1
    },
    "HUDX": {
        "description": "Manual horizontal coordinate of the display HUD widget as a percentage of screen width (0 to 100). Leave null for auto/drag-and-drop position.",
        "type": "number",
        "min": 0,
        "max": 100,
        "step": 0.1
    },
    "HUDY": {
        "description": "Manual vertical coordinate of the display HUD widget as a percentage of screen height (0 to 100). Leave null for auto/drag-and-drop position.",
        "type": "number",
        "min": 0,
        "max": 100,
        "step": 0.1
    },
    "HUDScale": {
        "description": "Scale factor for the accessory HUD display size.",
        "type": "number",
        "min": 0.5,
        "max": 3.0,
        "step": 0.1
    },
    "ScanIntervalMs": {
        "description": "Interval between checking player accessories (ms).",
        "type": "number",
        "min": 100,
        "max": 5000,
        "step": 100
    },
    "Debug": {
        "description": "Toggle debug diagnostic prints to the UE4SS log console.",
        "type": "boolean"
    },
    "CardBg": { "description": "RGBA color of the HUD widget background panel.", "type": "color" },
    "BorderColor": { "description": "RGBA color of the HUD widget border line.", "type": "color" },
    "ShadowColor": { "description": "RGBA color of the drop shadow effect.", "type": "color" },
    "TextColorEnabled": { "description": "RGBA color of active/enabled slot values.", "type": "color" },
    "TextColorDisabled": { "description": "RGBA color of empty/disabled slot values.", "type": "color" },
    "TextColorLabel": { "description": "RGBA color of category / title labels.", "type": "color" },
    "AccessoryNames": {
        "description": "Dictionary mapping internal game accessory names to readable names shown on the HUD.",
        "type": "map"
    },
    "KeyBinds": {
        "description": "Keybindings for toggling accessory slots and editor mode."
    },
    "KeyBinds.Modifier": {
        "description": "Modifier key required for utility shortcuts (ToggleEditMode, ResetCoords, ToggleUI).",
        "type": "enum",
        "options": ["ALT", "CTRL", "SHIFT", "NONE"]
    },
    "KeyBinds.ToggleSlot1": { "description": "Hotkey to toggle Slot 1 accessory.", "type": "keybind" },
    "KeyBinds.ToggleSlot2": { "description": "Hotkey to toggle Slot 2 accessory.", "type": "keybind" },
    "KeyBinds.ToggleSlot3": { "description": "Hotkey to toggle Slot 3 accessory.", "type": "keybind" },
    "KeyBinds.ToggleSlot4": { "description": "Hotkey to toggle Slot 4 accessory.", "type": "keybind" },
    "KeyBinds.ToggleUI": { "description": "Hotkey to toggle HUD visibility (requires the configured Modifier).", "type": "keybind" },
    "KeyBinds.ToggleEditMode": { "description": "Hotkey to toggle screen-drag UI editor mode (requires the configured Modifier).", "type": "keybind" },
    "KeyBinds.ResetCoords": { "description": "Hotkey to reset HUD coordinates back to default position in edit mode (requires the configured Modifier).", "type": "keybind" }
}

METADATA_HOLD_TO_FIRE = {
    "Enabled": {
        "description": "Enable or disable Hold To Fire globally.",
        "type": "boolean"
    },
    "DebugMode": {
        "description": "Print debug messages to the UE4SS log console.",
        "type": "boolean"
    },
    "ScanIntervalMs": {
        "description": "Interval in milliseconds between equipped weapon changes checks.",
        "type": "number",
        "min": 100,
        "max": 5000,
        "step": 100
    },
    "WeaponTypes": {
        "description": "Toggles autofire functionality per weapon type."
    },
    "WeaponTypes.Handgun": { "description": "Autofire for Handguns.", "type": "boolean" },
    "WeaponTypes.SniperRifle": { "description": "Autofire for Sniper Rifles.", "type": "boolean" },
    "WeaponTypes.Shotgun": { "description": "Autofire for Shotguns.", "type": "boolean" },
    "WeaponTypes.RocketLauncher": { "description": "Autofire for Rocket Launchers.", "type": "boolean" },
    "WeaponTypes.BowGun": { "description": "Autofire for Bows/Crossbows.", "type": "boolean" },
    "WeaponTypes.LaserRifle": { "description": "Autofire for Laser Rifles.", "type": "boolean" },
    "WeaponTypes.MissileLauncher": { "description": "Autofire for Missile Launchers.", "type": "boolean" },
    "WeaponTypes.GrenadeLauncher": { "description": "Autofire for Grenade Launchers.", "type": "boolean" }
}

METADATA_FREECAM = {
    "Debug": {
        "description": "Print debug messages to the UE4SS log console.",
        "type": "boolean"
    },
    "BaseOnly": {
        "description": "Restrict FreeCam mode to inside Base Camp boundaries.",
        "type": "boolean"
    },
    "MaxRange": {
        "description": "Maximum flight distance (meters) from starting position.",
        "type": "number",
        "min": 10.0,
        "max": 500.0,
        "step": 5.0
    },
    "AutoSwitchOnBuild": {
        "description": "Automatically enable FreeCam when selecting a building structure in a Base Camp.",
        "type": "boolean"
    },
    "InputMode": {
        "description": "Select the active control device for FreeCam (Keyboard or Gamepad).",
        "type": "enum",
        "options": ["Keyboard", "Gamepad"]
    },
    "DefaultSpeed": {
        "description": "Default camera flight speed.",
        "type": "number",
        "min": 2.0,
        "max": 150.0,
        "step": 1.0
    },
    "KeyBinds": {
        "description": "Keybindings for controlling the FreeCam mod."
    },
    "KeyBinds.ToggleFreeCam": {
        "description": "Hotkey to manually toggle FreeCam mode (requires the configured Modifier).",
        "type": "keybind"
    },
    "KeyBinds.Modifier": {
        "description": "Modifier key required for the keyboard toggle shortcut.",
        "type": "enum",
        "options": ["ALT", "CTRL", "SHIFT", "NONE"]
    },
    "KeyBinds.FlyUp": {
        "description": "Hotkey to fly upwards.",
        "type": "keybind"
    },
    "KeyBinds.FlyDown": {
        "description": "Hotkey to fly downwards.",
        "type": "keybind"
    },
    "KeyBinds.SpeedUp": {
        "description": "Hotkey to increase camera flight speed.",
        "type": "keybind"
    },
    "KeyBinds.SpeedDown": {
        "description": "Hotkey to decrease camera flight speed.",
        "type": "keybind"
    },
    "Gamepad": {
        "description": "Gamepad input and controller shortcut settings."
    },
    "Gamepad.EnableGamepad": {
        "description": "Enable controller shortcuts to toggle FreeCam mode.",
        "type": "boolean"
    },
    "Gamepad.ModifierButton": {
        "description": "Required modifier button on the controller (e.g. Left Trigger, Right Trigger, or None).",
        "type": "enum",
        "options": ["Gamepad_LeftTrigger", "Gamepad_RightTrigger", "Gamepad_LeftShoulder", "Gamepad_RightShoulder", "None"]
    },
    "Gamepad.ToggleButton": {
        "description": "Gamepad action button to trigger FreeCam toggle.",
        "type": "enum",
        "options": ["Gamepad_Special_Right", "Gamepad_Special_Left", "Gamepad_LeftThumbstick", "Gamepad_RightThumbstick", "Gamepad_FaceButton_Top", "Gamepad_FaceButton_Left"]
    },
    "Gamepad.FlyUpButton": {
        "description": "Gamepad button to fly upwards (R3 / RS click by default).",
        "type": "enum",
        "options": ["Gamepad_RightThumbstick", "Gamepad_LeftThumbstick", "Gamepad_RightShoulder", "Gamepad_LeftShoulder", "Gamepad_FaceButton_Top", "None"]
    },
    "Gamepad.FlyDownButton": {
        "description": "Gamepad button to fly downwards (L3 / LS click by default).",
        "type": "enum",
        "options": ["Gamepad_LeftThumbstick", "Gamepad_RightThumbstick", "Gamepad_LeftShoulder", "Gamepad_RightShoulder", "Gamepad_FaceButton_Bottom", "None"]
    }
}

METADATA_PRESET_SWITCH = {
    "Enabled": {
        "description": "Enable or disable PresetSwitch mod.",
        "type": "boolean"
    },
    "Debug": {
        "description": "Enable diagnostic logging console prints.",
        "type": "boolean"
    },
    "KeyBinds": {
        "description": "Keybindings for switching native in-game Pal presets."
    },
    "KeyBinds.Modifier": {
        "description": "Global modifier key for preset shortcuts (ALT, CTRL, SHIFT, or NONE).",
        "type": "enum",
        "options": ["ALT", "CTRL", "SHIFT", "NONE"]
    },
    "KeyBinds.SwitchPreset1": {
        "description": "Hotkey to switch to Pal Preset 1.",
        "type": "keybind"
    },
    "KeyBinds.SwitchPreset2": {
        "description": "Hotkey to switch to Pal Preset 2.",
        "type": "keybind"
    },
    "KeyBinds.SwitchPreset3": {
        "description": "Hotkey to switch to Pal Preset 3.",
        "type": "keybind"
    },
    "KeyBinds.SwitchPreset4": {
        "description": "Hotkey to switch to Pal Preset 4.",
        "type": "keybind"
    },
    "KeyBinds.SwitchPreset5": {
        "description": "Hotkey to switch to Pal Preset 5.",
        "type": "keybind"
    }
}


# --- Lua Tokenizer and Parser ---

def tokenize_lua(source):
    # Remove single-line comments
    source = re.sub(r'--.*$', '', source, flags=re.MULTILINE)
    
    token_specification = [
        ('STRING_LONG', r'\[\[(.*?)\]\]'),            # [[ string ]]
        ('STRING_DBL', r'"([^"\\]*(?:\\.[^"\\]*)*)"'), # "string"
        ('STRING_SGL', r"'([^'\\]*(?:\\.[^'\\]*)*)'"), # 'string'
        ('NUMBER', r'-?\d+(?:\.\d+)?'),               # integer or float
        ('BOOLEAN', r'\b(?:true|false)\b'),           # true/false
        ('NIL', r'\bnil\b'),                           # nil
        ('IDENTIFIER', r'[a-zA-Z_][a-zA-Z0-9_]*'),     # identifier
        ('SYMBOL', r'[{}==,]'),                        # {, }, =, ,
        ('SKIP', r'[ \t\n\r]+'),                       # whitespace
        ('MISMATCH', r'.'),                            # error fallback
    ]
    
    tok_regex = '|'.join(f'(?P<{name}>{pattern})' for name, pattern in token_specification)
    
    tokens = []
    for mo in re.finditer(tok_regex, source, re.DOTALL):
        kind = mo.lastgroup
        value = mo.group()
        if kind == 'SKIP' or kind == 'MISMATCH':
            continue
        elif kind == 'STRING_LONG':
            tokens.append(('STRING', value[2:-2]))
        elif kind in ('STRING_DBL', 'STRING_SGL'):
            tokens.append(('STRING', value[1:-1]))
        elif kind == 'NUMBER':
            if '.' in value:
                tokens.append(('NUMBER', float(value)))
            else:
                tokens.append(('NUMBER', int(value)))
        elif kind == 'BOOLEAN':
            tokens.append(('BOOLEAN', value == 'true'))
        elif kind == 'NIL':
            tokens.append(('NIL', None))
        else:
            tokens.append((kind, value))
    return tokens

def parse_table_value(tokens, index):
    tok_type, tok_val = tokens[index]
    if tok_type in ('BOOLEAN', 'NUMBER', 'STRING', 'NIL'):
        return tok_val, index + 1
    elif tok_type == 'SYMBOL' and tok_val == '{':
        table = {}
        array_index = 1
        index += 1
        while index < len(tokens):
            t_type, t_val = tokens[index]
            if t_type == 'SYMBOL' and t_val == '}':
                if table:
                    keys = list(table.keys())
                    if all(isinstance(k, int) for k in keys):
                        sorted_keys = sorted(keys)
                        if sorted_keys == list(range(1, len(keys) + 1)):
                            return [table[k] for k in sorted_keys], index + 1
                return table, index + 1
            
            is_kv = False
            if index + 2 < len(tokens):
                next_type, next_val = tokens[index + 1]
                if next_type == 'SYMBOL' and next_val == '=':
                    is_kv = True
            
            if is_kv:
                key = t_val
                val, next_index = parse_table_value(tokens, index + 2)
                table[key] = val
                index = next_index
            else:
                val, next_index = parse_table_value(tokens, index)
                table[array_index] = val
                array_index += 1
                index = next_index
                
            if index < len(tokens):
                t_type, t_val = tokens[index]
                if t_type == 'SYMBOL' and (t_val == ',' or t_val == ';'):
                    index += 1
        raise ValueError("Unclosed table constructor")
    else:
        raise ValueError(f"Unexpected token {tok_type}: {tok_val}")

def extract_and_parse_config(lua_content):
    match = re.search(r'M\.CONFIG\s*=\s*(\{)', lua_content)
    if not match:
        match = re.search(r'CONFIG\s*=\s*(\{)', lua_content)
    if not match:
        raise ValueError("Could not find configuration table in file.")
    
    start_brace_pos = match.start(1)
    brace_count = 0
    end_brace_pos = -1
    for i in range(start_brace_pos, len(lua_content)):
        char = lua_content[i]
        if char == '{':
            brace_count += 1
        elif char == '}':
            brace_count -= 1
            if brace_count == 0:
                end_brace_pos = i
                break
    
    if end_brace_pos == -1:
        raise ValueError("Unbalanced braces in configuration table.")
        
    table_str = lua_content[start_brace_pos:end_brace_pos+1]
    tokens = tokenize_lua(table_str)
    config_dict, _ = parse_table_value(tokens, 0)
    return config_dict

# --- Schema Builder ---

def build_schema(config_node, path_parts, metadata_db):
    path_str = ".".join(str(p) for p in path_parts)
    meta = metadata_db.get(path_str, {})
    
    is_color = isinstance(config_node, dict) and 'R' in config_node and 'G' in config_node and 'B' in config_node
    
    if isinstance(config_node, dict) and not is_color:
        explicit_type = meta.get("type")
        if explicit_type in ("array", "map"):
            default_val = list(config_node.values()) if isinstance(config_node, dict) else (config_node if isinstance(config_node, list) else [])
            return {
                "type": explicit_type,
                "description": meta.get("description", f"Configuration for {path_parts[-1]}."),
                "default": default_val if explicit_type == "array" else (config_node if isinstance(config_node, dict) else {})
            }
            
        node_type = "section" if len(path_parts) == 1 else "group"
        properties = {}
        for key, val in config_node.items():
            properties[str(key)] = build_schema(val, path_parts + [key], metadata_db)
            
        result = {
            "type": node_type,
            "description": meta.get("description", f"{path_parts[-1] if path_parts else 'Configuration'} settings.")
        }
        if node_type == "section":
            result["properties"] = properties
        else:
            result["type"] = "group"
            result["properties"] = properties
        return result
    else:
        inferred_type = "string"
        if isinstance(config_node, bool):
            inferred_type = "boolean"
        elif isinstance(config_node, (int, float)):
            inferred_type = "number"
        elif is_color:
            inferred_type = "color"
        elif isinstance(config_node, list):
            inferred_type = "array"
        elif isinstance(config_node, dict):
            inferred_type = "map"
        
        prop_type = meta.get("type", inferred_type)
        
        prop_schema = {
            "type": prop_type,
            "description": meta.get("description", f"Configuration for {path_parts[-1]}."),
            "default": config_node
        }
        
        if "min" in meta: prop_schema["min"] = meta["min"]
        if "max" in meta: prop_schema["max"] = meta["max"]
        if "step" in meta: prop_schema["step"] = meta["step"]
        if "options" in meta: prop_schema["options"] = meta["options"]
        
        return prop_schema

# --- Main Generator Runner ---

def main():
    mods = [
        {
            "name": "HUDLocator",
            "lua_path": "HUDLocator/Scripts/HUDLocator/config.lua",
            "metadata": METADATA_HUD_LOCATOR,
            "version": "2.13.0"
        },
        {
            "name": "AccessoryToggler",
            "lua_path": "AccessoryToggler/Scripts/AccessoryToggler/config.lua",
            "metadata": METADATA_ACCESSORY_TOGGLER,
            "version": "2.4.0"
        },
        {
            "name": "HoldToFire",
            "lua_path": "HoldToFire/Scripts/HoldToFire/config.lua",
            "metadata": METADATA_HOLD_TO_FIRE,
            "version": "1.0.0"
        },
        {
            "name": "FreeCam",
            "lua_path": "FreeCam/Scripts/FreeCam/config.lua",
            "metadata": METADATA_FREECAM,
            "version": "1.0.1"
        },
        {
            "name": "PresetSwitch",
            "lua_path": "PresetSwitch/Scripts/PresetSwitch/config.lua",
            "metadata": METADATA_PRESET_SWITCH,
            "version": "1.0.3"
        }
    ]
    
    os.makedirs("docs/schemas", exist_ok=True)
    combined_schemas = {}
    
    for mod in mods:
        print(f"Parsing configuration for {mod['name']}...")
        if not os.path.exists(mod["lua_path"]):
            print(f"Warning: {mod['lua_path']} not found. Skipping.")
            continue
            
        with open(mod["lua_path"], "r", encoding="utf-8") as f:
            content = f.read()
            
        try:
            config_dict = extract_and_parse_config(content)
            
            # Build schema starting from root
            schema_data = {}
            for k, v in config_dict.items():
                schema_data[k] = build_schema(v, [k], mod["metadata"])
                
            mod_schema = {
                "modName": mod["name"],
                "version": mod["version"],
                "schema": schema_data
            }
            
            # Save individual schema
            out_path = f"docs/schemas/{mod['name']}.schema.json"
            with open(out_path, "w", encoding="utf-8") as out_f:
                json.dump(mod_schema, out_f, indent=2)
            print(f"Successfully generated {out_path}")

            # Sync to ModConfigWeb if directory exists
            web_sync_targets = {
                "HUDLocator": "d:/Mods/ModConfigWeb/will-palmods-configurator/src/features/hud-locator/utils/HUDLocator.schema.json",
                "AccessoryToggler": "d:/Mods/ModConfigWeb/will-palmods-configurator/src/features/accessory-toggler/AccessoryToggler.schema.json"
            }
            if mod["name"] in web_sync_targets and os.path.exists(os.path.dirname(web_sync_targets[mod["name"]])):
                with open(web_sync_targets[mod["name"]], "w", encoding="utf-8") as web_f:
                    json.dump(mod_schema, web_f, indent=2)
                print(f"Synced {mod['name']} schema to {web_sync_targets[mod['name']]}")
            
            # Add to combined schemas
            combined_schemas[mod["name"]] = mod_schema
            
        except Exception as e:
            print(f"Error generating schema for {mod['name']}: {e}")
            import traceback
            traceback.print_exc()

    # Save combined schema
    combined_path = "docs/schemas/all_schemas.json"
    with open(combined_path, "w", encoding="utf-8") as out_f:
        json.dump(combined_schemas, out_f, indent=2)
    print(f"Successfully generated combined schemas at {combined_path}")

if __name__ == "__main__":
    main()
