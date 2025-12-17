-- Configuration
local DEFAULT_DEBUG_MODE = false

-- Create the main addon table (global namespace)
-- Use the standard addon entry pattern so an internal toc name or folder rename doesn't break references.
local ADDON_NAME, addonFromTOC = ...
-- Ensure a global table named 'WhisperManager' exists. Keep it as the canonical table used throughout the codebase.
_G["WhisperManager"] = _G["WhisperManager"] or {}
local addon = _G["WhisperManager"]
addon._tocName = ADDON_NAME

-- ============================================================================
-- Addon State (runtime data structures)
-- ============================================================================

addon.windows = {};              -- Active whisper window frames
addon.playerDisplayNames = {};   -- Cached display names
addon.recentChats = {};          -- Recent conversation tracking
addon.nextFrameLevel = 1;        -- Z-order tracking for windows
addon.cascadeCounter = 0;        -- Counter for alternating window positioning
addon.combatQueue = {};          -- Queue for operations during combat lockdown

-- ============================================================================
-- Constants
-- ============================================================================

addon.MAX_HISTORY_LINES = 1000;
addon.CHAT_MAX_LETTERS = 245;
addon.RECENT_CHAT_EXPIRY = 72 * 60 * 60;  -- 72 hours in seconds
addon.FOCUSED_ALPHA = 1.0;
addon.UNFOCUSED_ALPHA = 0.65;

-- ============================================================================
-- Overlay Helpers (keep frames visible over major Blizzard scenes like Housing)
-- ============================================================================

--- Return the safest parent that remains visible when UIParent is hidden
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
-- @param frame table Frame to adjust
function addon:EnsureFrameOverlay(frame)
    if not frame then return end

    local parent = self:GetOverlayParent()
    if parent and frame:GetParent() ~= parent then
        frame:SetParent(parent)
    end

    -- Always use DIALOG strata for dropdown menu compatibility
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

    -- Active whisper windows and their input containers
    for _, win in pairs(self.windows) do
        if win then
            apply(win)
            apply(win.InputContainer)
        end
    end
end

-- Class ID to Class Token mapping (for compact storage)
-- Numeric IDs are stored in database, converted to tokens for color lookup
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



-- ============================================================================
-- Debug System
-- ============================================================================

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



-- ============================================================================
-- Initialization
-- ============================================================================

--- Initialize the addon (called from Events.lua after all modules load)
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
    -- In BNet conversations, our own messages will have character names while received messages have BNet IDs
    if WhisperManager_HistoryDB then
        local charactersFound = 0
        for playerKey, history in pairs(WhisperManager_HistoryDB) do
            -- Only scan BNet conversations
            if playerKey ~= "__schema" and playerKey:match("^bnet_") and type(history) == "table" then
                for _, entry in ipairs(history) do
                    local author = entry.a or entry.author
                    -- In BNet conversations:
                    -- - Received messages have BNet session IDs like |Kp123|k
                    -- - Our sent messages have character names like Character-Realm
                    if author and author:match("^[^|]+%-[^|]+$") and not author:match("|K") then
                        -- This is a character name format (Name-Realm), likely one of our characters
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
    
    -- CRITICAL: Validate schema version BEFORE any data operations
    self:DebugMessage("Running schema validation...")
    if not self:ValidateSchema() then
        self:Print("|cffff0000WhisperManager has been disabled due to version mismatch!|r")
        self:Print("|cffff8800Your saved data is safe and has not been modified.|r")
        return -- ABORT initialization
    end
    
    -- Set schema version for new installations
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
    
    -- Force them to be the same if they're not
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

    -- Register slash commands (defined in Commands.lua)
    if addon.RegisterSlashCommands then
        addon:RegisterSlashCommands()
    end

    -- Load settings (defined in Settings.lua)
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

    -- Register events (defined in Events.lua)
    if addon.RegisterEvents then
        addon:RegisterEvents()
    end

    -- Keep key frames visible when the Housing editor or other fullscreen UIs hide UIParent
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

-- Note: Initialize() is called from Events.lua after all modules are loaded

-- ============================================================================
-- Embedded: Commands.lua (merged)
-- ============================================================================

--- Register slash commands
function addon:RegisterSlashCommands()
    self:DebugMessage("Registering slash commands...")
    
    SLASH_WHISPERMANAGER1 = "/wmgr"
    SLASH_WHISPERMANAGER2 = "/whispermanager"
    
    SlashCmdList["WHISPERMANAGER"] = function(msg)
        addon:HandleSlashCommand(msg)
    end
    
    self:DebugMessage("Slash commands registered: /wmgr and /whispermanager")
end

-- ============================================================================
-- Slash Command Handling
-- ============================================================================

--- Reset all saved window positions (whisper windows, floating button, recent chats, history viewer, settings)
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
    else
        -- Try to open conversation with the input as player name
        if not self:OpenConversation(input) then
            self:Print(string.format("Unable to open a whisper window for '%s'.", input))
        end
    end
end

-- ============================================================================
-- Embedded: Hooks.lua (merged)
-- ============================================================================

-- Track which EditBox currently has focus
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
