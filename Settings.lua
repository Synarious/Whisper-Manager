-- ============================================================================
-- Settings.lua - Settings UI and configuration
-- ============================================================================

local addon = WhisperManager;

-- ============================================================================
-- Default Settings
-- ============================================================================

 -- ARCHIVAL MARKER: Settings.lua (moved)
 --
 -- This file was previously a standalone settings implementation. It has been
 -- moved to debug_addons/Settings.lua.bak to avoid duplicate/unused code.
 -- The active settings UI is located at UI/Settings.lua and is the file
 -- referenced by WhisperManager.xml. If you need to restore the original
 -- implementation, copy the file from debug_addons/Settings.lua.bak back here.
 
 -- No runtime code lives in this placeholder.
 
 local addon = WhisperManager; -- placeholder to avoid syntax errors when loaded
 
 return
 }
    messageFontSize = 14,
    inputFontSize = 14,
    fontFamily = "Fonts\\ARIALN.TTF", -- Default to Arial per user request
    
    -- Message colors (using WoW's default whisper colors)
    whisperReceiveColor = {r = 1.0, g = 0.5, b = 1.0}, -- Pink (default whisper receive)
    -- Default whisper send color: #D832FF -> (216,50,255)
    whisperSendColor = {r = 216/255, g = 50/255, b = 255/255},
    bnetReceiveColor = {r = 0.0, g = 0.66, b = 1.0}, -- Blue (default BNet receive)
    -- Default BNet send color: #0072FF -> (0,114,255)
    bnetSendColor = {r = 0/255, g = 114/255, b = 255/255}, -- Blue (default BNet send)
    timestampColor = {r = 0.5, g = 0.5, b = 0.5}, -- Gray (timestamp color)
    
    -- Window appearance settings
    windowBackgroundColor = {r = 0.0, g = 0.0, b = 0.0}, -- Black background
    windowBackgroundAlpha = 0.9, -- 90% opacity
    titleBarColor = {r = 0.0, g = 0.0, b = 0.0}, -- Black title bar
    titleBarAlpha = 0.8, -- 80% opacity
    inputBoxColor = {r = 0.0, g = 0.0, b = 0.0}, -- Black input box
    inputBoxAlpha = 0.5, -- 50% opacity
    recentChatBackgroundColor = {r = 0.0, g = 0.0, b = 0.0}, -- Black recent chat bg
    recentChatBackgroundAlpha = 0.9, -- 90% opacity
    
    -- Notification settings
    notificationSound = SOUNDKIT.TELL_MESSAGE, -- Default notification sound (using sound kit ID)
    soundChannel = "Master", -- Sound channel (Master, SFX, Music, Ambience, Dialog)
    enableTaskbarAlert = true, -- Enable Windows taskbar alert on whisper
}

-- Available fonts
local FONT_OPTIONS = {
    {name = "Friz Quadrata (Default)", path = "Fonts\\FRIZQT__.TTF"},
    {name = "Arial", path = "Fonts\\ARIALN.TTF"},
    {name = "Skurri", path = "Fonts\\skurri.ttf"},
    {name = "Morpheus", path = "Fonts\\MORPHEUS.TTF"},
}

-- Available notification sounds
-- Using WoW Sound Kit IDs (more reliable than file paths)
local SOUND_OPTIONS = {
    {name = "None (Disabled)", soundKit = nil},
    {name = "Tell Message", soundKit = SOUNDKIT.TELL_MESSAGE},
    {name = "Whisper Inform", soundKit = SOUNDKIT.WHISPER_INFORM},
    {name = "UI Quest Complete", soundKit = SOUNDKIT.UI_QUEST_OBJECTIVES_COMPLETE},
    {name = "Level Up", soundKit = SOUNDKIT.LEVEL_UP},
    {name = "Auction Open", soundKit = SOUNDKIT.AUCTION_WINDOW_OPEN},
    {name = "Ready Check", soundKit = SOUNDKIT.READY_CHECK},
}

-- Available sound channels
local SOUND_CHANNEL_OPTIONS = {
    {name = "Master", value = "Master"},
    {name = "SFX", value = "SFX"},
    {name = "Music", value = "Music"},
    {name = "Ambience", value = "Ambience"},
    {name = "Dialog", value = "Dialog"},
}

-- ============================================================================
-- Settings Management
-- ============================================================================

