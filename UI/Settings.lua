-- Settings UI and configuration
local addon = WhisperManager;

local DEFAULT_SETTINGS = {
    messageFontSize = 14,
    inputFontSize = 14,
    fontFamily = "Fonts\\ARIALN.TTF", -- Default to Arial per user request
    
    -- Notification settings
    notificationSound = SOUNDKIT.TELL_MESSAGE, -- Default notification sound (using sound kit ID)
    soundChannel = "Master", -- Sound channel (Master, SFX, Music, Ambience, Dialog)
    enableTaskbarAlert = true, -- Enable Windows taskbar alert on whisper
    
    -- Chat suppression 
    suppressDefaultChat = false, -- Do not suppress whispers from default chat

    -- Chat mode
    chatModeEnabled = false, -- Enables in-window reply editbox and multi-window mode

    -- Startup behavior settings
    defaultBehavior = "silent_off_chat_off", -- Startup preset for Silent/Chat mode
    settingBehavior = "preferRemembering", -- preferRemembering | preferLoadingDefault

    -- Silent Mode settings (legacy compatibility)
    silentModeEnabled = false, -- Current Silent Mode state (used when persistence is enabled)
    rememberSilentModeAcrossSessions = false, -- Persist Silent Mode state across sessions
    silentModeDefaultEnabled = false, -- Session default when persistence is disabled
    
    -- Window spawn settings
    spawnAnchorX = 450, -- X offset from center (default: screen center)
    spawnAnchorY = 200, -- Y offset from center (default: upper center)
    
    -- Default window size
    defaultWindowWidth = 340,
    defaultWindowHeight = 200,
    
    -- History retention settings
    historyRetentionMode = "mode1", -- none, mode1, mode2, mode3, mode4, mode5
    
    -- Window appearance settings
    windowBackgroundColor = {r = 0, g = 0, b = 0},
    windowBackgroundAlpha = 0.9,
    titleBarColor = {r = 0, g = 0, b = 0},
    titleBarAlpha = 0.8,
    inputBoxColor = {r = 0, g = 0, b = 0},
    inputBoxAlpha = 0.9,
    recentChatBackgroundColor = {r = 0, g = 0, b = 0},
    recentChatBackgroundAlpha = 0.9,
    
    -- Button settings
    enableTRP3Button = false, -- Show TRP3 button (disabled by default)
    enableGinviteButton = false, -- Show ginvite button (disabled by default)
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
    {name = "(Safest) Keep 10 recent (3 mo), delete rest 3 mo", value = "mode1", keepCount = 10, keepMonths = 3, deleteMonths = 3},
    {name = "(Safe) Keep 20 recent (6 mo), delete rest 4 mo", value = "mode2", keepCount = 20, keepMonths = 6, deleteMonths = 4},
    {name = "(!Recruiter) Keep 5 recent (6 mo), delete rest 6 mo", value = "mode3", keepCount = 5, keepMonths = 6, deleteMonths = 6},
    {name = "(!Unsafe) Keep 30 recent (12 mo), delete rest 6 mo", value = "mode4", keepCount = 30, keepMonths = 12, deleteMonths = 6},
}

local DEFAULT_BEHAVIOR_OPTIONS = {
    {name = "Silent Mode Enabled | Chat Mode Enabled", value = "silent_on_chat_on"},
    {name = "Silent Mode Disabled | Chat Mode Disabled", value = "silent_off_chat_off"},
    {name = "Silent Mode Enabled | Chat Mode Disabled", value = "silent_on_chat_off"},
}

local SETTING_BEHAVIOR_OPTIONS = {
    {name = "Prefer Remembering", value = "preferRemembering"},
    {name = "Prefer Loading Default", value = "preferLoadingDefault"},
}

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
    -- Ensure new button settings always exist
    if WhisperManager_Config.settings.enableTRP3Button == nil then
        WhisperManager_Config.settings.enableTRP3Button = false
    end
    if WhisperManager_Config.settings.enableGinviteButton == nil then
        WhisperManager_Config.settings.enableGinviteButton = false
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

