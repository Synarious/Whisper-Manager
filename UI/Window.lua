-- Window lifecycle only. Conversation construction and behavior live in Modules/Chat.lua.
local addon = WhisperManager
addon.deferredWindowActions = {}

function addon:QueueWindowAction(key, action)
    self.deferredWindowActions[key] = action
end

function addon:CancelDeferredWindowActions()
    wipe(self.deferredWindowActions)
end

function addon:FlushDeferredWindowActions()
    if InCombatLockdown() then return end
    local pending = self.deferredWindowActions
    self.deferredWindowActions = {}
    for _, action in pairs(pending) do
        local ok, err = pcall(action)
        if not ok then self:DebugMessage("Deferred window action failed:", err) end
    end
end

local lifecycle = CreateFrame("Frame")
lifecycle:RegisterEvent("PLAYER_REGEN_ENABLED")
lifecycle:RegisterEvent("PLAYER_REGEN_DISABLED")
lifecycle:RegisterEvent("PLAYER_ENTERING_WORLD")
lifecycle:RegisterEvent("ZONE_CHANGED_NEW_AREA")
if C_RestrictedActions and C_RestrictedActions.GetAddOnRestrictionState then
    lifecycle:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
end
lifecycle:SetScript("OnEvent", function(_, event, restrictionType, state)
    -- This event fires BEFORE enforcement. Honor Activating from its payload;
    -- querying IsAddOnRestrictionActive here would incorrectly report false.
    if event == "ADDON_RESTRICTION_STATE_CHANGED" then
        local types = Enum and Enum.AddOnRestrictionType
        local states = Enum and Enum.AddOnRestrictionState
        if types and states and types.Chat ~= nil and restrictionType == types.Chat then
            addon.chatRestrictionTransition = state ~= states.Inactive
            if addon.chatRestrictionTransition and addon.CancelRestrictedWhispers then
                addon:CancelRestrictedWhispers("Chat messaging restrictions became active.")
            end
        end
        -- Re-evaluate after Blizzard has finished the security transition.
        C_Timer.After(0, function()
            if addon.CheckRuntimeRestrictions then addon:CheckRuntimeRestrictions() end
            addon:FlushDeferredWindowActions()
        end)
        return
    end
    if addon.CheckRuntimeRestrictions then addon:CheckRuntimeRestrictions() end
    addon:FlushDeferredWindowActions()
end)
