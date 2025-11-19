-- ============================================================================
-- PlayerUtils.lua  Player identification and name resolution
-- ============================================================================

local addon = WhisperManager;

--- Resolve a player name into canonical key, full name, and display name
function addon:ResolvePlayerIdentifiers(playerName)
    local trimmed = self:TrimWhitespace(playerName)
    if not trimmed or trimmed == "" then return nil end
    if trimmed:match("^c_") or trimmed:match("^bnet_") then
        local display = self:GetDisplayNameFromKey(trimmed)
        local target = trimmed:match("^c_(.+)") or trimmed:match("^bnet_(.+)") or trimmed
        return trimmed, target, display
    end
    local target = Ambiguate(trimmed, "none") or trimmed
    local namePart, realmPart = target:match("^([^%-]+)%-(.+)$")
    local baseName = namePart or target
    local canonicalKey
    if realmPart and realmPart ~= "" then
        local normalizedRealm = realmPart:gsub("%s+", "")
        canonicalKey = "c_" .. baseName .. "-" .. normalizedRealm
    else
        local currentRealm = GetRealmName():gsub("%s+", "")
        canonicalKey = "c_" .. baseName .. "-" .. currentRealm
    end
    local display = Ambiguate(trimmed, "short") or baseName
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