function addon:LoadSettings()
    if not WhisperManager_Config then
        WhisperManager_Config = {}
    end
    
    if not WhisperManager_Config.settings then
        WhisperManager_Config.settings = {}
    end
    
    -- Set defaults for any missing values
    for key, value in pairs(DEFAULT_SETTINGS) do
        if WhisperManager_Config.settings[key] == nil then
            WhisperManager_Config.settings[key] = value
        end
    end
    
    return WhisperManager_Config.settings
end

function addon:SaveSettings()
    if not WhisperManager_Config then
        WhisperManager_Config = {}
    end
    WhisperManager_Config.settings = self.settings
end

function addon:GetSetting(key)
    if not self.settings then
        self.settings = self:LoadSettings()
    end
    local value = self.settings[key]
    if value == nil then
        value = DEFAULT_SETTINGS[key]
    end
    return value
end

function addon:SetSetting(key, value)
    if not self.settings then
        self.settings = self:LoadSettings()
    end
    self.settings[key] = value
    self:SaveSettings()
end

-- ============================================================================
-- Apply Settings to Existing Windows
-- ============================================================================

function addon:ApplyFontSettings()
    local fontPath = self:GetSetting("fontFamily") or "Fonts\\FRIZQT__.TTF"
    local messageSize = self:GetSetting("messageFontSize") or 14
    local inputSize = self:GetSetting("inputFontSize") or 14
    
    -- Update all open whisper windows
    for _, window in pairs(self.windows) do
        if window and window.History then
            -- Update history font
            local _, _, flags = window.History:GetFont()
            window.History:SetFont(fontPath, messageSize, flags or "")
        end
        
        if window and window.Input then
            -- Update input font
            local _, _, flags = window.Input:GetFont()
            window.Input:SetFont(fontPath, inputSize, flags or "")
        end
    end
    
    -- Update history viewer if it exists
    if self.historyFrame and self.historyFrame.detailText then
        local _, _, flags = self.historyFrame.detailText:GetFont()
        self.historyFrame.detailText:SetFont(fontPath, messageSize, flags or "")
    end
end

function addon:ApplyAppearanceSettings()
    -- Get appearance settings
    local bgColor = self:GetSetting("windowBackgroundColor") or DEFAULT_SETTINGS.windowBackgroundColor
    local bgAlpha = self:GetSetting("windowBackgroundAlpha") or DEFAULT_SETTINGS.windowBackgroundAlpha
    local titleColor = self:GetSetting("titleBarColor") or DEFAULT_SETTINGS.titleBarColor
    local titleAlpha = self:GetSetting("titleBarAlpha") or DEFAULT_SETTINGS.titleBarAlpha
    local inputColor = self:GetSetting("inputBoxColor") or DEFAULT_SETTINGS.inputBoxColor
    local inputAlpha = self:GetSetting("inputBoxAlpha") or DEFAULT_SETTINGS.inputBoxAlpha
    local recentBgColor = self:GetSetting("recentChatBackgroundColor") or DEFAULT_SETTINGS.recentChatBackgroundColor
    local recentBgAlpha = self:GetSetting("recentChatBackgroundAlpha") or DEFAULT_SETTINGS.recentChatBackgroundAlpha
    
    -- Update all open whisper windows
    for _, window in pairs(self.windows) do
        if window then
            -- Update window background
            if window.SetBackdropColor then
                window:SetBackdropColor(bgColor.r, bgColor.g, bgColor.b, bgAlpha)
            end
            
            -- Update title bar
            if window.titleBar and window.titleBar.SetBackdropColor then
                window.titleBar:SetBackdropColor(titleColor.r, titleColor.g, titleColor.b, titleAlpha)
            end
            
            -- Update input box background
            if window.InputContainer and window.InputContainer.SetBackdropColor then
                window.InputContainer:SetBackdropColor(inputColor.r, inputColor.g, inputColor.b, inputAlpha)
            end
        end
    end
    
    -- Update recent chats window
    if self.recentChatsFrame then
        self.recentChatsFrame:SetBackdropColor(recentBgColor.r, recentBgColor.g, recentBgColor.b, recentBgAlpha)
    end
end

-- ============================================================================
-- Sound Notification Functions
-- ============================================================================

