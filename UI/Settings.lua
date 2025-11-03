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
    -- Default whisper send color: #D832FF -> (216,50,255)
    whisperSendColor = {r = 216/255, g = 50/255, b = 255/255},
    bnetReceiveColor = {r = 0.0, g = 0.66, b = 1.0}, -- Blue (default BNet receive)
    -- Default BNet send color: #0072FF -> (0,114,255)
    bnetSendColor = {r = 0/255, g = 114/255, b = 255/255}, -- Blue (default BNet send)
    timestampColor = {r = 0.5, g = 0.5, b = 0.5}, -- Gray (timestamp color)
    
    -- Notification settings
    notificationSound = SOUNDKIT.TELL_MESSAGE, -- Default notification sound (using sound kit ID)
    soundChannel = "Master", -- Sound channel (Master, SFX, Music, Ambience, Dialog)
    enableTaskbarAlert = true, -- Enable Windows taskbar alert on whisper
    
    -- Chat suppression (WIM-style)
    suppressDefaultChat = true, -- Suppress whispers from default chat when handled by WhisperManager
    
    -- Window spawn settings
    spawnAnchorX = 450, -- X offset from center (default: screen center)
    spawnAnchorY = 200, -- Y offset from center (default: upper center)
    windowSpacing = 50, -- Vertical spacing between windows
    
    -- Default window size
    defaultWindowWidth = 350,
    defaultWindowHeight = 250,
    
    -- History retention settings
    historyRetentionMode = "none", -- none, mode1, mode2, mode3, mode4, mode5
}

