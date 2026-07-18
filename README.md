# Palworld Mods Development Workspace

Welcome! This workspace contains highly optimized client-side Lua and native mods for Palworld, built for the UE4SS scripting framework.

---

## 🛠️ Active Mods

### 1. [HUDLocator](HUDLocator) (Merged & Modularized HUD)
*   **Location:** `HUDLocator`
*   **Features:** A unified, configurable HUD tracking system that displays in-world markers and distances for:
    *   **Players:** Real-time location and distance nameplates for friends.
    *   **Relics:** Nearby Lifmunk Effigies.
    *   **Chests:** Treasure chests, Gilded boxes, and other loot.
    *   **Eggs:** Pal eggs with configurable size filters (All, Large+, HugeOnly).
    *   **Caves:** Dungeon entrances with level and clearance state indicators.
*   **Interactive Menu:** Alt + F6 toggles the modern, semi-transparent in-game settings menu. Alt + Arrows navigates and changes options.
*   **Localization:** Fully supports automatic game-engine localization (system language) or custom language selections.

### 2. [AccessoryToggler](AccessoryToggler) (Visual Accessory Utility)
*   **Location:** `AccessoryToggler`
*   **Features:** Toggle the visibility of player accessories to customize appearance without losing stat benefits.

### 3. [IdleServerShutdown](IdleServerShutdown) (Dedicated Server Optimizer)
*   **Location:** `IdleServerShutdown`
*   **Features:** Automates shutting down dedicated servers when no players are active for a prolonged period, saving CPU/memory resources.

### 4. [ProductionRepeat](ProductionRepeat) (Native Project)
*   **Location:** `ProductionRepeat`
*   **Features:** Native/Blueprint project supporting repeat options for workstation production queues.

---

## 🧹 Deprecated Mods (Merged into HUDLocator)
Consolidated into **HUDLocator**:
*   🚫 **EnemyUI:** Integrated into HUD rendering.
*   🚫 **RelicFinder:** Integrated into HUDLocator relics/chests trackers.
*   🚫 **PlayerLocator:** Integrated into HUDLocator players tracker.
*   *Note:* Backups of these old projects are located in the [Deprecated](Deprecated) folder.

---

## ⚠️ Development Guidelines

All developers must follow these grouped directives to prevent crashes, frame-time spikes, or memory leaks:

### 1. Performance & Scan Optimization

#### Zero-Query Render Tick Directive
*   **Directive:** Keep the HUD draw hook (`ReceiveDrawHUD`) query-free. Never call `UEHelpers.GetPlayer()`, `FindFirstOf()`, `FindAllOf()`, or Unreal Engine search methods inside rendering loops.
*   **Directive:** Execute player/actor scans on a slow background timer loop (e.g. `1500ms` delay).
*   **Directive:** Restrict render ticks to fast math calculations and drawing functions using local cached tables.

#### GC Spike & Scan Interval Directive
*   **Directive:** Restrict heavy resource scans (e.g., `FindAllOf("PalPlayerState")`) to intervals of 1.5 - 5 seconds to prevent garbage collection stutters.

#### Palworld Modding Kit
*   **Directive:** Use Palworld Modding Kit for deeper scan of cpp and header files when needed: `D:\Mods\PalworkdModdingKit\PalworldModdingKit`

---

### 2. Stability & Crash Prevention

#### Loading Screen Protection Directive
*   **Directive:** Stop background scan loops on loading/title screens by checking if the HUD actor exists as the first step in every scan:
    ```lua
    local hudCheck = FindFirstOf("BP_PalHUD_InGame_C")
    if not hudCheck or not hudCheck:IsValid() then return end
    ```

#### UE4SS Hook Stability Directive
*   **Directive:** Never query font properties on the HUD object (e.g., `hud.RobotoFont`). Pass `nil` to default to the system font safely.
*   **Directive:** Safe-cast `RemoteUnrealParam` wrapper objects when handling HUD variables (e.g., call `SizeX:get()` if `type(SizeX) == "userdata"`) to avoid arithmetic crash errors.

---

### 3. Game State & Localization Logic

#### Map Object & Egg Pickup Directive
*   **Directive:** Do not query physical 3D actor scale using `K2_GetActorScale3D()`. Use `egg.Scale` double property directly.
*   **Directive:** Check if an egg is picked up using `egg.bPickedInClient` and checking `concrete.bPicked` / `concrete.bIsPicked` on the concrete model *only if* `MapObjectModel` is valid.
*   **Directive:** Do not assume an egg is picked up if `MapObjectModel` is `nil`. It is normal for `MapObjectModel` to be `nil` during initial client replication.

#### Game-Engine Localization Directive
*   **Directive:** Access configuration language setting via `CONFIG.Global.Language`.
*   **Directive:** Translate strings by calling `UPalMasterDataTablesUtility:GetLocalizedText(world, Category, TextId)` on the CDO `/Script/Pal.Default__PalMasterDataTablesUtility` (e.g., `Category = 11` for items, `13` for map objects). Do not use `UPalUIUtility:GetItemName()`.
*   **Directive:** Prefix item translation database IDs with `ITEM_NAME_` (e.g., `ITEM_NAME_Relic`).
*   **Directive:** Handle the returned array from `UDataTable:GetRowNames()` as standard Lua string lists.
