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
    if authorString:match("^|Kp%d+|k$") then
        if playerKey and playerKey:match("^bnet_") then
            local battleTag = playerKey:match("^bnet_(.+)")
            if battleTag then
                local displayName = battleTag:match("^([^#]+)") or battleTag
                return displayName
            end
        end
        local numBNetTotal, _ = BNGetNumFriends()
        for i = 1, numBNetTotal do
            local accountInfo = C_BattleNet.GetFriendAccountInfo(i)
            if accountInfo and accountInfo.battleTag then
                if accountInfo.gameAccountInfo and accountInfo.gameAccountInfo.playerGuid then
                    local displayName = accountInfo.accountName or accountInfo.battleTag:match("^([^#]+)") or accountInfo.battleTag
                    return displayName
                end
            end
        end
        return "BNet Friend"
    end
    return authorString
end
