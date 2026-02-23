-- Configuration
local DEFAULT_DEBUG_MODE = false

local ADDON_NAME, addonFromTOC = ...
_G["WhisperManager"] = _G["WhisperManager"] or {}
local addon = _G["WhisperManager"]
addon._tocName = ADDON_NAME

-- Addon State
addon.windows = {};              -- Active whisper window frames
addon.playerDisplayNames = {};   -- Cached display names
addon.recentChats = {};          -- Recent conversation tracking
addon.nextFrameLevel = 1;        -- Z-order tracking for windows
addon.cascadeCounter = 0;        -- Counter for alternating window positioning
addon.combatQueue = {};          -- Queue for operations during combat lockdown

-- Constants
addon.MAX_HISTORY_LINES = 1000;
addon.CHAT_MAX_LETTERS = 245;
addon.RECENT_CHAT_EXPIRY = 72 * 60 * 60;  -- 72 hours in seconds
addon.FOCUSED_ALPHA = 1.0;
addon.UNFOCUSED_ALPHA = 0.65;

-- Overlay Helpers (keep frames visible over major Blizzard scenes like Housing)
function addon:GetOverlayParent()
    if UIParent and UIParent:IsShown() then
        return UIParent
    end

    local housingFrame = _G.HouseEditorFrame or _G.PlayerHousingFrame
    if housingFrame and housingFrame:IsShown() then
        return housingFrame
    end

    return WorldFrame
end

--- Apply overlay settings (parent only, keep DIALOG strata for dropdown compatibility)
function addon:EnsureFrameOverlay(frame)
    if not frame then return end

    local parent = self:GetOverlayParent()
    if parent and frame:GetParent() ~= parent then
        frame:SetParent(parent)
    end

    frame:SetFrameStrata("DIALOG")

    if frame.SetToplevel then
        frame:SetToplevel(true)
    end
end

--- Re-apply overlay settings to all primary WhisperManager frames
function addon:RefreshOverlayAnchors()
    local parent = self:GetOverlayParent()

    local function apply(frame)
        if not frame then return end
        if parent and frame:GetParent() ~= parent then
            frame:SetParent(parent)
        end
        frame:SetFrameStrata("DIALOG")
        if frame.SetToplevel then frame:SetToplevel(true) end
    end

    apply(self.floatingButton)
    apply(self.recentChatsFrame)
    apply(self.historyFrame)
    apply(self.settingsFrame)
    apply(self.chatExportFrame)

    for _, win in pairs(self.windows) do
        if win then
            apply(win)
            apply(win.InputContainer)
        end
    end
end

-- Class ID to Class Token mapping
addon.CLASS_ID_TO_TOKEN = {
    [1] = "WARRIOR",
    [2] = "PALADIN",
    [3] = "HUNTER",
    [4] = "ROGUE",
    [5] = "PRIEST",
    [6] = "DEATHKNIGHT",
    [7] = "SHAMAN",
    [8] = "MAGE",
    [9] = "WARLOCK",
    [10] = "MONK",
    [11] = "DRUID",
    [12] = "DEMONHUNTER",
    [13] = "EVOKER",
}

-- Reverse mapping for quick lookup
addon.CLASS_TOKEN_TO_ID = {
    ["WARRIOR"] = 1,
    ["PALADIN"] = 2,
    ["HUNTER"] = 3,
    ["ROGUE"] = 4,
    ["PRIEST"] = 5,
    ["DEATHKNIGHT"] = 6,
    ["SHAMAN"] = 7,
    ["MAGE"] = 8,
    ["WARLOCK"] = 9,
    ["MONK"] = 10,
    ["DRUID"] = 11,
    ["DEMONHUNTER"] = 12,
    ["EVOKER"] = 13,
}

-- Debug System
addon.debugEnabled = DEFAULT_DEBUG_MODE;

--- Output debug message (only if debug enabled)
function addon:DebugMessage(...)
    if self.debugEnabled then
        local args = {...}
        for i = 1, #args do
            args[i] = tostring(args[i])
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00WhisperManager:|r " .. table.concat(args, " "));
    end
end

--- Print message to chat (always visible)
function addon:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00WhisperManager:|r " .. tostring(message))
end

--- Set debug mode on or off
function addon:SetDebugEnabled(enabled)
    self.debugEnabled = enabled
    WhisperManager_Config.debug = enabled
    if enabled then
        self:Print("|cff00ff00Debug mode enabled.|r")
    else
        self:Print("|cffff8800Debug mode disabled.|r")
    end
end

