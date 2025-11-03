-- ============================================================================
-- PlayerUtils.lua - Player identification and name resolution
-- ============================================================================
-- This module handles player name parsing and identification logic.
-- Data management functions (history, recent chats, class cache) are in Data.lua
-- ============================================================================

local addon = WhisperManager;

-- ============================================================================
-- Player Name Resolution
-- ============================================================================

--- Resolve a player name into canonical key, full name, and display name
-- @param playerName string Raw player name (may include realm)
-- @return string|nil canonicalKey Canonical key for storage (c_Name-Realm)
-- @return string|nil target Full name with realm
-- @return string|nil display Short display name without realm
function addon:ResolvePlayerIdentifiers(playerName)
    local trimmed = self:TrimWhitespace(playerName)
    if not trimmed or trimmed == "" then return nil end

    -- CRITICAL FIX: If input already has c_ or bnet_ prefix, return it as-is
    -- This prevents double-prefixing (c_c_Name) when called with existing keys
    if trimmed:match("^c_") or trimmed:match("^bnet_") then
        addon:DebugMessage("ResolvePlayerIdentifiers: Input already has prefix, returning as-is:", trimmed)
        -- Extract display name from the key
        local display = self:GetDisplayNameFromKey(trimmed)
        -- For target, strip prefix and return the name-realm part
        local target = trimmed:match("^c_(.+)") or trimmed:match("^bnet_(.+)") or trimmed
        return trimmed, target, display
    end

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

--- Extract display name from a playerKey (works for both c_ and bnet_ keys)
-- @param playerKey string Canonical player key (c_Name-Realm or bnet_Tag)
-- @return string Display name without realm or prefix
function addon:GetDisplayNameFromKey(playerKey)
    if not playerKey then 
        addon:DebugMessage("GetDisplayNameFromKey: playerKey is nil")
        return "Unknown" 
    end
    
    addon:DebugMessage("GetDisplayNameFromKey: playerKey =", playerKey)
    
    -- For BNet keys: bnet_Name#1234 -> Name
    if playerKey:match("^bnet_") then
        local battleTag = playerKey:match("^bnet_(.+)")
        if battleTag then
            local name = battleTag:match("^([^#]+)") or battleTag
            addon:DebugMessage("GetDisplayNameFromKey: BNet name =", name)
            return name or "Unknown"
        end
    end
    
    -- For character keys: c_Name-Realm -> Name
    if playerKey:match("^c_") then
        local fullName = playerKey:match("^c_(.+)")
        if fullName then
            -- Split on the first hyphen to get name
            local name = fullName:match("^([^-]+)")  -- Everything before first hyphen
            addon:DebugMessage("GetDisplayNameFromKey: Character name =", name or fullName)
            return name or fullName
        end
    end
    
    -- Fallback for old format keys
    addon:DebugMessage("GetDisplayNameFromKey: Using fallback, returning playerKey as-is")
    return playerKey
end

--- Extract whisper target from slash command text (/w or /whisper)
-- @param text string Command text to parse
-- @return string|nil Extracted player name or nil
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
