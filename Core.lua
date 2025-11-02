-- ============================================================================
-- Core.lua - Minimal addon core (initialization and global state only)
-- ============================================================================
-- This file creates the addon namespace and initializes saved variables.
-- All other functionality is split into specialized modules.
-- ============================================================================

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

-- ============================================================================
-- Constants
-- ============================================================================

addon.MAX_HISTORY_LINES = 200;
addon.CHAT_MAX_LETTERS = 245;
addon.RECENT_CHAT_EXPIRY = 72 * 60 * 60;  -- 72 hours in seconds
addon.FOCUSED_ALPHA = 1.0;
addon.UNFOCUSED_ALPHA = 0.65;

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

-- ============================================================================
-- Initialization
-- ============================================================================

--- Initialize the addon (called from Events.lua after all modules load)
function addon:Initialize()
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
        WhisperManager_Config = {}
    end

    -- Migrate old history format if needed
    if not WhisperManager_HistoryDB.__schema or WhisperManager_HistoryDB.__schema < 2 then
        local migrated = {}
        for key, history in pairs(WhisperManager_HistoryDB) do
            if key ~= "__schema" then
                local canonicalKey, _, displayName = addon:ResolvePlayerIdentifiers(key)
                if canonicalKey then
                    if not migrated[canonicalKey] then
                        migrated[canonicalKey] = type(history) == "table" and history or {}
                    elseif type(history) == "table" then
                        for _, entry in ipairs(history) do
                            table.insert(migrated[canonicalKey], entry)
                        end
                    end

                    local targetHistory = migrated[canonicalKey]
                    if type(targetHistory) == "table" and displayName then
                        targetHistory.__display = targetHistory.__display or displayName
                    end
                end
            end
        end
        migrated.__schema = 2
        WhisperManager_HistoryDB = migrated
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
