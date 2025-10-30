-- ============================================================================
-- PlayerUtils.lua - Player identification and name resolution
-- ============================================================================

local addon = WhisperManager;

-- ============================================================================
-- Player Identifier Functions
-- ============================================================================

function addon:ResolvePlayerIdentifiers(playerName)
    local trimmed = self:TrimWhitespace(playerName)
    if not trimmed or trimmed == "" then return nil end

    local target = Ambiguate(trimmed, "none") or trimmed
    if not target or target == "" then return nil end

    local namePart, realmPart = target:match("^([^%-]+)%-(.+)$")
    local baseName = namePart or target
    
    -- Use full name-realm as canonical key (prefixed with c_)
    -- Remove spaces from realm names (e.g., "Moon Guard" -> "MoonGuard")
    local canonicalKey
    if realmPart and realmPart ~= "" then
        local normalizedRealm = realmPart:gsub("%s+", "")
        canonicalKey = "c_" .. baseName .. "-" .. normalizedRealm
    else
        -- If no realm, add current realm (normalized)
        local currentRealm = GetRealmName():gsub("%s+", "")
        canonicalKey = "c_" .. baseName .. "-" .. currentRealm
    end

    local display = Ambiguate(trimmed, "short") or baseName

    return canonicalKey, target, display
end

-- Extract display name from a key (works for both c_ and bnet_ keys)
function addon:GetDisplayNameFromKey(playerKey)
    if not playerKey then return "Unknown" end
    
    -- For BNet keys: bnet_Name#1234 -> Name
    if playerKey:match("^bnet_(.+)") then
        local battleTag = playerKey:match("^bnet_(.+)")
        local name = battleTag:match("^([^#]+)") or battleTag
        return name
    end
    
    -- For character keys: c_Name-Realm -> Name
    if playerKey:match("^c_(.+)") then
        local fullName = playerKey:match("^c_(.+)")
        local name = fullName:match("^([^%-]+)") or fullName
        return name
    end
    
    -- Fallback for old format keys
    return playerKey
end

function addon:ExtractWhisperTarget(text)
    if type(text) ~= "string" then return nil end

    local trimmed = self:TrimWhitespace(text)
    if not trimmed or trimmed == "" then return nil end

    local _, target = trimmed:match("^/([Ww][Hh][Ii][Ss][Pp][Ee][Rr])%s+([^%s]+)")
    if not target then
        _, target = trimmed:match("^/([Ww])%s+([^%s]+)")
    end

    return target and target:gsub("[,.;:]+$", "") or nil
end

-- ============================================================================
-- Recent Chat Management
-- ============================================================================

-- Update recent chat entry
function addon:UpdateRecentChat(playerKey, displayName, isBNet)
    if not WhisperManager_RecentChats then
        WhisperManager_RecentChats = {}
    end
    
    local now = time()
    
    -- Clean up old entries (older than 72 hours)
    for key, data in pairs(WhisperManager_RecentChats) do
        if (now - data.lastMessageTime) > self.RECENT_CHAT_EXPIRY then
            WhisperManager_RecentChats[key] = nil
        end
    end
    
    -- Update or create entry (no displayName needed, extracted from key)
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

-- Mark chat as read
function addon:MarkChatAsRead(playerKey)
    if WhisperManager_RecentChats and WhisperManager_RecentChats[playerKey] then
        WhisperManager_RecentChats[playerKey].isRead = true
    end
end

-- ============================================================================
-- Class Color Functions
-- ============================================================================

-- Get class color for a character name (returns hex color string or nil)
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
        -- Cache the result in saved variables
        if not WhisperManager_Config then
            WhisperManager_Config = {}
        end
        if not WhisperManager_Config.classCache then
            WhisperManager_Config.classCache = {}
        end
        WhisperManager_Config.classCache[playerName] = class
        
        local classColor = RAID_CLASS_COLORS[class]
        if classColor then
            return string.format("%02x%02x%02x", classColor.r * 255, classColor.g * 255, classColor.b * 255)
        end
    end
    
    return nil  -- No class info available
end

-- Function to manually set class info (can be called when receiving GUID info from whisper events)
function addon:SetPlayerClass(playerName, class)
    if playerName and class then
        -- Store in saved variables for persistence
        if not WhisperManager_Config then
            WhisperManager_Config = {}
        end
        if not WhisperManager_Config.classCache then
            WhisperManager_Config.classCache = {}
        end
        WhisperManager_Config.classCache[playerName] = class
    end
end
