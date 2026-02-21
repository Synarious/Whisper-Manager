-- Dialogs.lua - Popup dialogs and context menus
local addon = WhisperManager;

local function FocusWindowInputIfChatMode(playerKey)
    if not playerKey then return end
    if not (addon.IsChatModeEnabled and addon:IsChatModeEnabled()) then return end

    C_Timer.After(0, function()
        local win = addon.windows and addon.windows[playerKey]
        if win and win:IsShown() and win.Input and win.InputContainer and win.InputContainer:IsShown() then
            addon:FocusWindow(win)
            win.Input:SetFocus()
            addon:SetEditBoxFocus(win.Input)
        end
    end)
end

--- Open a context menu for a player
function addon:OpenPlayerContextMenu(owner, playerName, displayName, isBNet, bnSenderID)
    if type(owner) == "string" or owner == nil then
        owner, playerName, displayName, isBNet, bnSenderID = nil, owner, playerName, displayName, isBNet
    end

    if not playerName and not isBNet then return end

    local function menuGenerator(ownerFrame, rootDescription)
        local label = displayName or addon.StripRealmFromName(playerName) or playerName
        if label and label ~= "" then
            rootDescription:CreateTitle(label)
        end

        if not isBNet and playerName and playerName ~= "" then
            rootDescription:CreateButton(WHISPER, function()
                local opened = addon:OpenConversation(playerName)
                if opened then
                    local playerKey = addon:ResolvePlayerIdentifiers(playerName)
                    FocusWindowInputIfChatMode(playerKey)
                end
            end)
            rootDescription:CreateButton(INVITE, function() C_PartyInfo.InviteUnit(playerName) end)
            rootDescription:CreateButton("Export Chat", function() 
                local playerKey = addon:NormalizePlayerKey(playerName)
                addon:ShowChatExportDialog(playerKey, displayName or playerName)
            end)
            local raidTargetButton = rootDescription:CreateButton(RAID_TARGET_ICON)
            raidTargetButton:CreateButton(RAID_TARGET_NONE, function() SetRaidTarget(playerName, 0) end)
            for i = 1, 8 do
                raidTargetButton:CreateButton(_G["RAID_TARGET_" .. i], function() SetRaidTarget(playerName, i) end)
            end
            rootDescription:CreateButton(ADD_FRIEND, function() C_FriendList.AddFriend(playerName) end)
            rootDescription:CreateButton(PLAYER_REPORT, function()
                local guid = C_PlayerInfo.GUIDFromPlayerName(playerName)
                if guid then C_ReportSystem.OpenReportPlayerDialog(guid, playerName) end
            end)
        elseif isBNet and bnSenderID then
            rootDescription:CreateButton(WHISPER, function()
                local opened = addon:OpenBNetConversation(bnSenderID, displayName)
                if opened then
                    local accountInfo = C_BattleNet.GetAccountInfoByID(bnSenderID)
                    if accountInfo and accountInfo.battleTag then
                        FocusWindowInputIfChatMode("bnet_" .. accountInfo.battleTag)
                    end
                end
            end)
            rootDescription:CreateButton("Export Chat", function() 
                local accountInfo = C_BattleNet.GetAccountInfoByID(bnSenderID)
                if accountInfo and accountInfo.battleTag then
                    local playerKey = "bnet_" .. accountInfo.battleTag
                    addon:ShowChatExportDialog(playerKey, displayName)
                else
                    addon:Print("|cffff0000Could not export chat: BattleTag not found.|r")
                end
            end)
            rootDescription:CreateButton(INVITE, function() BNInviteFriend(bnSenderID) end)
        end

        rootDescription:CreateButton(CANCEL, function() end)
    end

    local createOwner = owner or UIParent
    local menu = nil
    pcall(function() menu = MenuUtil.CreateContextMenu(createOwner, menuGenerator) end)
    if menu and type(menu.Show) == "function" then
        pcall(function() menu:Show() end)
        return
    end
    local ok2, mouseFrame = pcall(function() return GetMouseFocus() end)
    if ok2 and mouseFrame then
        local altMenu = nil
        pcall(function() altMenu = MenuUtil.CreateContextMenu(mouseFrame, menuGenerator) end)
        if altMenu and type(altMenu.Show) == "function" then
            pcall(function() altMenu:Show() end)
            return
        end
    end
end

