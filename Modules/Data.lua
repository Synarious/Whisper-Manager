local addon = WhisperManager;
local SCHEMA_VERSION = 1
local WINDOW_INITIAL_HISTORY_LIMIT = 100

-- Helper: insert a gray date divider line when messages cross day boundaries
local function GetDayKey(timestamp)
    if not timestamp then return nil end
    return date("%Y%m%d", timestamp)
end

local function GetRelativeDateLabel(timestamp)
    local now = time()
    local diff = now - timestamp
    local dateStr = date("%m/%d/%y", timestamp)
    
    local relative = ""
    if diff < 3600 then
        relative = math.floor(diff / 60) .. "m ago"
    elseif diff < 86400 then
        relative = math.floor(diff / 3600) .. "h ago"
    elseif diff < 604800 then
        relative = math.floor(diff / 86400) .. "d ago"
    elseif diff < 2592000 then
        relative = math.floor(diff / 604800) .. "w ago"
    else
        relative = math.floor(diff / 2592000) .. "mo ago"
    end
    
    return string.format("----- (%s) %s -----", relative, dateStr)
end

local function AddDateFooter(window, timestamp)
    if not window or not window.History or not timestamp then return end
    local label = GetRelativeDateLabel(timestamp)
    window.History:AddMessage(label, 0.8078, 0.4863, 0.0)
end

function addon:AddMessageToHistory(playerKey, displayName, author, message, classToken)
    -- SCHEMA PROTECTION: Block if validation failed
    if not addon:IsSafeToOperate() then return end
    if InCombatLockdown() then
        addon:DebugMessage("In combat - skipping AddMessageToHistory write")
        return
    end
    
    if not playerKey then return end
    if not WhisperManager_HistoryDB then WhisperManager_HistoryDB = {} end
    WhisperManager_HistoryDB.__schema = SCHEMA_VERSION  -- Updated schema version (per-message class storage)
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
    
    -- Build entry with class ID if available (convert token to numeric ID for compact storage)
    local entry = { m = message, a = authorName, t = time() }
    if classToken and addon.CLASS_TOKEN_TO_ID[classToken] then
        entry.c = addon.CLASS_TOKEN_TO_ID[classToken]  -- Store numeric class ID (1-13)
    end
    
    table.insert(history, entry)
    if #history > self.MAX_HISTORY_LINES then
        table.remove(history, 1)
    end
    
    -- Update recent chats
    local isBNet = playerKey:match("^bnet_") ~= nil
    self:UpdateRecentChat(playerKey, displayName, isBNet, authorName)
end