-- Available fonts
local FONT_OPTIONS = {
    {name = "Arial (Default)", path = "Fonts\\ARIALN.TTF"},
    {name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF"},
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
    {name = "Master (Default)", value = "Master"},
    {name = "SFX", value = "SFX"},
    {name = "Music", value = "Music"},
    {name = "Ambience", value = "Ambience"},
    {name = "Dialog", value = "Dialog"},
}

-- History retention modes
local RETENTION_OPTIONS = {
    {name = "Keep All (No Limit)", value = "none", keepCount = nil, keepMonths = nil, deleteMonths = nil},
    {name = "Keep 10 recent (6 mo), delete after 3 mo", value = "mode1", keepCount = 10, keepMonths = 6, deleteMonths = 3},
    {name = "Keep 25 recent (12 mo), delete after 2 mo", value = "mode2", keepCount = 25, keepMonths = 12, deleteMonths = 2},
    {name = "Keep 5 recent (forever), delete after 2 mo", value = "mode3", keepCount = 5, keepMonths = nil, deleteMonths = 2},
    {name = "Keep 10 recent (forever), delete after 2 mo", value = "mode4", keepCount = 10, keepMonths = nil, deleteMonths = 2},
    {name = "Keep 25 recent (forever), delete after 1 mo", value = "mode5", keepCount = 25, keepMonths = nil, deleteMonths = 1},
}

-- ============================================================================
-- Settings Management
-- ============================================================================

function addon:LoadSettings()
    self:DebugMessage("[LoadSettings] Starting...")
    
    -- Ensure the global config table and its settings sub-table exist.
    if not WhisperManager_Config then
        WhisperManager_Config = { settings = {} }
        self:DebugMessage("[LoadSettings] Created new WhisperManager_Config table.")
    elseif not WhisperManager_Config.settings then
        WhisperManager_Config.settings = {}
        self:DebugMessage("[LoadSettings] Created new WhisperManager_Config.settings sub-table.")
    end

    self:DebugMessage("[LoadSettings] Current values BEFORE applying defaults:")
    self:DebugMessage("  spawnAnchorX: " .. tostring(WhisperManager_Config.settings.spawnAnchorX))
    self:DebugMessage("  spawnAnchorY: " .. tostring(WhisperManager_Config.settings.spawnAnchorY))
    self:DebugMessage("  windowSpacing: " .. tostring(WhisperManager_Config.settings.windowSpacing))
    self:DebugMessage("  defaultWindowWidth: " .. tostring(WhisperManager_Config.settings.defaultWindowWidth))
    self:DebugMessage("  defaultWindowHeight: " .. tostring(WhisperManager_Config.settings.defaultWindowHeight))

    -- Set defaults for any missing values - DIRECTLY on the global table
    for key, value in pairs(DEFAULT_SETTINGS) do
        if WhisperManager_Config.settings[key] == nil then
            WhisperManager_Config.settings[key] = value
            self:DebugMessage("[LoadSettings] Applied default for '" .. key .. "' = " .. tostring(value))
        end
    end

    self:DebugMessage("[LoadSettings] Values AFTER applying defaults:")
    self:DebugMessage("  spawnAnchorX: " .. tostring(WhisperManager_Config.settings.spawnAnchorX))
    self:DebugMessage("  spawnAnchorY: " .. tostring(WhisperManager_Config.settings.spawnAnchorY))
    self:DebugMessage("  windowSpacing: " .. tostring(WhisperManager_Config.settings.windowSpacing))
    self:DebugMessage("  defaultWindowWidth: " .. tostring(WhisperManager_Config.settings.defaultWindowWidth))
    self:DebugMessage("  defaultWindowHeight: " .. tostring(WhisperManager_Config.settings.defaultWindowHeight))
    
    self:DebugMessage("[LoadSettings] Returning DIRECT reference to WhisperManager_Config.settings")
    -- Return the ACTUAL global table, not a local variable copy
    return WhisperManager_Config.settings
end

function addon:SaveSettings()
    -- This function is now simpler, as we directly modify addon.settings
    -- which is a reference to WhisperManager_Config.settings.
    -- The game handles saving the global table automatically.
    if not WhisperManager_Config then
        WhisperManager_Config = {}
    end
    WhisperManager_Config.settings = self.settings or WhisperManager_Config.settings or {}
    self:DebugMessage("Settings saved to WhisperManager_Config.settings")
end

function addon:GetSetting(key)
    -- addon.settings is now guaranteed to be loaded at startup.
    local value = self.settings[key]
    if value == nil then
        self:DebugMessage("Warning: No setting found for '", key, "'. Using default.")
        return DEFAULT_SETTINGS[key]
    end
    return value
end

function addon:SetSetting(key, value)
    self:DebugMessage("[SetSetting] Called for key: '" .. key .. "' with value: " .. tostring(value))
    
    -- FORCE addon.settings to always be WhisperManager_Config.settings
    if self.settings ~= WhisperManager_Config.settings then
        self:DebugMessage("[SetSetting] WARNING: Table mismatch detected! Fixing reference...")
        self.settings = WhisperManager_Config.settings
    end
    
    if not self.settings then
        self:DebugMessage("[SetSetting] ERROR: addon.settings is nil!")
        return
    end
    
    -- Directly modify the settings table (which is now guaranteed to be the global one)
    self.settings[key] = value
    
    self:DebugMessage("[SetSetting] Updated addon.settings['" .. key .. "'] = " .. tostring(self.settings[key]))
    self:DebugMessage("[SetSetting] Verifying write to global table...")
    self:DebugMessage("[SetSetting] WhisperManager_Config.settings['" .. key .. "'] = " .. tostring(WhisperManager_Config.settings[key]))
    self:DebugMessage("[SetSetting] Same table reference? " .. tostring(self.settings == WhisperManager_Config.settings))
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
-- Sound Notification Functions
-- ============================================================================

function addon:PlayNotificationSound()
    local soundKitID = self:GetSetting("notificationSound")
    
    if not soundKitID then
        addon:DebugMessage("|cffff8800Sound notification disabled|r")
        self:DebugMessage("Sound notification disabled (nil soundKit)")
        return -- Sound disabled
    end
    
    -- Debug output
    addon:DebugMessage("|cff00ff00Attempting to play sound kit ID: " .. tostring(soundKitID) .. "|r")
    self:DebugMessage("Attempting to play sound kit ID: " .. tostring(soundKitID))
    
    -- PlaySound API:
    -- PlaySound(soundKitID, channel, forceNoDuplicateSounds, runFinishCallback)
    -- Returns true if successful
    -- Channel is optional, uses Master by default
    
    local channel = self:GetSetting("soundChannel")
    -- Play the sound; PlaySound does not reliably return a success value, so don't depend on a return.
    PlaySound(soundKitID, channel)
    self:DebugMessage("Triggered PlaySound for kit ID: " .. tostring(soundKitID) .. " on channel: " .. tostring(channel))
    addon:DebugMessage("|cff00ff00Played notification sound.|r")
end

-- Preview the notification sound
function addon:PreviewNotificationSound()
    addon:DebugMessage("|cff00ff00Preview Sound button clicked|r")
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
    
    colorSwatch:SetScript("OnClick", function()
        local color = addon:GetSetting(settingKey) or DEFAULT_SETTINGS[settingKey]
        -- Use the standard ColorPickerFrame API to avoid depending on non-standard helpers
        local previousValues = { r = color.r, g = color.g, b = color.b }

        ColorPickerFrame.func = function(restore)
            if restore then
                -- restore is a table with r,g,b
                addon:SetSetting(settingKey, { r = restore.r, g = restore.g, b = restore.b })
                colorSwatch:SetBackdropColor(restore.r, restore.g, restore.b, 1)
            else
                local r, g, b = ColorPickerFrame:GetColorRGB()
                addon:SetSetting(settingKey, { r = r, g = g, b = b })
                colorSwatch:SetBackdropColor(r, g, b, 1)
            end
        end

        ColorPickerFrame.cancelFunc = function(restore)
            if restore then
                addon:SetSetting(settingKey, { r = restore.r, g = restore.g, b = restore.b })
                colorSwatch:SetBackdropColor(restore.r, restore.g, restore.b, 1)
            end
        end

        ColorPickerFrame.previousValues = previousValues
        ColorPickerFrame:SetColorRGB(color.r, color.g, color.b)
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame:Show()
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
    
    -- ESC key handling - don't use UISpecialFrames to avoid conflicts
    frame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Hide()
        end
    end)
    frame:SetPropagateKeyboardInput(true)
    
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
    
    -- Whisper Receive / Send (inline)
    frame.whisperReceiveColor = CreateColorPicker(scrollChild, "Whisper Receive:", "whisperReceiveColor", 10, yOffset)
    -- place send to the right of receive
    frame.whisperSendColor = CreateColorPicker(scrollChild, "Whisper Send:", "whisperSendColor", 180, yOffset)
    yOffset = yOffset - 30

    -- BNet Receive / Send (inline)
    frame.bnetReceiveColor = CreateColorPicker(scrollChild, "BNet Receive:", "bnetReceiveColor", 10, yOffset)
    -- place send to the right of receive
    frame.bnetSendColor = CreateColorPicker(scrollChild, "BNet Send:", "bnetSendColor", 180, yOffset)
    yOffset = yOffset - 30

    -- Timestamp Color (own line)
    frame.timestampColor = CreateColorPicker(scrollChild, "Timestamp:", "timestampColor", 10, yOffset)
    yOffset = yOffset - 50
    
    -- Notification Settings Header
    local notificationHeader = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    notificationHeader:SetPoint("TOPLEFT", 10, yOffset)
    notificationHeader:SetText("Notification Settings")
    notificationHeader:SetTextColor(1, 0.82, 0)
    yOffset = yOffset - 30
    
    -- Notification Sound Dropdown, Channel dropdown and Preview button inline
    local soundLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    soundLabel:SetPoint("TOPLEFT", 10, yOffset)
    soundLabel:SetText("Sound:")

    local soundDropdown = CreateFrame("Frame", "WhisperManager_SoundDropdown", scrollChild, "UIDropDownMenuTemplate")
    soundDropdown:SetPoint("LEFT", soundLabel, "RIGHT", 5, 0)
    UIDropDownMenu_SetWidth(soundDropdown, 75)
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

    local channelLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    channelLabel:SetPoint("LEFT", soundDropdown, "RIGHT", 10, 0)
    channelLabel:SetText("Channel:")

    local channelDropdown = CreateFrame("Frame", "WhisperManager_ChannelDropdown", scrollChild, "UIDropDownMenuTemplate")
    channelDropdown:SetPoint("LEFT", channelLabel, "RIGHT", 8, 0)
    UIDropDownMenu_SetWidth(channelDropdown, 90)
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

    local previewBtn = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
    previewBtn:SetSize(70, 20)
    previewBtn:SetPoint("LEFT", channelDropdown, "RIGHT", 8, 0)
    previewBtn:SetText("Play")
    previewBtn:SetScript("OnClick", function()
        addon:PreviewNotificationSound()
    end)

    yOffset = yOffset - 30
    
    -- Taskbar Alert Checkbox
    local taskbarCheckbox = CreateFrame("CheckButton", nil, scrollChild, "UICheckButtonTemplate")
    taskbarCheckbox:SetPoint("TOPLEFT", 10, yOffset)
    taskbarCheckbox:SetSize(24, 24)
    taskbarCheckbox:SetChecked(addon:GetSetting("enableTaskbarAlert"))
    
    local taskbarLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    taskbarLabel:SetPoint("LEFT", taskbarCheckbox, "RIGHT", 5, 0)
    taskbarLabel:SetText("Enable Windows Taskbar Alert on Whisper")
    
    taskbarCheckbox:SetScript("OnClick", function(self)
        addon:SetSetting("enableTaskbarAlert", self:GetChecked())
    end)
    yOffset = yOffset - 50
    
    -- History Retention Header
    local retentionHeader = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    retentionHeader:SetPoint("TOPLEFT", 10, yOffset)
    retentionHeader:SetText("History Retention")
    retentionHeader:SetTextColor(1, 0.82, 0)
    yOffset = yOffset - 30
    
    -- Retention Mode Dropdown
    local retentionLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    retentionLabel:SetPoint("TOPLEFT", 10, yOffset)
    retentionLabel:SetText("Automatic Cleanup:")
    yOffset = yOffset - 25
    
    local retentionDropdown = CreateFrame("Frame", "WhisperManager_RetentionDropdown", scrollChild, "UIDropDownMenuTemplate")
    retentionDropdown:SetPoint("TOPLEFT", 0, yOffset)
    UIDropDownMenu_SetWidth(retentionDropdown, 350)
    UIDropDownMenu_Initialize(retentionDropdown, function(self, level)
        for i, mode in ipairs(RETENTION_OPTIONS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = mode.name
            info.value = mode.value
            info.func = function(self)
                addon:SetSetting("historyRetentionMode", self.value)
                UIDropDownMenu_SetSelectedValue(retentionDropdown, self.value)
                -- Run cleanup immediately when mode changes
                addon:RunHistoryRetentionCleanup()
            end
            info.checked = (addon:GetSetting("historyRetentionMode") == mode.value)
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    UIDropDownMenu_SetSelectedValue(retentionDropdown, addon:GetSetting("historyRetentionMode"))
    yOffset = yOffset - 30
    
    -- Info text about retention
    local retentionInfo = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    retentionInfo:SetPoint("TOPLEFT", 10, yOffset)
    retentionInfo:SetPoint("TOPRIGHT", -10, yOffset)
    retentionInfo:SetJustifyH("LEFT")
    retentionInfo:SetText("Automatic cleanup keeps your saved history lean. The N most recent messages with each person are protected for the specified time. Older messages are deleted after the shorter time limit. Cleanup runs on login and once per day.")
    retentionInfo:SetTextColor(0.7, 0.7, 0.7)
    yOffset = yOffset - 60
    
    -- Window Spawn Settings Header
    local spawnHeader = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    spawnHeader:SetPoint("TOPLEFT", 10, yOffset)
    spawnHeader:SetText("Window Size / Postion")
    spawnHeader:SetTextColor(1, 0.82, 0)
    yOffset = yOffset - 35
    
    -- Spawn Anchor X
    local spawnXLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    spawnXLabel:SetPoint("TOPLEFT", 10, yOffset)
    spawnXLabel:SetText("Horizontal Position (X):")
    
    local spawnXSlider = CreateFrame("Slider", nil, scrollChild, "OptionsSliderTemplate")
    spawnXSlider:SetPoint("TOPLEFT", 20, yOffset - 20)
    spawnXSlider:SetWidth(400)
    spawnXSlider:SetMinMaxValues(-960, 960)
    spawnXSlider:SetValueStep(10)
    spawnXSlider:SetObeyStepOnDrag(true)
    
    -- Set the initial value first
    spawnXSlider:SetValue(addon:GetSetting("spawnAnchorX") or 0)
    -- Ensure a Text FontString exists (OptionsSliderTemplate expects a named slider to create it)
    if not spawnXSlider.Text then
        spawnXSlider.Text = spawnXSlider:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        spawnXSlider.Text:SetPoint("BOTTOMLEFT", spawnXSlider, "TOPLEFT", 0, 0)
    end
    spawnXSlider.Text:SetText("X Offset: " .. (addon:GetSetting("spawnAnchorX") or 0))
    
    -- Set up the callback
    spawnXSlider:SetScript("OnValueChanged", function(self, value)
        self.Text:SetText("X Offset: " .. math.floor(value))
        addon:SetSetting("spawnAnchorX", math.floor(value))
    end)
    
    yOffset = yOffset - 60
    
    -- Spawn Anchor Y
    local spawnYLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    spawnYLabel:SetPoint("TOPLEFT", 10, yOffset)
    spawnYLabel:SetText("Vertical Position (Y):")
    
    local spawnYSlider = CreateFrame("Slider", nil, scrollChild, "OptionsSliderTemplate")
    spawnYSlider:SetPoint("TOPLEFT", 20, yOffset - 20)
    spawnYSlider:SetWidth(400)
    spawnYSlider:SetMinMaxValues(-540, 540)
    spawnYSlider:SetValueStep(10)
    spawnYSlider:SetObeyStepOnDrag(true)
    
    -- Set up the callback first
    -- Set the initial value first
    spawnYSlider:SetValue(addon:GetSetting("spawnAnchorY") or 200)
    if not spawnYSlider.Text then
        spawnYSlider.Text = spawnYSlider:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        spawnYSlider.Text:SetPoint("BOTTOMLEFT", spawnYSlider, "TOPLEFT", 0, 0)
    end
    spawnYSlider.Text:SetText("Y Offset: " .. (addon:GetSetting("spawnAnchorY") or 200))
    
    -- Set up the callback
    spawnYSlider:SetScript("OnValueChanged", function(self, value)
        self.Text:SetText("Y Offset: " .. math.floor(value))
        addon:SetSetting("spawnAnchorY", math.floor(value))
    end)
    
    yOffset = yOffset - 60
    
    -- Window Spacing
    local spacingLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    spacingLabel:SetPoint("TOPLEFT", 10, yOffset)
    spacingLabel:SetText("Window Spacing:")
    
    local spacingSlider = CreateFrame("Slider", nil, scrollChild, "OptionsSliderTemplate")
    spacingSlider:SetPoint("TOPLEFT", 20, yOffset - 20)
    spacingSlider:SetWidth(400)
    spacingSlider:SetMinMaxValues(0, 200)
    spacingSlider:SetValueStep(5)
    spacingSlider:SetObeyStepOnDrag(true)
    
    -- Set up the callback first
    -- Set the initial value first
    spacingSlider:SetValue(addon:GetSetting("windowSpacing") or 50)
    if not spacingSlider.Text then
        spacingSlider.Text = spacingSlider:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        spacingSlider.Text:SetPoint("BOTTOMLEFT", spacingSlider, "TOPLEFT", 0, 0)
    end
    spacingSlider.Text:SetText("Spacing: " .. (addon:GetSetting("windowSpacing") or 50) .. " pixels")
    
    -- Set up the callback
    spacingSlider:SetScript("OnValueChanged", function(self, value)
        self.Text:SetText("Spacing: " .. math.floor(value) .. " pixels")
        addon:SetSetting("windowSpacing", math.floor(value))
    end)
    
    yOffset = yOffset - 60
    
    -- Default Window Width
    local widthLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    widthLabel:SetPoint("TOPLEFT", 10, yOffset)
    widthLabel:SetText("Default Window Width:")
    
    local widthSlider = CreateFrame("Slider", nil, scrollChild, "OptionsSliderTemplate")
    widthSlider:SetPoint("TOPLEFT", 20, yOffset - 20)
    widthSlider:SetWidth(400)
    widthSlider:SetMinMaxValues(250, 800)
    widthSlider:SetValueStep(10)
    widthSlider:SetObeyStepOnDrag(true)
    
    -- Set up the callback first
    -- Set the initial value first
    widthSlider:SetValue(addon:GetSetting("defaultWindowWidth") or 400)
    if not widthSlider.Text then
        widthSlider.Text = widthSlider:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        widthSlider.Text:SetPoint("BOTTOMLEFT", widthSlider, "TOPLEFT", 0, 0)
    end
    widthSlider.Text:SetText("Width: " .. (addon:GetSetting("defaultWindowWidth") or 400) .. " pixels")
    
    -- Set up the callback
    widthSlider:SetScript("OnValueChanged", function(self, value)
        self.Text:SetText("Width: " .. math.floor(value) .. " pixels")
        addon:SetSetting("defaultWindowWidth", math.floor(value))
    end)
    
    yOffset = yOffset - 60
    
    -- Default Window Height
    local heightLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    heightLabel:SetPoint("TOPLEFT", 10, yOffset)
    heightLabel:SetText("Default Window Height:")
    
    local heightSlider = CreateFrame("Slider", nil, scrollChild, "OptionsSliderTemplate")
    heightSlider:SetPoint("TOPLEFT", 20, yOffset - 20)
    heightSlider:SetWidth(400)
    heightSlider:SetMinMaxValues(200, 600)
    heightSlider:SetValueStep(10)
    heightSlider:SetObeyStepOnDrag(true)
    
    -- Set the initial value first
    heightSlider:SetValue(addon:GetSetting("defaultWindowHeight") or 300)
    if not heightSlider.Text then
        heightSlider.Text = heightSlider:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        heightSlider.Text:SetPoint("BOTTOMLEFT", heightSlider, "TOPLEFT", 0, 0)
    end
    heightSlider.Text:SetText("Height: " .. (addon:GetSetting("defaultWindowHeight") or 300) .. " pixels")
    
    -- Set up the callback
    heightSlider:SetScript("OnValueChanged", function(self, value)
        self.Text:SetText("Height: " .. math.floor(value) .. " pixels")
        addon:SetSetting("defaultWindowHeight", math.floor(value))
    end)
    
    yOffset = yOffset - 60
    
    -- Info text
    local spawnInfo = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    spawnInfo:SetPoint("TOPLEFT", 10, yOffset)
    spawnInfo:SetPoint("TOPRIGHT", -10, yOffset)
    spawnInfo:SetJustifyH("LEFT")
    spawnInfo:SetText("New windows spawn at the configured anchor position and cascade downward with spacing between them. Anchor offsets are saved in settings.")
    spawnInfo:SetTextColor(0.7, 0.7, 0.7)
    yOffset = yOffset - 12
    
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
        UIDropDownMenu_SetSelectedValue(retentionDropdown, DEFAULT_SETTINGS.historyRetentionMode)
        spawnXSlider:SetValue(DEFAULT_SETTINGS.spawnAnchorX)
        spawnYSlider:SetValue(DEFAULT_SETTINGS.spawnAnchorY)
        spacingSlider:SetValue(DEFAULT_SETTINGS.windowSpacing)
        widthSlider:SetValue(DEFAULT_SETTINGS.defaultWindowWidth)
        heightSlider:SetValue(DEFAULT_SETTINGS.defaultWindowHeight)
        
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
        addon:DebugMessage("Settings reset to defaults.")
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
