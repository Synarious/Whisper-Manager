-- ============================================================================
-- Events.lua - Event handlers and hooks
-- ============================================================================

local addon = WhisperManager;

-- ============================================================================
-- Event Registration and Handlers
-- ============================================================================

-- Chat message filter to suppress whispers that are handled by WhisperManager windows
local function ChatMessageEventFilter(self, event, msg, ...)
    -- Don't filter our own frames (History display)
    if self and self._WhisperManager then
        return false
    end
    
    if event == "CHAT_MSG_WHISPER" then
        -- Incoming whisper
        local message, author = msg, (...)
        local playerKey = addon:ResolvePlayerIdentifiers(author)
        if playerKey then
            local window = addon.windows[playerKey]
            -- Suppress if we have a window for this conversation and setting is enabled
            if window and addon:GetSetting("suppressDefaultChat") ~= false then
                return true  -- Suppress from default chat
            end
        end
    elseif event == "CHAT_MSG_WHISPER_INFORM" then
        -- Outgoing whisper
        local message, target = msg, (...)
        local playerKey = addon:ResolvePlayerIdentifiers(target)
        if playerKey then
            local window = addon.windows[playerKey]
            -- Suppress if we have a window for this conversation and setting is enabled
            if window and addon:GetSetting("suppressDefaultChat") ~= false then
                return true  -- Suppress from default chat
            end
        end
    elseif event == "CHAT_MSG_BN_WHISPER" then
        -- Incoming BNet whisper
        local message, author, _, _, _, _, _, _, _, _, _, _, bnSenderID = msg, ...
        if bnSenderID then
            local accountInfo = C_BattleNet.GetAccountInfoByID(bnSenderID)
            if accountInfo and accountInfo.battleTag then
                local playerKey = "bnet_" .. accountInfo.battleTag
                local window = addon.windows[playerKey]
                -- Suppress if we have a window for this conversation and setting is enabled
                if window and addon:GetSetting("suppressDefaultChat") ~= false then
                    return true  -- Suppress from default chat
                end
            end
        end
    elseif event == "CHAT_MSG_BN_WHISPER_INFORM" then
        -- Outgoing BNet whisper
        local message, _, _, _, _, _, _, _, _, _, _, _, bnSenderID = msg, ...
        if bnSenderID then
            local accountInfo = C_BattleNet.GetAccountInfoByID(bnSenderID)
            if accountInfo and accountInfo.battleTag then
                local playerKey = "bnet_" .. accountInfo.battleTag
                local window = addon.windows[playerKey]
                -- Suppress if we have a window for this conversation and setting is enabled
                if window and addon:GetSetting("suppressDefaultChat") ~= false then
                    return true  -- Suppress from default chat
                end
            end
        end
    end
    
    return false
end

