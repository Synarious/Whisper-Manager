-- ============================================================================
-- Events.lua - Event handlers and hooks
-- ============================================================================

local addon = WhisperManager;

-- ============================================================================
-- Event Registration and Handlers
-- ============================================================================

function addon:RegisterEvents()
    -- Prevent duplicate event registrations
    if addon.__eventFrame then
        addon:DebugMessage("Events already registered, skipping.")
        return
    end
    
    local eventFrame = CreateFrame("Frame")
    addon.__eventFrame = eventFrame
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("CHAT_MSG_WHISPER")
    eventFrame:RegisterEvent("CHAT_MSG_WHISPER_INFORM")
    eventFrame:RegisterEvent("CHAT_MSG_BN_WHISPER")
    eventFrame:RegisterEvent("CHAT_MSG_BN_WHISPER_INFORM")

    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "CHAT_MSG_WHISPER" then
            local message, author, _, _, _, _, _, _, _, _, _, guid = ...
            local playerKey, _, displayName = addon:ResolvePlayerIdentifiers(author)
            if not playerKey then return end

            -- Try to extract class from GUID if available
            local classToken = nil
            if guid and guid ~= "" then
                local _, class = GetPlayerInfoByGUID(guid)
                if class then
                    addon:SetPlayerClass(author, class)
                    classToken = class
                end
            end

            addon:AddMessageToHistory(playerKey, displayName or author, author, message, classToken)
            addon:UpdateRecentChat(playerKey, displayName or author, false)
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
                    addon:SetPlayerClass(target, class)
                    classToken = class
                end
            end

            -- Use actual player character name instead of "Me"
            local playerName = UnitName("player")
            local _, playerClass = UnitClass("player")
            addon:AddMessageToHistory(playerKey, displayName or resolvedTarget, playerName, message, playerClass)
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
            
            -- Use actual player character name instead of "Me"
            local playerName = UnitName("player")
            local _, playerClass = UnitClass("player")
            addon:AddMessageToHistory(playerKey, displayName, playerName, message, playerClass)
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
        end
    end)
    
    addon:DebugMessage("Events registered.");
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

    -- Setup context menu integration
    addon:SetupContextMenu()
end

-- ============================================================================
-- Context Menu Integration
-- ============================================================================

function addon:SetupContextMenu()
    -- Prevent duplicate menu modifications
    if addon.__contextMenuInstalled then
        addon:DebugMessage("Context menu already installed, skipping.")
        return
    end
    addon.__contextMenuInstalled = true
    
    local function AddWhisperManagerButton(owner, rootDescription, contextData)
        addon:DebugMessage("AddWhisperManagerButton fired.")
    
        if not contextData then
            addon:DebugMessage("|cffff0000ERROR: contextData is nil!|r")
            return
        end
    
        addon:DebugMessage("Inspecting contextData:")
        if contextData.unit then
            addon:DebugMessage("- contextData.unit:", contextData.unit)
        else
            addon:DebugMessage("- contextData.unit: nil")
        end
        if contextData.name then
            addon:DebugMessage("- contextData.name:", contextData.name)
        else
            addon:DebugMessage("- contextData.name: nil")
        end
    
        local playerName
        local unit = contextData.unit
        
        -- Try to get name from unit token first
        if unit and UnitExists(unit) and UnitIsPlayer(unit) then
            local name, realm = UnitName(unit)
            if name then
                if realm and realm ~= "" then
                    playerName = string.format("%s-%s", name, realm)
                else
                    playerName = name
                end
            end
            addon:DebugMessage("Player name found from unit token:", playerName)
        end
        
        -- Fallback to contextData.name if available
        if not playerName and contextData.name and contextData.name ~= "" then
            playerName = contextData.name
            addon:DebugMessage("Player name found from contextData.name:", playerName)
        end
    
        if playerName then
            addon:DebugMessage("Successfully determined playerName:", playerName)
            local playerKey = addon:ResolvePlayerIdentifiers(playerName)
            if playerKey then
                addon:DebugMessage("Adding button to the menu...")
                rootDescription:CreateDivider()
                rootDescription:CreateButton("Open in WhisperManager", function()
                    addon:DebugMessage("Menu button clicked for:", playerName)
                    addon:OpenConversation(playerName)
                end)
                addon:DebugMessage("Button added successfully.")
            else
                addon:DebugMessage("|cffffff00INFO: Could not normalize player key.|r")
            end
        else
            addon:DebugMessage("|cffffff00INFO: Could not determine a player name. Not adding button.|r")
        end
    end

    local tagsToModify = {
        "MENU_UNIT_TARGET",
        "MENU_UNIT_FOCUS",
        "MENU_UNIT_FRIEND",
        "MENU_UNIT_CHAT_PLAYER",
        "MENU_UNIT_PLAYER",
        "MENU_UNIT_ENEMY_PLAYER",
        "MENU_UNIT_RAID_PLAYER",
        "MENU_UNIT_SELF",
    }
    for i = 1, 4 do 
        table.insert(tagsToModify, "MENU_UNIT_PARTY"..i)
        table.insert(tagsToModify, "MENU_UNIT_RAID"..i)
    end
    for i = 1, 40 do
        table.insert(tagsToModify, "MENU_UNIT_RAID_PLAYER"..i)
    end
    for _, tag in ipairs(tagsToModify) do 
        Menu.ModifyMenu(tag, AddWhisperManagerButton) 
    end
end
