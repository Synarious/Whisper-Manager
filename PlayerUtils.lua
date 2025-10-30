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