--- Show URL copy dialog with extracted URL
function addon:ShowURLCopyDialog(url)
    if not url or url == "" then return end
    
    url = url:gsub('%%%%', '%%')
    local urlToShow = url
    
    StaticPopupDialogs["WHISPERMANAGER_SHOW_URL"] = {
        text = "URL: ( CTRL+C to Copy )",
        button1 = OKAY,
        hasEditBox = 1,
        hasWideEditBox = 1,
        editBoxWidth = 400,
        OnShow = function(self)
            local editBox = self.wideEditBox or self.editBox or _G[self:GetName().."WideEditBox"] or _G[self:GetName().."EditBox"]
            
            if editBox then
                editBox:SetText(urlToShow)
                editBox:SetFocus()
                editBox:HighlightText(0)
                editBox:SetMaxLetters(0)
            else
                for i = 1, self:GetNumChildren() do
                    local child = select(i, self:GetChildren())
                    if child and child:GetObjectType() == "EditBox" then
                        editBox = child
                        editBox:SetText(urlToShow)
                        editBox:SetFocus()
                        editBox:HighlightText(0)
                        break
                    end
                end
            end
        end,
        OnHide = function(self)
            local editBox = self.wideEditBox or self.editBox or _G[self:GetName().."WideEditBox"] or _G[self:GetName().."EditBox"]
            if editBox then
                editBox:SetText("")
            end
        end,
        OnAccept = function() end,
        EditBoxOnEscapePressed = function(self)
            self:GetParent():Hide()
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        preferredIndex = 3,
    }
    
    StaticPopup_Show("WHISPERMANAGER_SHOW_URL")
end

--- Format chat history for export (plain text)
local function FormatChatHistoryForExport(playerKey)
    if not WhisperManager_HistoryDB or not playerKey then
        return "No chat history found."
    end
    
    local history = WhisperManager_HistoryDB[playerKey]
    if not history or #history == 0 then
        return "No messages found for this conversation."
    end
    
    local MAX_LINES = 2500
    local totalMessages = #history
    local startIndex = 1
    local wasTruncated = false
    if totalMessages > MAX_LINES then
        startIndex = totalMessages - MAX_LINES + 1
        wasTruncated = true
    end

    local lines = {}
    local displayName = addon:GetDisplayNameFromKey(playerKey)
    
    table.insert(lines, "Chat History Export")
    table.insert(lines, "Conversation with: " .. displayName)
    table.insert(lines, "Player Key: " .. playerKey)
    if wasTruncated then
        table.insert(lines, string.format("Showing last %d messages (of %d total)", MAX_LINES, totalMessages))
    else
        table.insert(lines, "Total Messages: " .. totalMessages)
    end
    table.insert(lines, "========================================")
    table.insert(lines, "")
    
    local playerName, playerRealm = UnitName("player")
    local realm = (playerRealm or GetRealmName()):gsub("%s+", "")
    local fullPlayerName = playerName .. "-" .. realm
    
    local function IsPlayerCharacter(authorName)
        if not authorName then return false end
        if authorName == "Me" then return true end
        
        if not WhisperManager_CharacterDB then WhisperManager_CharacterDB = {} end
        
        if WhisperManager_CharacterDB[authorName] then return true end
        
        if authorName == playerName or authorName == fullPlayerName then
            return true
        end
        
        return false
    end
    
    for i = startIndex, totalMessages do
        local entry = history[i]
        if not entry then
            -- safety
        else
            local timestamp = entry.t or entry.timestamp
            local author = entry.a or entry.author
            local message = entry.m or entry.message
            
            if timestamp and author and message then
                local timeString = date("%Y-%m-%d %H:%M:%S", timestamp)
                
                local authorDisplay
                if IsPlayerCharacter(author) then
                    authorDisplay = author:match("^([^%-]+)") or author
                else
                    if playerKey:match("^bnet_") and author:match("^|Kp%d+|k$") then
                        authorDisplay = addon:ResolveBNetID(author, playerKey)
                    else
                        authorDisplay = author:match("^([^%-]+)") or author
                    end
                end
                
                local plainMessage = message
                
                plainMessage = plainMessage:gsub("|T.-|t", "")
                plainMessage = plainMessage:gsub("|A.-|a", "")
                plainMessage = plainMessage:gsub("|c%x%x%x%x%x%x%x%x", "")
                plainMessage = plainMessage:gsub("|cn.-:", "")
                plainMessage = plainMessage:gsub("|r", "")
                plainMessage = plainMessage:gsub("|H.-|h(.-)|h", "%1")
                plainMessage = plainMessage:gsub("|K.-|k", "")
                plainMessage = plainMessage:gsub("|n", "\n")
                plainMessage = plainMessage:gsub("  +", " ")
                
                local line = string.format("[%s] %s: %s", timeString, authorDisplay, plainMessage)
                table.insert(lines, line)
            end
        end
    end
    
    return table.concat(lines, "\n")