function addon:RegisterEvents()
    -- Prevent duplicate event registrations
    if addon.__eventFrame then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00WhisperManager:|r Events already registered, skipping.")
        return
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00WhisperManager:|r Creating event frame and registering events...")
    
    -- Register chat message filters to suppress whispers handled by our windows
    ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", ChatMessageEventFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", ChatMessageEventFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER", ChatMessageEventFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER_INFORM", ChatMessageEventFilter)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00WhisperManager:|r Registered chat message filters")
    
    local eventFrame = CreateFrame("Frame")
    addon.__eventFrame = eventFrame
    
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "ADDON_LOADED" then
            local addonName = ...
            -- Compare to the value stored in the addon namespace so renaming the folder or toc doesn't break loading
            if addonName == addon._tocName or addonName == "WhisperManager" then
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00WhisperManager:|r Loaded successfully!")
                -- Saved variables are now loaded, initialize the addon
                addon:Initialize()
                eventFrame:UnregisterEvent("ADDON_LOADED") -- Only need this once
            end
        elseif event == "PLAYER_STARTED_MOVING" then
            -- Player moved = window is focused, stop taskbar alert
            if addon.isFlashing then
                addon:StopTaskbarAlert()
            end
        elseif event == "CHAT_MSG_WHISPER" then
            local message, author, _, _, _, _, _, _, _, _, _, guid = ...
            local playerKey, _, displayName = addon:ResolvePlayerIdentifiers(author)
            if not playerKey then return end

            -- Try to extract class from GUID if available
            local classToken = nil
            if guid and guid ~= "" then
                local _, class = GetPlayerInfoByGUID(guid)
                if class then
                    classToken = class
                end
            end

            addon:AddMessageToHistory(playerKey, displayName or author, author, message, classToken)
            addon:UpdateRecentChat(playerKey, displayName or author, false)
            
            -- Play notification sound if enabled
            addon:PlayNotificationSound()
            
            -- Trigger Windows taskbar alert if enabled
            if addon:GetSetting("enableTaskbarAlert") then
                addon:TriggerTaskbarAlert()
            end
            
            addon:OpenConversation(author)
            local window = addon.windows[playerKey]
            if window then
                addon:DisplayHistory(window, playerKey)
            end
        elseif event == "CHAT_MSG_WHISPER_INFORM" then
            local message, target, _, _, _, _, _, _, _, _, _, guid = ...
            local playerKey, resolvedTarget, displayName = addon:ResolvePlayerIdentifiers(target)
            if not playerKey then return end

            -- Try to extract class from GUID if available
            local classToken = nil
            if guid and guid ~= "" then
                local _, class = GetPlayerInfoByGUID(guid)
                if class then
                    classToken = class
                end
            end

            -- Use actual player character name with realm instead of "Me"
            local playerName, playerRealm = UnitName("player")
            local realm = (playerRealm or GetRealmName()):gsub("%s+", "")
            local fullPlayerName = playerName .. "-" .. realm
            local _, playerClass = UnitClass("player")
            
            addon:AddMessageToHistory(playerKey, displayName or resolvedTarget, fullPlayerName, message, playerClass)
            addon:UpdateRecentChat(playerKey, displayName or resolvedTarget, false)
            
            addon:OpenConversation(resolvedTarget)
            local window = addon.windows[playerKey]
            if window then
                addon:DisplayHistory(window, playerKey)
            end
        elseif event == "CHAT_MSG_BN_WHISPER" then
            local message, author, _, _, _, _, _, _, _, _, _, _, bnSenderID = ...
            
            -- Get BattleTag for permanent identification
            local accountInfo = C_BattleNet.GetAccountInfoByID(bnSenderID)
            if not accountInfo or not accountInfo.battleTag then
                addon:DebugMessage("|cffff0000ERROR: Could not get BattleTag for incoming BNet whisper|r")
                return
            end
            
            local playerKey = "bnet_" .. accountInfo.battleTag
            local displayName = accountInfo.accountName or author or accountInfo.battleTag
            
            -- Use displayName for history so it's consistent, not the session-based author
            -- BNet whispers don't have class info
            addon:AddMessageToHistory(playerKey, displayName, displayName, message, nil)
            addon:UpdateRecentChat(playerKey, displayName, true)
            
            -- Play notification sound if enabled
            addon:PlayNotificationSound()
            
            -- Trigger Windows taskbar alert if enabled
            if addon:GetSetting("enableTaskbarAlert") then
                addon:TriggerTaskbarAlert()
            end
            
            addon:OpenBNetConversation(bnSenderID, displayName)
            local window = addon.windows[playerKey]
            if window then
                addon:DisplayHistory(window, playerKey)
            end
        elseif event == "CHAT_MSG_BN_WHISPER_INFORM" then
            local message, _, _, _, _, _, _, _, _, _, _, _, bnSenderID = ...
            
            -- Get BattleTag for permanent identification
            local accountInfo = C_BattleNet.GetAccountInfoByID(bnSenderID)
            if not accountInfo or not accountInfo.battleTag then
                addon:DebugMessage("|cffff0000ERROR: Could not get BattleTag for outgoing BNet whisper|r")
                return
            end
            
            local playerKey = "bnet_" .. accountInfo.battleTag
            local displayName = accountInfo.accountName or accountInfo.battleTag
            
            -- Use actual player character name with realm instead of "Me"
            local playerName, playerRealm = UnitName("player")
            local realm = (playerRealm or GetRealmName()):gsub("%s+", "")
            local fullPlayerName = playerName .. "-" .. realm
            local _, playerClass = UnitClass("player")
            addon:AddMessageToHistory(playerKey, displayName, fullPlayerName, message, playerClass)
            addon:UpdateRecentChat(playerKey, displayName, true)
            addon:OpenBNetConversation(bnSenderID, displayName)
            local window = addon.windows[playerKey]
            if window then
                addon:DisplayHistory(window, playerKey)
            end

        elseif event == "PLAYER_ENTERING_WORLD" then
            addon:DebugMessage("PLAYER_ENTERING_WORLD fired. Setting up hooks.");
            addon:SetupHooks()
            self:UnregisterEvent("PLAYER_ENTERING_WORLD")
            addon:DebugMessage("Hooks installed.");
            
            -- Create floating button after hooks are set up
            addon:CreateFloatingButton()
            
            -- Run retention cleanup on login
            addon:RunHistoryRetentionCleanup()
            
            -- Schedule daily cleanup (runs every 24 hours)
            C_Timer.NewTicker(86400, function()
                addon:RunHistoryRetentionCleanup()
            end)
        end
    end)
    
    -- Register all events
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("CHAT_MSG_WHISPER")
    eventFrame:RegisterEvent("CHAT_MSG_WHISPER_INFORM")
    eventFrame:RegisterEvent("CHAT_MSG_BN_WHISPER")
    eventFrame:RegisterEvent("CHAT_MSG_BN_WHISPER_INFORM")
    eventFrame:RegisterEvent("PLAYER_STARTED_MOVING")
