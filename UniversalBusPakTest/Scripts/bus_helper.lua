local json = require("json")
local M = {}

local function JsonEncode(val)
    if not json then return "{}" end
    if json.encode then return json.encode(val) end
    if json.Encode then return json.Encode(val) end
    return "{}"
end

local function JsonDecode(str)
    if not json or type(str) ~= "string" then return {} end
    if json.decode then return json.decode(str) or {} end
    if json.Decode then return json.Decode(str) or {} end
    return {}
end

--- Resolves the BPC_UniversalRPCBus component attached to local PlayerController
function M.GetBusComponent()
    local pc = FindFirstOf("BP_PalPlayerController_C")
    if not pc or not pc:IsValid() then pc = FindFirstOf("PalPlayerController") end
    if pc and pc:IsValid() then
        -- 1. Check direct property access
        pcall(function()
            if pc.BPC_UniversalRPCBus and pc.BPC_UniversalRPCBus:IsValid() then
                return pc.BPC_UniversalRPCBus
            end
        end)

        local compClass = StaticFindObject("/Game/Mods/UniversalBusPak/BPC_UniversalRPCBus.BPC_UniversalRPCBus_C")
        if compClass and compClass:IsValid() then
            -- 2. Check via GetComponentByClass
            local comp = nil
            pcall(function()
                if pc.GetComponentByClass then
                    comp = pc:GetComponentByClass(compClass)
                end
            end)
            if comp and comp:IsValid() then return comp end

            -- 3. Dynamic auto-attach fallback on demand
            local newComp = nil
            pcall(function()
                if pc.AddComponentByClass then
                    newComp = pc:AddComponentByClass(compClass, false, { Rotation = {X=0,Y=0,Z=0,W=1}, Translation = {X=0,Y=0,Z=0}, Scale3D = {X=1,Y=1,Z=1} }, false)
                    if newComp and newComp:IsValid() then
                        newComp:SetIsReplicated(true)
                    end
                end
            end)
            if newComp and newComp:IsValid() then return newComp end
        end
    end
    return nil
end

--- Returns true if executing on a dedicated server (no local player UI)
function M.IsDedicatedServer()
    local isDedicated = false
    pcall(function()
        local engine = GetEngine()
        if engine and engine:IsValid() and engine.IsDedicatedServer then
            isDedicated = engine:IsDedicatedServer()
        end
    end)
    return isDedicated
end

--- Checks if player is inside an active gameplay world (not Title/Splash/Login menu)
function M.IsInInGameWorld()
    local inGameHUD = FindFirstOf("BP_PalHUD_InGame_C")
    if inGameHUD and inGameHUD:IsValid() then
        return true
    end
    return false
end

--- Send an RPC message from Client to Server
function M.SendToServer(modId, eventName, dataTable)
    -- Guard: Do not send RPCs on Title Screen / Menus (prevents level reset)
    if not M.IsInInGameWorld() then return false end

    local pc = FindFirstOf("BP_PalPlayerController_C")
    if not pc or not pc:IsValid() then pc = FindFirstOf("PalPlayerController") end
    if not pc or not pc:IsValid() then return false end

    local sent = false
    pcall(function()
        local payload = "[URPC]" .. JsonEncode({
            mod = tostring(modId),
            event = tostring(eventName),
            data = dataTable or {}
        })
        pc:RequestChangeGuildName_ToServer(payload)
        sent = true
    end)

    return sent
end

local isHookRegistered = false
local eventHandlers = {}

local function TryDispatchHandler(pc, modId, eventName, dataTable)
    if modId and eventName and eventHandlers[modId] and eventHandlers[modId][eventName] then
        local handler = eventHandlers[modId][eventName]
        pcall(ExecuteInGameThread, function()
            pcall(handler, pc, dataTable)
        end)
    end
end

local function TryRegisterHook()
    if isHookRegistered then return end
    local success = pcall(function()
        -- 1. Hook Blueprint .pak RPC Event
        RegisterHook("/Game/Mods/UniversalBusPak/BPC_UniversalRPCBus.BPC_UniversalRPCBus_C:OnServerRPCReceived", function(selfParam, modIdParam, eventNameParam, jsonDataParam)
            local selfObj, modId, eventName, jsonData = nil, nil, nil, nil
            pcall(function()
                if selfParam then selfObj = selfParam:get() end
                if modIdParam then modId = modIdParam:get():ToString() end
                if eventNameParam then eventName = eventNameParam:get():ToString() end
                if jsonDataParam then jsonData = jsonDataParam:get():ToString() end
            end)

            local pc = nil
            pcall(function()
                if selfObj and selfObj:IsValid() then
                    pc = selfObj:GetOwner()
                end
            end)
            local dataTable = JsonDecode(jsonData or "{}")
            TryDispatchHandler(pc, modId, eventName, dataTable)
        end)

        -- 2. Hook Native C++ PalPlayerController RPC Carrier Fallback
        RegisterHook("/Script/Pal.PalPlayerController:RequestChangeGuildName_ToServer", function(selfParam, nameParam)
            local pc, rawName = nil, nil
            pcall(function()
                if selfParam then pc = selfParam:get() end
                if nameParam then rawName = nameParam:get():ToString() end
            end)

            if type(rawName) == "string" and rawName:sub(1, 6) == "[URPC]" then
                local jsonStr = rawName:sub(7)
                local env = JsonDecode(jsonStr)
                if env and env.mod and env.event then
                    TryDispatchHandler(pc, tostring(env.mod), tostring(env.event), env.data or {})
                end
            end
        end)
    end)

    if success then
        isHookRegistered = true
    end
end

-- Watch for BPC_UniversalRPCBus creation in memory to register hook if UFunction wasn't loaded yet
pcall(function()
    NotifyOnNewObject("/Game/Mods/UniversalBusPak/BPC_UniversalRPCBus.BPC_UniversalRPCBus_C", function()
        TryRegisterHook()
    end)
end)

-- Watch for PalPlayerController creation as fallback
pcall(function()
    NotifyOnNewObject("/Script/Pal.PalPlayerController", function()
        TryRegisterHook()
    end)
end)

--- Register a Server RPC receiver in Lua
function M.RegisterServerHandler(targetModId, targetEventName, callback)
    if not eventHandlers[targetModId] then eventHandlers[targetModId] = {} end
    eventHandlers[targetModId][targetEventName] = callback

    TryRegisterHook()
end

return M
