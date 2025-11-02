-- ============================================================================
-- Data.lua - Database management for history, recent chats, and class cache
-- ============================================================================
-- This module handles all persistent data storage including:
-- - Message history (WhisperManager_HistoryDB)
-- - Recent conversations (WhisperManager_RecentChats)
-- - Player class cache (WhisperManager_Config.classCache)
-- ============================================================================

local addon = WhisperManager;

-- ============================================================================
-- SECTION 1: Message History Management
-- ============================================================================

--- Add a message to the history database
-- @param playerKey string Canonical player key (c_Name-Realm or bnet_Tag)
-- @param displayName string Display name for the player
-- @param author string Message author (character name or "Me")
-- @param message string Message content
-- @param classToken string Optional class token (e.g., "WARRIOR", "MAGE")
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

--- Display message history in a window
-- @param window table The whisper window frame
-- @param playerKey string Canonical player key
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

    for i, entry in ipairs(history) do
        -- Support both old and new format
        local timestamp = entry.t or entry.timestamp
        local author = entry.a or entry.author
        local message = entry.m or entry.message
        local classToken = entry.c  -- Get stored class token
        
        if timestamp and author and message then
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
    
    historyFrame:ScrollToBottom()
end

-- ============================================================================
-- SECTION 2: Recent Chat Management
-- ============================================================================

--- Update recent chat entry (adds or updates last message time)
-- @param playerKey string Canonical player key
-- @param displayName string Display name (unused, kept for compatibility)
-- @param isBNet boolean Whether this is a BNet conversation
function addon:UpdateRecentChat(playerKey, displayName, isBNet)
    if not playerKey then return end
    
    if not WhisperManager_RecentChats then
        WhisperManager_RecentChats = {}
    end
    
    local now = time()
    
    -- Clean up old entries (older than 72 hours)
    for key, data in pairs(WhisperManager_RecentChats) do
        if data and data.lastMessageTime and (now - data.lastMessageTime) > self.RECENT_CHAT_EXPIRY then
            WhisperManager_RecentChats[key] = nil
        end
    end
    
    -- Update or create entry
    if not WhisperManager_RecentChats[playerKey] then
        WhisperManager_RecentChats[playerKey] = {
            lastMessageTime = now,
            isRead = false,
            isBNet = isBNet or false,
        }
    else
        WhisperManager_RecentChats[playerKey].lastMessageTime = now
    end
end

--- Mark a conversation as read
-- @param playerKey string Canonical player key
function addon:MarkChatAsRead(playerKey)
    if WhisperManager_RecentChats and WhisperManager_RecentChats[playerKey] then
        WhisperManager_RecentChats[playerKey].isRead = true
    end
end

-- ============================================================================
-- SECTION 3: Class Cache Management
-- ============================================================================

--- Get class color for a player (returns hex color string or nil)
-- @param playerName string Player name (with or without realm)
-- @return string|nil Hex color string (e.g., "ffc41f3b") or nil if not found
function addon:GetClassColorForPlayer(playerName)
    if not playerName or playerName == "" then return nil end
    
    -- Initialize class cache in saved variables
    if not WhisperManager_Config then
        WhisperManager_Config = {}
    end
    if not WhisperManager_Config.classCache then
        WhisperManager_Config.classCache = {}
    end
    
    -- Check cache first
    if WhisperManager_Config.classCache[playerName] then
        local classColor = RAID_CLASS_COLORS[WhisperManager_Config.classCache[playerName]]
        if classColor then
            return string.format("%02x%02x%02x", classColor.r * 255, classColor.g * 255, classColor.b * 255)
        end
    end
    
    -- Strip realm if present to get just the character name
    local name = playerName:match("^([^%-]+)") or playerName
    
    -- Try to get class info from UnitClass (works for party/raid members)
    local _, class = UnitClass(name)
    if not class then
        -- Try with hyphenated version for same-server players
        _, class = UnitClass(playerName)
    end
    
    -- Try checking if they're in a group
    if not class then
        -- Check raid members
        if IsInRaid() then
            for i = 1, GetNumGroupMembers() do
                local unitId = "raid" .. i
                local unitName = GetUnitName(unitId, true)  -- true = include realm
                if unitName and (unitName == playerName or unitName == name) then
                    _, class = UnitClass(unitId)
                    break
                end
            end
        elseif IsInGroup() then
            -- Check party members
            for i = 1, GetNumSubgroupMembers() do
                local unitId = "party" .. i
                local unitName = GetUnitName(unitId, true)
                if unitName and (unitName == playerName or unitName == name) then
                    _, class = UnitClass(unitId)
                    break
                end
            end
        end
    end
    
    -- Try checking guild members
    if not class and IsInGuild() then
        local numTotalMembers = GetNumGuildMembers()
        for i = 1, numTotalMembers do
            local guildName, _, _, _, _, _, _, _, _, _, classFileName = GetGuildRosterInfo(i)
            if guildName then
                local guildNameShort = guildName:match("^([^%-]+)") or guildName
                if guildName == playerName or guildNameShort == name then
                    class = classFileName
                    break
                end
            end
        end
    end
    
    if class then
        -- Cache the result
        addon:SetPlayerClass(playerName, class)
        
        local classColor = RAID_CLASS_COLORS[class]
        if classColor then
            return string.format("%02x%02x%02x", classColor.r * 255, classColor.g * 255, classColor.b * 255)
        end
    end
    
    return nil  -- No class info available
end

--- Set player class info in cache (called when we get GUID info from events)
-- @param playerName string Player name
-- @param class string Class token (e.g., "WARRIOR")
function addon:SetPlayerClass(playerName, class)
    if playerName and class then
        if not WhisperManager_Config then
            WhisperManager_Config = {}
        end
        if not WhisperManager_Config.classCache then
            WhisperManager_Config.classCache = {}
        end
        WhisperManager_Config.classCache[playerName] = class
    end
end

-- ============================================================================
-- SECTION 4: Utility Functions
-- ============================================================================

--- Convert timestamp to "time ago" format
-- @param timestamp number Unix timestamp
-- @return string Formatted time string (e.g., "2 hours ago")
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

-- Export GetTimeAgo for use in other modules
addon.GetTimeAgo = GetTimeAgo;
