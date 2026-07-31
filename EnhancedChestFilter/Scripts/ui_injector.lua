local config = require("config")
local manager = require("chest_filter_manager")
local bus = require("bus_helper")
local UEHelpers = require("UEHelpers")

local M = {}
local insertedRowWidget = nil
local activeChestGuid = nil
local lastInteractiveObjectPtr = nil

local chestRegistry = {}
local cachedCanvas = nil

local function Log(msg)
    if config.EnableDebugLog then
        print(string.format("[%s] [UI] %s", config.MOD_ID, tostring(msg)))
    end
end

local function Quiet(callback, fallback)
    local ok, value = pcall(function() return callback() end)
    if not ok or value == nil then return fallback end
    return value
end

local function Hex32(val)
    val = tonumber(val)
    if val == nil then return nil end
    if val < 0 then val = val + 4294967296 end
    return string.format("%08X", val)
end

local function GuidToString(guid)
    if not guid then return nil end
    return Quiet(function()
        local a, b, c, d = Hex32(guid.A), Hex32(guid.B), Hex32(guid.C), Hex32(guid.D)
        if a and b and c and d then
            return string.format("%s-%s-%s-%s", a, b, c, d)
        end
        return nil
    end, nil)
end

local function MakeFText(text)
    if FText == nil then return nil end
    local ok, val = pcall(function() return FText(tostring(text)) end)
    if ok and val then return val end
    return nil
end

local function Unwrap(obj)
    if obj == nil then return nil end
    return Quiet(function()
        if type(obj) == "userdata" and type(obj.get) == "function" then
            return obj:get()
        end
        return obj
    end, obj)
end

function M.FindIndicatorCanvasFast()
    if cachedCanvas and cachedCanvas:IsValid() then
        return cachedCanvas
    end

    local canvases = Quiet(function() return FindAllOf("WBP_PalInteractiveObjectIndicatorCanvas_C") end, nil)
    if not canvases then return nil end

    for _, canvasObj in pairs(canvases) do
        pcall(function()
            local canvas = Unwrap(canvasObj)
            if canvas and canvas:IsValid() then
                -- The CDO (Class Default Object) will not have initialized child widgets.
                -- Only the live, instantiated UI Canvas will have a valid IndicatorVerticalBox!
                local vBox = Unwrap(canvas.IndicatorVerticalBox)
                if vBox and vBox:IsValid() then
                    cachedCanvas = canvas
                end
            end
        end)
        if cachedCanvas then break end
    end
    
    return cachedCanvas
end

function M.ExtractChestGuid(obj)
    obj = Unwrap(obj)
    if not obj then return nil end
    
    pcall(function()
        if type(obj) == "userdata" then
            if obj.Self then
                local selfObj = obj:Self()
                if selfObj and selfObj:IsValid() then
                    obj = Unwrap(selfObj)
                end
            end
            if obj.GetOwner then
                local owner = obj:GetOwner()
                if owner and owner:IsValid() then
                    obj = Unwrap(owner)
                end
            end
        end
    end)

    local isChest = false
    pcall(function()
        if obj and obj:IsValid() then
            -- Check if the actor has any of the specific container parameter components natively!
            local hasChestParam = false
            pcall(function() 
                local p = obj.PalMapObjectItemChestParameter 
                if type(p) == "userdata" and p:IsValid() then hasChestParam = true end 
            end)
            
            local hasFoodParam = false
            pcall(function() 
                local p = obj.FoodBoxParameter 
                if type(p) == "userdata" and p:IsValid() then hasFoodParam = true end 
            end)
            
            local hasMedicineParam = false
            pcall(function() 
                local p = obj.MedicineBoxParameter 
                if type(p) == "userdata" and p:IsValid() then hasMedicineParam = true end 
            end)
            
            if hasChestParam or hasFoodParam or hasMedicineParam then
                isChest = true
            end
        end
    end)
    if not isChest then return nil end

    local chestGuidStr = nil
    pcall(function()
        if obj.InstanceId then
            chestGuidStr = GuidToString(obj.InstanceId)
        end
    end)
    if not chestGuidStr then
        pcall(function()
            if obj.ConcreteModel then
                local cm = Unwrap(obj.ConcreteModel)
                if cm and cm.InstanceId then
                    chestGuidStr = GuidToString(cm.InstanceId)
                end
            end
        end)
    end
    if not chestGuidStr then
        pcall(function()
            if obj.GetModel then
                local model = obj:GetModel()
                if model and model.InstanceId then
                    chestGuidStr = GuidToString(model.InstanceId)
                end
            end
        end)
    end
    return chestGuidStr
