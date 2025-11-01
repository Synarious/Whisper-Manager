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

function addon:AddMessageToHistory(playerKey, displayName, author, message, classToken)
    if not playerKey then return end
    if not WhisperManager_HistoryDB then WhisperManager_HistoryDB = {} end
    WhisperManager_HistoryDB.__schema = 5  -- Updated schema version (per-message class storage)
    if not WhisperManager_HistoryDB[playerKey] then
        WhisperManager_HistoryDB[playerKey] = {}
    end
    local history = WhisperManager_HistoryDB[playerKey]
    
    -- Use optimized format: m = message, a = author, t = timestamp, c = class token (optional)
    -- Use actual character name with realm (normalized, no spaces)
    local playerName, playerRealm = UnitName("player")
    local realm = (playerRealm or GetRealmName()):gsub("%s+", "")
    local fullPlayerName = playerName .. "-" .. realm
    local authorName = (author == "Me") and fullPlayerName or author
    
    -- Try to get class if not provided
    if not classToken then
        -- Check cache first
        if WhisperManager_Config and WhisperManager_Config.classCache then
            classToken = WhisperManager_Config.classCache[authorName] or WhisperManager_Config.classCache[author]
        end
    end
    
    -- Build entry with class if available
    local entry = { m = message, a = authorName, t = time() }
    if classToken then
        entry.c = classToken  -- Store class token (e.g., "WARRIOR", "MAGE", etc.)
    end
    
    table.insert(history, entry)
    if #history > self.MAX_HISTORY_LINES then
        table.remove(history, 1)
    end
end

