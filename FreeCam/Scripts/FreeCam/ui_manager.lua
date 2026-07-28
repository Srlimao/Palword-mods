-- FreeCam UI Manager component
-- Handles building window button injection ([L] Free Cam) and Esc key exit

local UEHelpers = require("UEHelpers")
local config = require("FreeCam.config")
local camera = require("FreeCam.camera")
local helpers = require("FreeCam.helpers")

local ui_manager = {}

local isHooked = false
local escKeyBound = false
local lKeyBound = false

-- Safe wrapper helper
local function quiet(fn, fallback)
    local ok, res = pcall(fn)
    if ok then return res end
    return fallback
end

local function unwrap(val)
    if type(val) == "userdata" and val.get then
        local ok, res = pcall(function() return val:get() end)
        if ok and res ~= nil then return res end
    end
    return val
end

local function is_valid(obj)
    obj = unwrap(obj)
    if not obj or type(obj) ~= "userdata" then return false end
    return quiet(function() return obj:IsValid() end, false) == true
end

-- Find key guide texture for keyboard letter
local function find_key_texture(letter)
    if StaticFindObject == nil then return nil end
    local asset = "/Game/Pal/Texture/UI/KeyGuide/keyboard/T_KeyGuide_Keyboard_" .. letter .. ".T_KeyGuide_Keyboard_" .. letter
    local paths = { asset, "Texture2D " .. asset }
    for _, path in ipairs(paths) do
        local texture = unwrap(quiet(function() return StaticFindObject(path) end, nil))
        if is_valid(texture) then return texture end
    end
    if LoadAsset ~= nil then
        for _, path in ipairs(paths) do
            if string.sub(path, 1, 1) == "/" then
                quiet(function() LoadAsset(path) end, nil)
                local texture = unwrap(quiet(function() return StaticFindObject(path) end, nil))
                if is_valid(texture) then return texture end
            end
        end
    end
    return nil
end

-- Helper: Create FText from string
local function make_ftext(str)
    if not str then return nil end
    local kismetText = StaticFindObject("/Script/Engine.Default__KismetTextLibrary")
    if kismetText and is_valid(kismetText) then
        local res = nil
        pcall(function() res = kismetText:Conv_StringToText(FString(str)) end)
        if res then return res end
    end
    local ok, res = pcall(function() return FText(str) end)
    if ok and res then return res end
    return str
end

-- Construct a new object safely using StaticConstructObject
local function construct_object(class_path, outer)
    if not StaticFindObject or not StaticConstructObject then return nil end
    local class = unwrap(quiet(function() return StaticFindObject(class_path) end, nil))
    if not is_valid(class) or not is_valid(outer) then return nil end
    local created = unwrap(quiet(function()
        return StaticConstructObject(class, outer, 0, 0, 0, nil, false, false, nil)
    end, nil))
    if is_valid(created) then return created end
    return nil
end