-- Initialization
function addon:Initialize()
    self:DebugMessage("=== WhisperManager Initializing ===")
    
    -- Initialize saved variable tables
    if type(WhisperManager_HistoryDB) ~= "table" then
        WhisperManager_HistoryDB = {}
    end
    
    if type(WhisperManager_RecentChats) ~= "table" then
        WhisperManager_RecentChats = {}
    end
    
    if type(WhisperManager_WindowDB) ~= "table" then
        WhisperManager_WindowDB = {}
    end
    
    if type(WhisperManager_CharacterDB) ~= "table" then
        WhisperManager_CharacterDB = {}
    end
    
    -- Add current character to character database
    local playerName, playerRealm = UnitName("player")
    local realm = (playerRealm or GetRealmName()):gsub("%s+", "")
    local fullPlayerName = playerName .. "-" .. realm
    WhisperManager_CharacterDB[fullPlayerName] = true
    
    -- Scan existing BNet conversation history to find all our character names
    if WhisperManager_HistoryDB then
        local charactersFound = 0
        for playerKey, history in pairs(WhisperManager_HistoryDB) do
            if playerKey ~= "__schema" and playerKey:match("^bnet_") and type(history) == "table" then
                for _, entry in ipairs(history) do
                    local author = entry.a or entry.author
                    if author and author:match("^[^|]+%-[^|]+$") and not author:match("|K") then
                        if not WhisperManager_CharacterDB[author] then
                            WhisperManager_CharacterDB[author] = true
                            charactersFound = charactersFound + 1
                        end
                    end
                end
            end
        end
        if charactersFound > 0 then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00WhisperManager:|r Found " .. charactersFound .. " additional character(s) in BNet history")
        end
    end
    
    if type(WhisperManager_Config) ~= "table" then
        self:DebugMessage("Creating new WhisperManager_Config (first time setup)")
        WhisperManager_Config = {}
    end
    
    -- Validate schema version
    self:DebugMessage("Running schema validation...")
    if not self:ValidateSchema() then
        self:Print("|cffff0000WhisperManager has been disabled due to version mismatch!|r")
        self:Print("|cffff8800Your saved data is safe and has not been modified.|r")
        return
    end
    
    if WhisperManager_HistoryDB and not WhisperManager_HistoryDB.__schema then
        WhisperManager_HistoryDB.__schema = self.EXPECTED_SCHEMA_VERSION
    end
    
    self:DebugMessage("Schema validation passed - continuing initialization")
    
    if WhisperManager_Config.settings then
        self:DebugMessage("WhisperManager_Config exists, loading saved settings...")
        if WhisperManager_Config.settings then
            self:DebugMessage("Found existing settings table:")
            self:DebugMessage("  spawnAnchorX: " .. tostring(WhisperManager_Config.settings.spawnAnchorX))
            self:DebugMessage("  spawnAnchorY: " .. tostring(WhisperManager_Config.settings.spawnAnchorY))
            self:DebugMessage("  windowSpacing: " .. tostring(WhisperManager_Config.settings.windowSpacing))
            self:DebugMessage("  defaultWindowWidth: " .. tostring(WhisperManager_Config.settings.defaultWindowWidth))
            self:DebugMessage("  defaultWindowHeight: " .. tostring(WhisperManager_Config.settings.defaultWindowHeight))
        end
    end

    -- Load settings immediately on startup to prevent race conditions.
    self:DebugMessage("Loading settings...")
    self.settings = self:LoadSettings()
    self:DebugMessage("Settings loaded into addon.settings")
    self:DebugMessage("  addon.settings reference: " .. tostring(self.settings))
    self:DebugMessage("  WhisperManager_Config.settings reference: " .. tostring(WhisperManager_Config.settings))
    self:DebugMessage("  Are they the same table? " .. tostring(self.settings == WhisperManager_Config.settings))
    
    if self.settings ~= WhisperManager_Config.settings then
        self:DebugMessage("WARNING: Table references are different! Forcing addon.settings to point to WhisperManager_Config.settings")
        self.settings = WhisperManager_Config.settings
        self:DebugMessage("  After fix, same table? " .. tostring(self.settings == WhisperManager_Config.settings))
    end

    -- Load display names from history
    for key, history in pairs(WhisperManager_HistoryDB) do
        if key ~= "__schema" and type(history) == "table" and history.__display then
            addon.playerDisplayNames[key] = history.__display
        end
    end

    -- Load debug setting
    if WhisperManager_Config.debug == nil then
        WhisperManager_Config.debug = DEFAULT_DEBUG_MODE
    end
    addon.debugEnabled = not not WhisperManager_Config.debug

    if addon.RegisterSlashCommands then
        addon:RegisterSlashCommands()
    end

    if addon.LoadSettings then
        addon.settings = addon:LoadSettings()
        self:DebugMessage("Settings loaded in Initialize():")
        self:DebugMessage("  addon.settings.spawnAnchorX =", addon.settings.spawnAnchorX)
        self:DebugMessage("  addon.settings.spawnAnchorY =", addon.settings.spawnAnchorY)
        self:DebugMessage("  addon.settings.windowSpacing =", addon.settings.windowSpacing)
    end

    self:InitializeSilentModeState()
    
    -- Hook shift-click item linking into our edit boxes
    local originalInsertLink = ChatFrameUtil.InsertLink
    ChatFrameUtil.InsertLink = function(link)
        if addon.activeEditBox and addon.activeEditBox:IsVisible() and addon.activeEditBox:HasFocus() then
            addon.activeEditBox:Insert(link)
            return true
        else
            return originalInsertLink(link)
        end
    end

    self:RefreshOverlayAnchors()
    if UIParent and not UIParent.__wmOverlayHookedForWhisperManager then
        UIParent.__wmOverlayHookedForWhisperManager = true
        UIParent:HookScript("OnShow", function() addon:RefreshOverlayAnchors() end)
        UIParent:HookScript("OnHide", function() addon:RefreshOverlayAnchors() end)
    end

    local housingFrame = _G.HouseEditorFrame or _G.PlayerHousingFrame
    if housingFrame and not housingFrame.__wmOverlayHookedForWhisperManager then
        housingFrame.__wmOverlayHookedForWhisperManager = true
        housingFrame:HookScript("OnShow", function() addon:RefreshOverlayAnchors() end)
        housingFrame:HookScript("OnHide", function() addon:RefreshOverlayAnchors() end)
    end

    -- Initialize TRP3 integration if available
    self:InitializeTRP3Integration()

    self:DebugMessage("WhisperManager initialized.");
