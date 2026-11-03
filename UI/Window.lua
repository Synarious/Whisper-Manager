-- Window lifecycle only. Conversation construction and behavior live in Modules/Chat.lua.
local addon = WhisperManager
addon.deferredWindowActions = {}
addon.deferredWindowActionSerial = 0

function addon:QueueWindowAction(key, action)
    self.deferredWindowActionSerial = self.deferredWindowActionSerial + 1
    self.deferredWindowActions[key] = {action = action, order = self.deferredWindowActionSerial}
end

function addon:CancelWindowAction(key)
    self.deferredWindowActions[key] = nil
end

function addon:CancelDeferredWindowActions()
    wipe(self.deferredWindowActions)
end

function addon:FlushDeferredWindowActions()
    if InCombatLockdown() then return end
    local pending = {}
    for key, entry in pairs(self.deferredWindowActions) do
        pending[#pending + 1] = {key = key, entry = entry}
    end
    table.sort(pending, function(a, b) return a.entry.order < b.entry.order end)
    for _, item in ipairs(pending) do
        -- Earlier actions may cancel or replace later work in this batch.
        if self.deferredWindowActions[item.key] == item.entry then
            self.deferredWindowActions[item.key] = nil
            local ok, err = pcall(item.entry.action)
            if not ok then self:DebugMessage("Deferred window action failed:", err) end
        end
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
    if not addon.initialized then return end
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
