local addon = WhisperManager;

-- Chat message filter to suppress whispers that are handled by WhisperManager windows
local function ChatMessageEventFilter(self, event, msg, ...)
    -- Don't filter our own frames (History display)
    if self and self._WhisperManager then
        return false
    end
    -- We no longer suppress messages from the default chat frame.
    -- Always allow messages through.
    return false
end

function addon:RegisterEvents()
    -- Prevent duplicate event registrations
    if addon.__eventFrame then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00WhisperManager:|r Events already registered, skipping.")
        return
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00WhisperManager:|r Creating event frame and registering events...")
    

    -- Filtering of default chat is disabled per user request; do not register filters here.
    -- ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_WHISPER", ChatMessageEventFilter)
    -- ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", ChatMessageEventFilter)
    -- ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_BN_WHISPER", ChatMessageEventFilter)
    -- ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_BN_WHISPER_INFORM", ChatMessageEventFilter)
    -- DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00WhisperManager:|r Registered chat message filters")
    
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
                -- Don't unregister yet - we need to watch for TRP3 loading
            elseif addonName == "totalRP3" or addonName == "TotalRP3" then
                -- TRP3 just loaded, try to set up integration
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00WhisperManager:|r TotalRP3 detected, setting up integration...")
                addon:InitializeTRP3Integration()
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
            
            -- Track this character as belonging to the player's account
            if not WhisperManager_CharacterDB then WhisperManager_CharacterDB = {} end
            WhisperManager_CharacterDB[fullPlayerName] = true
            
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
            
            -- Track this character as belonging to the player's account
            if not WhisperManager_CharacterDB then WhisperManager_CharacterDB = {} end
            WhisperManager_CharacterDB[fullPlayerName] = true
            
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
            addon:UpdateFloatingButtonUnreadStatus()
            
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

function addon:SetupHooks()
    -- Prevent duplicate hooks
    if addon.__hooksInstalled then
        addon:DebugMessage("Hooks already installed, skipping.")
        return
    end
    addon.__hooksInstalled = true

    -- Defer addon work out of the protected Blizzard call path.
    -- The UnitPopup "Whisper"/"Reply"/BNet-whisper buttons execute
    -- ChatFrameUtil.SendTell / ReplyTell / SendBNetTell synchronously inside
    -- the protected menu button flow; running addon code (frame creation,
    -- ChatFrameUtil.DeactivateChat, editbox attribute writes) there taints
    -- the menu state, which later shows up as ADDON_ACTION_FORBIDDEN when the
    -- player clicks "Copy Name" (CopyToClipboard) in the same menu system.
    local function Schedule(action)
        C_Timer.After(0, action)
    end

    -- Queue one whisper action per tick so the SendTell/OpenChat pair fired by
    -- a single menu click only opens the conversation once, and all work runs
    -- outside the protected execution context.
    local function QueueOpenConversation(openFn)
        if addon.__wmPendingOpen then
            return
        end
        addon.__wmPendingOpen = true
        Schedule(function()
            addon.__wmPendingOpen = nil
            local ok = false
            pcall(function() ok = openFn() end)
            if ok then
                local editBox = ChatFrameUtil.ChooseBoxForSend()
                if editBox and editBox:IsShown() then
                    ChatFrameUtil.DeactivateChat(editBox)
                end
            end
        end)
    end

    -- Hook whisper command extraction - use editbox mixin method
    local function OnExtractTellTarget(editBox, text)
        local target = addon:ExtractWhisperTarget(text)
        if not target then return end
        addon:DebugMessage("Hooked /w via ExtractTellTarget. Target:", target)
        QueueOpenConversation(function() return addon:OpenConversation(target) end)
    end

    -- Hook the mixin method on ChatFrameEditBox
    hooksecurefunc(ChatFrameEditBoxMixin, "ExtractTellTarget", OnExtractTellTarget)

    -- Hook chat frame opening
    hooksecurefunc(ChatFrameUtil, "OpenChat", function(text, chatFrame, desiredCursorPosition)
        -- Don't trigger if we're closing a window
        if addon.__closingWindow then
            addon:DebugMessage("OpenChat ignored - window closing")
            return
        end

        local editBox = ChatFrameUtil.ChooseBoxForSend(chatFrame)
        if not editBox then return end

        local chatType = editBox:GetAttribute("chatType")
        if chatType ~= "WHISPER" then
            return
        end

        local target = editBox:GetAttribute("tellTarget")
        if not target or target == "" then return end

        addon:DebugMessage("OpenChat captured whisper target:", target)

        QueueOpenConversation(function() return addon:OpenConversation(target) end)
    end)

    -- Hook reply tell
    hooksecurefunc(ChatFrameUtil, "ReplyTell", function(chatFrame)
        local target = ChatFrameUtil.GetLastTellTarget()
        if target then
            QueueOpenConversation(function() return addon:OpenConversation(target) end)
        end
    end)

    -- Hook the default Whisper menu action so it opens WhisperManager windows
    hooksecurefunc(ChatFrameUtil, "SendTell", function(name, chatFrame)
        if not name or name == "" then return end
        -- Open conversation. If successful, close any opened chat editbox to avoid duplicate UI
        QueueOpenConversation(function() return addon:OpenConversation(name) end)
    end)

    -- Hook BNet whisper default action similarly
    hooksecurefunc(ChatFrameUtil, "SendBNetTell", function(tokenizedName)
        if not tokenizedName or tokenizedName == "" then return end
        -- SendBNetTell may pass a BattleTag or name; try to open by BattleTag when possible
        QueueOpenConversation(function() return addon:OpenBNetConversation(tokenizedName) end)
    end)

    -- Setup context menu integration
    addon:SetupContextMenu()
end

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

-- Initialize() is now called from the ADDON_LOADED event handler above
-- This ensures saved variables are loaded before we try to read settings

-- Start event registration when this file loads
addon:RegisterEvents()