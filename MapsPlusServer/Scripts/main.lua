-- main.lua
print("[MapsPlusServer] Mod file main.lua executed.")

local serverInitialized = false
local clientInitialized = false

local function InitializeMod(world)
    local palUtility = StaticFindObject("/Script/Pal.Default__PalUtility")
    if not palUtility or not palUtility:IsValid() then
        return false -- Try again next tick
    end
    
    local isServer = palUtility:IsServer(world)
    local isDedicated = palUtility:IsDedicatedServer(world)
    print(string.format("[MapsPlusServer] InitializeMod called. isServer=%s | isDedicated=%s", tostring(isServer), tostring(isDedicated)))
    
    if (isServer or isDedicated) and not serverInitialized then
        serverInitialized = true
        print("[MapsPlusServer] Initializing Server Module...")
        require("server").Initialize()
    end
    
    if not isDedicated and not clientInitialized then
        clientInitialized = true
        print("[MapsPlusServer] Initializing Client Module...")
        require("client").Initialize()
    end
    
    return true
end

-- Robust Initialization: Poll for World and UPalUtility
local function WaitForWorldAndInit()
    -- Only try to initialize if we haven't fully initialized both sides
    -- (Or at least the ones we need for the current net mode)
    if serverInitialized and clientInitialized then return end

    local world = FindFirstOf("World")
    if world and world:IsValid() then
        local success = InitializeMod(world)
        if success then
            return -- Stop polling once initialized
        end
    end
    
    -- Keep polling every 2000ms until the World and Utility exist
    ExecuteWithDelay(2000, WaitForWorldAndInit)
end

print("[MapsPlusServer] Starting world polling loop...")
ExecuteWithDelay(2000, WaitForWorldAndInit)