end

local function ScanChestsBackground()
    pcall(function()
        local chests = FindAllOf("PalMapObjectItemChest")
        if not chests or #chests == 0 then
            chests = FindAllOf("PalMapObject")
        end
        if chests then
            local newRegistry = {}
            for _, chest in ipairs(chests) do
                if chest and chest:IsValid() then
                    pcall(function()
                        local chestName = string.lower(chest:GetFullName())
                        if string.find(chestName, "chest") or string.find(chestName, "container") or string.find(chestName, "treasurebox") or string.find(chestName, "locker") or string.find(chestName, "box") or string.find(chestName, "shelf") or string.find(chestName, "barrel") or string.find(chestName, "closet") then
                            local loc = chest:K2_GetActorLocation()
                            local guid = M.ExtractChestGuid(chest)
                            if guid then
                                table.insert(newRegistry, { x = loc.X, y = loc.Y, z = loc.Z, guid = guid })
                            end
                        end
                    end)
                end
            end
            chestRegistry = newRegistry
            Log("Background Scan Complete: Cached " .. tostring(#chestRegistry) .. " chests.")
        end
    end)
end

function M.FindClosestChestGuidFromRegistry()
    local chestGuid = nil
    -- Optimize: Use squared distance checks to avoid expensive math.sqrt and ^2 operations in a tight loop
    local minDistSq = 800 * 800
    local distLog = ""

    local ok, err = pcall(function()
        local player = FindFirstOf("PalPlayerCharacter")
        if player and player:IsValid() then
            local playerLoc = player:K2_GetActorLocation()
            local px, py, pz = playerLoc.X, playerLoc.Y, playerLoc.Z
            for _, data in ipairs(chestRegistry) do
                local dx = px - data.x
                local dy = py - data.y
                local dz = pz - data.z
                local distSq = dx * dx + dy * dy + dz * dz

                if distSq < (1200 * 1200) then
                    local dist = math.sqrt(distSq)
                    distLog = distLog .. string.format("[%.1f]", dist)
                end
                if distSq < minDistSq then
                    minDistSq = distSq
                    chestGuid = data.guid
                end
            end
        else
            error("PalPlayerCharacter not found")
        end
    end)
    
    if not ok then
        Log("FindClosest ERROR: " .. tostring(err))
    else
        local nearestDist = minDistSq == (800 * 800) and 800 or math.sqrt(minDistSq)
        Log(string.format("FindClosest evaluated. Nearest dist: %.1f | Found: %s | Close dists: %s", nearestDist, tostring(chestGuid ~= nil), distLog))
    end
    
    return chestGuid
end



local originalActionText = nil

function M.InjectCustomUI(canvas, vBox)
    local childCount = vBox:GetChildrenCount()
    if childCount == 0 then return end
    
    local nativeTemplateRow = Unwrap(vBox:GetChildAt(childCount - 1))
    if not nativeTemplateRow or not nativeTemplateRow:IsValid() then return end
    
    local isStrict = manager.GetChestStrict(activeChestGuid)
    local statusText = isStrict and "Apenas itens em estoque: LIGADO" or "Apenas itens em estoque: DESATIVADO"
    
    -- Check if we already injected our custom row
    if insertedRowWidget and insertedRowWidget:IsValid() then
        if not insertedRowWidget:GetParent() then
            vBox:AddChild(insertedRowWidget)
        end
        insertedRowWidget:SetVisibility(4)
        
        -- Update the text on our custom row
        pcall(function()
            local finalDisplayText = "[N] " .. statusText
            if insertedRowWidget.SetText then
                insertedRowWidget:SetText(MakeFText(finalDisplayText))
            end
        end)
        return
    end
    
    -- Create a completely new UTextBlock
    local ok, err = pcall(function()
        local UTextBlock_C = StaticFindObject("/Script/UMG.TextBlock")
        local newText = StaticConstructObject(UTextBlock_C, vBox, "filter_text", 0, false)
        
        if newText and newText:IsValid() then
            insertedRowWidget = newText
            
            -- Basic styling
            pcall(function()
                newText:SetRenderOpacity(1.0)
                newText:SetVisibility(4) -- SelfHitTestInvisible
                
                -- Attempt to set nice font
                local fontInfo = newText.Font
                if fontInfo then
                    fontInfo.Size = 18
                    fontInfo.OutlineSettings.OutlineSize = 2
                    fontInfo.OutlineSettings.OutlineColor = {R=0, G=0, B=0, A=1}
                    newText:SetFont(fontInfo)
                end
                
                newText:SetShadowColorAndOpacity({R=0, G=0, B=0, A=0.8})
                newText:SetShadowOffset({X=1, Y=1})
                
                local finalDisplayText = "[N] " .. statusText
                newText:SetText(MakeFText(finalDisplayText))
            end)
            
            local slot = vBox:AddChild(newText)
            if slot and slot:IsValid() then
                slot.Padding.Top = 4.0
                slot.Padding.Bottom = 4.0
            end
            
            Log("InjectCustomUI: SUCCESS: Constructed UTextBlock row!")
        end
    end)
    
    if not ok then
        Log("InjectCustomUI CLONE ERROR: " .. tostring(err))
    end
end

function M.UpdateCustomUIString(isStrict)
    Log("UpdateCustomUIString: Triggering manual UI update...")
    -- Trigger an immediate update by re-running the injection
    pcall(function()
        local canvas = M.FindIndicatorCanvasFast()
        if canvas and canvas:IsValid() then
            local vBox = Unwrap(canvas.IndicatorVerticalBox)
            if vBox and vBox:IsValid() then
                Log("UpdateCustomUIString: Injecting...")
                M.InjectCustomUI(canvas, vBox)
            else
                Log("UpdateCustomUIString ERROR: vBox is invalid!")
            end
        else
            Log("UpdateCustomUIString ERROR: Canvas is invalid!")
        end
    end)
end

function M.OnHotkeyNPressed()
    Log("HOTKEY [N] TOGGLED!")

    if activeChestGuid then
        local currentStrict = manager.GetChestStrict(activeChestGuid)
        local newStrict = not currentStrict
        Log("Chest is now " .. (newStrict and "Strict" or "Normal"))
        manager.SetChestStrict(activeChestGuid, newStrict)
        
        -- Instantly update the UI text
        M.UpdateCustomUIString(newStrict)
    else
        Log("Key [N] pressed, but no targeted chest within range.")
    end
end

function M.InitializeHooks()
    Log("Initializing UI Background Loop & Keybind [N]...")

    pcall(function()
        local registerKeybind = _G.RegisterKeyBind or RegisterKeyBind
        registerKeybind(Key.N, function()
            pcall(ExecuteInGameThread, M.OnHotkeyNPressed)
        end)
        Log("SUCCESS: Registered hotkey [N]!")
    end)

    local function FindCanvasPathLoop()
        pcall(function()
            local canvas = M.FindIndicatorCanvasFast()
            if canvas and canvas:IsValid() then
                local vBox = Unwrap(canvas.IndicatorVerticalBox)
                if vBox and vBox:IsValid() then
                    local count = vBox:GetChildrenCount()
                    local currentChestGuid = nil
                    
                    if count > 0 then
                        local cachedPlayer = UEHelpers.GetPlayer()
                        if cachedPlayer and cachedPlayer:IsValid() then
                            local interactComp = cachedPlayer.InteractComponent
                            if interactComp and interactComp:IsValid() then
                                local targetInt = interactComp.TargetInteractiveObject
                                if targetInt then
                                    local target = Unwrap(targetInt)
                                    if target and target:IsValid() then
                                        currentChestGuid = M.ExtractChestGuid(target)
                                    end
                                end
                            end
                        end
                    end
                    
                    -- Global state update for the keybind
                    activeChestGuid = currentChestGuid

                    -- Inject/Update or Hide our UI row based on state
                    if activeChestGuid then
                        M.InjectCustomUI(canvas, vBox)
                    else
                        -- Hide our custom row if we look away from a chest
                        if insertedRowWidget and insertedRowWidget:IsValid() then
                            insertedRowWidget:SetVisibility(1) -- Collapsed
                        end
                    end
                end
            end
        end)
        ExecuteWithDelay(20, FindCanvasPathLoop)
    end
    ExecuteWithDelay(1000, FindCanvasPathLoop)
end

return M