end

-- ============================================================================
-- Hook Setup
-- ============================================================================

function addon:SetupHooks()
    -- Prevent duplicate hooks
    if addon.__hooksInstalled then
        addon:DebugMessage("Hooks already installed, skipping.")
        return
    end
    addon.__hooksInstalled = true
    
    -- Hook whisper command extraction
    hooksecurefunc("ChatEdit_ExtractTellTarget", function(editBox, text)
        local target = addon:ExtractWhisperTarget(text)
        if not target then return end
        addon:DebugMessage("Hooked /w via ChatEdit_ExtractTellTarget. Target:", target)
        
        if addon:OpenConversation(target) then
            _G.ChatEdit_OnEscapePressed(editBox)
        end
    end)

    -- Hook chat frame opening
    hooksecurefunc("ChatFrame_OpenChat", function(text, chatFrame)
        -- Don't trigger if we're closing a window
        if addon.__closingWindow then
            addon:DebugMessage("ChatFrame_OpenChat ignored - window closing")
            return
        end
        
        local editBox = chatFrame and chatFrame.editBox or _G.ChatEdit_ChooseBoxForSend(chatFrame)
        if not editBox then return end

        local chatType = editBox:GetAttribute("chatType")
        if chatType ~= "WHISPER" then
            return
        end

        -- Only intercept if text contains /w or /whisper command
        if not text or not text:match("^/[Ww]") then
            addon:DebugMessage("ChatFrame_OpenChat ignored - no /w command in text")
            return
        end

        local target = editBox:GetAttribute("tellTarget")
        if not target or target == "" then return end

        if editBox.__WhisperManagerHandled then return end
        editBox.__WhisperManagerHandled = true

        addon:DebugMessage("ChatFrame_OpenChat captured whisper target:", target)

        if addon:OpenConversation(target) then
            _G.ChatEdit_OnEscapePressed(editBox)
        end
        
        C_Timer.After(0.1, function()
            editBox.__WhisperManagerHandled = nil
        end)
    end)

    -- Hook reply tell
    hooksecurefunc("ChatFrame_ReplyTell", function()
        local target = _G.ChatEdit_GetLastTellTarget()
        if target and addon:OpenConversation(target) then
            local activeEditBox = _G.ChatEdit_ChooseBoxForSend()
            if activeEditBox then
                _G.ChatEdit_OnEscapePressed(activeEditBox)
            end
        end
    end)

    -- Hook the default Whisper menu action so it opens WhisperManager windows
    hooksecurefunc("ChatFrame_SendTell", function(target)
        if not target or target == "" then return end
        -- Open conversation. If successful, close any opened chat editbox to avoid duplicate UI
        local ok = false
        pcall(function() ok = addon:OpenConversation(target) end)
        if ok then
            local editBox = _G.ChatEdit_ChooseBoxForSend()
            if editBox and editBox:IsShown() then
                _G.ChatEdit_OnEscapePressed(editBox)
            end
        end
    end)

    -- Hook BNet whisper default action similarly
    hooksecurefunc("ChatFrame_SendBNetTell", function(target)
        if not target or target == "" then return end
        local ok = false
        -- ChatFrame_SendBNetTell may pass a BattleTag or name; try to open by BattleTag when possible
        pcall(function() ok = addon:OpenBNetConversation(target) end)
        if ok then
            local editBox = _G.ChatEdit_ChooseBoxForSend()
            if editBox and editBox:IsShown() then
                _G.ChatEdit_OnEscapePressed(editBox)
            end
        end
    end)

    -- Setup context menu integration
    addon:SetupContextMenu()
end

-- ============================================================================
-- Context Menu Integration
-- ============================================================================

function addon:SetupContextMenu()
    -- Intentionally disable context-menu modifications.
    -- The addon will rely on the default "Whisper" action (which already opens
    -- a WhisperManager window via other hooks) instead of adding its own menu
    -- entries. Keeping this function minimal avoids adding a divider-only
    -- menu item or causing errors when `contextData` is not a table.
    if addon.__contextMenuInstalled then
        addon:DebugMessage("Context menu already installed, skipping.")
        return
    end
    addon.__contextMenuInstalled = true
    addon:DebugMessage("Context menu modification disabled: relying on default Whisper action.")
end

-- ============================================================================
-- Initialize Addon (called after saved variables are loaded)
-- ============================================================================

-- Initialize() is now called from the ADDON_LOADED event handler above
-- This ensures saved variables are loaded before we try to read settings

-- Start event registration when this file loads
addon:RegisterEvents()