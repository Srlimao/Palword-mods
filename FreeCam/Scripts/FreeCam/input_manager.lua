-- FreeCam Input Manager component
local config = require("FreeCam.config")

local input_manager = {}

-- Pre-allocate FNames to prevent massive string table allocation lag
local KeyW = FName("W")
local KeyS = FName("S")
local KeyA = FName("A")
local KeyD = FName("D")
local GamepadLeftX = { KeyName = FName("Gamepad_LeftX") }
local GamepadLeftY = { KeyName = FName("Gamepad_LeftY") }
local GamepadDPadUp = { KeyName = FName("Gamepad_DPad_Up") }
local GamepadDPadDown = { KeyName = FName("Gamepad_DPad_Down") }
local GamepadDPadRight = { KeyName = FName("Gamepad_DPad_Right") }
local GamepadDPadLeft = { KeyName = FName("Gamepad_DPad_Left") }

-- Pre-allocated key objects to prevent per-frame input checking allocations
local KeyW_Obj = { KeyName = KeyW }
local KeyS_Obj = { KeyName = KeyS }
local KeyA_Obj = { KeyName = KeyA }
local KeyD_Obj = { KeyName = KeyD }

local modKeyObj = nil
local toggleKeyObj = nil
local flyUpGpKeyObj = nil
local flyDownGpKeyObj = nil
local flyUpKbKeyObj = nil
local flyDownKbKeyObj = nil

local function CacheConfigKeyObjects()
    if config.CONFIG.Gamepad then
        local modName = config.CONFIG.Gamepad.ModifierButton or "Gamepad_LeftTrigger"
        local toggleName = config.CONFIG.Gamepad.ToggleButton or "Gamepad_Special_Right"
        local flyUpGp = config.CONFIG.Gamepad.FlyUpButton or "Gamepad_RightThumbstick"
        local flyDownGp = config.CONFIG.Gamepad.FlyDownButton or "Gamepad_LeftThumbstick"

        modKeyObj = (modName ~= "None" and modName ~= "") and { KeyName = FName(modName) } or nil
        toggleKeyObj = { KeyName = FName(toggleName) }
        flyUpGpKeyObj = (flyUpGp ~= "None" and flyUpGp ~= "") and { KeyName = FName(flyUpGp) } or nil
        flyDownGpKeyObj = (flyDownGp ~= "None" and flyDownGp ~= "") and { KeyName = FName(flyDownGp) } or nil
    end

    if config.CONFIG.KeyBinds then
        local flyUpKb = config.CONFIG.KeyBinds.FlyUp or "SpaceBar"
        local flyDownKb = config.CONFIG.KeyBinds.FlyDown or "LeftShift"
        flyUpKbKeyObj = { KeyName = FName(flyUpKb) }
        flyDownKbKeyObj = { KeyName = FName(flyDownKb) }
    end
end

function input_manager.RefreshConfigCache()
    CacheConfigKeyObjects()
end

-- Check if the FreeCam toggle shortcut is pressed
function input_manager.IsToggleShortcutPressed(pc)
    if not pc or not pc:IsValid() then return false end
    
    local inputMode = config.CONFIG.InputMode or "Keyboard"
    if inputMode == "Gamepad" and config.CONFIG.Gamepad then
        if not toggleKeyObj then CacheConfigKeyObjects() end
        local isModDown = true
        if modKeyObj then
            isModDown = pc:IsInputKeyDown(modKeyObj)
        end
        return isModDown and pc:WasInputKeyJustPressed(toggleKeyObj)
    end
    
    return false
end

