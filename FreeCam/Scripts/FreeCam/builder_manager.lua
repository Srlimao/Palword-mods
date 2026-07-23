-- FreeCam Builder Manager component
local builder_manager = {}
local helpers = require("FreeCam.helpers")

local originalInstallDistance = 400.0
local lastBuilderMode = -1
local lastDismantleTarget = nil
local lastLogTime = 0.0
local buildModeTicks = 0
local hasSetSnapMode = false
local customRotationYaw = 0.0
builder_manager.TargetSnapYaw = nil

local originalBuilderModeInstallableRange = 1000.0
local originalPaintBuildModeInstallableRange = 1000.0
local originalJumpSP = 15
local originalStepSP = 10
local originalSprintSP = 20.0
local originalGliderSP = 15.0

local function SafeCheckIsSnapMode(builder)
    return builder:IsSnapMode()
end

local function IsConstructionPart(objectIdStr)
    if not objectIdStr then return false end
    local lower = string.lower(objectIdStr)
    local keywords = {
        "wall", "floor", "roof", "stair", "foundation", "pillar",
        "door", "gate", "fence", "window", "support", "slope",
        "attachment"
    }
    for _, kw in ipairs(keywords) do
        if string.find(lower, kw, 1, true) then
            return true
        end
    end
    return false
end

local function SafeSetDismantleVisual(actor, state)
    if actor and actor:IsValid() and actor.OnChangeVisualForDismantle then
        actor:OnChangeVisualForDismantle(state)
    end
end

function builder_manager.GetReticleTargetObject()
    return lastDismantleTarget
end

function builder_manager.ResetSnapModeState()
    buildModeTicks = 0
    hasSetSnapMode = false
    customRotationYaw = 0.0
end

function builder_manager.RotateTarget(bRight)
    local step = 90.0
    if bRight then
        customRotationYaw = (customRotationYaw + step) % 360.0
    else
        customRotationYaw = (customRotationYaw - step) % 360.0
    end
    print("[FreeCam] Rotate Target called. New customRotationYaw = " .. customRotationYaw)
end

-- Cache original installation distance
function builder_manager.Setup(player)
    if not player or not player:IsValid() then return false end
    
    local builder = player.BuilderComponent
    if not builder or not builder:IsValid() then return false end
    
    originalInstallDistance = builder.InstallDistanceNormalFromOwner
    pcall(function() if type(originalInstallDistance) == "userdata" then originalInstallDistance = originalInstallDistance:get() end end)
    if not originalInstallDistance or originalInstallDistance < 10.0 then
        originalInstallDistance = 400.0
    end
    
    -- Dynamically extend the PalGameSetting building trace ranges and disable stamina costs
    local _, PalUtility = helpers.GetEngineHelpers()
    if PalUtility and PalUtility:IsValid() then
        local gameSetting = PalUtility:GetGameSetting(player)
        if gameSetting and gameSetting:IsValid() then
            originalBuilderModeInstallableRange = gameSetting.BuilderModeInstallableRange
            pcall(function() if type(originalBuilderModeInstallableRange) == "userdata" then originalBuilderModeInstallableRange = originalBuilderModeInstallableRange:get() end end)
            
            originalPaintBuildModeInstallableRange = gameSetting.PaintBuildModeInstallableRange
            pcall(function() if type(originalPaintBuildModeInstallableRange) == "userdata" then originalPaintBuildModeInstallableRange = originalPaintBuildModeInstallableRange:get() end end)
            
            originalJumpSP = gameSetting.JumpSP
            pcall(function() if type(originalJumpSP) == "userdata" then originalJumpSP = originalJumpSP:get() end end)
            
            originalStepSP = gameSetting.StepSP
            pcall(function() if type(originalStepSP) == "userdata" then originalStepSP = originalStepSP:get() end end)
            
            originalSprintSP = gameSetting.SprintSP
            pcall(function() if type(originalSprintSP) == "userdata" then originalSprintSP = originalSprintSP:get() end end)
            
            originalGliderSP = gameSetting.GliderSP
            pcall(function() if type(originalGliderSP) == "userdata" then originalGliderSP = originalGliderSP:get() end end)
            
            -- Set trace distance to 40 meters (4000.0 units)
            gameSetting.BuilderModeInstallableRange = 4000.0
            gameSetting.PaintBuildModeInstallableRange = 4000.0
            
            -- Disable stamina costs
            gameSetting.JumpSP = 0
            gameSetting.StepSP = 0
            gameSetting.SprintSP = 0.0
            gameSetting.GliderSP = 0.0
            print("[FreeCam] Extended trace range and disabled stamina costs successfully.")
        end
    end
    
    lastBuilderMode = -1
    lastDismantleTarget = nil
    lastLogTime = 0.0
    buildModeTicks = 0
    hasSetSnapMode = false
    builder_manager.TargetSnapYaw = nil
    return true
