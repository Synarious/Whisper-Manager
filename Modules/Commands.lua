-- ============================================================================
-- Commands.lua - Slash command handlers
-- ============================================================================
-- This module handles /wm slash commands and related functionality.
-- ============================================================================

local addon = WhisperManager;

-- ============================================================================
-- Slash Command Handler
-- ============================================================================

--- Handle slash command input
-- @param message string Command text entered by user
function addon:HandleSlashCommand(message)
    print("[WM DEBUG] HandleSlashCommand called with: " .. tostring(message))
    local input = self:TrimWhitespace(message or "") or ""
    if input == "" or input:lower() == "help" then
        self:Print("Usage:")
        self:Print("/whispermanager <player> - Open a WhisperManager window.")
        self:Print("/whispermanager debug [on|off|toggle] - Control diagnostic chat output.")
        self:Print("/whispermanager resetwindows - Reset saved window positions.")
        self:Print("/whispermanager reset_all_data - Clear all saved data (history, windows, config).")
        self:Print("/whispermanager debug_retention/whispermanager debug_retention - Test retention cleanup (keep 3 recent, delete older than 5 min).")
        self:Print("/whispermanager cleanup_empty - Remove empty conversation entries from history.")
        self:Print("Aliases: /wm, /whispermanager")
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
    elseif command == "resetwindows" then
        self:ResetWindowPositions()
    elseif command == "reset_all_data" then
        WhisperManager_HistoryDB = {}
        WhisperManager_WindowDB = {}
        WhisperManager_Config = {}
        WhisperManager_RecentChats = {}
        self:Print("|cffff0000All WhisperManager data has been cleared!|r")
        self:Print("Please /reload to apply changes.")
    elseif command == "debug_retention" then
        self:RunDebugRetentionCleanup()
    elseif command == "cleanup_empty" then
        local removed = self:CleanupEmptyHistoryEntries()
        if removed > 0 then
            self:Print(string.format("Removed %d empty conversation%s from history.", 
                removed, removed ~= 1 and "s" or ""))
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
-- Register Slash Commands
-- ============================================================================

--- Register slash commands (called during initialization)
function addon:RegisterSlashCommands()
    SLASH_WHISPERMANAGER1 = "/whisper"
    SLASH_WHISPERMANAGER2 = "/whispermanager"
    SLASH_WHISPERMANAGER3 = "/wm"
    SlashCmdList["WHISPERMANAGER"] = function(msg)
        addon:HandleSlashCommand(msg)
    end
    
    print("|cFF00FF00[WhisperManager]|r Slash commands registered: /whisper, /whispermanager, /wm")
    self:DebugMessage("Slash commands registered: /whisper, /whispermanager, /wm")
end