-- Poll movement keys/sticks and populate outMoveDir
function input_manager.PollMovement(pc, outMoveDir, forwardVec, rightVec, upVec)
    outMoveDir.X, outMoveDir.Y, outMoveDir.Z = 0.0, 0.0, 0.0
    if not pc or not pc:IsValid() then return end
    
    if not toggleKeyObj then CacheConfigKeyObjects() end
    local inputMode = config.CONFIG.InputMode or "Keyboard"
    
    if inputMode == "Keyboard" then
        if pc:IsInputKeyDown(KeyW_Obj) then
            outMoveDir.X = outMoveDir.X + forwardVec.X
            outMoveDir.Y = outMoveDir.Y + forwardVec.Y
            outMoveDir.Z = outMoveDir.Z + forwardVec.Z
        end
        if pc:IsInputKeyDown(KeyS_Obj) then
            outMoveDir.X = outMoveDir.X - forwardVec.X
            outMoveDir.Y = outMoveDir.Y - forwardVec.Y
            outMoveDir.Z = outMoveDir.Z - forwardVec.Z
        end
        if pc:IsInputKeyDown(KeyD_Obj) then
            outMoveDir.X = outMoveDir.X + rightVec.X
            outMoveDir.Y = outMoveDir.Y + rightVec.Y
            outMoveDir.Z = outMoveDir.Z + rightVec.Z
        end
        if pc:IsInputKeyDown(KeyA_Obj) then
            outMoveDir.X = outMoveDir.X - rightVec.X
            outMoveDir.Y = outMoveDir.Y - rightVec.Y
            outMoveDir.Z = outMoveDir.Z - rightVec.Z
        end
        if flyUpKbKeyObj and pc:IsInputKeyDown(flyUpKbKeyObj) then
            outMoveDir.X = outMoveDir.X + upVec.X
            outMoveDir.Y = outMoveDir.Y + upVec.Y
            outMoveDir.Z = outMoveDir.Z + upVec.Z
        end
        if flyDownKbKeyObj and pc:IsInputKeyDown(flyDownKbKeyObj) then
            outMoveDir.X = outMoveDir.X - upVec.X
            outMoveDir.Y = outMoveDir.Y - upVec.Y
            outMoveDir.Z = outMoveDir.Z - upVec.Z
        end
    elseif inputMode == "Gamepad" and config.CONFIG.Gamepad then
        local stickX = pc:GetInputAnalogKeyState(GamepadLeftX) or 0.0
        local stickY = pc:GetInputAnalogKeyState(GamepadLeftY) or 0.0
        if type(stickX) == "userdata" and stickX.get then stickX = stickX:get() end
        if type(stickY) == "userdata" and stickY.get then stickY = stickY:get() end

        if math.abs(stickY) > 0.15 then
            outMoveDir.X = outMoveDir.X + forwardVec.X * stickY
            outMoveDir.Y = outMoveDir.Y + forwardVec.Y * stickY
            outMoveDir.Z = outMoveDir.Z + forwardVec.Z * stickY
        end
        if math.abs(stickX) > 0.15 then
            outMoveDir.X = outMoveDir.X + rightVec.X * stickX
            outMoveDir.Y = outMoveDir.Y + rightVec.Y * stickX
            outMoveDir.Z = outMoveDir.Z + rightVec.Z * stickX
        end

        if flyUpGpKeyObj and pc:IsInputKeyDown(flyUpGpKeyObj) then
            outMoveDir.X = outMoveDir.X + upVec.X
            outMoveDir.Y = outMoveDir.Y + upVec.Y
            outMoveDir.Z = outMoveDir.Z + upVec.Z
        end
        if flyDownGpKeyObj and pc:IsInputKeyDown(flyDownGpKeyObj) then
            outMoveDir.X = outMoveDir.X - upVec.X
            outMoveDir.Y = outMoveDir.Y - upVec.Y
            outMoveDir.Z = outMoveDir.Z - upVec.Z
        end

        if pc:IsInputKeyDown(GamepadDPadUp) then
            outMoveDir.X = outMoveDir.X + forwardVec.X
            outMoveDir.Y = outMoveDir.Y + forwardVec.Y
            outMoveDir.Z = outMoveDir.Z + forwardVec.Z
        end
        if pc:IsInputKeyDown(GamepadDPadDown) then
            outMoveDir.X = outMoveDir.X - forwardVec.X
            outMoveDir.Y = outMoveDir.Y - forwardVec.Y
            outMoveDir.Z = outMoveDir.Z - forwardVec.Z
        end
        if pc:IsInputKeyDown(GamepadDPadRight) then
            outMoveDir.X = outMoveDir.X + rightVec.X
            outMoveDir.Y = outMoveDir.Y + rightVec.Y
            outMoveDir.Z = outMoveDir.Z + rightVec.Z
        end
        if pc:IsInputKeyDown(GamepadDPadLeft) then
            outMoveDir.X = outMoveDir.X - rightVec.X
            outMoveDir.Y = outMoveDir.Y - rightVec.Y
            outMoveDir.Z = outMoveDir.Z - rightVec.Z
        end
    end
end

-- Poll speed modifiers from PageUp/PageDown / Gamepad D-pad Up/Down (when modifiers aren't down)
function input_manager.PollSpeedAdjustment(pc)
    return 0.0
end

return input_manager
