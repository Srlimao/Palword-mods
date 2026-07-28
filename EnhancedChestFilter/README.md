# Enhanced Chest Filter (`EnhancedChestFilter`)

**EnhancedChestFilter** is a Palworld UE4SS mod that adds a **per-chest "Strict Existing Items Only"** mode to container storage.

Instead of manually configuring item categories or whitelists, players simply place 1 unit of desired items inside a chest (e.g. 1 Ore, 1 Ingot) and check **"Only Allow Existing Items"**. The chest will then restrict manual transfers, quick-stacking, and auto-deposits exclusively to item types already present in that chest.

---

## 🎯 How It Works

1. **Per-Chest UI Option**: Toggling chest settings (`F` -> Filter) reveals a new checkbox: **"Only Allow Existing Items"**.
2. **Per-Chest Persistence**: Each chest's setting is stored individually by its unique Map Object Instance GUID in a JSON file (`config.json` / `chests_config.json`).
3. **Multiplayer Network Sync (`UniversalBusPak`)**:
   - Uses `bus_helper.lua` and `BPC_UniversalRPCBus` to communicate between Client and Dedicated Server.
   - Client sends `SetChestFilterState` RPC when checkbox is toggled.
   - Server updates its server-side database and enforces rules for players and Base Pals.
4. **Instant Engine Check**: When enabled for a specific chest, any deposit or quick-stack operation performs a fast `container:GetItemStackCount(staticItemId) > 0` check.
5. **Item Filtering**:
   - Items **already present** in that chest (stack count > 0) are allowed to stack into existing or empty slots.
   - Items **not present** in that chest are rejected and remain in inventory.
6. **Empty Chest Edge Case**: If a chest is 100% empty, new items cannot be deposited while Strict Mode is ON until items are seeded or Strict Mode is toggled OFF.

---

## 📡 Multiplayer RPC Handlers (`UniversalBusPak`)

```lua
local bus = require("bus_helper")
local MOD_ID = "EnhancedChestFilter"

-- Server RPC Listener
bus.RegisterServerHandler(MOD_ID, "SetChestFilterState", function(playerController, data)
    -- data = { chestGuid = "3A82C7B1-...", bStrictExistingOnly = true }
end)

-- Client RPC Sender
bus.SendToServer(MOD_ID, "SetChestFilterState", {
    chestGuid = chestGuid,
    bStrictExistingOnly = isChecked
})
```

---

## 💾 Per-Chest Config JSON Schema

The mod checks `%LOCALAPPDATA%/Pal/Saved/Mods/EnhancedChestFilter/config.json` (and falls back to `Pal/Binaries/Win64/Mods/EnhancedChestFilter/chests_config.json` inside the game directory):

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

## 🧠 Technical Architecture & Pal Transport AI

### Pal Transporting Engine Flow (`CXXHeaderDump`)

```
┌────────────────────────────────────────────────────────┐
│        UPalBaseCampModuleTransportItemDirector         │
│ - Scans items at base & available chests (Depots)       │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼ Assigns Target Chest ID
┌────────────────────────────────────────────────────────┐
│                 UPalActionTransportItem                │
│ - Pal AI Action: Pick up item -> Pathfind to Chest     │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼ Deposit Item
┌────────────────────────────────────────────────────────┐
│          UPalMapObjectItemContainerModule              │
│ - Calls UPalItemContainer to insert the item          │
└───────────────────────────┬────────────────────────────┘
```

### Mod Script Hook Points

1. **Client UI Quick-Stack Hook (`WBP_IngameMenu_Chest`)**:
   - Intercepts player Quick-Stack requests for the open chest.
   - Filters out non-existing item IDs before sending move requests to the server.

2. **Container Deposit Guard (`UPalItemContainerManager`)**:
   - Hooks item movement/deposit delegates (`ItemOperationMoveDelegate`).
   - Evaluates `container:GetItemStackCount(staticItemId) > 0` for the specific target chest GUID.

3. **Server-Side Pal AI Transport Routing (`UPalBaseCampModuleTransportItemDirector`)**:
   - Filters candidate chests during Pal transport depot selection on dedicated servers with UE4SS.
   - Directs Pals carrying specific item types to chests that already hold those items.