-- Setup [L] Free Cam button in the Building Menu
local function SetupBuildingMenuButton(menu)
    menu = unwrap(menu)
    if not is_valid(menu) then return end

    -- Check if custom button already injected
    local existing = quiet(function() return menu.Canvas_FreeCam end, nil)
    if is_valid(existing) then return end

    local canvasPaint = unwrap(quiet(function() return menu.Canvas_Paint end, nil))
    if not is_valid(canvasPaint) then
        config.DebugPrint("SetupBuildingMenuButton: Canvas_Paint not found on menu.")
        return
    end

    local parentContainer = unwrap(quiet(function() return canvasPaint:GetParent() end, nil))
    if not is_valid(parentContainer) then
        config.DebugPrint("SetupBuildingMenuButton: Parent container of Canvas_Paint not found.")
        return
    end

    local tree = unwrap(quiet(function() return menu.WidgetTree end, nil))
    local outer = is_valid(tree) and tree or menu

    -- Create custom HorizontalBox for our button layout
    local boxClass = "/Script/UMG.HorizontalBox"
    local containerBox = construct_object(boxClass, outer)
    if not is_valid(containerBox) then
        config.DebugPrint("SetupBuildingMenuButton: Could not construct HorizontalBox container.")
        return
    end

    -- Create SizeBox wrapper for layout padding/sizing
    local sizeBoxClass = "/Script/UMG.SizeBox"
    local sizeBox = construct_object(sizeBoxClass, outer)
    if is_valid(sizeBox) then
        quiet(function()
            sizeBox.WidthOverride = 32.0
            sizeBox.HeightOverride = 32.0
            sizeBox.bOverride_WidthOverride = true
            sizeBox.bOverride_HeightOverride = true
        end, nil)
    end

    -- Create Key Icon Image
    local imageClass = "/Script/UMG.Image"
    local keyImage = construct_object(imageClass, outer)
    local keyTexture = find_key_texture("L")
    if is_valid(keyImage) and is_valid(keyTexture) then
        quiet(function()
            keyImage:SetBrushFromTexture(keyTexture, false)
            keyImage.Brush.ImageSize = { X = 32.0, Y = 32.0 }
            keyImage.Brush.DrawAs = 3
        end, nil)
    end

    -- Create Text Block for "Free Cam" label
    local textClass = "/Script/UMG.TextBlock"
    local textBlock = construct_object(textClass, outer)
    if not is_valid(textBlock) then
        textClass = "/Script/Pal.BP_PalTextBlock_C"
        textBlock = construct_object(textClass, outer)
    end

    if is_valid(textBlock) then
        local labelText = make_ftext("Free Cam")
        quiet(function()
            textBlock:SetText(labelText)
            textBlock.Font.Size = 14
            textBlock.ColorAndOpacity = { SpecifiedColor = { R = 1.0, G = 1.0, B = 1.0, A = 1.0 } }
            textBlock.Margin = { Left = 6.0, Top = 0.0, Right = 12.0, Bottom = 0.0 }
        end, nil)
    end

    -- Add key image into size box (or container box)
    if is_valid(sizeBox) and is_valid(keyImage) then
        local imgSlot = unwrap(quiet(function() return sizeBox:AddChild(keyImage) end, nil))
        if is_valid(imgSlot) then
            quiet(function()
                imgSlot.HorizontalAlignment = 2 -- Center
                imgSlot.VerticalAlignment = 2   -- Center
            end, nil)
        end
        containerBox:AddChild(sizeBox)
    elseif is_valid(keyImage) then
        containerBox:AddChild(keyImage)
    end

    -- Add text label to container box
    if is_valid(textBlock) then
        local txtSlot = unwrap(quiet(function() return containerBox:AddChild(textBlock) end, nil))
        if is_valid(txtSlot) then
            quiet(function()
                txtSlot.VerticalAlignment = 2 -- Center
            end, nil)
        end
    end

    -- Create or clone Invisible Button overlay for mouse interaction
    local btnPaint = unwrap(quiet(function() return menu.WBP_PalInvisibleButton_Paint end, nil))
    local invButton = nil
    if is_valid(btnPaint) then
        invButton = unwrap(quiet(function()
            return StaticConstructObject(btnPaint:GetClass(), outer, 0, 0, 0, nil, false, false, nil)
        end, nil))
    end

    -- Overlay Box to layer containerBox and invButton
    local overlayClass = "/Script/UMG.Overlay"
    local overlay = construct_object(overlayClass, outer)
    if is_valid(overlay) then
        overlay:AddChild(containerBox)
        if is_valid(invButton) then
            overlay:AddChild(invButton)
        end
    end

    local finalWidget = is_valid(overlay) and overlay or containerBox

    -- Attach into parent container next to Canvas_Paint
    local parentSlot = unwrap(quiet(function() return parentContainer:AddChild(finalWidget) end, nil))
    if is_valid(parentSlot) then
        quiet(function()
            parentSlot.VerticalAlignment = 2 -- Center
            parentSlot.Padding = { Left = 16.0, Top = 0.0, Right = 0.0, Bottom = 0.0 }
        end, nil)
        
        -- Store reference on menu to avoid duplicate creation
        pcall(function() menu.Canvas_FreeCam = finalWidget end)
        pcall(function() menu.WBP_PalInvisibleButton_FreeCam = invButton end)
        
        config.DebugPrint("Successfully attached [L] Free Cam button to building menu UI!")
    else
        config.DebugPrint("Failed to attach [L] Free Cam button slot to building menu parent container.")
    end
end

-- Keybind Registration for 'L' and 'Esc'
local function RegisterKeyBinds()
    if not lKeyBound then
        local keyL = Key.L or Key.l or 0x4C
        RegisterKeyBind(keyL, {}, function()
            local pc = UEHelpers.GetPlayerController()
            if not pc or not pc:IsValid() then return end

            -- Check if building menu is currently visible or open
            local isBuildingMenuOpen = false
            pcall(function()
                local menu = FindFirstOf("WBP_IngameMenu_Construction_Menu_C")
                if menu and menu:IsValid() and menu:IsVisible() then
                    isBuildingMenuOpen = true
                end
            end)

            if isBuildingMenuOpen or camera.IsSpectating() then
                print("[FreeCam] L key pressed in building menu or FreeCam active. Toggling FreeCam...")
                camera.ToggleFreeCam()
            end
        end)
        lKeyBound = true
        config.DebugPrint("Registered 'L' keybind for FreeCam toggle in building menu.")
    end

    if not escKeyBound then
        local keyEsc = Key.ESCAPE or Key.Escape or Key.Esc or 0x1B
        RegisterKeyBind(keyEsc, {}, function()
            if camera.IsSpectating() then
                print("[FreeCam] Esc key pressed while FreeCam active. Exiting FreeCam...")
                camera.ToggleFreeCam()
            end
        end)
        escKeyBound = true
        config.DebugPrint("Registered 'Esc' keybind for exiting FreeCam anywhere.")
    end
end

function ui_manager.Initialize()
    if isHooked then return end
    isHooked = true

    -- Hook Construction Menu Construction & Open Event
    local menuClass = "/Game/Pal/Blueprint/UI/UserInterface/IngameMenu/WBP_IngameMenu_Construction_Menu.WBP_IngameMenu_Construction_Menu_C"
    
    pcall(RegisterHook, menuClass .. ":Construct", function(self)
        local menu = self:get()
        if menu and menu:IsValid() then
            SetupBuildingMenuButton(menu)
        end
    end)

    pcall(RegisterHook, menuClass .. ":AnmEvent_Open", function(self)
        local menu = self:get()
        if menu and menu:IsValid() then
            SetupBuildingMenuButton(menu)
        end
    end)

    RegisterKeyBinds()
    config.DebugPrint("UI Manager initialized successfully.")
end

return ui_manager
