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

local function hookChatFrameEditBox(editBox)
    if editBox and not Hooked_ChatFrameEditBoxes[editBox:GetName()] then
        hooksecurefunc(editBox, "Insert", function(self, theText)
            if addon.EditBoxInFocus then
                addon.EditBoxInFocus:Insert(theText)
            end
        end)

        editBox.wmIsVisible = editBox.IsVisible
        editBox.IsVisible = function(self)
            if addon.EditBoxInFocus then
                return true
            else
                return self:wmIsVisible()
            end
        end

        editBox.wmIsShown = editBox.IsShown
        editBox.IsShown = function(self)
            if addon.EditBoxInFocus then
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
            if addon.EditBoxInFocus and firstChar ~= "/" then
                addon.EditBoxInFocus:SetText(theText)
            end
        end)

        editBox.wmHighlightText = editBox.HighlightText
        editBox.HighlightText = function(self, theStart, theEnd)
            if addon.EditBoxInFocus then
                addon.EditBoxInFocus:HighlightText(theStart, theEnd)
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
    originalActivateChat(editBox)
    hookChatFrameEditBox(editBox)
end

local originalGetActiveWindow = ChatFrameUtil.GetActiveWindow
function ChatFrameUtil.GetActiveWindow()
    return addon.EditBoxInFocus or originalGetActiveWindow()
end

if ChatEdit_GetActiveWindow then
    local originalChatEdit_GetActiveWindow = ChatEdit_GetActiveWindow
    function ChatEdit_GetActiveWindow()
        return addon.EditBoxInFocus or originalChatEdit_GetActiveWindow()
    end
end

function addon:SetEditBoxFocus(editBox)
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
    return value:gsub("^%s+", ""):gsub("%s+$", "")
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
    
    -- Hook whisper command extraction - use editbox mixin method
    local function OnExtractTellTarget(editBox, text)
        local target = addon:ExtractWhisperTarget(text)
        if not target then return end
        addon:DebugMessage("Hooked /w via ExtractTellTarget. Target:", target)
        
        if addon:OpenConversation(target) then
            ChatFrameUtil.DeactivateChat(editBox)
        end
    end
    
    -- Hook the mixin method on ChatFrameEditBox
    hooksecurefunc(ChatFrameEditBoxMixin, "ExtractTellTarget", OnExtractTellTarget)

    -- Hook chat frame opening
    hooksecurefunc(ChatFrameUtil, "OpenChat", function(text, chatFrame, desiredCursorPosition)
        -- Don't trigger if we're closing a window
        if addon.__closingWindow then
            addon:DebugMessage("OpenChat ignored - window closing")
            return
        end
        
        local editBox = ChatFrameUtil.ChooseBoxForSend(chatFrame)
        if not editBox then return end

        local chatType = editBox:GetAttribute("chatType")
        if chatType ~= "WHISPER" then
            return
        end

        -- Only intercept if text contains /w or /whisper command
        if not text or not text:match("^/[Ww]") then
            addon:DebugMessage("OpenChat ignored - no /w command in text")
            return
        end

        local target = editBox:GetAttribute("tellTarget")
        if not target or target == "" then return end

        if editBox.__WhisperManagerHandled then return end
        editBox.__WhisperManagerHandled = true

        addon:DebugMessage("OpenChat captured whisper target:", target)

        if addon:OpenConversation(target) then
            ChatFrameUtil.DeactivateChat(editBox)
        end
        
        C_Timer.After(0.1, function()
            editBox.__WhisperManagerHandled = nil
        end)
    end)

    -- Hook reply tell
    hooksecurefunc(ChatFrameUtil, "ReplyTell", function(chatFrame)
        local target = ChatFrameUtil.GetLastTellTarget()
        if target and addon:OpenConversation(target) then
            local activeEditBox = ChatFrameUtil.ChooseBoxForSend()
            if activeEditBox then
                ChatFrameUtil.DeactivateChat(activeEditBox)
            end
        end
    end)

    -- Hook the default Whisper menu action so it opens WhisperManager windows
    hooksecurefunc(ChatFrameUtil, "SendTell", function(name, chatFrame)
        if not name or name == "" then return end
        -- Open conversation. If successful, close any opened chat editbox to avoid duplicate UI
        local ok = false
        pcall(function() ok = addon:OpenConversation(name) end)
        if ok then
            local editBox = ChatFrameUtil.ChooseBoxForSend()
            if editBox and editBox:IsShown() then
                ChatFrameUtil.DeactivateChat(editBox)
            end
        end
    end)

    -- Hook BNet whisper default action similarly
    hooksecurefunc(ChatFrameUtil, "SendBNetTell", function(tokenizedName)
        if not tokenizedName or tokenizedName == "" then return end
        local ok = false
        -- SendBNetTell may pass a BattleTag or name; try to open by BattleTag when possible
        pcall(function() ok = addon:OpenBNetConversation(tokenizedName) end)
        if ok then
            local editBox = ChatFrameUtil.ChooseBoxForSend()
            if editBox and editBox:IsShown() then
                ChatFrameUtil.DeactivateChat(editBox)
            end
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
        end
    end)
end

-- Start core event registration
addon:RegisterCoreEvents()
