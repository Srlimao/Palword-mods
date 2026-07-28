# UniversalBusPak Guide: Native Unreal Engine Blueprint RPC Bus

`UniversalBusPak` is a native Unreal Engine Blueprint (`.pak`) mod framework for Palworld that handles client-server RPC replication natively inside Unreal Engine's multiplayer engine.

It allows **Blueprint `.pak` mods** and **UE4SS Lua mods** (`MapsPlusServer`, `EnhancedChestFilter`, etc.) to exchange network messages without string-carrier hacks, thread crashes, or UI artifacts.

---

## 📐 Architecture Overview

```
[Player Client]                                      [UniversalBusPak.pak]                            [Dedicated Server]
UE4SS / .pak Mod (e.g. EnhancedChestFilter)          BPC_UniversalRPCBus (PlayerController Component) UE4SS Server Mod (EnhancedChestFilterServer)
 └── Calls BPC_UniversalRPCBus:                      └── Native Engine Server RPC                      └── RegisterHook on OnServerRPCReceived
      Server_SendRPC(modId, event, jsonData)              └── Replicates natively on GameThread             └── Validates & Saves Whitelist JSON
```

---

## 🛠️ Step-by-Step Guide: Creating `UniversalBusPak.pak` in Unreal Editor 5.1

### 1. Project Folder Setup in Unreal Editor
1. Open your **Palworld Modding Kit** project in **Unreal Engine 5.1**.
2. In the Content Browser, navigate to `Content/`.
3. Create a dedicated plugin/mod directory:
   `Content/Mods/UniversalBusPak/`

---

### 2. Creating the `BPC_UniversalRPCBus` Actor Component
1. Right-click inside `Content/Mods/UniversalBusPak/` $\rightarrow$ **Blueprint Class**.
2. Select **Actor Component** as the parent class.
3. Name it **`BPC_UniversalRPCBus`**.
4. Open `BPC_UniversalRPCBus`:
   * Go to **Class Defaults**.
   * Under **Component Replication**, check **Component Replicates = True**.

---

### 3. Creating the RPC & Hook Delegate Events

#### A. Server RPC Event (`Server_SendRPC`)
1. In `BPC_UniversalRPCBus` My Blueprint panel, add a Custom Event: **`Server_SendRPC`**.
2. In Details panel:
   * **Replicates**: `Run on Server`
   * **Reliable**: `Checked (True)`
3. Add Inputs:
   * `ModId` (`String`)
   * `EventName` (`String`)
   * `JsonData` (`String`)
4. In the Event Graph, connect `Server_SendRPC` to call a non-replicated custom event **`OnServerRPCReceived`** (passing `ModId`, `EventName`, `JsonData`).

#### B. Client RPC Event (`Client_SendRPC`)
1. Add a Custom Event: **`Client_SendRPC`**.
2. In Details panel:
   * **Replicates**: `Run on Owning Client`
   * **Reliable**: `Checked (True)`
3. Add Inputs:
   * `ModId` (`String`)
   * `EventName` (`String`)
   * `JsonData` (`String`)
4. In the Event Graph, connect `Client_SendRPC` to call **`OnClientRPCReceived`** (passing `ModId`, `EventName`, `JsonData`).

#### C. Hook Targets for UE4SS Lua
Create the two non-replicated dispatcher events:
* **`OnServerRPCReceived`** (Inputs: `ModId`, `EventName`, `JsonData`)
* **`OnClientRPCReceived`** (Inputs: `ModId`, `EventName`, `JsonData`)

> **Why?** UE4SS Lua hooks on `/Game/Mods/UniversalBusPak/BPC_UniversalRPCBus.BPC_UniversalRPCBus_C:OnServerRPCReceived` so server Lua mods get triggered automatically whenever any RPC arrives!

---

### 4. Auto-Attaching Component to PlayerController
To enable clients to send Server RPCs, `BPC_UniversalRPCBus` MUST be attached to an actor owned by the local player (like `APalPlayerController`).

1. Create a Mod Actor `BP_UniversalBusPak_Initializer` (or use a LogicMod init script).
2. On `BeginPlay`:
   * Get Local `PlayerController`.
   * Call `Construct Object from Class` (Class: `BPC_UniversalRPCBus`).
   * Call `Register Component` on `PlayerController`.
   * Call `AttachToComponent` or add to `PlayerController`'s component list.

---

### 5. Cooking & Packaging `.pak` File
1. In Unreal Editor top bar: **File** $\rightarrow$ **Cook Content for Windows**.
2. After cooking finishes, locate cooked asset files in:
   `<ProjectFolder>/Saved/Cooked/Windows/Pal/Content/Mods/UniversalBusPak/`
3. Pack into `.pak` using UnrealPak or Palworld Modding Kit build script.
4. Output file: **`UniversalBusPak_P.pak`**
5. Distribute: Place `UniversalBusPak_P.pak` in:
   * Client: `Pal/Content/Paks/LogicMods/UniversalBusPak_P.pak`
   * Server: `Pal/Content/Paks/LogicMods/UniversalBusPak_P.pak`

---

## 🔌 How UE4SS Lua Mods Consume `UniversalBusPak`

Once `UniversalBusPak_P.pak` is loaded in Palworld, any UE4SS Lua mod can interact with it cleanly!

### 1. Sending an RPC from Lua (Client $\rightarrow$ Server)
```lua
-- Helper to get BPC_UniversalRPCBus from local PlayerController
local function GetRPCBus()
    local pc = FindFirstOf("PalPlayerController")
    if pc and pc:IsValid() and pc.BPC_UniversalRPCBus then
        return pc.BPC_UniversalRPCBus
    end
    return nil
end

-- Send RPC from Lua client!
local bus = GetRPCBus()
if bus and bus:IsValid() then
    local payload = json.encode({ chestId = "CHEST_01", whitelist = { "Item_PalSphere", "Item_Ingot" } })
    bus:Server_SendRPC("EnhancedChestFilter", "SaveWhitelist", payload)
end
```

### 2. Registering a Server Handler in Lua (Server $\rightarrow$ Logic Execution)
```lua
RegisterHook("/Game/Mods/UniversalBusPak/BPC_UniversalRPCBus.BPC_UniversalRPCBus_C:OnServerRPCReceived", function(selfParam, modIdParam, eventNameParam, jsonDataParam)
    local modId = nil
    local eventName = nil
    local jsonData = nil

    pcall(function()
        if modIdParam then modId = modIdParam:get():ToString() end
        if eventNameParam then eventName = eventNameParam:get():ToString() end
        if jsonDataParam then jsonData = jsonDataParam:get():ToString() end
    end)

    if modId == "EnhancedChestFilter" and eventName == "SaveWhitelist" then
        local data = json.decode(jsonData)
        print("[EnhancedChestFilter] Server received chest whitelist update for chest: " .. tostring(data.chestId))
        
        -- Process and save config safely!
    end
end)
```

---

## ⚡ Benefits Summary

* **100% Native Unreal Engine Replication**: No string-carrier hacks on native RPC functions.
* **100% Game Thread Execution**: Engine handles execution timing automatically. Zero crashes.
* **Lua & Blueprint Compatible**: Usable by pure UE4SS Lua mods, C++ mods, or Blueprint `.pak` mods!
