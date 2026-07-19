# Stashed Feature Plan: Coordinated In-Game Changelogs (Automatic Date Check)

This plan details how to add interactive in-game changelog popups for Palworld mods (e.g. `HUDLocator` and `AccessoryToggler`) when the player is on the Title Screen/Main Menu, coordinated using a shared queue.

---

## Architecture & Coordination

### 1. Coordinated Queue File (`changelog_queue.json`)
Since mods run in separate UE4SS Lua states, they coordinate their popups via a shared JSON file in the `%LOCALAPPDATA%\Pal\Saved\Mods` directory:

```json
{
  "queue": ["HUDLocator", "AccessoryToggler"],
  "active": "HUDLocator"
}
```

### 2. Automatic Update Detection (Zero Code Management)
Instead of updating version numbers or date strings manually in the Lua code, each mod automatically checks the modification timestamp (`Ticks`) of its own script at runtime.
- **Config Flag:** `SeenChangelogDate` (holds the tick timestamp of the last dismissed update).
- **Check on Startup:** If the script's `LastWriteTimeUtc.Ticks` differs from `SeenChangelogDate` in `config.json`, the mod registers itself to the queue.
- **Dismissal:** Clicking the Close button updates `SeenChangelogDate` to the script's current modification date, so the popup shows exactly once per update/deployment.

---

## Mod-Specific Implementation Details

### HUDLocator Mod

1. **`config.lua` Changes:**
   - Add a utility function to get the current script file's last modified ticks using `powershell`:
     ```lua
     local function GetScriptLastModifiedDate()
         local info = debug.getinfo(1, "S")
         if info and info.source and info.source:sub(1, 1) == "@" then
             local src = info.source:sub(2)
             local pipe = io.popen('powershell -Command "(Get-Item \'' .. src .. '\').LastWriteTimeUtc.Ticks"')
             if pipe then
                 local output = pipe:read("*all")
                 pipe:close()
                 return output:match("(%d+)") or "0"
             end
         end
         return "0"
     end
     ```
   - At startup, compare `CONFIG.Global.SeenChangelogDate` to this timestamp. If different, register `HUDLocator` to the shared `changelog_queue.json`.

2. **Changelog UI (`changelog.lua`):**
   - Renders the popup card on the main menu HUD (when `APalGameModeTitle` is active and it is the `"active"` mod in the queue).
   - Draws a translucent centered overlay box, bullet points of features/fixes, and a `[ Close ]` button.
   - Highlights the button when the cursor hovers over it.
   - Listens to `LEFT_MOUSE_BUTTON` click to check coordinates and close the window, updating `SeenChangelogDate` and saving configs.

3. **`main.lua` Changes:**
   - Register a generic `/Script/Engine.HUD:ReceiveDrawHUD` hook to draw on the Title screen if any HUD is instantiated.

---

### AccessoryToggler Mod

1. **`config.lua` Changes:**
   - Implement the same `GetScriptLastModifiedDate()` function.
   - Register to the queue on startup if script date is newer than `SeenChangelogDate` in config.

2. **Changelog UI (`changelog.lua`):**
   - Matches the popup interface design of HUDLocator, with its own specific bullets.
   - Updates `SeenChangelogDate` and advances the queue on click dismiss.

3. **`main.lua` Changes:**
   - Hook generic HUD draw callback to display the popup.
