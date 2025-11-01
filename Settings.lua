-- ============================================================================
-- Settings.lua - Settings UI and configuration
-- ============================================================================

local addon = WhisperManager;

-- ============================================================================
-- Default Settings
-- ============================================================================

local DEFAULT_SETTINGS = {
    messageFontSize = 14,
    inputFontSize = 14,
    fontFamily = "Fonts\\ARIALN.TTF", -- Default to Arial per user request
    
    -- Message colors (using WoW's default whisper colors)
    whisperReceiveColor = {r = 1.0, g = 0.5, b = 1.0}, -- Pink (default whisper receive)
    whisperSendColor = {r = 1.0, g = 0.5, b = 1.0}, -- Pink (default whisper send)
    bnetReceiveColor = {r = 0.0, g = 0.66, b = 1.0}, -- Blue (default BNet receive)
    bnetSendColor = {r = 0.0, g = 0.66, b = 1.0}, -- Blue (default BNet send)
    timestampColor = {r = 0.5, g = 0.5, b = 0.5}, -- Gray (timestamp color)
}

-- Available fonts
local FONT_OPTIONS = {
    {name = "Friz Quadrata (Default)", path = "Fonts\\FRIZQT__.TTF"},
    {name = "Arial", path = "Fonts\\ARIALN.TTF"},
    {name = "Skurri", path = "Fonts\\skurri.ttf"},
    {name = "Morpheus", path = "Fonts\\MORPHEUS.TTF"},
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

function addon:CreateSettingsFrame()
    local frame = CreateFrame("Frame", "WhisperManager_Settings", UIParent, "BackdropTemplate")
    frame:SetSize(450, 500)
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
    
    -- Font Family Section
    local fontLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fontLabel:SetPoint("TOPLEFT", 20, -50)
    fontLabel:SetText("Font Family:")
    
    local fontDropdown = CreateFrame("Frame", "WhisperManager_FontDropdown", frame, "UIDropDownMenuTemplate")
    fontDropdown:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", -15, -5)
    
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
    
    -- Message Font Size Section
    local messageSizeLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    messageSizeLabel:SetPoint("TOPLEFT", 20, -110)
    messageSizeLabel:SetText("Message Font Size:")
    
    local messageSizeValue = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    messageSizeValue:SetPoint("LEFT", messageSizeLabel, "RIGHT", 10, 0)
    messageSizeValue:SetText(tostring(addon:GetSetting("messageFontSize")))
    messageSizeValue:SetTextColor(1, 1, 1)
    
    local messageSizeSlider = CreateFrame("Slider", "WhisperManager_MessageSizeSlider", frame, "OptionsSliderTemplate")
    messageSizeSlider:SetPoint("TOPLEFT", messageSizeLabel, "BOTTOMLEFT", 5, -10)
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
    
    -- Input Font Size Section
    local inputSizeLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    inputSizeLabel:SetPoint("TOPLEFT", 20, -190)
    inputSizeLabel:SetText("Input Box Font Size:")
    
    local inputSizeValue = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    inputSizeValue:SetPoint("LEFT", inputSizeLabel, "RIGHT", 10, 0)
    inputSizeValue:SetText(tostring(addon:GetSetting("inputFontSize")))
    inputSizeValue:SetTextColor(1, 1, 1)
    
    local inputSizeSlider = CreateFrame("Slider", "WhisperManager_InputSizeSlider", frame, "OptionsSliderTemplate")
    inputSizeSlider:SetPoint("TOPLEFT", inputSizeLabel, "BOTTOMLEFT", 5, -10)
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
    
    -- Color Settings Section Header
    local colorHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    colorHeader:SetPoint("TOPLEFT", 20, -270)
    colorHeader:SetText("Message Colors")
    colorHeader:SetTextColor(1, 0.82, 0)
    
    -- Whisper Receive Color
    frame.whisperReceiveColor = CreateColorPicker(frame, "Whisper Receive:", "whisperReceiveColor", 20, -300)
    
    -- Whisper Send Color
    frame.whisperSendColor = CreateColorPicker(frame, "Whisper Send:", "whisperSendColor", 20, -330)
    
    -- BNet Receive Color
    frame.bnetReceiveColor = CreateColorPicker(frame, "BNet Receive:", "bnetReceiveColor", 20, -360)
    
    -- BNet Send Color
    frame.bnetSendColor = CreateColorPicker(frame, "BNet Send:", "bnetSendColor", 20, -390)
    
    -- Timestamp Color
    frame.timestampColor = CreateColorPicker(frame, "Timestamp:", "timestampColor", 20, -420)
    
    -- Reset button
    local resetBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    resetBtn:SetSize(100, 25)
    resetBtn:SetPoint("BOTTOM", 0, 20)
    resetBtn:SetText("Reset Defaults")
    resetBtn:SetScript("OnClick", function()
        for key, value in pairs(DEFAULT_SETTINGS) do
            addon:SetSetting(key, value)
        end
        
        -- Update UI
        UIDropDownMenu_SetSelectedValue(fontDropdown, DEFAULT_SETTINGS.fontFamily)
        messageSizeSlider:SetValue(DEFAULT_SETTINGS.messageFontSize)
        inputSizeSlider:SetValue(DEFAULT_SETTINGS.inputFontSize)
        
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
        
        addon:ApplyFontSettings()
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