end

-- Restore builder distance and clear outlines
function builder_manager.Teardown(player)
    if not player or not player:IsValid() then return end
    
    local builder = player.BuilderComponent
    if builder and builder:IsValid() then
        builder.InstallDistanceNormalFromOwner = originalInstallDistance
    end
    
    -- Restore UPalGameSetting building trace ranges and stamina costs
    local _, PalUtility = helpers.GetEngineHelpers()
    if PalUtility and PalUtility:IsValid() then
        local gameSetting = PalUtility:GetGameSetting(player)
        if gameSetting and gameSetting:IsValid() then
            gameSetting.BuilderModeInstallableRange = originalBuilderModeInstallableRange or 1000.0
            gameSetting.PaintBuildModeInstallableRange = originalPaintBuildModeInstallableRange or 1000.0
            gameSetting.JumpSP = originalJumpSP or 15
            gameSetting.StepSP = originalStepSP or 10
            gameSetting.SprintSP = originalSprintSP or 20.0
            gameSetting.GliderSP = originalGliderSP or 15.0
            print("[FreeCam] Restored trace settings and stamina costs successfully.")
        end
    end
    
    if lastDismantleTarget and lastDismantleTarget:IsValid() then
        pcall(SafeSetDismantleVisual, lastDismantleTarget, false)
        lastDismantleTarget.bDismantleTargetInLocal = false
    end
    
    pcall(SafeSetDismantleVisual, player, false)
    lastDismantleTarget = nil
    buildModeTicks = 0
    hasSetSnapMode = false
    builder_manager.TargetSnapYaw = nil
end