--- Display message history in a window
-- @param window table The whisper window frame
-- @param playerKey string Canonical player key
function addon:DisplayHistory(window, playerKey)
    -- Force a print so we ALWAYS see when this is called
    addon:DebugMessage("|cffff00ff=== DisplayHistory CALLED ===|r")
    addon:DebugMessage("|cffff00ffplayerKey: " .. tostring(playerKey) .. "|r")
    
    addon:DebugMessage("=== DisplayHistory START ===")
    addon:DebugMessage("playerKey:", playerKey)
    addon:DebugMessage("WhisperManager_HistoryDB exists:", WhisperManager_HistoryDB ~= nil)
    
    if not WhisperManager_HistoryDB then 
        addon:DebugMessage("ERROR: WhisperManager_HistoryDB is nil!")
        return 
    end
    
    if not window or not window.History then 
        addon:DebugMessage("ERROR: window or window.History is nil!")
        addon:DebugMessage("window exists:", window ~= nil)
        if window then
            addon:DebugMessage("window.History exists:", window.History ~= nil)
        end
        return 
    end
    
    local historyFrame = window.History
    historyFrame:Clear()
    window.__wm_lastDayKey = nil
    
    local history = WhisperManager_HistoryDB[playerKey]
    if not history then 
        addon:DebugMessage("ERROR: No history found for playerKey:", playerKey)
        addon:DebugMessage("Available keys in HistoryDB:")
        for key, _ in pairs(WhisperManager_HistoryDB) do
            if key ~= "__schema" then
                addon:DebugMessage("  - " .. tostring(key))
            end
        end
        return 
    end
    
    addon:DebugMessage("Found history with", #history, "messages for playerKey:", playerKey)

    -- Extract display name from key instead of using __display
    local displayName = self:GetDisplayNameFromKey(playerKey)
    if window.Title then
        window.playerDisplay = displayName
        local titlePrefix = window.isBNet and "BNet: " or "Whisper: "
        window.Title:SetText(titlePrefix .. displayName)
    end
    
    local playerName, playerRealm = UnitName("player")
    local realm = (playerRealm or GetRealmName()):gsub("%s+", "")
    local fullPlayerName = playerName .. "-" .. realm
    
    -- Helper function to check if an author is one of the player's characters
    local function IsPlayerCharacter(authorName)
        if not authorName then return false end
        if authorName == "Me" then return true end
        
        -- Initialize character DB if needed (shouldn't happen, but safety check)
        if not WhisperManager_CharacterDB then WhisperManager_CharacterDB = {} end
        
        -- Check if this is a known player character
        if WhisperManager_CharacterDB[authorName] then return true end
        
        -- Also check current character variants
        if authorName == playerName or authorName == fullPlayerName then
            return true
        end
        
        return false
    end

    -- Always render only the most recent messages for the whisper window.
    local historyCount = #history
    local maxLines = WINDOW_INITIAL_HISTORY_LIMIT
    local startIndex = math.max(1, historyCount - maxLines + 1)

    -- Fixed header shown at the top of history to indicate start of saved backlog
    historyFrame:AddMessage("== Looback End: Check History ==", 1.0, 0.82, 0.0)

    for i = startIndex, historyCount do
        local entry = history[i]
        -- Support both old and new format
        local timestamp = entry.t or entry.timestamp
        local author = entry.a or entry.author
        local message = entry.m or entry.message
        -- Convert numeric class ID to class token
        local classToken = nil
        if entry.c then
            classToken = addon.CLASS_ID_TO_TOKEN[entry.c]
        end
        
        -- Resolve BNet IDs (|KpXX|k) to display names for BNet conversations
        local originalAuthor = author
        if window.isBNet and author then
            author = addon:ResolveBNetID(author, playerKey)
        end
        
        addon:DebugMessage("Processing message", i, "- timestamp:", timestamp, "originalAuthor:", originalAuthor, "resolvedAuthor:", author, "message length:", message and #message or 0)
        
        if timestamp and author and message then
                -- Regular message handling
            -- Timestamp with customizable color
                local tsColor = self.settings.timestampColor or {r = 0.8078, g = 0.4863, b = 0.0}
                local tsColorHex = string.format("%02x%02x%02x", tsColor.r * 255, tsColor.g * 255, tsColor.b * 255)
                local timeString = "|cff" .. tsColorHex .. date("%H:%M", timestamp) .. "|r"
                
                local coloredAuthor
                local messageColor
                if IsPlayerCharacter(author) then
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
                    
                    -- Try to get RP name with color from TRP3 integration (if loaded)
                    addon:DebugMessage("[Data:DisplayHistory] Checking for TRP3 integration:", addon.TRP3_GetMyRPNameWithColor ~= nil);
                    local rpNameWithColor = addon.TRP3_GetMyRPNameWithColor and addon.TRP3_GetMyRPNameWithColor()
                    addon:DebugMessage("[Data:DisplayHistory] TRP3 returned my RP name with color:", rpNameWithColor);
                    
                    if rpNameWithColor then
                        -- TRP3 returned a colored name, use it directly in the hyperlink
                        -- Use the stored author name (character-realm) for the hyperlink target
                        local nameLink = string.format("|Hplayer:%s|h%s|h", author, rpNameWithColor)
                        coloredAuthor = string.format("%s[%s]:|r", messageColor, nameLink)
                        addon:DebugMessage("[Data:DisplayHistory] Using TRP3 colored name");
                    else
                        -- No TRP3 name, fall back to class color and character name
                        addon:DebugMessage("[Data:DisplayHistory] No TRP3 name, using class color");
                        
                        -- Use the class token stored in the message if available
                        local authorClass = classToken
                        local classColor = authorClass and RAID_CLASS_COLORS[authorClass]
                        local classColorHex
                        if classColor then
                            classColorHex = string.format("%02x%02x%02x", classColor.r * 255, classColor.g * 255, classColor.b * 255)
                        else
                            classColorHex = "ffd100"
                        end
                        
                        -- Extract just the character name (without realm) for display
                        local charName = author:match("^([^%-]+)") or author
                        
                        -- Use formatting: brackets outside, hyperlink only around the name
                        local nameLink = string.format("|Hplayer:%s|h|cff%s%s|r|h", author, classColorHex, charName)
                        coloredAuthor = string.format("%s[%s]:|r", messageColor, nameLink)
                    end
                else
                    -- Color based on whisper type (receive)
                    if window.isBNet then
                        -- Use the window's display name instead of stored author (which might be session ID)
                        local bnetDisplayName = window.playerDisplay or displayName or author
                        -- For BNet, use a fixed color for the name (cyan)
                        coloredAuthor = "|cff00ddff" .. bnetDisplayName .. "|r"
                        
                        -- Use customizable receive color for BNet message text
                        local color = self.settings.bnetReceiveColor or {r = 0.0, g = 0.66, b = 1.0}
                        local colorHex = string.format("%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
                        messageColor = "|cff" .. colorHex
                    else
                        -- Use customizable receive color for whisper message text
                        local color = self.settings.whisperReceiveColor or {r = 1.0, g = 0.5, b = 1.0}
                        local colorHex = string.format("%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
                        messageColor = "|cff" .. colorHex
                        
                        -- Try to get RP name from TRP3 integration (if loaded)
                        addon:DebugMessage("[Data:DisplayHistory] Checking for TRP3 integration:", addon.TRP3_GetRPNameWithColor ~= nil);
                        addon:DebugMessage("[Data:DisplayHistory] Author name:", author);
                        local rpNameWithColor = addon.TRP3_GetRPNameWithColor and addon.TRP3_GetRPNameWithColor(author)
                        addon:DebugMessage("[Data:DisplayHistory] TRP3 returned RP name with color:", rpNameWithColor);
                        
                        if rpNameWithColor then
                            -- TRP3 returned a colored name with possible icon, use it directly
                            addon:DebugMessage("[Data:DisplayHistory] Using TRP3 colored name");
                            coloredAuthor = string.format("|Hplayer:%s|h%s[|r%s%s]:|h", author, messageColor, rpNameWithColor, messageColor)
                        else
                            -- No TRP3 name, use default class color
                            local authorDisplayName = author:match("^([^%-]+)") or author
                            addon:DebugMessage("[Data:DisplayHistory] No TRP3 name, using class color for:", authorDisplayName);
                            
                            -- Build clickable hyperlink with class colors
                            local classColorHex
                            
                            -- Use stored class token (converted from numeric ID)
                            if classToken then
                                local classColor = RAID_CLASS_COLORS[classToken]
                                if classColor then
                                    classColorHex = string.format("%02x%02x%02x", classColor.r * 255, classColor.g * 255, classColor.b * 255)
                                end
                            end
                            
                            local nameColorHex = classColorHex or "ffd100"  -- Class color or gold
                            -- Format: brackets in message color, name in class color
                            coloredAuthor = string.format("|Hplayer:%s|h%s[|r|cff%s%s|r%s]:|h", author, messageColor, nameColorHex, authorDisplayName, messageColor)
                        end
                    end
                end
            
                -- CRITICAL: Don't use gsub on message - preserve hyperlinks as-is
                -- Apply emote and speech formatting (this function preserves hyperlinks)
                local formattedText = self:FormatEmotesAndSpeech(message)
                -- Trim any leading whitespace so there is exactly one space after the colon
                formattedText = formattedText:gsub("^%s+", "")
                
                -- Convert URLs to clickable links
                formattedText = self:ConvertURLsToLinks(formattedText)
                
                -- Format message - concatenate parts WITHOUT string.format to preserve hyperlinks
                -- Simple concatenation preserves all escape sequences
                local formattedMessage = timeString .. " " .. coloredAuthor .. " " .. messageColor .. formattedText .. "|r"
                
                addon:DebugMessage("Adding message to historyFrame:")
                addon:DebugMessage("  timeString:", timeString)
                addon:DebugMessage("  coloredAuthor length:", #coloredAuthor)
                addon:DebugMessage("  messageColor:", messageColor)
                addon:DebugMessage("  formattedText length:", #formattedText)
                addon:DebugMessage("  formattedMessage length:", #formattedMessage)
                historyFrame:AddMessage(formattedMessage)
                
                -- Check for divider AFTER this message
                local nextEntry = history[i+1]
                local showDivider = false
                
                if nextEntry then
                    local nextTimestamp = nextEntry.t or nextEntry.timestamp
                    if GetDayKey(timestamp) ~= GetDayKey(nextTimestamp) then
                        showDivider = true
                    end
                else
                    -- Last message: show divider if older than 6 hours
                    if (time() - timestamp) > (6 * 3600) then
                        showDivider = true
                    end
                end
                
                if showDivider then
                    AddDateFooter(window, timestamp)
                end
        else
            addon:DebugMessage("Skipping message", i, "- missing data. timestamp:", tostring(timestamp), "author:", tostring(author), "message:", tostring(message))
        end
    end
    
    addon:DebugMessage("=== DisplayHistory END - Total messages processed:", #history, "===")
    historyFrame:ScrollToBottom()
end

-- Recent Chat Management
function addon:UpdateRecentChat(playerKey, displayName, isBNet, author)
    -- SCHEMA PROTECTION: Block if validation failed
    if not addon:IsSafeToOperate() then return end
    if InCombatLockdown() then
        addon:DebugMessage("In combat - skipping UpdateRecentChat write")
        return
    end
    
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
    
    -- Determine if message is unread
    local isRead = false
    local playerName, playerRealm = UnitName("player")
    local realm = (playerRealm or GetRealmName()):gsub("%s+", "")
    local fullPlayerName = playerName .. "-" .. realm
    
    if author == "Me" or author == playerName or author == fullPlayerName then
        isRead = true
    else
        -- Check if window is focused
        local win = addon.windows[playerKey]
        if win and win:IsShown() then
            isRead = true
        end
    end
    
    -- Update or create entry
    if not WhisperManager_RecentChats[playerKey] then
        WhisperManager_RecentChats[playerKey] = {
            lastMessageTime = now,
            isRead = isRead,
            isBNet = isBNet or false,
        }
    else
        WhisperManager_RecentChats[playerKey].lastMessageTime = now
        if not isRead then
            WhisperManager_RecentChats[playerKey].isRead = false
        end
    end
    
    addon:UpdateFloatingButtonUnreadStatus()
    if addon.recentChatsFrame and addon.recentChatsFrame:IsShown() then
        addon:RefreshRecentChats()
    end
end

--- Mark a conversation as read
-- @param playerKey string Canonical player key
function addon:MarkChatAsRead(playerKey)
    if WhisperManager_RecentChats and WhisperManager_RecentChats[playerKey] then
        WhisperManager_RecentChats[playerKey].isRead = true
        addon:UpdateFloatingButtonUnreadStatus()
        if addon.recentChatsFrame and addon.recentChatsFrame:IsShown() then
            addon:RefreshRecentChats()
        end
    end
end

function addon:IsChatAutoHidden(playerKey)
    if not playerKey or not WhisperManager_RecentChats then
        return false
    end

    local chatData = WhisperManager_RecentChats[playerKey]
    return chatData and chatData.autoHideWindow == true or false
end

function addon:SetChatAutoHidden(playerKey, shouldHide)
    if not playerKey then return end

    if not WhisperManager_RecentChats then
        WhisperManager_RecentChats = {}
    end

    if not WhisperManager_RecentChats[playerKey] then
        WhisperManager_RecentChats[playerKey] = {
            lastMessageTime = time(),
            isRead = true,
            isBNet = playerKey:match("^bnet_") ~= nil,
        }
    end

    WhisperManager_RecentChats[playerKey].autoHideWindow = shouldHide == true

    if shouldHide then
        addon:CloseWindow(playerKey)
    end

    if addon.recentChatsFrame and addon.recentChatsFrame:IsShown() then
        addon:RefreshRecentChats()
    end
end

-- Utility Functions
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

-- History Retention Cleanup
function addon:RunHistoryRetentionCleanup()
    local config = WhisperManager_Config or {}
    local retentionMode = config.historyRetentionMode or "none"
    
    if retentionMode == "none" then
        if addon.DebugMode then
            DEFAULT_CHAT_FRAME:AddMessage("[WM] Retention cleanup: Mode is 'none', skipping")
        end
        return
    end
    
    -- Find the retention options from Settings.lua
    local retentionOptions = self.RETENTION_OPTIONS
    if not retentionOptions then
        if addon.DebugMode then
            DEFAULT_CHAT_FRAME:AddMessage("[WM] Retention cleanup: RETENTION_OPTIONS not found")
        end
        return
    end
    
    -- Find the selected mode configuration
    local modeConfig = nil
    for _, option in ipairs(retentionOptions) do
        if option.value == retentionMode then
            modeConfig = option
            break
        end
    end
    
    if not modeConfig then
        if addon.DebugMode then
            DEFAULT_CHAT_FRAME:AddMessage("[WM] Retention cleanup: Mode config not found for: " .. retentionMode)
        end
        return
    end
    
    local keepCount = modeConfig.keepCount
    local keepMonths = modeConfig.keepMonths
    local deleteMonths = modeConfig.deleteMonths
    
    if addon.DebugMode then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("[WM] Retention cleanup: Mode=%s, Keep=%d, KeepMonths=%s, DeleteMonths=%d", 
            retentionMode, keepCount, tostring(keepMonths), deleteMonths))
    end
    
    local historyDB = WhisperManager_HistoryDB or {}
    local currentTime = time()
    local secondsPerMonth = 30 * 24 * 60 * 60  -- Approximate month as 30 days
    
    local totalPlayersProcessed = 0
    local totalMessagesDeleted = 0
    
    -- Iterate through each player's history
    for playerKey, history in pairs(historyDB) do
        if type(history) == "table" and #history > 0 then
            -- Sort messages by timestamp (newest first)
            table.sort(history, function(a, b)
                return (a.t or 0) > (b.t or 0)
            end)
            
            local messagesToKeep = {}
            local protectedCount = 0
            
            -- Process messages
            for i, message in ipairs(history) do
                local messageAge = currentTime - (message.t or 0)
                local ageInMonths = messageAge / secondsPerMonth
                
                local shouldKeep = false
                
                -- Protected messages: within keepCount AND within keepMonths (if specified)
                if i <= keepCount then
                    if keepMonths == nil or ageInMonths <= keepMonths then
                        shouldKeep = true
                        protectedCount = protectedCount + 1
                    end
                end
                
                -- Non-protected messages: keep if younger than deleteMonths
                if not shouldKeep and ageInMonths < deleteMonths then
                    shouldKeep = true
                end
                
                if shouldKeep then
                    table.insert(messagesToKeep, message)
                end
            end
            
            local deletedCount = #history - #messagesToKeep
            if deletedCount > 0 then
                historyDB[playerKey] = messagesToKeep
                totalMessagesDeleted = totalMessagesDeleted + deletedCount
                
                if addon.DebugMode then
                    DEFAULT_CHAT_FRAME:AddMessage(string.format("[WM] Cleaned %s: %d messages deleted, %d kept (%d protected)", 
                        playerKey, deletedCount, #messagesToKeep, protectedCount))
                end
            end
            
            totalPlayersProcessed = totalPlayersProcessed + 1
        end
    end
    
    -- Clean up empty entries
    local emptyRemoved = addon:CleanupEmptyHistoryEntries()
    
    -- Clean up window positions not accessed in over 7 days
    local windowPositionsRemoved = addon:CleanupWindowPositions()
    
    -- Refresh all open windows to reflect deleted messages
    if totalMessagesDeleted > 0 or emptyRemoved > 0 then
        addon:RefreshAllOpenWindows()
    end
    
    -- Always show cleanup results to user if messages were deleted
    if totalMessagesDeleted > 0 then
        local message = string.format("|cFF00FF00[WhisperManager]|r History cleanup complete: Removed %d old message%s from %d conversation%s to keep your saved history lean.", 
            totalMessagesDeleted,
            totalMessagesDeleted ~= 1 and "s" or "",
            totalPlayersProcessed,
            totalPlayersProcessed ~= 1 and "s" or "")
        if emptyRemoved > 0 then
            message = message .. string.format(" Also removed %d empty conversation%s.", 
                emptyRemoved, emptyRemoved ~= 1 and "s" or "")
        end
        print(message)
    elseif emptyRemoved > 0 then
        print(string.format("|cFF00FF00[WhisperManager]|r Removed %d empty conversation%s from history.", 
            emptyRemoved, emptyRemoved ~= 1 and "s" or ""))
    elseif addon.DebugMode then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("[WM] Retention cleanup complete: No messages needed deletion (%d players checked)", 
            totalPlayersProcessed))
    end
end

-- Debug Retention Cleanup (for testing with short time intervals)
function addon:RunDebugRetentionCleanup()
    local historyDB = WhisperManager_HistoryDB or {}
    local currentTime = time()
    
    local keepCount = 3  -- Keep 3 most recent messages
    local keepSeconds = 120  -- Protected for 2 minutes
    local deleteSeconds = 120  -- Delete messages older than 2 minutes
    
    print("|cFF00FF00[WhisperManager]|r Debug Retention Test: Keep 3 recent (protect <2min), delete >2min old")
    
    local totalPlayersProcessed = 0
    local totalMessagesDeleted = 0
    
    -- Iterate through each player's history
    for playerKey, history in pairs(historyDB) do
        if type(history) == "table" and #history > 0 then
            -- Sort messages by timestamp (newest first)
            table.sort(history, function(a, b)
                return (a.t or 0) > (b.t or 0)
            end)
            
            local messagesToKeep = {}
            local protectedCount = 0
            
            -- Process messages
            for i, message in ipairs(history) do
                local messageAge = currentTime - (message.t or 0)
                
                local shouldKeep = false
                
                -- Always keep the top 3 most recent messages
                if i <= keepCount then
                    shouldKeep = true
                    -- Mark as protected if also within keepSeconds
                    if messageAge <= keepSeconds then
                        protectedCount = protectedCount + 1
                    end
                -- Delete messages older than 5 minutes (if not in top 3)
                elseif messageAge < deleteSeconds then
                    shouldKeep = true
                end
                
                if shouldKeep then
                    table.insert(messagesToKeep, message)
                end
            end
            
            local deletedCount = #history - #messagesToKeep
            if deletedCount > 0 then
                historyDB[playerKey] = messagesToKeep
                totalMessagesDeleted = totalMessagesDeleted + deletedCount
                
                print(string.format("[WM] %s: Deleted %d, Kept %d (%d protected)", 
                    playerKey, deletedCount, #messagesToKeep, protectedCount))
            end
            
            totalPlayersProcessed = totalPlayersProcessed + 1
        end
    end
    
    -- Clean up empty entries
    local emptyRemoved = addon:CleanupEmptyHistoryEntries()
    
    -- Refresh all open windows to reflect deleted messages
    if totalMessagesDeleted > 0 or emptyRemoved > 0 then
        addon:RefreshAllOpenWindows()
    end
    
    local message = string.format("|cFF00FF00[WhisperManager]|r Debug cleanup complete: %d players, %d messages deleted", 
        totalPlayersProcessed, totalMessagesDeleted)
    if emptyRemoved > 0 then
        message = message .. string.format(", %d empty removed", emptyRemoved)
    end
    print(message)
end

--- Refresh all currently open whisper windows to display updated history
-- This is called after retention cleanup to show updated messages to the user
function addon:RefreshAllOpenWindows()
    if not addon.windows then return end
    
    for playerKey, window in pairs(addon.windows) do
        if window and window:IsVisible() then
            addon:DebugMessage("Refreshing window for: " .. tostring(playerKey))
            addon:DisplayHistory(window, playerKey)
        end
    end
end

-- Clean up empty history entries
function addon:CleanupEmptyHistoryEntries()
    local historyDB = WhisperManager_HistoryDB or {}
    local removedCount = 0
    
    -- Find and remove empty entries
    local keysToRemove = {}
    for playerKey, history in pairs(historyDB) do
        -- Skip the schema version key
        if playerKey ~= "__schema" then
            -- Check if history is empty or not a table
            if type(history) ~= "table" or #history == 0 then
                table.insert(keysToRemove, playerKey)
            end
        end
    end
    
    -- Remove the empty entries
    for _, key in ipairs(keysToRemove) do
        historyDB[key] = nil
        removedCount = removedCount + 1
    end
    
    if removedCount > 0 then
        if addon.DebugMode then
            print(string.format("[WM] Removed %d empty history entr%s", 
                removedCount, removedCount ~= 1 and "ies" or "y"))
        end
    end
    
    return removedCount
end

-- Clean up window positions not accessed in over 7 days
function addon:CleanupWindowPositions()
    if not WhisperManager_Config or not WhisperManager_Config.windowPositions then
        return 0
    end
    
    local positions = WhisperManager_Config.windowPositions
    local currentTime = time()
    local sevenDaysInSeconds = 7 * 24 * 60 * 60
    local keysToRemove = {}
    
    -- Find positions that haven't been focused in over 7 days
    for playerKey, pos in pairs(positions) do
        if type(pos) == "table" then
            local lastFocus = pos.lastFocus
            if lastFocus and (currentTime - lastFocus) > sevenDaysInSeconds then
                table.insert(keysToRemove, playerKey)
                addon:DebugMessage(string.format("[Data] Removing window position for %s (last focused %.1f days ago)", 
                    playerKey, (currentTime - lastFocus) / (24 * 60 * 60)))
            end
        end
    end
    
    -- Remove the old positions
    for _, key in ipairs(keysToRemove) do
        positions[key] = nil
    end
    
    if #keysToRemove > 0 then
        addon:DebugMessage(string.format("[Data] Removed %d window position(s) not used in 7 days", #keysToRemove))
    end
    
    return #keysToRemove
end

function addon:ResolvePlayerIdentifiers(playerName)
    local trimmed = self:TrimWhitespace(playerName)
    if not trimmed or trimmed == "" then return nil end

    local okPrefixed, isCharacterKey = pcall(string.match, trimmed, "^c_")
    local okBnetPrefixed, isBnetKey = pcall(string.match, trimmed, "^bnet_")
    if not okPrefixed or not okBnetPrefixed then
        if self.IsRestrictedChatModeInstance and self:IsRestrictedChatModeInstance() then
            return nil
        end
        return nil
    end

    if isCharacterKey or isBnetKey then
        local display = self:GetDisplayNameFromKey(trimmed)
        local okCharTarget, charTarget = pcall(string.match, trimmed, "^c_(.+)")
        local okBnetTarget, bnetTarget = pcall(string.match, trimmed, "^bnet_(.+)")
        local target = (okCharTarget and charTarget) or (okBnetTarget and bnetTarget) or trimmed
        return trimmed, target, display
    end

    local target = trimmed
    local okAmbiguate, ambiguatedTarget = pcall(Ambiguate, trimmed, "none")
    if okAmbiguate and ambiguatedTarget and ambiguatedTarget ~= "" then
        target = ambiguatedTarget
    end

    local okMatchNameRealm, namePart, realmPart = pcall(string.match, target, "^([^%-]+)%-(.+)$")
    if not okMatchNameRealm then
        if self.IsRestrictedChatModeInstance and self:IsRestrictedChatModeInstance() then
            return nil
        end
        return nil
    end

    local baseName = namePart or target
    local canonicalKey
    if realmPart and realmPart ~= "" then
        local okRealm, normalizedRealm = pcall(string.gsub, realmPart, "%s+", "")
        if not okRealm then return nil end
        canonicalKey = "c_" .. baseName .. "-" .. normalizedRealm
    else
        local realmName = GetRealmName()
        local okRealm, currentRealm = pcall(string.gsub, realmName, "%s+", "")
        if not okRealm then return nil end
        canonicalKey = "c_" .. baseName .. "-" .. currentRealm
    end

    local display = baseName
    local okDisplay, ambiguatedDisplay = pcall(Ambiguate, trimmed, "short")
    if okDisplay and ambiguatedDisplay and ambiguatedDisplay ~= "" then
        display = ambiguatedDisplay
    end

    return canonicalKey, target, display
end

function addon:GetDisplayNameFromKey(playerKey)
    if not playerKey then return "Unknown" end
    if playerKey:match("^bnet_") then
        local battleTag = playerKey:match("^bnet_(.+)")
        if battleTag then
            local name = battleTag:match("^([^#]+)") or battleTag
            return name or "Unknown"
        end
    end
    if playerKey:match("^c_") then
        local fullName = playerKey:match("^c_(.+)")
        if fullName then
            local name = fullName:match("^([^-]+)")
            return name or fullName
        end
    end
    return playerKey
end

function addon:ResolveBNetID(authorString, playerKey)
    if not authorString or authorString == "" then return "Unknown" end

    -- Session tokens look like |Kp123|k — try to resolve to a friendly display name
    if authorString:match("^|Kp%d+|k$") then
        -- 1) Prefer the BattleTag extracted from the provided playerKey (fast and deterministic)
        if playerKey and playerKey:match("^bnet_") then
            local battleTag = playerKey:match("^bnet_(.+)")
            if battleTag and battleTag ~= "" then
                return battleTag:match("^([^#]+)") or battleTag
            end
        end

        -- 2) Fallback: scan the Battle.net friends list for a friendly name (accountName preferred)
        local num = BNGetNumFriends() or 0
        for i = 1, num do
            local info = C_BattleNet.GetFriendAccountInfo(i)
            if info then
                if info.accountName and info.accountName ~= "" then
                    return info.accountName
                elseif info.battleTag and info.battleTag ~= "" then
                    return info.battleTag:match("^([^#]+)") or info.battleTag
                end
            end
        end

        -- 3) Last resort
        return "BNet Friend"
    end

    -- Not a session token — return input unchanged
    return authorString
end
