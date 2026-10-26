local addon = WhisperManager

function addon:IsSecretValue(value)
    return issecretvalue and issecretvalue(value) == true
end

function addon:GetReadableBNetName(accountInfo, fallback)
    local name = accountInfo and accountInfo.accountName
    if self:IsSecretValue(name) then name = nil end
    if self:IsSecretValue(fallback) then fallback = nil end
    local tag = accountInfo and accountInfo.battleTag
    if self:IsSecretValue(tag) then tag = nil end
    return name or fallback or (tag and tag:match("^([^#]+)")) or "BNet Friend"
end

-- Ask the current client about this object instead of assuming all UI is locked.
function addon:CanChangeAddonFrame(frame)
    if not frame then return false end
    if C_RestrictedActions and C_RestrictedActions.CheckAllowProtectedFunctions then
        local ok, allowed = pcall(C_RestrictedActions.CheckAllowProtectedFunctions, frame, true)
        return ok and allowed == true
    end
    return not (InCombatLockdown() and frame.IsProtected and frame:IsProtected())
end

function addon:GetWhisperRestrictionReason()
    if self.chatRestrictionTransition then return "Chat messaging is currently restricted." end
    local types = Enum and Enum.AddOnRestrictionType
    local states = Enum and Enum.AddOnRestrictionState
    if types and states and types.Chat ~= nil and C_RestrictedActions
        and C_RestrictedActions.GetAddOnRestrictionState then
        local ok, state = pcall(C_RestrictedActions.GetAddOnRestrictionState, types.Chat)
        if not ok or state ~= states.Inactive then return "Chat messaging is currently restricted." end
    end
    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
        local ok, restricted = pcall(C_ChatInfo.InChatMessagingLockdown)
        if not ok or restricted then return "Chat messaging is currently restricted." end
    end
    -- Preserve the user's existing policy for dungeons, raids and PvP.
    if self.IsRestrictedChatModeInstance and self:IsRestrictedChatModeInstance() then
        return "Whisper Manager chat is disabled in this instance. Use default chat."
    end
end

function addon:CheckRuntimeRestrictions()
    local reason = self:GetWhisperRestrictionReason()
    if reason then
        if self.CancelRestrictedWhispers then self:CancelRestrictedWhispers(reason) end
        if self.CancelDeferredWindowActions then self:CancelDeferredWindowActions() end
    end
    if self.EnforceChatModeRestrictions then self:EnforceChatModeRestrictions(true) end
end