end

-- Slash Commands
function addon:RegisterSlashCommands()
    self:DebugMessage("Registering slash commands...")
    
    SLASH_WHISPERMANAGER1 = "/wmgr"
    SLASH_WHISPERMANAGER2 = "/whispermanager"
    
    SlashCmdList["WHISPERMANAGER"] = function(msg)
        addon:HandleSlashCommand(msg)
    end
    
    self:DebugMessage("Slash commands registered: /wmgr and /whispermanager")
end

-- Slash Command Handling
function addon:ResetWindowPositions()
    if not WhisperManager_Config then
        self:Print("No window positions to reset.")
        return
    end
    
    local positionKeys = {
        "windowPositions",   -- Whisper windows (individual chats)
        "buttonPos",         -- Floating action button
        "recentChatsPos",    -- Recent Chats frame
        "historyPos",        -- History Viewer frame
        "settingsPos",       -- Settings frame (add for consistency)
    }
    
    local totalCount = 0
    local details = {}
    
    -- Count and track what's being cleared
    for _, key in ipairs(positionKeys) do
        if WhisperManager_Config[key] then
            local count = 0
            if key == "windowPositions" then
                -- Count individual whisper windows
                for _, _ in pairs(WhisperManager_Config[key]) do
                    count = count + 1
                end
            else
                -- Single window/button positions
                count = 1
            end
            
            if count > 0 then
                totalCount = totalCount + count
                table.insert(details, string.format("%d %s", count, key))
            end
        end
    end
    
    -- Clear all positions
    for _, key in ipairs(positionKeys) do
        WhisperManager_Config[key] = nil
    end
    
    if totalCount > 0 then
        local detailStr = table.concat(details, ", ")
        self:Print(string.format("|cffff00ffReset all window positions (%s). Now use /reload and all windows will spawn at default locations.|r", detailStr))
    else
        self:Print("No window positions to reset.")
    end
end

--- Handle slash command input
-- @param message string Command text entered by user
function addon:HandleSlashCommand(message)
    print("[WM DEBUG] HandleSlashCommand called with: " .. tostring(message))
    local input = self:TrimWhitespace(message or "") or ""
    if input == "" or input:lower() == "help" then
        self:Print("Usage:")
        self:Print("/wmgr debug [on|off|toggle] - Control diagnostic chat output.")
        self:Print("/wmgr reset_positions - Reset saved window positions.")
        self:Print("/wmgr reset_all_data - [Dangerous]  Clear all saved data (history, windows, config).")
        self:Print("/wmgr delete_data_retention_test - [Dangerous] Data retention cleanup (keep 3 recent, delete older than 5 min).")
        self:Print("/wmgr cleanup_empty - [Dangerous] Remove empty conversation entries from history.")
        self:Print("/wmgr test-unread - Create a fake unread message.")
        self:Print("/wmgr read-all - Mark all messages as read.")
        self:Print("Aliases: /wmgr, /whispermanager")
        return
    end

    local command, rest = input:match("^(%S+)%s*(.-)$")
    command = command and command:lower() or ""
    
    if command == "debug" then
        local directive = rest and rest:lower() or ""
        if directive == "on" or directive == "1" or directive == "true" then
            self:SetDebugEnabled(true)
        elseif directive == "off" or directive == "0" or directive == "false" then
            self:SetDebugEnabled(false)
        else
            self:SetDebugEnabled(not self.debugEnabled)
        end
    elseif command == "reset_positions" then
        self:ResetWindowPositions()
    elseif command == "reset_all_data" then
        WhisperManager_HistoryDB = {}
        WhisperManager_WindowDB = {}
        WhisperManager_Config = {}
        WhisperManager_RecentChats = {}
        self:Print("|cffff0000All WhisperManager data has been cleared!|r")
        self:Print("Please /reload to apply changes.")
    elseif command == "delete_data_retention_test" then
        self:RunDebugRetentionCleanup()
    elseif command == "cleanup_empty" then
        local removed = self:CleanupEmptyHistoryEntries()
        if removed > 0 then
            self:Print(string.format("Removed %d empty conversation%s from history.", removed, removed ~= 1 and "s" or ""))
        else
            self:Print("No empty conversations found.")
        end
    elseif command == "test-unread" then
        -- Simulate an unread message
        local testKey = "TestPlayer-TestRealm"
        if not WhisperManager_RecentChats then WhisperManager_RecentChats = {} end
        WhisperManager_RecentChats[testKey] = {
            lastMessageTime = time(),
            isRead = false,
            isBNet = false
        }
        self:Print("Created test unread message for " .. testKey)
        self:UpdateFloatingButtonUnreadStatus()
        if self.recentChatsFrame and self.recentChatsFrame:IsShown() then
            self:RefreshRecentChats()
        end
    elseif command == "read-all" then
        -- Mark all as read
        if WhisperManager_RecentChats then
            for key, data in pairs(WhisperManager_RecentChats) do
                data.isRead = true
            end
            self:Print("Marked all chats as read.")
            self:UpdateFloatingButtonUnreadStatus()
            if self.recentChatsFrame and self.recentChatsFrame:IsShown() then
                self:RefreshRecentChats()
            end
        end
    else
        -- Try to open conversation with the input as player name
        if not self:OpenConversation(input) then
            self:Print(string.format("Unable to open a whisper window for '%s'.", input))
        end
    end