function addon:PlayNotificationSound()
    local soundKitID = self:GetSetting("notificationSound")
    
    if not soundKitID then
        addon:Print("|cffff8800Sound notification disabled|r")
        self:DebugMessage("Sound notification disabled (nil soundKit)")
        return -- Sound disabled
    end
    
    -- Debug output
    addon:Print("|cff00ff00Attempting to play sound kit ID: " .. tostring(soundKitID) .. "|r")
    self:DebugMessage("Attempting to play sound kit ID: " .. tostring(soundKitID))
    
    -- PlaySound API:
    -- PlaySound(soundKitID, channel, forceNoDuplicateSounds, runFinishCallback)
    -- Returns true if successful
    -- Channel is optional, uses Master by default
    
    local success = PlaySound(soundKitID)
    
    self:DebugMessage("PlaySound result: " .. tostring(success))
    if success then
        addon:Print("|cff00ff00✓ Sound played successfully!|r")
        self:DebugMessage("Playing notification sound with kit ID: " .. tostring(soundKitID))
    else
        addon:Print("|cffff0000ERROR: Failed to play sound kit ID: " .. tostring(soundKitID) .. "|r")
        addon:Print("|cffff8800Try a different sound option from the dropdown|r")
        self:DebugMessage("|cffff0000ERROR: Failed to play sound|r")
    end
end

-- Preview the notification sound
function addon:PreviewNotificationSound()
    addon:Print("|cff00ff00Preview Sound button clicked|r")
    self:DebugMessage("PreviewNotificationSound called")
    self:PlayNotificationSound()
end

-- ============================================================================
-- Settings Frame Creation
-- ============================================================================

-- Helper function to create a color picker button
local function CreateColorPicker(parent, label, settingKey, x, y)
    local labelText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelText:SetPoint("TOPLEFT", x, y)
    labelText:SetText(label)
    
    local colorSwatch = CreateFrame("Button", nil, parent, "BackdropTemplate")
    colorSwatch:SetSize(30, 20)
    colorSwatch:SetPoint("LEFT", labelText, "RIGHT", 10, 0)
    colorSwatch:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, tileSize = 0, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    
    local color = addon:GetSetting(settingKey) or DEFAULT_SETTINGS[settingKey]
    colorSwatch:SetBackdropColor(color.r, color.g, color.b, 1)
    colorSwatch:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    
    colorSwatch:SetScript("OnClick", function(self)
        local color = addon:GetSetting(settingKey) or DEFAULT_SETTINGS[settingKey]
        ColorPickerFrame:SetupColorPickerAndShow({
            r = color.r,
            g = color.g,
            b = color.b,
            opacity = 1,
            hasOpacity = false,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                addon:SetSetting(settingKey, {r = r, g = g, b = b})
                self:SetBackdropColor(r, g, b, 1)
            end,
            cancelFunc = function(previousValues)
                addon:SetSetting(settingKey, {r = previousValues.r, g = previousValues.g, b = previousValues.b})
                self:SetBackdropColor(previousValues.r, previousValues.g, previousValues.b, 1)
            end,
        })
    end)
    
    colorSwatch:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Click to change color", 1, 1, 1)
        GameTooltip:Show()
    end)
    
    colorSwatch:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    return colorSwatch
end