end

--- Show chat export dialog with formatted history
function addon:ShowChatExportDialog(playerKey, displayName, parentWindow)
    if not playerKey then
        addon:Print("|cffff0000Cannot export chat: Invalid player key.|r")
        return
    end
    
    local exportText = FormatChatHistoryForExport(playerKey)
    displayName = displayName or addon:GetDisplayNameFromKey(playerKey)
    
    local frame = addon.chatExportFrame
    if not frame then
        frame = CreateFrame("Frame", "WhisperManager_ChatExportFrame", addon:GetOverlayParent(), "BackdropTemplate")
        frame:SetSize(600, 500)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:SetFrameLevel(200)
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        frame:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
        frame:SetBackdropColor(0, 0, 0, 0.9)
        frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        frame:SetToplevel(true)
        
        frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        frame.title:SetPoint("TOP", 0, -10)
        frame.title:SetText("Export Chat History")
        
        frame.closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        frame.closeBtn:SetPoint("TOPRIGHT", -2, -2)
        frame.closeBtn:SetSize(24, 24)
        frame.closeBtn:SetScript("OnClick", function(self)
            self:GetParent():Hide()
        end)
        
        frame.infoText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        frame.infoText:SetPoint("TOP", 0, -35)
        frame.infoText:SetText("Press CTRL+A to select all, then CTRL+C to copy")
        frame.infoText:SetTextColor(0.8, 0.8, 0.8)
        
        frame.playerLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        frame.playerLabel:SetPoint("TOPLEFT", 15, -60)
        frame.playerLabel:SetJustifyH("LEFT")
        
        frame.scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        frame.scrollFrame:SetPoint("TOPLEFT", 15, -80)
        frame.scrollFrame:SetPoint("BOTTOMRIGHT", -30, 15)
        frame.scrollFrame:EnableMouse(true)
        
        frame.editBox = CreateFrame("EditBox", nil, frame.scrollFrame)
        frame.editBox:SetMultiLine(true)
        frame.editBox:SetMaxLetters(0)
        frame.editBox:SetFontObject(ChatFontNormal)
        frame.editBox:SetWidth(550)
        frame.editBox:SetAutoFocus(false)
        frame.editBox:EnableMouse(true)
        frame.editBox:EnableMouseWheel(true)
        frame.editBox:SetScript("OnEscapePressed", function(self)
            frame:Hide()
        end)
        frame.scrollFrame:SetScrollChild(frame.editBox)
        
        frame:SetScript("OnKeyDown", function(self, key)
            if key == "ESCAPE" then
                self:Hide()
            end
        end)
        frame:SetPropagateKeyboardInput(true)
        
        addon.chatExportFrame = frame
    end
    
    if parentWindow and parentWindow:IsShown() then
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", parentWindow, "CENTER", 0, 0)
    else
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", addon:GetOverlayParent(), "CENTER")
    end
    
    addon.nextDialogLevel = (addon.nextDialogLevel or 200) + 10
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(addon.nextDialogLevel)
    
    if frame.title then
        frame.title:SetDrawLayer("OVERLAY", 7)
    end
    if frame.closeBtn then
        frame.closeBtn:SetFrameStrata("DIALOG")
        frame.closeBtn:SetFrameLevel(addon.nextDialogLevel + 10)
    end
    if frame.scrollFrame then
        frame.scrollFrame:SetFrameStrata("DIALOG")
        frame.scrollFrame:SetFrameLevel(addon.nextDialogLevel + 5)
    end
    if frame.editBox then
        frame.editBox:SetFrameStrata("DIALOG")
        frame.editBox:SetFrameLevel(addon.nextDialogLevel + 6)
    end
    
    frame.playerLabel:SetText("Conversation with: " .. displayName)
    frame.editBox:SetText(exportText)
    frame.editBox:SetCursorPosition(0)
    frame.editBox:HighlightText(0, 0)
    
    frame:Show()
    frame:Raise()
end