function addon:AddSystemMessageToHistory(playerKey, displayName, systemMessage)
    addon:DebugMessage("=== AddSystemMessageToHistory called ===")
    addon:DebugMessage("PlayerKey:", playerKey)
    addon:DebugMessage("SystemMessage:", systemMessage)
    
    if not playerKey or not systemMessage then 
        addon:DebugMessage("ERROR: Missing playerKey or systemMessage")
        return 
    end
    if not WhisperManager_HistoryDB then WhisperManager_HistoryDB = {} end
    WhisperManager_HistoryDB.__schema = 5
    if not WhisperManager_HistoryDB[playerKey] then
        WhisperManager_HistoryDB[playerKey] = {}
    end
    local history = WhisperManager_HistoryDB[playerKey]
    
    -- System messages are stored with a special 's' flag to distinguish them
    local entry = { 
        m = systemMessage, 
        a = "System",  -- Mark as system message
        t = time(),
        s = true  -- System message flag
    }
    
    addon:DebugMessage("Entry created:", entry.m, entry.a, entry.t, entry.s)
    table.insert(history, entry)
    addon:DebugMessage("History length after insert:", #history)
    
    if #history > self.MAX_HISTORY_LINES then
        table.remove(history, 1)
    end
end

function addon:DisplayHistory(window, playerKey)
    addon:DebugMessage("=== DisplayHistory called ===")
    addon:DebugMessage("PlayerKey:", playerKey)
    
    if not WhisperManager_HistoryDB then 
        addon:DebugMessage("ERROR: WhisperManager_HistoryDB is nil")
        return 
    end
    local historyFrame = window.History
    historyFrame:Clear()
    local history = WhisperManager_HistoryDB[playerKey]
    if not history then 
        addon:DebugMessage("ERROR: No history for playerKey")
        return 
    end
    
    addon:DebugMessage("History entries to display:", #history)

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

    for i, entry in ipairs(history) do
        addon:DebugMessage("Processing entry", i, "- System flag:", entry.s)
        -- Support both old and new format
        local timestamp = entry.t or entry.timestamp
        local author = entry.a or entry.author
        local message = entry.m or entry.message
        local classToken = entry.c  -- Get stored class token
        local isSystemMessage = entry.s  -- Check if it's a system message
        
        if timestamp and author and message then
            -- Handle system messages differently
            if isSystemMessage then
                addon:DebugMessage("Displaying system message:", message)
                -- System messages are displayed in a distinct color (orange/red)
                local tsColor = self.settings.timestampColor or {r = 0.5, g = 0.5, b = 0.5}
                local tsColorHex = string.format("%02x%02x%02x", tsColor.r * 255, tsColor.g * 255, tsColor.b * 255)
                local timeString = "|cff" .. tsColorHex .. date("%H:%M", timestamp) .. "|r"
                
                -- Display system message with distinct formatting
                local formattedMessage = timeString .. " " .. message
                addon:DebugMessage("Formatted message:", formattedMessage)
                historyFrame:AddMessage(formattedMessage)
                addon:DebugMessage("AddMessage called successfully")
            else
                -- Regular message handling
                -- Timestamp with customizable color
                local tsColor = self.settings.timestampColor or {r = 0.5, g = 0.5, b = 0.5}
                local tsColorHex = string.format("%02x%02x%02x", tsColor.r * 255, tsColor.g * 255, tsColor.b * 255)
                local timeString = "|cff" .. tsColorHex .. date("%H:%M", timestamp) .. "|r"
                
                local coloredAuthor
                local messageColor
                if author == "Me" or author == playerName or author == fullPlayerName then
                    -- Use customizable send color for message text
                    if window.isBNet then
                        local color = self.settings.bnetSendColor or {r = 0.0, g = 0.66, b = 1.0}
                        local colorHex = string.format("%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
                        messageColor = "|cff" .. colorHex
                    else
                        local color = self.settings.whisperSendColor or {r = 1.0, g = 0.5, b = 1.0}
                        local colorHex = string.format("%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
                        messageColor = "|cff" .. colorHex
                    end
                    
                    -- Use player's class color for name only, brackets use message color
                    local _, playerClass = UnitClass("player")
                    local classColor = playerClass and RAID_CLASS_COLORS[playerClass]
                    local classColorHex
                    if classColor then
                        classColorHex = string.format("%02x%02x%02x", classColor.r * 255, classColor.g * 255, classColor.b * 255)
                    else
                        classColorHex = "ffd100"
                    end
                    -- Use WIM-style formatting: brackets outside, hyperlink only around the name
                    local nameLink = string.format("|Hplayer:%s|h|cff%s%s|r|h", fullPlayerName, classColorHex, playerName)
                    coloredAuthor = string.format("%s[%s]|r: ", messageColor, nameLink)
                else
                    -- Color based on whisper type (receive)
                    if window.isBNet then
                        -- Use the window's display name instead of stored author (which might be session ID)
                        local bnetDisplayName = window.playerDisplay or displayName or author
                        -- For BNet, use a fixed color for the name (cyan) - BNet names aren't clickable in the same way
                        coloredAuthor = "|TInterface\\ChatFrame\\UI-ChatIcon-Blizz:14:14:0:-1|t|cff00ddff" .. bnetDisplayName .. "|r"
                        
                        -- Use customizable receive color for BNet message text
                        local color = self.settings.bnetReceiveColor or {r = 0.0, g = 0.66, b = 1.0}
                        local colorHex = string.format("%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
                        messageColor = "|cff" .. colorHex
                    else
                        -- Use customizable receive color for whisper message text
                        local color = self.settings.whisperReceiveColor or {r = 1.0, g = 0.5, b = 1.0}
                        local colorHex = string.format("%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
                        messageColor = "|cff" .. colorHex
                        
                        -- Regular whispers: try to use stored class color, fallback to lookup then gold
                        -- Strip realm name from author (Name-Realm -> Name)
                        local authorDisplayName = author:match("^([^%-]+)") or author
                        
                        -- Build clickable hyperlink with class colors
                        local classColorHex
                        
                        -- Use stored class token if available (performance optimization)
                        if classToken then
                            local classColor = RAID_CLASS_COLORS[classToken]
                            if classColor then
                                classColorHex = string.format("%02x%02x%02x", classColor.r * 255, classColor.g * 255, classColor.b * 255)
                            end
                        end
                        
                        -- Fallback to lookup only if no stored class
                        if not classColorHex then
                            classColorHex = self:GetClassColorForPlayer(author)
                        end
                        
                        local nameColorHex = classColorHex or "ffd100"  -- Class color or gold
                        -- Format: brackets in message color, name in class color
                        coloredAuthor = string.format("|Hplayer:%s|h%s[|r|cff%s%s|r%s]:|h", author, messageColor, nameColorHex, authorDisplayName, messageColor)
                    end
                end
            
                -- CRITICAL: Don't use gsub on message - preserve hyperlinks as-is
                -- Apply emote and speech formatting (this function preserves hyperlinks)
                local formattedText = self:FormatEmotesAndSpeech(message)
                
                -- Convert URLs to clickable links
                formattedText = self:ConvertURLsToLinks(formattedText)
                
                -- Format message - concatenate parts WITHOUT string.format to preserve hyperlinks
                -- WIM/Prat3 method: Simple concatenation preserves all escape sequences
                local formattedMessage = timeString .. " " .. coloredAuthor .. " " .. messageColor .. formattedText .. "|r"
                historyFrame:AddMessage(formattedMessage)
            end
        end
    end
    historyFrame:ScrollToBottom()
end