-- Update building/dismantling state and components
function builder_manager.Update(player, pc, cameraRotation, aimLocation, aimDistance, hitActor)
    if not player or not player:IsValid() or not pc or not pc:IsValid() then return end
    
    local builder = player.BuilderComponent
    if not builder or not builder:IsValid() then return end
    
    local mode = builder:GetCurrentMode()
    local modeNum = 0
    if type(mode) == "number" then
        modeNum = mode
    elseif type(mode) == "userdata" and mode.get then
        modeNum = mode:get()
    end
    
    local timeNow = os.clock()
    if modeNum ~= lastBuilderMode then
        lastBuilderMode = modeNum
        print(string.format("[FreeCam Debug] Builder Mode Changed: mode = %d (0=None, 1=Building, 2=Dismantling, 3=Painting)", modeNum))
    end
    
    -- Auto-toggle Snap Mode to true with a safe 30-frame delay (approx 0.5s) after entering building mode
    -- Only auto-enables snap mode for production/freestanding buildings (filtering out walls/construction parts)
    if modeNum ~= 1 then
        buildModeTicks = 0
        hasSetSnapMode = false
    else
        buildModeTicks = buildModeTicks + 1
        if buildModeTicks == 30 and not hasSetSnapMode then
            local models = FindAllOf("PalUIBuildingModel")
            if models then
                for _, model in ipairs(models) do
                    if model:IsValid() then
                        local objId = model.BuildObjectId
                        local objIdStr = "None"
                        if objId then
                            if type(objId) == "userdata" and objId.ToString then
                                objIdStr = objId:ToString()
                            elseif type(objId) == "string" then
                                objIdStr = objId
                            end
                        end
                        
                        local isConstruction = IsConstructionPart(objIdStr)
                        print(string.format("[FreeCam] Build item selected: %s. IsConstructionPart = %s", objIdStr, tostring(isConstruction)))
                        
                        if not isConstruction and objIdStr ~= "None" and objIdStr ~= "" then
                            pcall(function()
                                model:ChangeSnapMode(true)
                                print("[FreeCam] Automatically enabled snap mode for production/freestanding building: " .. objIdStr)
                            end)
                        end
                        break
                    end
                end
            end
            hasSetSnapMode = true
        end
    end

    
    local isSnap = false
    if builder.IsSnapMode then
        isSnap = builder:IsSnapMode()
    end
    
    local isDismantle = (modeNum == 2)
    if isSnap or isDismantle then
        builder.InstallDistanceNormalFromOwner = originalInstallDistance * 15.0
    else
        builder.InstallDistanceNormalFromOwner = originalInstallDistance
    end
    
    if modeNum == 2 then
        pc:SetControlRotation(cameraRotation)
        local checker = builder.DismantleChecker
        
        -- Clear previous dismantle visual outline if target changed
        if lastDismantleTarget and lastDismantleTarget:IsValid() and lastDismantleTarget ~= hitActor then
            SafeSetDismantleVisual(lastDismantleTarget, false)
            lastDismantleTarget.bDismantleTargetInLocal = false
            lastDismantleTarget = nil
        end

        if hitActor and hitActor:IsValid() and hitActor ~= player then
            if checker and checker:IsValid() then
                checker.TargetBuildObject = hitActor
            end
            SafeSetDismantleVisual(hitActor, true)
            hitActor.bDismantleTargetInLocal = true
            lastDismantleTarget = hitActor
        end
        
        if (timeNow - lastLogTime) > 1.5 then
            lastLogTime = timeNow
            local targetName = "None"
            local hitActorName = (hitActor and hitActor:IsValid()) and hitActor:GetFullName() or "None"
            local targetObj = builder:GetDismantleTargetObject()
            if targetObj and targetObj:IsValid() then
                targetName = targetObj:GetFullName()
            end
            print(string.format("[FreeCam Debug] Dismantle Mode: hitActor=%s, GetDismantleTarget=%s", hitActorName, targetName))
        end
    else
        if lastDismantleTarget and lastDismantleTarget:IsValid() then
            SafeSetDismantleVisual(lastDismantleTarget, false)
            lastDismantleTarget.bDismantleTargetInLocal = false
            lastDismantleTarget = nil
        end
    end
    
    if not isSnap then
        -- Adjust Z offset of the character location to center blueprint previews with the reticle target
        local checker = builder.InstallChecker
        if checker and checker:IsValid() then
            local preview = checker.TargetBuildObject
            if preview and preview:IsValid() then
                local bounds = preview.LocalBounds
                if bounds then
                    local xMin = bounds.Min.X
                    local xMax = bounds.Max.X
                    local yMin = bounds.Min.Y
                    local yMax = bounds.Max.Y
                    local zMin = bounds.Min.Z
                    local zMax = bounds.Max.Z
                    if type(xMin) == "userdata" and xMin.get then xMin = xMin:get() end
                    if type(xMax) == "userdata" and xMax.get then xMax = xMax:get() end
                    if type(yMin) == "userdata" and yMin.get then yMin = yMin:get() end
                    if type(yMax) == "userdata" and yMax.get then yMax = yMax:get() end
                    if type(zMin) == "userdata" and zMin.get then zMin = zMin:get() end
                    if type(zMax) == "userdata" and zMax.get then zMax = zMax:get() end
                    
                    local xCenter = (xMin + xMax) / 2.0
                    local yCenter = (yMin + yMax) / 2.0
                    local zCenter = (zMin + zMax) / 2.0
                    
                    local forward = preview:GetActorForwardVector()
                    local right = preview:GetActorRightVector()
                    local up = preview:GetActorUpVector()
                    
                    local pfX, pfY, pfZ = forward.X, forward.Y, forward.Z
                    local prX, prY, prZ = right.X, right.Y, right.Z
                    local puX, puY, puZ = up.X, up.Y, up.Z
                    
                    if type(pfX) == "userdata" and pfX.get then pfX = pfX:get() pfY = pfY:get() pfZ = pfZ:get() end
                    if type(prX) == "userdata" and prX.get then prX = prX:get() prY = prY:get() prZ = prZ:get() end
                    if type(puX) == "userdata" and puX.get then puX = puX:get() puY = puY:get() puZ = puZ:get() end
                    
                    local worldOffsetX = pfX * xCenter + prX * yCenter + puX * zCenter
                    local worldOffsetY = pfY * xCenter + prY * yCenter + puY * zCenter
                    local worldOffsetZ = pfZ * xCenter + prZ * yCenter + puZ * zCenter
                    
                    aimLocation.X = aimLocation.X - worldOffsetX
                    aimLocation.Y = aimLocation.Y - worldOffsetY
                    aimLocation.Z = aimLocation.Z - worldOffsetZ
                end
            end
        end
    end
    
    builder_manager.TargetSnapYaw = nil
    if isSnap then
        -- In snap mode (Axis Alignment Mode), the blueprint's rotation is locked to the grid.
        -- If the blueprint is currently NOT snapped to any socket, we calculate our target cardinal Yaw.
        local checker = builder.InstallChecker
        if checker and checker:IsValid() then
            local strategy = checker.InstallStrategy
            local isSnapped = false
            if strategy and strategy:IsValid() then
                local snapCache = strategy.SnapHitBuildObjectCache
                if snapCache and snapCache:IsValid() then
                    isSnapped = true
                end
            end
            
            if not isSnapped then
                local camYaw = 0.0
                if cameraRotation then
                    if type(cameraRotation.Yaw) == "number" then
                        camYaw = cameraRotation.Yaw
                    elseif type(cameraRotation.Yaw) == "userdata" and cameraRotation.Yaw.get then
                        camYaw = cameraRotation.Yaw:get()
                    end
                end
                
                -- Align grid-snapped orientation to the camera look direction (nearest 90-deg) + manual scroll offset
                local snappedCamYaw = math.floor((camYaw + 45.0) / 90.0) * 90.0
                builder_manager.TargetSnapYaw = (snappedCamYaw + customRotationYaw) % 360.0
            end
        end
    end
end

return builder_manager
