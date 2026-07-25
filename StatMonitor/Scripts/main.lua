-- Palworld StatMonitor Mod
-- Automatically executes 'stat unit' on game startup

local UEHelpers = require("UEHelpers")

local statExecuted = false

local function RunStatUnit()
    local KismetSystemLibrary = StaticFindObject("/Script/Engine.Default__KismetSystemLibrary")
    local world = UEHelpers.GetWorld() or FindFirstOf("World")
    if KismetSystemLibrary and world and world:IsValid() then
        pcall(function()
            KismetSystemLibrary:ExecuteConsoleCommand(world, "stat unit", nil)
        end)
        print("[StatMonitor] Executed console command 'stat unit'")
    end
end

local function RegisterHUDHook()
    pcall(function()
        RegisterHook("/Game/Pal/Blueprint/UI/BP_PalHUD_InGame.BP_PalHUD_InGame_C:ReceiveDrawHUD", function(self, SizeX, SizeY)
            if not statExecuted then
                statExecuted = true
                RunStatUnit()
            end
        end)
    end)
end

RegisterHUDHook()

NotifyOnNewObject("/Game/Pal/Blueprint/UI/BP_PalHUD_InGame.BP_PalHUD_InGame_C", function(hudObj)
    RegisterHUDHook()
end)

print("[StatMonitor] Mod Loaded Successfully!")