end

-- Hooks
addon.EditBoxInFocus = nil

local Hooked_ChatFrameEditBoxes = {}
local GetKeyboardFocusFn = _G.GetCurrentKeyBoardFocus or _G.GetCurrentKeyboardFocus

local function GetActiveWhisperManagerEditBox()
    local editBox = addon.EditBoxInFocus
    if not editBox then
        return nil
    end

    if not editBox._WhisperManagerInput then
        addon.EditBoxInFocus = nil
        return nil
    end

    if type(GetKeyboardFocusFn) == "function" then
        local keyboardFocus = GetKeyboardFocusFn()
        if keyboardFocus ~= editBox then
            addon.EditBoxInFocus = nil
            return nil
        end
    end

    if not editBox.HasFocus or not editBox:HasFocus() then
        addon.EditBoxInFocus = nil
        return nil
    end

    if editBox.IsVisible and not editBox:IsVisible() then
        addon.EditBoxInFocus = nil
        return nil
    end

    if editBox.IsShown and not editBox:IsShown() then
        addon.EditBoxInFocus = nil
        return nil
    end

    return editBox
end

local function hookChatFrameEditBox(editBox)
    if editBox and not Hooked_ChatFrameEditBoxes[editBox:GetName()] then
        hooksecurefunc(editBox, "Insert", function(self, theText)
            local activeEditBox = GetActiveWhisperManagerEditBox()
            if activeEditBox and activeEditBox ~= self then
                activeEditBox:Insert(theText)
            end
        end)

        editBox.wmIsVisible = editBox.IsVisible
        editBox.IsVisible = function(self)
            if GetActiveWhisperManagerEditBox() then
                return true
            else
                return self:wmIsVisible()
            end
        end

        editBox.wmIsShown = editBox.IsShown
        editBox.IsShown = function(self)
            if GetActiveWhisperManagerEditBox() then
                return true
            else
                return self:wmIsShown()
            end
        end

        hooksecurefunc(editBox, "SetText", function(self, theText)
            local firstChar = ""
            if string.len(theText) > 0 then
                firstChar = string.sub(theText, 1, 1)
            end
            local activeEditBox = GetActiveWhisperManagerEditBox()
            if activeEditBox and activeEditBox ~= self and firstChar ~= "/" then
                activeEditBox:SetText(theText)
            end
        end)

        editBox.wmHighlightText = editBox.HighlightText
        editBox.HighlightText = function(self, theStart, theEnd)
            local activeEditBox = GetActiveWhisperManagerEditBox()
            if activeEditBox and activeEditBox ~= self then
                activeEditBox:HighlightText(theStart, theEnd)
            else
                self:wmHighlightText(theStart, theEnd)
            end
        end

        Hooked_ChatFrameEditBoxes[editBox:GetName()] = true
        addon:DebugMessage("Hooked ChatFrame EditBox:", editBox:GetName())
    end
end

local originalActivateChat = ChatFrameUtil.ActivateChat
ChatFrameUtil.ActivateChat = function(editBox)
    if editBox and editBox.GetAttribute then
        local chatType = editBox:GetAttribute("chatType")
        if chatType and chatType ~= "WHISPER" then
            addon:SetEditBoxFocus(nil)
        end
    end
    originalActivateChat(editBox)
    hookChatFrameEditBox(editBox)
end

local originalGetActiveWindow = ChatFrameUtil.GetActiveWindow
function ChatFrameUtil.GetActiveWindow()
    return GetActiveWhisperManagerEditBox() or originalGetActiveWindow()
end

if ChatEdit_GetActiveWindow then
    local originalChatEdit_GetActiveWindow = ChatEdit_GetActiveWindow
    function ChatEdit_GetActiveWindow()
        return GetActiveWhisperManagerEditBox() or originalChatEdit_GetActiveWindow()
    end
end

function addon:SetEditBoxFocus(editBox)
    if editBox and not editBox._WhisperManagerInput then
        self.EditBoxInFocus = nil
        self:DebugMessage("Ignored non-whisper edit box focus")
        return
    end

    self.EditBoxInFocus = editBox
    if editBox then
        self:DebugMessage("EditBox focus set:", editBox:GetName())
    else
        self:DebugMessage("EditBox focus cleared")
    end
end

function addon:GetEditBoxFocus()
    return self.EditBoxInFocus
end

function addon:SetupChatHooks()
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox then
        hookChatFrameEditBox(DEFAULT_CHAT_FRAME.editBox)
    end
    for i = 1, Constants.ChatFrameConstants.MaxChatWindows do
        local chatFrame = _G["ChatFrame" .. i]
        if chatFrame and chatFrame.editBox then
            hookChatFrameEditBox(chatFrame.editBox)
        end
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00WhisperManager:|r Chat hooks installed")
end