-- Apply Settings to Existing Windows
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

-- Sound Notification Functions
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

-- Settings Frame Creation
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
        local current = { r = color.r, g = color.g, b = color.b }

        ColorPickerFrame:SetupColorPickerAndShow({
            r = current.r,
            g = current.g,
            b = current.b,
            opacity = 1,
            hasOpacity = false,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                addon:SetSetting(settingKey, { r = r, g = g, b = b })
                self:SetBackdropColor(r, g, b, 1)
            end,
            cancelFunc = function(previousValues)
                if previousValues then
                    addon:SetSetting(settingKey, { r = previousValues.r, g = previousValues.g, b = previousValues.b })
                    self:SetBackdropColor(previousValues.r, previousValues.g, previousValues.b, 1)
                end
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

-- Helper function to create color picker with opacity
local function CreateColorAlphaPicker(parent, label, colorKey, alphaKey, x, y, applyCallback)
    -- Label
    local labelText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelText:SetPoint("TOPLEFT", x, y)
    labelText:SetText(label)
    
    -- Color swatch button
    local colorSwatch = CreateFrame("Button", nil, parent, "BackdropTemplate")
    colorSwatch:SetPoint("TOPLEFT", x + 200, y - 3)
    colorSwatch:SetSize(20, 20)
    colorSwatch:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 8,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    
    local color = addon:GetSetting(colorKey) or {r = 0, g = 0, b = 0}
    local alpha = addon:GetSetting(alphaKey) or 0.9
    colorSwatch:SetBackdropColor(color.r, color.g, color.b, alpha)
    colorSwatch:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    
    colorSwatch:SetScript("OnClick", function(self)
        local currentColor = addon:GetSetting(colorKey) or {r = 0, g = 0, b = 0}
        local currentAlpha = addon:GetSetting(alphaKey) or 0.9
        
        ColorPickerFrame:SetupColorPickerAndShow({
            r = currentColor.r,
            g = currentColor.g,
            b = currentColor.b,
            opacity = currentAlpha,
            hasOpacity = true,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                local a = ColorPickerFrame:GetColorAlpha()
                addon:SetSetting(colorKey, {r = r, g = g, b = b})
                addon:SetSetting(alphaKey, a)
                self:SetBackdropColor(r, g, b, a)
                if applyCallback then applyCallback() end
            end,
            opacityFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                local a = ColorPickerFrame:GetColorAlpha()
                addon:SetSetting(colorKey, {r = r, g = g, b = b})
                addon:SetSetting(alphaKey, a)
                self:SetBackdropColor(r, g, b, a)
                if applyCallback then applyCallback() end
            end,
            cancelFunc = function()
                addon:SetSetting(colorKey, currentColor)
                addon:SetSetting(alphaKey, currentAlpha)
                self:SetBackdropColor(currentColor.r, currentColor.g, currentColor.b, currentAlpha)
                if applyCallback then applyCallback() end
            end,
        })
    end)
    
    colorSwatch:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Click to change color and transparency", 1, 1, 1)
        GameTooltip:Show()
    end)
    
    colorSwatch:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    return colorSwatch
end

local function GetCenterOffsets(frame, parent)
    if not frame then return 0, 0 end
    parent = parent or UIParent

    local centerX, centerY = frame:GetCenter()
    local parentCenterX, parentCenterY = parent:GetCenter()
    if not centerX or not centerY or not parentCenterX or not parentCenterY then
        return 0, 0
    end

    return math.floor(centerX - parentCenterX + 0.5), math.floor(centerY - parentCenterY + 0.5)
end

function addon:UpdateSpawnPreviewStatus()
    if not self.settingsFrame or not self.settingsFrame.spawnPreviewStatus then return end

    local preview = self.spawnPreviewWindow
    if not preview or not preview:IsShown() then
        self.settingsFrame.spawnPreviewStatus:SetText("Example window is hidden.")
        return
    end

    local width, height = preview:GetSize()
    local x, y = GetCenterOffsets(preview, addon:GetOverlayParent())
    self.settingsFrame.spawnPreviewStatus:SetText(
        string.format("Preview X:%d  Y:%d  W:%d  H:%d", x, y, math.floor(width + 0.5), math.floor(height + 0.5))
    )
end

function addon:CreateSpawnPreviewWindow()
    if self.spawnPreviewWindow then
        local x = self:GetSetting("spawnAnchorX") or 0
        local y = self:GetSetting("spawnAnchorY") or 200
        local w = self:GetSetting("defaultWindowWidth") or 340
        local h = self:GetSetting("defaultWindowHeight") or 200
        self.spawnPreviewWindow:ClearAllPoints()
        self.spawnPreviewWindow:SetPoint("CENTER", addon:GetOverlayParent(), "CENTER", x, y)
        self.spawnPreviewWindow:SetSize(w, h)
        self.spawnPreviewWindow:Show()
        self:UpdateSpawnPreviewStatus()
        return self.spawnPreviewWindow
    end

    local preview = CreateFrame("Frame", "WhisperManager_SpawnPreview", addon:GetOverlayParent(), "BackdropTemplate")
    preview:SetFrameStrata("DIALOG")
    preview:SetToplevel(true)
    preview:SetMovable(true)
    preview:SetResizable(true)
    preview:SetResizeBounds(250, 100, 800, 600)
    preview:EnableMouse(true)
    preview:RegisterForDrag("LeftButton")
    preview:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    preview:SetBackdropColor(0, 0, 0, 0.9)
    preview:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    preview.titleBar = CreateFrame("Frame", nil, preview, "BackdropTemplate")
    preview.titleBar:SetPoint("TOPLEFT", 3, -3)
    preview.titleBar:SetPoint("TOPRIGHT", -3, -3)
    preview.titleBar:SetHeight(24)
    preview.titleBar:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground", tile = false })
    preview.titleBar:SetBackdropColor(0, 0, 0, 0.8)

    preview.title = preview.titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    preview.title:SetPoint("CENTER", 0, 0)
    preview.title:SetText("Example Whisper Window")

    preview.closeBtn = CreateFrame("Button", nil, preview, "UIPanelCloseButton")
    preview.closeBtn:SetPoint("TOPRIGHT", -2, -2)
    preview.closeBtn:SetSize(24, 24)
    preview.closeBtn:SetScript("OnClick", function()
        preview:Hide()
    end)

    preview.resizeBtn = CreateFrame("Button", nil, preview)
    preview.resizeBtn:SetSize(16, 16)
    preview.resizeBtn:SetPoint("BOTTOMRIGHT")
    preview.resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    preview.resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    preview.resizeBtn:SetScript("OnMouseDown", function()
        preview:StartSizing("BOTTOMRIGHT")
    end)
    preview.resizeBtn:SetScript("OnMouseUp", function()
        preview:StopMovingOrSizing()
        addon:UpdateSpawnPreviewStatus()
    end)

    preview:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    preview:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        addon:UpdateSpawnPreviewStatus()
    end)
    preview:SetScript("OnSizeChanged", function()
        addon:UpdateSpawnPreviewStatus()
    end)
    preview:SetScript("OnShow", function()
        addon:UpdateSpawnPreviewStatus()
    end)
    preview:SetScript("OnHide", function()
        addon:UpdateSpawnPreviewStatus()
    end)

    self.spawnPreviewWindow = preview
    return self:CreateSpawnPreviewWindow()
