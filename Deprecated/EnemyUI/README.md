# Palworld Mods Development Workspace

Welcome! This workspace contains a collection of highly optimized client-side Lua mods for Palworld, built using the UE4SS scripting framework.

---

## 🛠️ Included Mods

### 1. EnemyUI (Enemy HP Bar & Tag Customization)
*   **Source:** [EnemyUI/Scripts/main.lua](file:///d:/Mods/Palword/EnemyUI/Scripts/main.lua)
*   **Features:** Displays enemy levels, names, and HP gauges above their heads. Includes an `Alt + F9` hotkey to toggle showing all bars vs. only looking at target enemies.

### 2. RelicFinder (Effigy & Treasure Finder)
*   **Source:** [RelicFinder/Scripts/main.lua](file:///d:/Mods/Palword/RelicFinder/Scripts/main.lua)
*   **Features:** Projects and draws centered 3D floating labels in world space above nearby Lifmunk Effigies (`Relic [45m]` in Cyan) and treasure chests (`Chest [12m]` in Gold).

### 3. PlayerLocator (Friend Distance Tracker)
*   **Source:** [PlayerLocator/Scripts/main.lua](file:///d:/Mods/Palword/PlayerLocator/Scripts/main.lua)
*   **Features:** Tracks all players server-wide (even beyond 3D network render distance) and draws a highly readable Ice-Blue nameplate and real-time distance indicator above their heads. Styled with a custom 8-way solid black outline.

---

## ⚠️ Critical Development Guidelines (For the Next Agent)

When modifying or adding new features to these mods, you **MUST** adhere to the following architectural rules to prevent game crashes, stutters, and lag:

### 1. Zero-Query Render Ticks (HUD Hook Optimization)
The HUD draw hook (`ReceiveDrawHUD`) runs every frame (60 to 120+ FPS). 
*   **DO NOT** call `UEHelpers.GetPlayer()`, `FindFirstOf()`, `FindAllOf()`, or complex C++ methods inside the HUD hook. Doing so will cause severe frame rate drops and stuttering.
*   **DO** execute player/actor scans on a slow background timer loop (e.g. 1500ms or 5000ms delay).
*   **DO** cache the player actor pointer (`cachedLocalPlayer`) and calculated coordinates in simple Lua tables. The HUD hook should only do fast math calculations and draw operations using these cached tables.

### 2. Startup & Loading Screen Protection (Crash Prevention)
Iterating C++ objects or managers while the world is loading or on the Title Screen will cause instant native Access Violations (process termination).
*   **DO** gatekeep the background scan loops. The first line of any scan should check if the in-game HUD exists:
    ```lua
    local hudCheck = FindFirstOf("BP_PalHUD_InGame_C")
    if not hudCheck or not hudCheck:IsValid() then return end
    ```
    Since `BP_PalHUD_InGame_C` is only created when you physically load into the playable game world, this safety check completely protects your scans from running on title/loading screens.

### 3. GC Spike Prevention (FindAllOf Mitigation)
Calling `FindAllOf` or iterating large Maps (`UPalLocationManager` map) iterates the global Unreal `GObjects` array (over 400,000 objects in memory).
*   **DO NOT** run these scans frequently.
*   **DO** set scan intervals to 5 seconds (`5000ms`) if you must use `FindAllOf("PalPlayerState")`. A 4ms scan once every 5 seconds is completely imperceptible to the player, whereas running it every frame or every second causes constant stuttering.

---

## 📦 Current Deployment Status
*   **Clean Game Files:** All local mod folders have been deleted from the game's UE4SS directories, and their entries set to `0` / `false` in `mods.txt` and `mods.json`. The user is currently running the Steam Workshop subscribed versions of these mods.
*   **Settings Config:** Console outputs have been disabled (`ConsoleEnabled = 0`, `GuiConsoleEnabled = 0`) in the game's [UE4SS-settings.ini](file:///C:/Program%20Files%20%28x86%29/Steam/steamapps/common/Palworld/Mods/NativeMods/UE4SS/UE4SS-settings.ini) to let the game boot silently.
*   **Release Packs:** Structured `.zip` distribution packages and Steam Workshop cover arts are saved inside each mod's workspace folders.
