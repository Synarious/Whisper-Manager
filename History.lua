-- ============================================================================
-- History.lua - Message history management
-- ============================================================================

local addon = WhisperManager;

-- ============================================================================
-- Helper Functions
-- ============================================================================

-- Helper function to convert timestamp to "time ago" format
local function GetTimeAgo(timestamp)
    local now = time()
    local diff = now - timestamp
    
    if diff < 60 then
        return "Just now"
    elseif diff < 3600 then
        local minutes = math.floor(diff / 60)
        return minutes .. " minute" .. (minutes ~= 1 and "s" or "") .. " ago"
    elseif diff < 86400 then
        local hours = math.floor(diff / 3600)
        return hours .. " hour" .. (hours ~= 1 and "s" or "") .. " ago"
    else
        local days = math.floor(diff / 86400)
        return days .. " day" .. (days ~= 1 and "s" or "") .. " ago"
    end
end

-- Make GetTimeAgo accessible to other modules
addon.GetTimeAgo = GetTimeAgo;

-- ============================================================================
-- History Management Functions
-- ============================================================================

function addon:AddMessageToHistory(playerKey, displayName, author, message)
    if not playerKey then return end
    if not WhisperManager_HistoryDB then WhisperManager_HistoryDB = {} end
    WhisperManager_HistoryDB.__schema = 4  -- Updated schema version (no __display)
    if not WhisperManager_HistoryDB[playerKey] then
        WhisperManager_HistoryDB[playerKey] = {}
    end
    local history = WhisperManager_HistoryDB[playerKey]
    
    -- Use optimized format: m = message, a = author, t = timestamp
    -- For "Me", use actual character name with realm (normalized, no spaces)
    local playerName, playerRealm = UnitName("player")
    local realm = (playerRealm or GetRealmName()):gsub("%s+", "")
    local fullPlayerName = playerName .. "-" .. realm
    local authorName = (author == "Me") and fullPlayerName or author
    
    table.insert(history, { m = message, a = authorName, t = time() })
    if #history > self.MAX_HISTORY_LINES then
        table.remove(history, 1)
    end
end

function addon:DisplayHistory(window, playerKey)
    if not WhisperManager_HistoryDB then return end
    local historyFrame = window.History
    historyFrame:Clear()
    local history = WhisperManager_HistoryDB[playerKey]
    if not history then return end

    -- Extract display name from key instead of using __display
    local displayName = self:GetDisplayNameFromKey(playerKey)
    if window.Title then
        window.playerDisplay = displayName
        local titlePrefix = window.isBNet and "BNet Whisper: " or "Whisper: "
        window.Title:SetText(titlePrefix .. displayName)
    end
    
    local playerName, playerRealm = UnitName("player")
    local realm = (playerRealm or GetRealmName()):gsub("%s+", "")
    local fullPlayerName = playerName .. "-" .. realm

    for _, entry in ipairs(history) do
        -- Support both old and new format
        local timestamp = entry.t or entry.timestamp
        local author = entry.a or entry.author
        local message = entry.m or entry.message
        
        if timestamp and author and message then
            local timeString = date("[%H:%M]", timestamp)
            local coloredAuthor
            if author == "Me" or author == playerName or author == fullPlayerName then
                coloredAuthor = "|cff9494ffMe|r"
            else
                coloredAuthor = string.format("|cffffd100%s|r", author)
            end
            local safeMessage = message:gsub("%%", "%%%%")
            
            -- Apply emote and speech formatting
            safeMessage = self:FormatEmotesAndSpeech(safeMessage)
            
            local formattedMessage = string.format("%s %s: %s", timeString, coloredAuthor, safeMessage)
            historyFrame:AddMessage(formattedMessage)
        end
    end
    historyFrame:ScrollToBottom()
end