C_Timer.After(0, function()
    addon:SetupChatHooks()
end)

-- Utility Functions
function addon:TrimWhitespace(value)
    if type(value) ~= "string" then return nil end

    local okLeading, noLeading = pcall(string.gsub, value, "^%s+", "")
    if not okLeading then
        return nil
    end

    local okTrailing, trimmed = pcall(string.gsub, noLeading, "%s+$", "")
    if not okTrailing then
        return nil
    end

    return trimmed
end

function addon:ResolveDefaultBehaviorPreset(preset)
    if preset == "silent_on_chat_on" then
        return true, true
    elseif preset == "silent_off_chat_on" then
        return false, true
    elseif preset == "silent_off_chat_off" then
        return false, false
    elseif preset == "silent_on_chat_off" then
        return true, false
    end

    -- Backward compatibility for previously saved values.
    if preset == "silent_on_keep_chat" then
        return true, self:GetSetting("chatModeEnabled") == true
    end

    return false, false
end

function addon:GetDefaultBehaviorLabel(preset)
    local key = preset or self:GetSetting("defaultBehavior") or "silent_off_chat_off"
    if key == "silent_on_chat_on" then
        return "Silent ON | Chat ON"
    elseif key == "silent_off_chat_on" then
        return "Silent OFF | Chat ON"
    elseif key == "silent_off_chat_off" then
        return "Silent OFF | Chat OFF"
    elseif key == "silent_on_chat_off" then
        return "Silent ON | Chat OFF"
    end
    return "Silent OFF | Chat OFF"
end

function addon:ApplyDefaultBehaviorPreset(preset, suppressOutput)
    local targetPreset = preset or self:GetSetting("defaultBehavior") or "silent_off_chat_off"
    local silentEnabled, chatEnabled = self:ResolveDefaultBehaviorPreset(targetPreset)

    self:SetSetting("defaultBehavior", targetPreset)
    self.__silentModeEnabled = silentEnabled == true
    self:SetSetting("silentModeEnabled", self.__silentModeEnabled)
    self:SetSetting("chatModeEnabled", chatEnabled == true)

    if self.EnforceChatModeRestrictions then
        self:EnforceChatModeRestrictions(true)
    end
    if self.ApplyChatModeToWindows then
        self:ApplyChatModeToWindows()
    end

    if not suppressOutput then
        self:Print("Default Behavior set to " .. self:GetDefaultBehaviorLabel(targetPreset) .. ".")
    end
end