end

function addon:SaveSpawnSettingsFromPreview()
    if not self.spawnPreviewWindow then
        self:CreateSpawnPreviewWindow()
    end

    local preview = self.spawnPreviewWindow
    if not preview then return end

    local width, height = preview:GetSize()
    local x, y = GetCenterOffsets(preview, addon:GetOverlayParent())

    self:SetSetting("spawnAnchorX", x)
    self:SetSetting("spawnAnchorY", y)
    self:SetSetting("defaultWindowWidth", math.floor(width + 0.5))
    self:SetSetting("defaultWindowHeight", math.floor(height + 0.5))

    if not WhisperManager_Config then
        WhisperManager_Config = {}
    end
    WhisperManager_Config.windowPositions = {}
    addon.sessionWindowSizes = {}

    for _, win in pairs(self.windows) do
        if win then
            win:ClearAllPoints()
            win:SetPoint("CENTER", addon:GetOverlayParent(), "CENTER", x, y)
            win:SetSize(math.floor(width + 0.5), math.floor(height + 0.5))
        end
    end

    self:SaveSettings()
    self:UpdateSpawnPreviewStatus()
    self:Print("Saved example window as default whisper window size and spawn position. Previous per-chat position overrides were cleared.")
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
    frame:SetScript("OnHide", function()
        if addon.spawnPreviewWindow and addon.spawnPreviewWindow:IsShown() then
            addon.spawnPreviewWindow:Hide()
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
    -- REMOVED per user request
    -- yOffset = yOffset - 30
    
    -- Whisper Receive / Send (inline)
    -- REMOVED
    -- yOffset = yOffset - 30

    -- BNet Receive / Send (inline)
    -- REMOVED
    -- yOffset = yOffset - 30

    -- Timestamp Color (own line)
    -- REMOVED
    -- yOffset = yOffset - 50
    
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

    yOffset = yOffset - 34

    -- Default Behavior dropdown
    local defaultBehaviorLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    defaultBehaviorLabel:SetPoint("TOPLEFT", 10, yOffset)
    defaultBehaviorLabel:SetText("Default Behavior:")

    local defaultBehaviorDropdown = CreateFrame("Frame", "WhisperManager_DefaultBehaviorDropdown", scrollChild, "UIDropDownMenuTemplate")
    defaultBehaviorDropdown:SetPoint("LEFT", defaultBehaviorLabel, "RIGHT", 6, 0)
    UIDropDownMenu_SetWidth(defaultBehaviorDropdown, 280)
    UIDropDownMenu_Initialize(defaultBehaviorDropdown, function(self, level)
        for _, option in ipairs(DEFAULT_BEHAVIOR_OPTIONS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.name
            info.value = option.value
            info.func = function(self)
                addon:SetSetting("defaultBehavior", self.value)
                UIDropDownMenu_SetSelectedValue(defaultBehaviorDropdown, self.value)
            end
            info.checked = (addon:GetSetting("defaultBehavior") == option.value)
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    UIDropDownMenu_SetSelectedValue(defaultBehaviorDropdown, addon:GetSetting("defaultBehavior"))

    yOffset = yOffset - 34

    -- Setting Behavior dropdown
    local settingBehaviorLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    settingBehaviorLabel:SetPoint("TOPLEFT", 10, yOffset)
    settingBehaviorLabel:SetText("Setting Behavior:")

    local settingBehaviorDropdown = CreateFrame("Frame", "WhisperManager_SettingBehaviorDropdown", scrollChild, "UIDropDownMenuTemplate")
    settingBehaviorDropdown:SetPoint("LEFT", settingBehaviorLabel, "RIGHT", 12, 0)
    UIDropDownMenu_SetWidth(settingBehaviorDropdown, 220)
    UIDropDownMenu_Initialize(settingBehaviorDropdown, function(self, level)
        for _, option in ipairs(SETTING_BEHAVIOR_OPTIONS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.name
            info.value = option.value
            info.func = function(self)
                addon:SetSetting("settingBehavior", self.value)
                UIDropDownMenu_SetSelectedValue(settingBehaviorDropdown, self.value)
            end
            info.checked = (addon:GetSetting("settingBehavior") == option.value)
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    UIDropDownMenu_SetSelectedValue(settingBehaviorDropdown, addon:GetSetting("settingBehavior"))

    yOffset = yOffset - 34

    -- TRP3 Button Toggle Checkbox
    local trp3Checkbox = CreateFrame("CheckButton", nil, scrollChild, "UICheckButtonTemplate")
    trp3Checkbox:SetPoint("TOPLEFT", 10, yOffset)
    trp3Checkbox:SetSize(24, 24)
    trp3Checkbox:SetChecked(addon:GetSetting("enableTRP3Button"))

    local trp3Label = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    trp3Label:SetPoint("LEFT", trp3Checkbox, "RIGHT", 5, 0)
    trp3Label:SetText("Show 'Open TRP3' Button in Whisper Window")

    trp3Checkbox:SetScript("OnClick", function(self)
        addon:SetSetting("enableTRP3Button", self:GetChecked())
        for _, win in pairs(addon.windows) do
            if win.trp3Btn then
                if self:GetChecked() then
                    win.trp3Btn:Show()
                else
                    win.trp3Btn:Hide()
                end
            end
        end
    end)
    -- Place Ginvite checkbox directly below TRP3 checkbox
    yOffset = yOffset - 34

    -- Ginvite Button Toggle Checkbox
    local ginviteCheckbox = CreateFrame("CheckButton", nil, scrollChild, "UICheckButtonTemplate")
    ginviteCheckbox:SetPoint("TOPLEFT", 10, yOffset)
    ginviteCheckbox:SetSize(24, 24)
    ginviteCheckbox:SetChecked(addon:GetSetting("enableGinviteButton"))

    local ginviteLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ginviteLabel:SetPoint("LEFT", ginviteCheckbox, "RIGHT", 5, 0)
    ginviteLabel:SetText("Show 'Send Guild Invite' Button in Whisper Window")

    ginviteCheckbox:SetScript("OnClick", function(self)
        addon:SetSetting("enableGinviteButton", self:GetChecked())
        for _, win in pairs(addon.windows) do
            if win.ginviteBtn then
                if self:GetChecked() then
                    win.ginviteBtn:Show()
                else
                    win.ginviteBtn:Hide()
                end
            end
        end
    end)
    yOffset = yOffset - 34
    
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

    local spawnInfo = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    spawnInfo:SetPoint("TOPLEFT", 10, yOffset)
    spawnInfo:SetPoint("TOPRIGHT", -10, yOffset)
    spawnInfo:SetJustifyH("LEFT")
    spawnInfo:SetText("Open an example window, move and resize it, then click Save Example. Its final position and size become your default whisper window spawn settings.")
    spawnInfo:SetTextColor(0.7, 0.7, 0.7)
    yOffset = yOffset - 42

    local openExampleBtn = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
    openExampleBtn:SetSize(140, 24)
    openExampleBtn:SetPoint("TOPLEFT", 10, yOffset)
    openExampleBtn:SetText("Open Example")
    openExampleBtn:SetScript("OnClick", function()
        addon:CreateSpawnPreviewWindow()
    end)

    local saveExampleBtn = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
    saveExampleBtn:SetSize(140, 24)
    saveExampleBtn:SetPoint("LEFT", openExampleBtn, "RIGHT", 12, 0)
    saveExampleBtn:SetText("Save Example")
    saveExampleBtn:SetScript("OnClick", function()
        addon:SaveSpawnSettingsFromPreview()
    end)

    yOffset = yOffset - 30

    frame.spawnPreviewStatus = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.spawnPreviewStatus:SetPoint("TOPLEFT", 10, yOffset)
    frame.spawnPreviewStatus:SetPoint("TOPRIGHT", -10, yOffset)
    frame.spawnPreviewStatus:SetJustifyH("LEFT")
    frame.spawnPreviewStatus:SetTextColor(0.8, 0.8, 0.8)
    frame.spawnPreviewStatus:SetText("Example window is hidden.")
    addon:UpdateSpawnPreviewStatus()

    yOffset = yOffset - 40
    
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
    yOffset = yOffset - 60
    
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
        UIDropDownMenu_Initialize(fontDropdown, fontDropdown.initialize)
        messageSizeSlider:SetValue(DEFAULT_SETTINGS.messageFontSize)
        inputSizeSlider:SetValue(DEFAULT_SETTINGS.inputFontSize)
        UIDropDownMenu_SetSelectedValue(soundDropdown, DEFAULT_SETTINGS.notificationSound)
        UIDropDownMenu_Initialize(soundDropdown, soundDropdown.initialize)
        UIDropDownMenu_SetSelectedValue(channelDropdown, DEFAULT_SETTINGS.soundChannel)
        UIDropDownMenu_Initialize(channelDropdown, channelDropdown.initialize)
        taskbarCheckbox:SetChecked(DEFAULT_SETTINGS.enableTaskbarAlert)
        addon:InitializeSilentModeState()
        UIDropDownMenu_SetSelectedValue(defaultBehaviorDropdown, DEFAULT_SETTINGS.defaultBehavior)
        UIDropDownMenu_Initialize(defaultBehaviorDropdown, defaultBehaviorDropdown.initialize)
        UIDropDownMenu_SetSelectedValue(settingBehaviorDropdown, DEFAULT_SETTINGS.settingBehavior)
        UIDropDownMenu_Initialize(settingBehaviorDropdown, settingBehaviorDropdown.initialize)
        UIDropDownMenu_SetSelectedValue(retentionDropdown, DEFAULT_SETTINGS.historyRetentionMode)
        UIDropDownMenu_Initialize(retentionDropdown, retentionDropdown.initialize)

        if addon.spawnPreviewWindow then
            addon.spawnPreviewWindow:ClearAllPoints()
            addon.spawnPreviewWindow:SetPoint("CENTER", addon:GetOverlayParent(), "CENTER", DEFAULT_SETTINGS.spawnAnchorX, DEFAULT_SETTINGS.spawnAnchorY)
            addon.spawnPreviewWindow:SetSize(DEFAULT_SETTINGS.defaultWindowWidth, DEFAULT_SETTINGS.defaultWindowHeight)
        end
        addon:UpdateSpawnPreviewStatus()
        
        -- Update appearance color swatches
        if frame.windowBg then
            local bgColor = DEFAULT_SETTINGS.windowBackgroundColor
            local bgAlpha = DEFAULT_SETTINGS.windowBackgroundAlpha
            frame.windowBg:SetBackdropColor(bgColor.r, bgColor.g, bgColor.b, bgAlpha)
        end
        
        if frame.titleBar then
            local titleColor = DEFAULT_SETTINGS.titleBarColor
            local titleAlpha = DEFAULT_SETTINGS.titleBarAlpha
            frame.titleBar:SetBackdropColor(titleColor.r, titleColor.g, titleColor.b, titleAlpha)
        end
        
        if frame.inputBox then
            local inputColor = DEFAULT_SETTINGS.inputBoxColor
            local inputAlpha = DEFAULT_SETTINGS.inputBoxAlpha
            frame.inputBox:SetBackdropColor(inputColor.r, inputColor.g, inputColor.b, inputAlpha)
        end
        
        if frame.recentChat then
            local recentColor = DEFAULT_SETTINGS.recentChatBackgroundColor
            local recentAlpha = DEFAULT_SETTINGS.recentChatBackgroundAlpha
            frame.recentChat:SetBackdropColor(recentColor.r, recentColor.g, recentColor.b, recentAlpha)
        end
        
        addon:ApplyFontSettings()
        addon:ApplyAppearanceSettings()
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
        self:UpdateSpawnPreviewStatus()
        -- Refresh all window buttons when settings frame is shown
        for _, win in pairs(addon.windows) do
            if win.trp3Btn then
                if addon:GetSetting("enableTRP3Button") then
                    win.trp3Btn:Show()
                else
                    win.trp3Btn:Hide()
                end
            end
            if win.ginviteBtn then
                if addon:GetSetting("enableGinviteButton") then
                    win.ginviteBtn:Show()
                else
                    win.ginviteBtn:Hide()
                end
            end
        end
    end
end
