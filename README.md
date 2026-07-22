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
    *   **Journals / Notes:** Coral/salmon overlays for uncollected lore memos/journals.
    *   **Ground Loot:** Green overlays for wild spheres, skill fruits, arrows, and coins.
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

## 🚀 Deployment & Testing

For local testing and development, always use the automated `debugDeploy.bat` script located within each mod's directory to copy files to your alternative game client's debug folder under `D:\Games\Palworld_Alt\`, rather than manually copying files to your primary Steam game folders.

- **FreeCam:** Run [FreeCam/debugDeploy.bat](file:///d:/Mods/Palword/FreeCam/debugDeploy.bat) to deploy to `FreeCamDEBUG`.
- **HUDLocator:** Run [HUDLocator/debugDeploy.bat](file:///d:/Mods/Palword/HUDLocator/debugDeploy.bat) to deploy to `HUDLocatorDEBUG`.
- **AccessoryToggler:** Run [AccessoryToggler/debugDeploy.bat](file:///d:/Mods/Palword/AccessoryToggler/debugDeploy.bat) to deploy to `AccessoryTogglerDEBUG`.

---

