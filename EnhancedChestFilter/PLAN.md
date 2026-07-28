# Enhanced Chest Filter Implementation Plan

This document outlines the phased development roadmap for **`EnhancedChestFilter`**.

---

## 📡 Network Communication (`UniversalBusPak` & `bus_helper.lua`)

Client-server communication is handled via the **`UniversalBusPak`** Blueprint component (`BPC_UniversalRPCBus`) and its helper module (`bus_helper.lua`).

```
CLIENT (Player UI)                                                 SERVER (Host Process)
┌───────────────────────────────┐                               ┌───────────────────────────────┐
│ Player toggles checkbox for   │                               │ Registers Server Handler      │
│ Chest GUID "3A82C7B1-..."     │                               │ "SetChestFilterState"         │
└───────────────┬───────────────┘                               └───────────────┬───────────────┘
                │                                                               │
                │ 1. bus.SendToServer("EnhancedChestFilter",                    │
                │                     "SetChestFilterState", payload)           │
                ├──────────────────────────────────────────────────────────────►│
                │    Wire Packet: UniversalBusPak RPC Carrier                   │ 2. Updates Server State
                │                                                               │    & saves to server config
                │                                                               │
                │ 3. bus.SendToClient(pc, "SyncChestFilterState", payload)      │
                │◄──────────────────────────────────────────────────────────────┤
                │    Wire Packet: UniversalBusPak Client RPC                    │
                │                                                               │
┌───────────────┴───────────────┐                               ┌───────────────┴───────────────┐
│ Client updates UI & local     │                               │ Server Enforces Item Deposit  │
│ quick-stack validation        │                               │ for Players & Base Pals       │
└───────────────────────────────┘                               └───────────────────────────────┘
```

---

## 💾 Per-Chest Configuration & JSON Storage Schema

The mod stores per-chest configurations in a JSON database keyed by each chest's unique Map Object Instance GUID (`OwnerMapObjectInstanceId` or `ContainerId` GUID).

### File Locations (Checked in order):
1. **Primary Path**: `%LOCALAPPDATA%/Pal/Saved/Mods/EnhancedChestFilter/config.json` (Guarantees `ModConfigurator` compatibility).
2. **Fallback / Local Path**: `Pal/Binaries/Win64/Mods/EnhancedChestFilter/chests_config.json`.

### JSON Database Structure:
```json
{
  "Chests": {
    "3A82C7B1-4A59-87D2-1100-998877665544": {
      "bStrictExistingOnly": true,
      "lastUpdated": "2026-07-28T17:31:00Z"
    },
    "9F10B4C2-1122-3344-5566-778899AABBCC": {
      "bStrictExistingOnly": false,
      "lastUpdated": "2026-07-28T17:32:00Z"
    }
  }
}
```

---

## 🌐 Environment Execution & Compatibility Matrix

| Feature / Action | Singleplayer & Co-Op Host | Dedicated Server (with UE4SS + UniversalBusPak) | Vanilla Dedicated Server (Client-Only Mod) |
| :--- | :--- | :--- | :--- |
| **Per-Chest Persistence** | Saved in Local JSON | Saved in Server-Side JSON | Saved in Client-Side JSON |
| **Client-Server Sync** | Direct local state | Synchronized via `UniversalBusPak` | Client-side local memory |
| **UI Checkbox Injection** | ✅ Renders in Chest Menu | ✅ Renders in Chest Menu | ✅ Renders in Chest Menu |
| **Player Quick-Stack Filter** | ✅ Filtered locally | ✅ Filtered client & server verified | ✅ Filtered on client before RPC |
| **Player Drag-Drop Block** | ✅ Blocked locally | ✅ Blocked client & server verified | ✅ Blocked on client UI |
| **Base Pal Transport AI Routing** | ✅ Intercepted on host | ✅ Intercepted on server | ❌ Native Server C++ (Client Fallback) |

---

## 📋 Development Roadmap

### Phase 1: Mod Structure & State Manager
- Create core mod files: `Scripts/main.lua`, `Scripts/config.lua`, `Scripts/bus_helper.lua`, `Scripts/json.lua`, `Scripts/chest_filter_manager.lua`.
- Implement `chest_filter_manager.lua` to load, save, and manage per-chest strict mode flags (`bStrictExistingOnly`) keyed by chest instance GUID.
- Register `bus_helper` server RPC handlers (`SetChestFilterState`, `GetChestFilterState`).
- Expose validation API: `M.CanInsertItem(container, staticItemId)`.

### Phase 2: UI Checkbox Injection (`WBP_IngameMenu_ChestSetting_FilterBlock`)
- Create `Scripts/ui_injector.lua`.
- Hook `WBP_IngameMenu_ChestSetting_FilterBlock` / `WBP_IngameMenu_Chest_Filter`.
- Dynamically construct and attach a **"Only Allow Existing Items"** checkbox widget into the chest filter menu.
- Bind checkbox `OnCheckStateChanged` events to update `chest_filter_manager` for that specific chest ID and fire `bus.SendToServer("SetChestFilterState", payload)`.

### Phase 3: Client Quick-Stack & Manual Move Interception
- Create `Scripts/transfer_hooks.lua`.
- Hook `WBP_IngameMenu_Chest` Quick-Stack button events.
- Intercept quick-stacking when Strict Mode is active for the open chest ID, filtering out inventory items that have `GetItemStackCount(itemId) == 0`.
- Guard manual drag-and-drop actions.

### Phase 4: Server Deposit Guard & Pal AI Transport Routing
- Hook `ItemOperationMoveDelegate` / `UPalItemContainerManager`.
- Intercept Pal base camp transport depot selection (`UPalBaseCampModuleTransportItemDirector`) on dedicated servers running UE4SS.
- Ensure Pal AI deposits items into chests matching existing item types.

---

## 🧪 Testing Checklist
- [ ] UI Checkbox renders cleanly inside `WBP_IngameMenu_ChestSetting_FilterBlock`.
- [ ] Toggling checkbox sends `SetChestFilterState` RPC via `bus_helper` and updates server `config.json`.
- [ ] Opening chest menu sends `GetChestFilterState` RPC and updates client checkbox.
- [ ] Checkbox state persists across menu close/open cycles and game restarts for each unique chest.
- [ ] Seeding a chest with Ore and Ingot permits stacking more Ore/Ingot.
- [ ] Unseeded item types (e.g. Stone, Wood) are rejected during Quick-Stack and manual drag-and-drop.
- [ ] Dedicated Server: `UniversalBusPak` syncs per-chest state between client and server smoothly.
- [ ] Toggling Strict Mode OFF restores native Palworld container behavior.