function addon:CycleDefaultBehaviorPreset()
    local order = {
        "silent_on_chat_on",
        "silent_off_chat_on",
        "silent_off_chat_off",
        "silent_on_chat_off",
    }

    local current = self:GetSetting("defaultBehavior")
    local currentIndex = 0
    for index, value in ipairs(order) do
        if value == current then
            currentIndex = index
            break
        end
    end

    local nextIndex = (currentIndex % #order) + 1
    local nextPreset = order[nextIndex]
    self:ApplyDefaultBehaviorPreset(nextPreset, false)
end

function addon:InitializeSilentModeState()
    local settingBehavior = self:GetSetting("settingBehavior") or "preferRemembering"
    local defaultBehavior = self:GetSetting("defaultBehavior") or "silent_off_chat_off"

    local silentEnabled
    local chatEnabled

    if settingBehavior == "preferLoadingDefault" then
        silentEnabled, chatEnabled = self:ResolveDefaultBehaviorPreset(defaultBehavior)
    else
        silentEnabled = self:GetSetting("silentModeEnabled") == true
        chatEnabled = self:GetSetting("chatModeEnabled") == true
    end

    self.__silentModeEnabled = silentEnabled == true
    self:SetSetting("silentModeEnabled", self.__silentModeEnabled)
    self:SetSetting("chatModeEnabled", chatEnabled == true)

    if self.ApplyChatModeToWindows then
        self:ApplyChatModeToWindows()
    end

    self:DebugMessage(
        "Mode init. behavior=", tostring(settingBehavior),
        "defaultPreset=", tostring(defaultBehavior),
        "silent=", tostring(self.__silentModeEnabled),
        "chat=", tostring(self:GetSetting("chatModeEnabled") == true)
    )
end

function addon:IsSilentModeEnabled()
    return self.__silentModeEnabled == true
end

function addon:SetSilentModeEnabled(enabled, suppressOutput)
    local isEnabled = enabled == true
    self.__silentModeEnabled = isEnabled
    self:SetSetting("silentModeEnabled", isEnabled)

    if not suppressOutput then
        if isEnabled then
            self:Print("|cffffff00Silent Mode enabled.|r Right-click whisper adds to Recents without opening a window.")
        else
            self:Print("|cff00ff00Silent Mode disabled.|r Right-click whisper opens WhisperManager windows as usual.")
        end
    end
end

local function StripRealmFromName(name)
    if type(name) ~= "string" then return nil end
    return name:match("^[^%-]+")
end
addon.StripRealmFromName = StripRealmFromName

-- Hook Setup
function addon:SetupHooks()
    -- Prevent duplicate hooks
    if addon.__hooksInstalled then
        addon:DebugMessage("Hooks already installed, skipping.")
        return
    end
    addon.__hooksInstalled = true

    local function NormalizeTellTarget(rawTarget)
        local function NormalizeRealm(realm)
            if type(realm) ~= "string" or realm == "" then return nil end
            local cleaned = realm:gsub("%s+", "")
            return cleaned ~= "" and cleaned or nil
        end

        local function CleanNameString(value)
            if type(value) ~= "string" then return nil end
            local cleaned = addon:TrimWhitespace(value)
            if not cleaned or cleaned == "" then return nil end

            local commandTarget = addon.ExtractWhisperTarget and addon:ExtractWhisperTarget(cleaned)
            if commandTarget and commandTarget ~= "" then
                cleaned = commandTarget
            end

            local linkedTarget = cleaned:match("|Hplayer:([^|]+)|h")
            if linkedTarget and linkedTarget ~= "" then
                cleaned = linkedTarget
            end

            cleaned = cleaned:gsub("|T.-|t", "")
            cleaned = cleaned:gsub("|c%x%x%x%x%x%x%x%x", "")
            cleaned = cleaned:gsub("|r", "")
            cleaned = cleaned:gsub("%[[^%]]+%]", "")
            cleaned = cleaned:gsub('^["`]+', ""):gsub('["`]+$', "")
            cleaned = cleaned:gsub("[,.;:]+$", "")
            cleaned = addon:TrimWhitespace(cleaned)

            local parenthesizedTarget = cleaned and cleaned:match("%(([^%(%)]+%-%S+)%)")
            if parenthesizedTarget then
                cleaned = parenthesizedTarget
            end

            if cleaned and cleaned:find(" ", 1, true) and not cleaned:find("%-", 1, true) then
                local firstToken = cleaned:match("^([^%s]+)")
                cleaned = firstToken or cleaned
            end

            return (cleaned and cleaned ~= "") and cleaned or nil
        end

        if type(rawTarget) == "string" then
            return CleanNameString(rawTarget)
        end

        if type(rawTarget) == "table" then
            local unitToken = rawTarget.unit or rawTarget.unitToken
            if type(unitToken) == "string" and unitToken ~= "" and UnitExists and UnitExists(unitToken) then
                local unitName, unitRealm = UnitName(unitToken)
                if unitName and unitName ~= "" then
                    local realm = NormalizeRealm(unitRealm)
                    if realm then
                        return unitName .. "-" .. realm
                    end
                    return unitName
                end
            end

            local guid = rawTarget.guid or rawTarget.playerGuid
            if type(guid) == "string" and guid ~= "" and GetPlayerInfoByGUID then
                local _, _, _, _, _, guidName, guidRealm = GetPlayerInfoByGUID(guid)
                if guidName and guidName ~= "" then
                    local realm = NormalizeRealm(guidRealm)
                    if realm then
                        return guidName .. "-" .. realm
                    end
                    return guidName
                end
            end

            local candidateKeys = {
                "name", "playerName", "fullName", "target", "sender", "author",
                "toonName", "charName", "characterName", "player", "displayName"
            }
            for _, key in ipairs(candidateKeys) do
                local candidate = rawTarget[key]
                if type(candidate) == "string" and candidate ~= "" then
                    local normalized = CleanNameString(candidate)
                    if normalized then
                        local realmCandidate = rawTarget.realm or rawTarget.server or rawTarget.realmName
                        local realm = NormalizeRealm(realmCandidate)
                        if realm and not normalized:find("%-", 1, true) then
                            return normalized .. "-" .. realm
                        end
                        return normalized
                    end
                elseif type(candidate) == "table" then
                    local nested = NormalizeTellTarget(candidate)
                    if nested then
                        return nested
                    end
                end
            end
        end

        return nil
    end

    local function HandleSendTell(name, chatFrame)
        if addon.IsRestrictedChatModeInstance and addon:IsRestrictedChatModeInstance() then
            return
        end
        if InCombatLockdown and InCombatLockdown() then
            return
        end

        local normalizedTarget = NormalizeTellTarget(name)
        if not normalizedTarget then
            return
        end

        local playerKey, _, displayName = addon:ResolvePlayerIdentifiers(normalizedTarget)
        if not playerKey then
            addon:DebugMessage("SendTell fallback to default chat (unresolved target):", tostring(normalizedTarget))
            return
        end

        local now = (GetTimePreciseSec and GetTimePreciseSec()) or GetTime()
        if addon.__wmLastTellTarget == playerKey and addon.__wmLastTellTime and (now - addon.__wmLastTellTime) < 0.05 then
            return
        end
        addon.__wmLastTellTarget = playerKey
        addon.__wmLastTellTime = now

        if playerKey and addon:IsChatAutoHidden(playerKey) then
            return
        end

        local monitorModeActive = addon.IsChatModeEnabled and (not addon:IsChatModeEnabled())
        if addon:IsSilentModeEnabled() or monitorModeActive then
            if playerKey then
                addon:UpdateRecentChat(playerKey, displayName or normalizedTarget, false, "Me")
                addon:MarkChatAsRead(playerKey)
                addon:DebugMessage("Monitor/Silent intercept for right-click whisper:", normalizedTarget)
            end
            return
        end

        local opened = false
        pcall(function() opened = addon:OpenConversation(normalizedTarget) end)

        if opened then
            local editBox = ChatFrameUtil.ChooseBoxForSend(chatFrame) or ChatFrameUtil.ChooseBoxForSend()
            if editBox and editBox:IsShown() then
                ChatFrameUtil.DeactivateChat(editBox)
            end
        end

        if opened and addon.IsChatModeEnabled and addon:IsChatModeEnabled() then
            C_Timer.After(0, function()
                local key = addon:ResolvePlayerIdentifiers(normalizedTarget)
                local win = key and addon.windows and addon.windows[key]
                if win and win:IsShown() and win.Input and win.InputContainer and win.InputContainer:IsShown() then
                    addon:FocusWindow(win)
                    win.Input:SetFocus()
                    addon:SetEditBoxFocus(win.Input)
                end
            end)
        end

    end

    local function HandleOpenChat(text, chatFrame)
        if addon.__closingWindow then
            return
        end

        local editBox = ChatFrameUtil.ChooseBoxForSend(chatFrame) or ChatFrameUtil.ChooseBoxForSend()
        if not editBox then
            return
        end

        local chatType = editBox:GetAttribute("chatType")
        if chatType ~= "WHISPER" then
            return
        end

        local tellTarget = editBox:GetAttribute("tellTarget")
        if (not tellTarget or tellTarget == "") and type(text) == "string" and addon.ExtractWhisperTarget then
            tellTarget = addon:ExtractWhisperTarget(text)
        end
        if not tellTarget or tellTarget == "" then
            return
        end

        local playerKey, _, displayName = addon:ResolvePlayerIdentifiers(tellTarget)
        if not playerKey then
            return
        end

        if playerKey and addon:IsChatAutoHidden(playerKey) then
            return
        end

        local monitorModeActive = addon.IsChatModeEnabled and (not addon:IsChatModeEnabled())
        if addon:IsSilentModeEnabled() or monitorModeActive then
            addon:UpdateRecentChat(playerKey, displayName or tellTarget, false, "Me")
            addon:MarkChatAsRead(playerKey)
            addon:DebugMessage("Monitor/Silent intercept for OpenChat whisper:", tellTarget)
            return
        end

        if editBox.__WhisperManagerHandled then
            return
        end
        editBox.__WhisperManagerHandled = true

        local opened = false
        pcall(function() opened = addon:OpenConversation(tellTarget) end)

        if opened and editBox:IsShown() then
            ChatFrameUtil.DeactivateChat(editBox)
        end

        if opened and addon.IsChatModeEnabled and addon:IsChatModeEnabled() then
            C_Timer.After(0, function()
                local key = addon:ResolvePlayerIdentifiers(tellTarget)
                local win = key and addon.windows and addon.windows[key]
                if win and win:IsShown() and win.Input and win.InputContainer and win.InputContainer:IsShown() then
                    addon:FocusWindow(win)
                    win.Input:SetFocus()
                    addon:SetEditBoxFocus(win.Input)
                end
            end)
        end

        C_Timer.After(0.1, function()
            if editBox then
                editBox.__WhisperManagerHandled = nil
            end
        end)
    end

    hooksecurefunc(ChatFrameUtil, "SendTell", function(name, chatFrame)
        HandleSendTell(name, chatFrame)
    end)

    hooksecurefunc(ChatFrameUtil, "OpenChat", function(text, chatFrame, desiredCursorPosition)
        HandleOpenChat(text, chatFrame)
    end)

    if type(ChatFrameUtil.ReplyTell) == "function" and type(ChatFrameUtil.GetLastTellTarget) == "function" then
        hooksecurefunc(ChatFrameUtil, "ReplyTell", function(chatFrame)
            local lastTellTarget = ChatFrameUtil.GetLastTellTarget()
            if lastTellTarget and lastTellTarget ~= "" then
                HandleSendTell(lastTellTarget, chatFrame)
            end
        end)
    end

    if type(ChatFrame_SendTell) == "function" then
        hooksecurefunc("ChatFrame_SendTell", function(name, chatFrame)
            HandleSendTell(name, chatFrame)
        end)
    end

    local function ResolveBNetTellTarget(tokenizedName)
        local function BuildResult(accountInfo)
            if not accountInfo or not accountInfo.bnetAccountID or not accountInfo.battleTag then
                return nil, nil, nil
            end
            local key = "bnet_" .. accountInfo.battleTag
            local displayName = accountInfo.accountName or accountInfo.battleTag
            return accountInfo.bnetAccountID, key, displayName
        end

        if type(tokenizedName) == "number" then
            return BuildResult(C_BattleNet.GetAccountInfoByID(tokenizedName))
        end

        if type(tokenizedName) ~= "string" or tokenizedName == "" then
            return nil, nil, nil
        end

        local requestedBattleTag = tokenizedName:match("^bnet_(.+)$")
        if not requestedBattleTag and tokenizedName:find("#", 1, true) then
            requestedBattleTag = tokenizedName
        end

        local tokenLower = strlower(tokenizedName)
        local numBNetTotal = BNGetNumFriends() or 0
        for i = 1, numBNetTotal do
            local accountInfo = C_BattleNet.GetFriendAccountInfo(i)
            if accountInfo and accountInfo.bnetAccountID and accountInfo.battleTag then
                if requestedBattleTag and accountInfo.battleTag == requestedBattleTag then
                    return BuildResult(accountInfo)
                end

                local battleTagLower = strlower(accountInfo.battleTag)
                local battleTagName = accountInfo.battleTag:match("^([^#]+)")
                local battleTagNameLower = battleTagName and strlower(battleTagName) or nil
                local accountNameLower = accountInfo.accountName and strlower(accountInfo.accountName) or nil

                if tokenLower == battleTagLower or tokenLower == battleTagNameLower or tokenLower == accountNameLower then
                    return BuildResult(accountInfo)
                end
            end
        end

        return nil, nil, nil
    end

    -- Hook BNet whisper default action similarly
    hooksecurefunc(ChatFrameUtil, "SendBNetTell", function(tokenizedName)
        if not tokenizedName or tokenizedName == "" then return end

        local bnetAccountID, playerKey, displayName = ResolveBNetTellTarget(tokenizedName)
        if not bnetAccountID or not playerKey then
            addon:DebugMessage("SendBNetTell fallback to default chat (unresolved target):", tostring(tokenizedName))
            return
        end

        if playerKey and addon:IsChatAutoHidden(playerKey) then
            return
        end

        local monitorModeActive = addon.IsChatModeEnabled and (not addon:IsChatModeEnabled())
        if addon:IsSilentModeEnabled() or monitorModeActive then
            addon:UpdateRecentChat(playerKey, displayName or tokenizedName, true, "Me")
            addon:MarkChatAsRead(playerKey)
            addon:DebugMessage("Monitor/Silent intercept for BNet right-click whisper:", tostring(tokenizedName))
            return
        end

        local opened = false
        pcall(function() opened = addon:OpenBNetConversation(bnetAccountID, displayName) end)

        local editBox = ChatFrameUtil.ChooseBoxForSend()
        if editBox and editBox:IsShown() then
            ChatFrameUtil.DeactivateChat(editBox)
        end

        if opened and addon.IsChatModeEnabled and addon:IsChatModeEnabled() then
            C_Timer.After(0, function()
                local win = playerKey and addon.windows and addon.windows[playerKey]
                if win and win:IsShown() and win.Input and win.InputContainer and win.InputContainer:IsShown() then
                    addon:FocusWindow(win)
                    win.Input:SetFocus()
                    addon:SetEditBoxFocus(win.Input)
                end
            end)
        end

    end)

    -- Setup context menu integration
    addon:SetupContextMenu()
end

function addon:SetupContextMenu()
    if addon.__contextMenuInstalled then
        addon:DebugMessage("Context menu already installed, skipping.")
        return
    end
    addon.__contextMenuInstalled = true
    addon:DebugMessage("Context menu modification disabled: relying on default Whisper action.")
end

function addon:EnsureWhisperVisibleInDefaultTab()
    if self.GetSetting and self:GetSetting("suppressDefaultChat") then
        return
    end

    local chatFrame = DEFAULT_CHAT_FRAME
    if not chatFrame then
        return
    end

    local whisperGroups = {
        "WHISPER",
        "WHISPER_INFORM",
        "BN_WHISPER",
        "BN_WHISPER_INFORM",
    }

    for _, group in ipairs(whisperGroups) do
        local hasGroup = false
        if ChatFrame_ContainsMessageGroup then
            hasGroup = ChatFrame_ContainsMessageGroup(chatFrame, group) == true
        end

        if not hasGroup and ChatFrame_AddMessageGroup then
            ChatFrame_AddMessageGroup(chatFrame, group)
            self:DebugMessage("Enabled chat group on default tab:", group)
        end
    end
end

-- Core Event Handling
function addon:RegisterCoreEvents()
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "ADDON_LOADED" then
            local addonName = ...
            if addonName == addon._tocName or addonName == "WhisperManager" then
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00WhisperManager:|r Loaded successfully!")
                addon:Initialize()
            elseif addonName == "totalRP3" or addonName == "TotalRP3" then
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00WhisperManager:|r TotalRP3 detected, setting up integration...")
                addon:InitializeTRP3Integration()
            end
        elseif event == "PLAYER_ENTERING_WORLD" then
            addon:DebugMessage("PLAYER_ENTERING_WORLD fired. Setting up hooks.");
            addon:SetupHooks()
            self:UnregisterEvent("PLAYER_ENTERING_WORLD")
            addon:DebugMessage("Hooks installed.");
            
            addon:CreateFloatingButton()
            addon:UpdateFloatingButtonUnreadStatus() -- Restore unread status on login
            
            addon:RunHistoryRetentionCleanup()
            
            C_Timer.NewTicker(86400, function()
                addon:RunHistoryRetentionCleanup()
            end)
            
            -- Register Chat Events (now in Chat.lua)
            if addon.RegisterChatEvents then
                addon:RegisterChatEvents()
            end

            addon:EnsureWhisperVisibleInDefaultTab()
            C_Timer.After(1, function()
                addon:EnsureWhisperVisibleInDefaultTab()
            end)
        end
    end)
end

-- Start core event registration
addon:RegisterCoreEvents()
