# Gamepad Support Implementation Notes

This document outlines the technical details and code patterns required to implement gamepad hotkeys and menu navigation in the HUD Locator mod using Unreal Engine's input API instead of standard Win32 keybinds.

---

## 1. How Gamepad Detection Works
Because UE4SS `RegisterKeyBind` only maps to Win32 Virtual Key (VK) codes, gamepad buttons (XInput / DirectInput) are not natively detected by standard hotkey routines.

To bypass this limitation, we hook into the HUD drawing frame tick (`BP_PalHUD_InGame_C:ReceiveDrawHUD`) and poll the player controller using the following C++ API methods exposed to Lua:
*   `APlayerController:WasInputKeyJustPressed(FKey Key)` (True on the exact frame the button is pressed).
*   `APlayerController:IsInputKeyDown(FKey Key)` (True while the button is held).

---

## 2. Unreal Engine FKey Structure
In Unreal Engine, input keys are represented by the `FKey` struct which wraps a string-based `KeyName` (`FName`). 

We can instantiate a Lua table representing this structure:
```lua
local myGamepadKey = { KeyName = FName("Gamepad_Special_Right") }
```

### Gamepad Key Name Reference
Here are the common FKey names for standard gamepads:
*   **Menu/Options Button**: `"Gamepad_Special_Right"`
*   **Share/View Button**: `"Gamepad_Special_Left"`
*   **Face Buttons**:
    *   `"Gamepad_FaceButton_Bottom"` (A / Cross)
    *   `"Gamepad_FaceButton_Right"` (B / Circle)
    *   `"Gamepad_FaceButton_Left"` (X / Square)
    *   `"Gamepad_FaceButton_Top"` (Y / Triangle)
*   **Shoulder Buttons / Bumpers**:
    *   `"Gamepad_LeftShoulder"` (LB / L1)
    *   `"Gamepad_RightShoulder"` (RB / R1)
*   **Triggers**:
    *   `"Gamepad_LeftTrigger"` (LT / L2)
    *   `"Gamepad_RightTrigger"` (RT / R2)
*   **Thumbstick Clicks**:
    *   `"Gamepad_LeftThumbstick"` (LS / L3)
    *   `"Gamepad_RightThumbstick"` (RS / R3)
*   **D-Pad**:
    *   `"Gamepad_DPad_Up"`
    *   `"Gamepad_DPad_Down"`
    *   `"Gamepad_DPad_Left"`
    *   `"Gamepad_DPad_Right"`

---

## 3. Implementation Code Example

This block shows how to safely check for a gamepad combination (e.g., holding Left Trigger and pressing Options to toggle the menu) inside your HUD tick handler:

```lua
-- Add this within the ReceiveDrawHUD hook in main.lua
local isMenuOpen = false

RegisterHook("/Game/Pal/Blueprint/UI/BP_PalHUD_InGame.BP_PalHUD_InGame_C:ReceiveDrawHUD", function(self, SizeX, SizeY)
    local controller = self:get():GetPlayerController()
    if controller and controller:IsValid() then
        -- 1. Create FKeys for trigger modifier and button action
        local modifierKey = { KeyName = FName("Gamepad_LeftTrigger") }
        local toggleKey = { KeyName = FName("Gamepad_Special_Right") }
        
        -- 2. Check if LT is held and Options is pressed
        local isLTDown = false
        local isOptionsPressed = false
        
        pcall(function() isLTDown = controller:IsInputKeyDown(modifierKey) end)
        pcall(function() isOptionsPressed = controller:WasInputKeyJustPressed(toggleKey) end)
        
        if isLTDown and isOptionsPressed then
            print("[HUDLocator] Gamepad shortcut detected: Toggling menu.")
            menu.Toggle()
        end
    end
end)
```
