-- Configuration
local DEFAULT_DEBUG_MODE = false

-- Create the main addon table (global namespace)
WhisperManager = {};
local addon = WhisperManager;

-- ============================================================================
-- Addon State (runtime data structures)
-- ============================================================================

addon.windows = {};              -- Active whisper window frames
addon.playerDisplayNames = {};   -- Cached display names
addon.recentChats = {};          -- Recent conversation tracking
addon.nextFrameLevel = 1;        -- Z-order tracking for windows
addon.cascadeCounter = 0;        -- Counter for alternating window positioning

-- ============================================================================
-- Constants
-- ============================================================================

addon.MAX_HISTORY_LINES = 200;
addon.CHAT_MAX_LETTERS = 245;
addon.RECENT_CHAT_EXPIRY = 72 * 60 * 60;  -- 72 hours in seconds
addon.FOCUSED_ALPHA = 1.0;
addon.UNFOCUSED_ALPHA = 0.65;

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
    local originalChatEdit_InsertLink = ChatEdit_InsertLink
    ChatEdit_InsertLink = function(link)
        if addon.activeEditBox and addon.activeEditBox:IsVisible() and addon.activeEditBox:HasFocus() then
            addon.activeEditBox:Insert(link)
            return true
        else
            return originalChatEdit_InsertLink(link)
        end
    end

    -- Register events (defined in Events.lua)
    if addon.RegisterEvents then
        addon:RegisterEvents()
    end

    self:DebugMessage("WhisperManager initialized.");
end

-- Note: Initialize() is called from Events.lua after all modules are loaded