-- Helper function to create a color picker with alpha slider
local function CreateColorAlphaPicker(parent, label, colorKey, alphaKey, x, y, applyCallback)
    local labelText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelText:SetPoint("TOPLEFT", x, y)
    labelText:SetText(label)
    
    -- Color swatch
    local colorSwatch = CreateFrame("Button", nil, parent, "BackdropTemplate")
    colorSwatch:SetSize(30, 20)
    colorSwatch:SetPoint("LEFT", labelText, "RIGHT", 10, 0)
    colorSwatch:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, tileSize = 0, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    
    local color = addon:GetSetting(colorKey) or DEFAULT_SETTINGS[colorKey]
    local alpha = addon:GetSetting(alphaKey) or DEFAULT_SETTINGS[alphaKey]
    colorSwatch:SetBackdropColor(color.r, color.g, color.b, 1)
    colorSwatch:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    
    colorSwatch:SetScript("OnClick", function(self)
        local color = addon:GetSetting(colorKey) or DEFAULT_SETTINGS[colorKey]
        ColorPickerFrame:SetupColorPickerAndShow({
            r = color.r,
            g = color.g,
            b = color.b,
            opacity = 1,
            hasOpacity = false,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                addon:SetSetting(colorKey, {r = r, g = g, b = b})
                self:SetBackdropColor(r, g, b, 1)
                if applyCallback then applyCallback() end
            end,
            cancelFunc = function(previousValues)
                addon:SetSetting(colorKey, {r = previousValues.r, g = previousValues.g, b = previousValues.b})
                self:SetBackdropColor(previousValues.r, previousValues.g, previousValues.b, 1)
                if applyCallback then applyCallback() end
            end,
        })
    end)
    
    colorSwatch:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Click to change color", 1, 1, 1)
        GameTooltip:Show()
    end)
    
    colorSwatch:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    -- Alpha slider label
    local alphaLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    alphaLabel:SetPoint("LEFT", colorSwatch, "RIGHT", 15, 0)
    alphaLabel:SetText("Opacity:")
    
    -- Alpha value display
    local alphaValue = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    alphaValue:SetPoint("LEFT", alphaLabel, "RIGHT", 5, 0)
    alphaValue:SetText(string.format("%.0f%%", alpha * 100))
    
    -- Alpha slider
    local alphaSlider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    alphaSlider:SetPoint("LEFT", alphaValue, "RIGHT", 10, 0)
    alphaSlider:SetMinMaxValues(0, 1)
    alphaSlider:SetValue(alpha)
    alphaSlider:SetValueStep(0.05)
    alphaSlider:SetObeyStepOnDrag(true)
    alphaSlider:SetWidth(120)
    alphaSlider:SetScript("OnValueChanged", function(self, value)
        alphaValue:SetText(string.format("%.0f%%", value * 100))
        addon:SetSetting(alphaKey, value)
        if applyCallback then applyCallback() end
    end)
    
    -- Hide default slider text
    local sliderName = alphaSlider:GetName()
    if sliderName then
        local low = _G[sliderName.."Low"]
        local high = _G[sliderName.."High"]
        local text = _G[sliderName.."Text"]
        if low then low:SetText("") end
        if high then high:SetText("") end
        if text then text:SetText("") end
    end
    
    return colorSwatch, alphaSlider
end

function addon:CreateSettingsFrame()
    local frame = CreateFrame("Frame", "WhisperManager_Settings", UIParent, "BackdropTemplate")
    frame:SetSize(500, 700)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.9)
    frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    frame:Hide()
    
    -- Title
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOP", 0, -10)
    frame.title:SetText("WhisperManager Settings")
    frame.title:SetTextColor(1, 0.82, 0)
    
    -- Close button
    frame.closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.closeBtn:SetPoint("TOPRIGHT", -2, -2)
    frame.closeBtn:SetSize(24, 24)
    
    -- Scroll frame for all settings
    frame.scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    frame.scrollFrame:SetPoint("TOPLEFT", 10, -40)
    frame.scrollFrame:SetPoint("BOTTOMRIGHT", -30, 40)
    
    frame.scrollChild = CreateFrame("Frame", nil, frame.scrollFrame)
    frame.scrollChild:SetSize(450, 1)
    frame.scrollFrame:SetScrollChild(frame.scrollChild)
    
    -- Enable mouse wheel scrolling
    frame.scrollFrame:EnableMouseWheel(true)
    frame.scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local scrollBar = self.ScrollBar
        if scrollBar then
            local current = scrollBar:GetValue()
            local _, maxValue = scrollBar:GetMinMaxValues()
            local step = 50 * delta
            scrollBar:SetValue(math.max(0, math.min(maxValue, current - step)))
        end
    end)
    
    local scrollChild = frame.scrollChild
    local yOffset = 0
    
    -- Font Family Section
    local fontLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fontLabel:SetPoint("TOPLEFT", 10, yOffset)
    fontLabel:SetText("Font Family:")
    yOffset = yOffset - 25
    
    local fontDropdown = CreateFrame("Frame", "WhisperManager_FontDropdown", scrollChild, "UIDropDownMenuTemplate")
    fontDropdown:SetPoint("TOPLEFT", 0, yOffset)
    
    UIDropDownMenu_SetWidth(fontDropdown, 250)
    UIDropDownMenu_Initialize(fontDropdown, function(self, level)
        for i, font in ipairs(FONT_OPTIONS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = font.name
            info.value = font.path
            info.func = function(self)
                addon:SetSetting("fontFamily", self.value)
                UIDropDownMenu_SetSelectedValue(fontDropdown, self.value)
                addon:ApplyFontSettings()
            end
            info.checked = (addon:GetSetting("fontFamily") == font.path)
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    
    UIDropDownMenu_SetSelectedValue(fontDropdown, addon:GetSetting("fontFamily"))
    yOffset = yOffset - 30
    
    -- Message Font Size Section
    local messageSizeLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    messageSizeLabel:SetPoint("TOPLEFT", 10, yOffset)
    messageSizeLabel:SetText("Message Font Size:")
    
    local messageSizeValue = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    messageSizeValue:SetPoint("LEFT", messageSizeLabel, "RIGHT", 10, 0)
    messageSizeValue:SetText(tostring(addon:GetSetting("messageFontSize")))
    messageSizeValue:SetTextColor(1, 1, 1)
    yOffset = yOffset - 25
    
    local messageSizeSlider = CreateFrame("Slider", "WhisperManager_MessageSizeSlider", scrollChild, "OptionsSliderTemplate")
    messageSizeSlider:SetPoint("TOPLEFT", 5, yOffset)
    messageSizeSlider:SetMinMaxValues(8, 36)
    messageSizeSlider:SetValue(addon:GetSetting("messageFontSize"))
    messageSizeSlider:SetValueStep(1)
    messageSizeSlider:SetObeyStepOnDrag(true)
    messageSizeSlider:SetWidth(300)
    _G[messageSizeSlider:GetName().."Low"]:SetText("8")
    _G[messageSizeSlider:GetName().."High"]:SetText("36")
    messageSizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        messageSizeValue:SetText(tostring(value))
        addon:SetSetting("messageFontSize", value)
        addon:ApplyFontSettings()
    end)
    yOffset = yOffset - 40
    
    -- Input Font Size Section
    local inputSizeLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    inputSizeLabel:SetPoint("TOPLEFT", 10, yOffset)
    inputSizeLabel:SetText("Input Box Font Size:")
    
    local inputSizeValue = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    inputSizeValue:SetPoint("LEFT", inputSizeLabel, "RIGHT", 10, 0)
    inputSizeValue:SetText(tostring(addon:GetSetting("inputFontSize")))
    inputSizeValue:SetTextColor(1, 1, 1)
    yOffset = yOffset - 25
    
    local inputSizeSlider = CreateFrame("Slider", "WhisperManager_InputSizeSlider", scrollChild, "OptionsSliderTemplate")
    inputSizeSlider:SetPoint("TOPLEFT", 5, yOffset)
    inputSizeSlider:SetMinMaxValues(8, 36)
    inputSizeSlider:SetValue(addon:GetSetting("inputFontSize"))
    inputSizeSlider:SetValueStep(1)
    inputSizeSlider:SetObeyStepOnDrag(true)
    inputSizeSlider:SetWidth(300)
    _G[inputSizeSlider:GetName().."Low"]:SetText("8")
    _G[inputSizeSlider:GetName().."High"]:SetText("36")
    inputSizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        inputSizeValue:SetText(tostring(value))
        addon:SetSetting("inputFontSize", value)
        addon:ApplyFontSettings()
    end)
    yOffset = yOffset - 50
    
    -- Color Settings Section Header
    local colorHeader = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    colorHeader:SetPoint("TOPLEFT", 10, yOffset)
    colorHeader:SetText("Message Colors")
    colorHeader:SetTextColor(1, 0.82, 0)
    yOffset = yOffset - 30
    
    -- Whisper Receive Color
    frame.whisperReceiveColor = CreateColorPicker(scrollChild, "Whisper Receive:", "whisperReceiveColor", 10, yOffset)
    yOffset = yOffset - 30
    
    -- Whisper Send Color
    frame.whisperSendColor = CreateColorPicker(scrollChild, "Whisper Send:", "whisperSendColor", 10, yOffset)
    yOffset = yOffset - 30
    
    -- BNet Receive Color
    frame.bnetReceiveColor = CreateColorPicker(scrollChild, "BNet Receive:", "bnetReceiveColor", 10, yOffset)
    yOffset = yOffset - 30
    
    -- BNet Send Color
    frame.bnetSendColor = CreateColorPicker(scrollChild, "BNet Send:", "bnetSendColor", 10, yOffset)
    yOffset = yOffset - 30
    
    -- Timestamp Color
    frame.timestampColor = CreateColorPicker(scrollChild, "Timestamp:", "timestampColor", 10, yOffset)
    yOffset = yOffset - 50
    
    -- Appearance Settings Header
    local appearanceHeader = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    appearanceHeader:SetPoint("TOPLEFT", 10, yOffset)
    appearanceHeader:SetText("Window Appearance")
    appearanceHeader:SetTextColor(1, 0.82, 0)
    yOffset = yOffset - 35
    
    -- Window Background
    frame.windowBg = CreateColorAlphaPicker(scrollChild, "Window Background:", "windowBackgroundColor", 
        "windowBackgroundAlpha", 10, yOffset, function() addon:ApplyAppearanceSettings() end)
    yOffset = yOffset - 35
    
    -- Title Bar
    frame.titleBar = CreateColorAlphaPicker(scrollChild, "Title Bar:", "titleBarColor", 
        "titleBarAlpha", 10, yOffset, function() addon:ApplyAppearanceSettings() end)
    yOffset = yOffset - 35
    
    -- Input Box
    frame.inputBox = CreateColorAlphaPicker(scrollChild, "Input Box:", "inputBoxColor", 
        "inputBoxAlpha", 10, yOffset, function() addon:ApplyAppearanceSettings() end)
    yOffset = yOffset - 35
    
    -- Recent Chat Window
    frame.recentChat = CreateColorAlphaPicker(scrollChild, "Recent Chat Window:", "recentChatBackgroundColor", 
        "recentChatBackgroundAlpha", 10, yOffset, function() addon:ApplyAppearanceSettings() end)
    yOffset = yOffset - 50
    
    -- Notification Settings Header
    local notificationHeader = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    notificationHeader:SetPoint("TOPLEFT", 10, yOffset)
    notificationHeader:SetText("Notification Settings")
    notificationHeader:SetTextColor(1, 0.82, 0)
    yOffset = yOffset - 30
    
    -- Notification Sound Dropdown
    local soundLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    soundLabel:SetPoint("TOPLEFT", 10, yOffset)
    soundLabel:SetText("Notification Sound:")
    yOffset = yOffset - 25
    
    local soundDropdown = CreateFrame("Frame", "WhisperManager_SoundDropdown", scrollChild, "UIDropDownMenuTemplate")
    soundDropdown:SetPoint("TOPLEFT", 0, yOffset)
    
    UIDropDownMenu_SetWidth(soundDropdown, 300)
    UIDropDownMenu_Initialize(soundDropdown, function(self, level)
        for i, sound in ipairs(SOUND_OPTIONS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = sound.name
            info.value = sound.soundKit
            info.func = function(self)
                addon:SetSetting("notificationSound", self.value)
                UIDropDownMenu_SetSelectedValue(soundDropdown, self.value)
            end
            info.checked = (addon:GetSetting("notificationSound") == sound.soundKit)
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    
    UIDropDownMenu_SetSelectedValue(soundDropdown, addon:GetSetting("notificationSound"))
    yOffset = yOffset - 30
    
    -- Sound Channel Dropdown
    local channelLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    channelLabel:SetPoint("TOPLEFT", 10, yOffset)
    channelLabel:SetText("Sound Channel:")
    yOffset = yOffset - 25
    
    local channelDropdown = CreateFrame("Frame", "WhisperManager_ChannelDropdown", scrollChild, "UIDropDownMenuTemplate")
    channelDropdown:SetPoint("TOPLEFT", 0, yOffset)
    
    UIDropDownMenu_SetWidth(channelDropdown, 150)
    UIDropDownMenu_Initialize(channelDropdown, function(self, level)
        for i, channel in ipairs(SOUND_CHANNEL_OPTIONS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = channel.name
            info.value = channel.value
            info.func = function(self)
                addon:SetSetting("soundChannel", self.value)
                UIDropDownMenu_SetSelectedValue(channelDropdown, self.value)
            end
            info.checked = (addon:GetSetting("soundChannel") == channel.value)
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    
    UIDropDownMenu_SetSelectedValue(channelDropdown, addon:GetSetting("soundChannel"))
    yOffset = yOffset - 30
    
    -- Preview Sound Button
    local previewBtn = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
    previewBtn:SetSize(100, 25)
    previewBtn:SetPoint("TOPLEFT", 10, yOffset)
    previewBtn:SetText("Preview Sound")
    previewBtn:SetScript("OnClick", function()
        addon:PreviewNotificationSound()
    end)
    yOffset = yOffset - 30
    
    -- Taskbar Alert Checkbox
    local taskbarCheckbox = CreateFrame("CheckButton", nil, scrollChild, "UICheckButtonTemplate")
    taskbarCheckbox:SetPoint("TOPLEFT", 10, yOffset)
    taskbarCheckbox:SetSize(24, 24)
    taskbarCheckbox:SetChecked(addon:GetSetting("enableTaskbarAlert"))
    
    local taskbarLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    taskbarLabel:SetPoint("LEFT", taskbarCheckbox, "RIGHT", 5, 0)
    taskbarLabel:SetText("Enable Windows Taskbar Alert on Whisper")
    
    taskbarCheckbox:SetScript("OnClick", function(self)
        addon:SetSetting("enableTaskbarAlert", self:GetChecked())
    end)
    yOffset = yOffset - 40
    
    -- Update scroll child height
    scrollChild:SetHeight(-yOffset + 20)
    
    -- Reset button (at bottom of frame)
    local resetBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    resetBtn:SetSize(100, 25)
    resetBtn:SetPoint("BOTTOM", 0, 10)
    resetBtn:SetText("Reset Defaults")
    resetBtn:SetScript("OnClick", function()
        for key, value in pairs(DEFAULT_SETTINGS) do
            addon:SetSetting(key, value)
        end
        
        -- Update UI
        UIDropDownMenu_SetSelectedValue(fontDropdown, DEFAULT_SETTINGS.fontFamily)
        messageSizeSlider:SetValue(DEFAULT_SETTINGS.messageFontSize)
        inputSizeSlider:SetValue(DEFAULT_SETTINGS.inputFontSize)
        UIDropDownMenu_SetSelectedValue(soundDropdown, DEFAULT_SETTINGS.notificationSound)
        UIDropDownMenu_SetSelectedValue(channelDropdown, DEFAULT_SETTINGS.soundChannel)
        taskbarCheckbox:SetChecked(DEFAULT_SETTINGS.enableTaskbarAlert)
        
        -- Update color swatches
        local whisperReceive = DEFAULT_SETTINGS.whisperReceiveColor
        frame.whisperReceiveColor:SetBackdropColor(whisperReceive.r, whisperReceive.g, whisperReceive.b, 1)
        
        local whisperSend = DEFAULT_SETTINGS.whisperSendColor
        frame.whisperSendColor:SetBackdropColor(whisperSend.r, whisperSend.g, whisperSend.b, 1)
        
        local bnetReceive = DEFAULT_SETTINGS.bnetReceiveColor
        frame.bnetReceiveColor:SetBackdropColor(bnetReceive.r, bnetReceive.g, bnetReceive.b, 1)
        
        local bnetSend = DEFAULT_SETTINGS.bnetSendColor
        frame.bnetSendColor:SetBackdropColor(bnetSend.r, bnetSend.g, bnetSend.b, 1)
        
        local timestamp = DEFAULT_SETTINGS.timestampColor
        frame.timestampColor:SetBackdropColor(timestamp.r, timestamp.g, timestamp.b, 1)
        
        -- Update appearance color swatches (just the color part, sliders update automatically)
        local windowBg = DEFAULT_SETTINGS.windowBackgroundColor
        frame.windowBg:SetBackdropColor(windowBg.r, windowBg.g, windowBg.b, 1)
        
        local titleBar = DEFAULT_SETTINGS.titleBarColor
        frame.titleBar:SetBackdropColor(titleBar.r, titleBar.g, titleBar.b, 1)
        
        local inputBox = DEFAULT_SETTINGS.inputBoxColor
        frame.inputBox:SetBackdropColor(inputBox.r, inputBox.g, inputBox.b, 1)
        
        local recentChat = DEFAULT_SETTINGS.recentChatBackgroundColor
        frame.recentChat:SetBackdropColor(recentChat.r, recentChat.g, recentChat.b, 1)
        
        addon:ApplyFontSettings()
        addon:ApplyAppearanceSettings()
        addon:Print("Settings reset to defaults.")
    end)
    
    addon.settingsFrame = frame
    return frame
end

function addon:ToggleSettingsFrame()
    if not self.settingsFrame then
        self:CreateSettingsFrame()
    end
    
    if self.settingsFrame:IsShown() then
        self.settingsFrame:Hide()
    else
        self.settingsFrame:Show()
    end
end
