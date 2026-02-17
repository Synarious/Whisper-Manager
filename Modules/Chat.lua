-- Chat window implementation
local addon = WhisperManager

-- Uses combatQueue from Core.lua for combat-safe operations

local function UpdateWindowFrameLevels(win, baseLevel)
    addon:EnsureFrameOverlay(win)

    addon:DebugMessage("UpdateWindowFrameLevels fired for window: " .. tostring(win:GetName() or "<unnamed>") .. " baseLevel=" .. tostring(baseLevel))
    win:SetFrameLevel(baseLevel)
    
    if win.titleBar then win.titleBar:SetFrameLevel(baseLevel + 1) end
    if win.History then win.History:SetFrameLevel(baseLevel + 10) end
    if win.closeBtn then win.closeBtn:SetFrameLevel(baseLevel + 50) end
    if win.copyBtn then win.copyBtn:SetFrameLevel(baseLevel + 49) end
    if win.resizeBtn then win.resizeBtn:SetFrameLevel(baseLevel + 48) end
    if win.trp3Btn then win.trp3Btn:SetFrameLevel(baseLevel + 49) end
    if win.ginviteBtn then win.ginviteBtn:SetFrameLevel(baseLevel + 49) end
end

local function GetDayKey(timestamp)
    if not timestamp then return nil end
    return date("%Y%m%d", timestamp)
end

local function GetRelativeDateLabel(timestamp)
    local now = time()
    local diff = now - timestamp
    local dateStr = date("%m/%d/%y", timestamp)
    
    local relative = ""
    if diff < 3600 then
        relative = math.floor(diff / 60) .. "m ago"
    elseif diff < 86400 then
        relative = math.floor(diff / 3600) .. "h ago"
    elseif diff < 604800 then
        relative = math.floor(diff / 86400) .. "d ago"
    elseif diff < 2592000 then
        relative = math.floor(diff / 604800) .. "w ago"
    else
        relative = math.floor(diff / 2592000) .. "mo ago"
    end
    
    return string.format("----- (%s) %s -----", relative, dateStr)
end

local function AddDateFooter(win, timestamp)
    if not win or not win.History or not timestamp then return end
    local label = GetRelativeDateLabel(timestamp)
    win.History:AddMessage(label, 0.8078, 0.4863, 0.0)
end

local function FormatMessageForDisplay(win, author, message, timestamp, classToken)
    -- Hardcoded timestamp color: CE7C00
    local tsColorHex = "CE7C00"
    local timeString = "|cff" .. tsColorHex .. date("%H:%M", timestamp) .. "|r"

    local playerName, playerRealm = UnitName("player")
    local realm = (playerRealm or GetRealmName()):gsub("%s+", "")
    local fullPlayerName = playerName .. "-" .. realm
    
    local coloredAuthor
    local messageColor
    
    local isMe = (author == "Me" or author == playerName or author == fullPlayerName)
    
    if isMe then
        if win.isBNet then
            -- Hardcoded BNet Send Color: #007EFF
            local colorHex = "007EFF"
            messageColor = "|cff" .. colorHex
        else
            -- Hardcoded Whisper Send Color: #D832FF
            local colorHex = "D832FF"
            messageColor = "|cff" .. colorHex
        end
        
        local _, playerClass = UnitClass("player")
        local classColor = playerClass and RAID_CLASS_COLORS[playerClass]
        local classColorHex = classColor and string.format("%02x%02x%02x", classColor.r * 255, classColor.g * 255, classColor.b * 255) or "ffd100"
        
        coloredAuthor = string.format("|Hplayer:%s|h%s[|r|cff%s%s|r%s]:|h", fullPlayerName, messageColor, classColorHex, playerName, messageColor)
    else
        if win.isBNet then
            local bnetDisplayName = win.displayName or author
            -- Hardcoded BNet Receive Color: #00A8FF
            local colorHex = "00A8FF"
            messageColor = "|cff" .. colorHex
            coloredAuthor = "|TInterface\\ChatFrame\\UI-ChatIcon-Blizz:14:14:0:-1|t|cff00ddff" .. (bnetDisplayName) .. "|r"
        else
            -- Hardcoded Whisper Receive Color: #FF80FF
            local colorHex = "FF80FF"
            messageColor = "|cff" .. colorHex
            
            local authorDisplayName = author:match("^([^%-]+)") or author
            local classColorHex
            if classToken then
                local classColor = RAID_CLASS_COLORS[classToken]
                if classColor then
                    classColorHex = string.format("%02x%02x%02x", classColor.r * 255, classColor.g * 255, classColor.b * 255)
                end
            end
            local nameColorHex = classColorHex or "ffd100"
            coloredAuthor = string.format("|Hplayer:%s|h%s[|r|cff%s%s|r%s]:|h", author, messageColor, nameColorHex, authorDisplayName, messageColor)
        end
    end

    local formattedText = addon:FormatEmotesAndSpeech(message)
    formattedText = formattedText:gsub("^%s+", "")

    return timeString .. " " .. coloredAuthor .. " " .. messageColor .. formattedText .. "|r"
end

local function CreateTitleBar(win, displayName, baseLevel)
    win.titleBar = CreateFrame("Frame", nil, win, "BackdropTemplate")
    win.titleBar:SetPoint("TOPLEFT", 3, -3)
    win.titleBar:SetPoint("TOPRIGHT", -3, -3)
    win.titleBar:SetHeight(30)
    win.titleBar:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        tile = false
    })
    win.titleBar:SetBackdropColor(0, 0, 0, 0.8)
    win.titleBar:SetFrameLevel(baseLevel + 1)
    
    win.title = win.titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    win.title:SetPoint("TOP", win.titleBar, "TOP", 0, -7)
    win.title:SetText(displayName)
end

local function CreateButtons(win, baseLevel)
    -- Copy Button
    win.copyBtn = CreateFrame("Button", nil, win)
    win.copyBtn:SetPoint("TOPLEFT", 6, -6)
    win.copyBtn:SetSize(20, 20)
    win.copyBtn:SetNormalTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
    win.copyBtn:SetPushedTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Down")
    win.copyBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    win.copyBtn:SetFrameLevel(baseLevel + 49)
    win.copyBtn:SetScript("OnClick", function(self)
        addon:DebugMessage("[Chat] Copy Chat History button clicked")
        addon:ShowChatExportDialog(win.playerKey, win.displayName)
    end)
    win.copyBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Copy Chat History", 1, 1, 1)
        GameTooltip:AddLine("Click to copy all messages to clipboard", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    win.copyBtn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)

    -- TRP3 Button
    win.trp3Btn = CreateFrame("Button", nil, win)
    win.trp3Btn:SetPoint("LEFT", win.copyBtn, "RIGHT", 4, 0)
    win.trp3Btn:SetSize(20, 20)
    win.trp3Btn:SetNormalTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
    win.trp3Btn:SetPushedTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Down")
    win.trp3Btn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    win.trp3Btn:SetFrameLevel(baseLevel + 49)
    win.trp3Btn:Hide()
    
    win.trp3Btn:SetScript("OnClick", function(self)
        if addon.settings and addon.settings.enableTRP3Button then
            local charRealm = win.playerTarget
            if charRealm and not charRealm:find("-") then
                local _, realm = UnitName("player")
                charRealm = charRealm .. "-" .. (realm or GetRealmName()):gsub("%s+", "")
            end
            if charRealm then
                local command = "/trp3 open " .. charRealm
                ChatFrameUtil.OpenChat(command)
                addon:Print("Press |cff00ff00Enter|r to open the TRP3 profile.")
            end
        end
    end)
    win.trp3Btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Open TRP3", 1, 1, 1)
        GameTooltip:AddLine("Click to open Total RP3 profile for this character.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    win.trp3Btn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)

    -- GInvite Button
    win.ginviteBtn = CreateFrame("Button", nil, win)
    win.ginviteBtn:SetPoint("LEFT", win.trp3Btn, "RIGHT", 4, 0)
    win.ginviteBtn:SetSize(20, 20)
    win.ginviteBtn:SetNormalTexture("Interface\\Buttons\\UI-GuildButton-MemberNote-Up")
    win.ginviteBtn:SetPushedTexture("Interface\\Buttons\\UI-GuildButton-MemberNote-Down")
    win.ginviteBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    win.ginviteBtn:SetFrameLevel(baseLevel + 49)
    win.ginviteBtn:Hide()

    win.ginviteBtn:SetScript("OnClick", function(self)
        if addon.settings and addon.settings.enableGinviteButton then
            local charName = win.playerTarget
            if charName then
                local command = "/ginvite " .. charName
                ChatFrameUtil.OpenChat(command)
                addon:Print("Press |cff00ff00Enter|r to send the guild invite.")
            end
        end
    end)
    win.ginviteBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Send Guild Invite", 1, 1, 1)
        GameTooltip:AddLine("Click to send a guild invite to this player.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    win.ginviteBtn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)

    -- Close Button
    win.closeBtn = CreateFrame("Button", nil, win, "UIPanelCloseButton")
    win.closeBtn:SetPoint("TOPRIGHT", -2, -2)
    win.closeBtn:SetSize(24, 24)
    win.closeBtn:SetFrameLevel(baseLevel + 50)
    win.closeBtn:SetScript("OnClick", function(self) win:Hide() end)
    
    -- Resize Button
    win.resizeBtn = CreateFrame("Button", nil, win)
    win.resizeBtn:SetSize(16, 16)
    win.resizeBtn:SetPoint("BOTTOMRIGHT")
    win.resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    win.resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    win.resizeBtn:SetFrameLevel(baseLevel + 48)
    win.resizeBtn:SetScript("OnMouseDown", function()
        win:StartSizing("BOTTOMRIGHT")
        addon:FocusWindow(win)
    end)
    win.resizeBtn:SetScript("OnMouseUp", function()
        win:StopMovingOrSizing()
        addon:SaveWindowPosition(win, true)
    end)

    -- Update visibility based on settings
    if addon.settings and addon.settings.enableTRP3Button then win.trp3Btn:Show() end
    if addon.settings and addon.settings.enableGinviteButton then win.ginviteBtn:Show() end
end

local function CreateHistoryFrame(win)
    win.History = CreateFrame("ScrollingMessageFrame", nil, win)
    win.History:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -40)
    win.History:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -12, 12)
    win.History:SetMaxLines(addon.MAX_HISTORY_LINES)
    win.History:SetFading(false)
    
    local messageFontPath = addon:GetSetting("fontFamily") or "Fonts\\FRIZQT__.TTF"
    local messageSize = addon:GetSetting("messageFontSize") or 14
    local _, _, messageFlags = ChatFontNormal:GetFont()
    win.History:SetFont(messageFontPath, messageSize, messageFlags or "")
    win.History:SetJustifyH("LEFT")
    win.History:SetHyperlinksEnabled(true)
    win.History:EnableMouse(true)
    win.History:SetMouseMotionEnabled(true)
    win.History:SetMouseClickEnabled(true)
    win.History:EnableMouseWheel(true)
    
    win.History:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then self:ScrollUp() else self:ScrollDown() end
    end)
    
    win.History:SetScript("OnHyperlinkClick", function(self, link, text, button)
        addon:DebugMessage("Hyperlink clicked in window:", link, text, button)
        
        local type, value = link:match("(%a+):(.+)")
        local isChatFilter = (type == "chatfilter" and value and value:match("^censoredmessage"))
        local isCensoredMessage = (link:match("^censoredmessage"))
        
        if isChatFilter or isCensoredMessage then
             local lineID
             if isChatFilter then
                 local _, id = strsplit(":", value)
                 lineID = tonumber(id)
             else
                 local _, id = strsplit(":", link)
                 lineID = tonumber(id)
             end
             
             if lineID then
                 C_ChatInfo.UncensorChatLine(lineID)
                 local newText = C_ChatInfo.GetChatLineText(lineID)
                 if newText and newText ~= "" then
                     if WhisperManager_HistoryDB and WhisperManager_HistoryDB[win.playerKey] then
                         local history = WhisperManager_HistoryDB[win.playerKey]
                         for i = #history, 1, -1 do
                             if history[i].m and history[i].m:find(link, 1, true) then
                                 history[i].m = newText
                                 break
                             end
                         end
                         addon:DisplayHistory(win, win.playerKey)
                     end
                 else
                     addon:Print("Unable to reveal message: The original text is no longer in the game memory (session expired).")
                 end
             end
             return
        end
        SetItemRef(link, text, button, self)
    end)
    
    win.History:SetScript("OnHyperlinkEnter", function(self, link, text, button)
        ShowUIPanel(GameTooltip)
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetHyperlink(link)
        GameTooltip:Show()
    end)
    win.History:SetScript("OnHyperlinkLeave", function(self) HideUIPanel(GameTooltip) end)
end

function addon:FocusWindow(window)
    if not window then return end

    self:EnsureFrameOverlay(window)
    
    if InCombatLockdown() then
        self:DebugMessage("In combat - skipping FocusWindow")
        return
    end
    
    if window.playerKey and WhisperManager_Config and WhisperManager_Config.windowPositions then
        local pos = WhisperManager_Config.windowPositions[window.playerKey]
        if pos then pos.lastFocus = time() end
    end
    
    for _, win in pairs(self.windows) do
        if win ~= window and win:IsShown() then
            win:SetAlpha(self.UNFOCUSED_ALPHA)
        end
    end
    
    window:SetAlpha(self.FOCUSED_ALPHA)
    self.nextFrameLevel = self.nextFrameLevel + 100
    
    if self.nextFrameLevel > 9000 then
        self:DebugMessage("Frame level counter exceeded 9000, resetting to base level")
        self.nextFrameLevel = 1000
    end
    
    UpdateWindowFrameLevels(window, self.nextFrameLevel)
    window:Raise()
end

function addon:OpenConversation(playerName)
    if self.__closingWindow then return false end
    
    self:DebugMessage("OpenConversation called for:", playerName)
    local playerKey, playerTarget, displayName = self:ResolvePlayerIdentifiers(playerName)
    if not playerKey then
        self:DebugMessage("|cffff0000ERROR: Unable to resolve player identifiers for|r", playerName)
        return false
    end

    displayName = self:GetDisplayNameFromKey(playerKey)
    local win = self.windows[playerKey]
    
    if InCombatLockdown() then
        self:DebugMessage("In combat - blocking whisper window open")
        return false
    end
    
    if not win then
        win = self:CreateWindow(playerKey, playerTarget, displayName, false)
        if not win then return false end
        self.windows[playerKey] = win
    else
        win.playerTarget = playerTarget
        win.displayName = displayName
        win.playerKey = playerKey
    end

    for _, otherWin in pairs(self.windows) do
        if otherWin and otherWin ~= win and otherWin:IsShown() then
            otherWin:Hide()
        end
    end

    self:DisplayHistory(win, playerKey)
    if win.title then win.title:SetText("Whisper: " .. (displayName or playerTarget)) end
    self:LoadWindowPosition(win)
    win:Show()

    self:FocusWindow(win)
    self:UpdateRecentChat(playerKey, displayName, false)
    return true
end

function addon:OpenBNetConversation(bnSenderID, displayName)
    self:DebugMessage("OpenBNetConversation called for BNet ID:", bnSenderID)
    
    local accountInfo = C_BattleNet.GetAccountInfoByID(bnSenderID)
    if not accountInfo or not accountInfo.battleTag then
        self:DebugMessage("|cffff0000ERROR: Could not get BattleTag for BNet ID:|r", bnSenderID)
        return false
    end
    
    local playerKey = "bnet_" .. accountInfo.battleTag
    displayName = accountInfo.accountName or displayName or accountInfo.battleTag
    local win = self.windows[playerKey]
    
    if InCombatLockdown() then
        self:DebugMessage("In combat - blocking BNet whisper window open")
        return false
    end
    
    if not win then
        win = self:CreateWindow(playerKey, bnSenderID, displayName, true)
        if not win then return false end
        self.windows[playerKey] = win
    else
        win.bnSenderID = bnSenderID
        win.displayName = displayName
        win.playerKey = playerKey
    end

    for _, otherWin in pairs(self.windows) do
        if otherWin and otherWin ~= win and otherWin:IsShown() then
            otherWin:Hide()
        end
    end
    
    self:DisplayHistory(win, playerKey)
    if win.title then win.title:SetText("BNet: " .. displayName) end
    self:LoadWindowPosition(win)
    win:Show()
    self:FocusWindow(win)
    self:UpdateRecentChat(playerKey, displayName, true)
    return true
end

function addon:ShowWindow(playerKey, displayName)
    if playerKey:match("^bnet_") then
        local battleTag = playerKey:match("bnet_(.+)")
        if battleTag then
            local numBNetTotal = BNGetNumFriends()
            for i = 1, numBNetTotal do
                local accountInfo = C_BattleNet.GetFriendAccountInfo(i)
                if accountInfo and accountInfo.battleTag == battleTag then
                    return self:OpenBNetConversation(accountInfo.bnetAccountID, displayName)
                end
            end
        end
    else
        return self:OpenConversation(playerKey)
    end
    return false
end

function addon:CreateWindow(playerKey, playerTarget, displayName, isBNet)
    if self.windows[playerKey] then return self.windows[playerKey] end

    local frameName = "WhisperManager_Window_" .. playerKey:gsub("[^%w]", "")
    local win = CreateFrame("Frame", frameName, addon:GetOverlayParent(), "BackdropTemplate")
    
    local defaultWidth = addon:GetSetting("defaultWindowWidth") or 340
    local defaultHeight = addon:GetSetting("defaultWindowHeight") or 200
    win:SetSize(defaultWidth, defaultHeight)
    
    win:SetPoint("CENTER")
    win:SetFrameStrata("DIALOG")
    win:SetMovable(true)
    win:SetResizable(true)
    win:SetResizeBounds(250, 100, 800, 600)
    win:EnableMouse(true)
    win:SetToplevel(true)
    win:RegisterForDrag("LeftButton")
    
    win.playerKey = playerKey
    win.playerTarget = playerTarget
    win.displayName = displayName
    win.isBNet = isBNet or false
    if isBNet then win.bnSenderID = playerTarget end
    
    win:SetScript("OnDragStart", function(self)
        self:StartMoving()
        addon:FocusWindow(self)
    end)
    win:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        addon:SaveWindowPosition(self, false)
        UpdateWindowFrameLevels(self, addon.nextFrameLevel)
    end)
    
    win:SetScript("OnMouseDown", function(self, button)
        if self.History and MouseIsOver(self.History) then return end
        addon:FocusWindow(self)
        if self.playerKey then addon:MarkChatAsRead(self.playerKey) end
    end)
    
    win:SetScript("OnHide", function(self)
        addon:SaveWindowPosition(self, false)
        if not InCombatLockdown() then
            for _, w in pairs(addon.windows) do
                if w:IsShown() and w ~= self then
                    addon:FocusWindow(w)
                    break
                end
            end
        end
    end)
    
    win:SetScript("OnShow", function(self)
        addon:EnsureFrameOverlay(self)
        addon:LoadWindowPosition(self)
        addon:FocusWindow(self)
        if self.playerKey then addon:MarkChatAsRead(self.playerKey) end
        UpdateWindowFrameLevels(self, addon.nextFrameLevel)
    end)
    
    win:SetScript("OnSizeChanged", function(self) UpdateWindowFrameLevels(self, addon.nextFrameLevel) end)
    local origSetSize = win.SetSize
    win.SetSize = function(self, ...)
        origSetSize(self, ...)
        UpdateWindowFrameLevels(self, addon.nextFrameLevel)
    end
    
    win:SetScript("OnEnter", function(self)
        if self.playerKey then addon:MarkChatAsRead(self.playerKey) end
    end)
    
    win:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    win:SetBackdropColor(0, 0, 0, 0.9)
    win:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    win:Hide()
    
    addon.nextFrameLevel = (addon.nextFrameLevel or 1000) + 100
    local baseLevel = addon.nextFrameLevel
    
    -- Initialize Components
    CreateTitleBar(win, displayName, baseLevel)
    CreateButtons(win, baseLevel)
    CreateHistoryFrame(win)
    
    -- Hook up button visibility updates on show
    local function UpdateLevelsOnShow() UpdateWindowFrameLevels(win, addon.nextFrameLevel) end
    if win.closeBtn then win.closeBtn:SetScript("OnShow", UpdateLevelsOnShow) end
    if win.copyBtn then win.copyBtn:SetScript("OnShow", UpdateLevelsOnShow) end
    if win.resizeBtn then win.resizeBtn:SetScript("OnShow", UpdateLevelsOnShow) end

    self.windows[playerKey] = win
    addon:LoadWindowPosition(win)
    addon:LoadWindowHistory(win)
    
    UpdateWindowFrameLevels(win, baseLevel)
    
    return win
end

function addon:LoadWindowHistory(win)
    if not win or not win.History then return end
    
    local playerKey = win.playerKey
    win.History:Clear()
    win.lastMessageTimestamp = nil
    win.lastMessageHasSeparator = false
    
    if not WhisperManager_HistoryDB or not WhisperManager_HistoryDB[playerKey] then
        win.History:AddMessage("No message history found.")
        return
    end
    
    local history = WhisperManager_HistoryDB[playerKey]
    
    for i, entry in ipairs(history) do
        local timestamp = entry.t or entry.timestamp
        local author = entry.a or entry.author
        local message = entry.m or entry.message
        local classToken = entry.c
        
        if timestamp and author and message then
            local formattedMessage = FormatMessageForDisplay(win, author, message, timestamp, classToken)
            win.History:AddMessage(formattedMessage)
            
            -- Check for divider AFTER this message
            local nextEntry = history[i+1]
            local showDivider = false
            
            if nextEntry then
                local nextTimestamp = nextEntry.t or nextEntry.timestamp
                if GetDayKey(timestamp) ~= GetDayKey(nextTimestamp) then
                    showDivider = true
                end
            else
                -- Last message: show divider if older than 6 hours
                if (time() - timestamp) > (6 * 3600) then
                    showDivider = true
                end
            end
            
            if showDivider then
                AddDateFooter(win, timestamp)
                win.lastMessageHasSeparator = true
            else
                win.lastMessageHasSeparator = false
            end
            
            win.lastMessageTimestamp = timestamp
        end
    end
    C_Timer.After(0, function() win.History:ScrollToBottom() end)
end

function addon:AddMessageToWindow(playerKey, author, message, timestamp)
    local win = self.windows[playerKey]
    if not win or not win.History then return end
    
    local isBNet = playerKey:match("^bnet_") ~= nil
    local playerName, playerRealm = UnitName("player")
    local realm = (playerRealm or GetRealmName()):gsub("%s+", "")
    local fullPlayerName = playerName .. "-" .. realm
    
    local classToken = nil
    if not isBNet and author ~= "Me" and author ~= playerName and author ~= fullPlayerName then
        local history = WhisperManager_HistoryDB[playerKey]
        if history and #history > 0 then
            classToken = history[#history].c
        end
    end
    
    -- Check if we need to add a divider for the PREVIOUS message
    if win.lastMessageTimestamp then
        if GetDayKey(win.lastMessageTimestamp) ~= GetDayKey(timestamp) then
             if not win.lastMessageHasSeparator then
                 AddDateFooter(win, win.lastMessageTimestamp)
                 win.lastMessageHasSeparator = true
             end
        else
             -- Same day, so no separator should be here.
             -- If one exists (e.g. from >6h rule), we leave it as a session break.
             win.lastMessageHasSeparator = false
        end
    end
    
    local formattedMessage = FormatMessageForDisplay(win, author, message, timestamp, classToken)
    win.History:AddMessage(formattedMessage)
    
    win.lastMessageTimestamp = timestamp
    win.lastMessageHasSeparator = false
    
    C_Timer.After(0, function()
        if win.History then win.History:ScrollToBottom() end
    end)
end

function addon:SaveWindowPosition(window, saveSize)
    if not addon:IsSafeToOperate() then return end
    if InCombatLockdown() then return end
    if not window then return end
    
    -- Initialize session storage if needed
    if not addon.sessionWindowSizes then addon.sessionWindowSizes = {} end

    local playerKey = window.playerKey
    local width, height = window:GetSize()

    -- Save size to session storage only if explicitly requested
    if saveSize then
        addon.sessionWindowSizes[playerKey] = {
            width = width,
            height = height
        }
    end
end

function addon:LoadWindowPosition(window)
    if not window then return end
    
    local playerKey = window.playerKey
    local spawnX = addon:GetSetting("spawnAnchorX") or 0
    local spawnY = addon:GetSetting("spawnAnchorY") or 200
    window:ClearAllPoints()
    window:SetPoint("CENTER", addon:GetOverlayParent(), "CENTER", spawnX, spawnY)

    -- 2. Restore Size (Session > Default)
    local width, height
    
    -- Check session storage first
    if addon.sessionWindowSizes and addon.sessionWindowSizes[playerKey] then
        width = addon.sessionWindowSizes[playerKey].width
        height = addon.sessionWindowSizes[playerKey].height
    else
        -- Fallback to default settings
        width = addon:GetSetting("defaultWindowWidth") or 340
        height = addon:GetSetting("defaultWindowHeight") or 200
    end
    
    if width and height then
        window:SetSize(width, height)
    end
end

function addon:CloseWindow(playerKey)
    local win = self.windows[playerKey]
    if win then
        win:Hide()
        return true
    end
    return false
end

function addon:CloseAllWindows()
    local closed = 0
    for _, win in pairs(self.windows) do
        if win:IsShown() then
            win:Hide()
            closed = closed + 1
        end
    end
    return closed > 0
end

-- Chat Utilities
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

function addon:FormatEmotesAndSpeech(message)
    if not message or message == "" then return message end
    local emoteColor = ChatTypeInfo["EMOTE"]
    local emoteHex = string.format("|cff%02x%02x%02x", emoteColor.r * 255, emoteColor.g * 255, emoteColor.b * 255)
    local sayColor = ChatTypeInfo["SAY"]
    local sayHex = string.format("|cff%02x%02x%02x", sayColor.r * 255, sayColor.g * 255, sayColor.b * 255)
    local oocHex = "|cff888888"
    message = message:gsub("(%*[^%*|]+%*)", function(emote) return emoteHex .. emote .. "|r" end)
    message = message:gsub('("[^"|]+")' , function(speech) return sayHex .. speech .. "|r" end)
    message = message:gsub("(%(%(.-%)%))", function(ooc) return oocHex .. ooc .. "|r" end)
    message = message:gsub("(%(.-%))", function(ooc) return oocHex .. ooc .. "|r" end)
    return message
end

function addon:TriggerTaskbarAlert()
    FlashClientIcon()
end

function addon:StopTaskbarAlert()
    -- FlashClientIcon stops automatically when the client is focused
end

-- Chat Event Handlers
local function ChatMessageEventFilter(self, event, msg, ...)
    -- Don't filter our own frames (History display)
    if self and self._WhisperManager then
        return false
    end
    -- We no longer suppress messages from the default chat frame.
    -- Always allow messages through.
    return false
end

function addon:RegisterChatEvents()
    -- Register chat message filters to suppress whispers handled by our windows
    -- Filtering of default chat is disabled per user request; do not register filters.
    -- ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_WHISPER", ChatMessageEventFilter)
    -- ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", ChatMessageEventFilter)
    -- ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_BN_WHISPER", ChatMessageEventFilter)
    -- ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_BN_WHISPER_INFORM", ChatMessageEventFilter)
    
    local eventFrame = CreateFrame("Frame")
    
    eventFrame:RegisterEvent("CHAT_MSG_WHISPER")
    eventFrame:RegisterEvent("CHAT_MSG_WHISPER_INFORM")
    eventFrame:RegisterEvent("CHAT_MSG_BN_WHISPER")
    eventFrame:RegisterEvent("CHAT_MSG_BN_WHISPER_INFORM")
    eventFrame:RegisterEvent("PLAYER_STARTED_MOVING")

    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "PLAYER_STARTED_MOVING" then
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

            if not addon:IsChatAutoHidden(playerKey) then
                addon:OpenConversation(author)
            end
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

            if not addon:IsChatAutoHidden(playerKey) then
                addon:OpenConversation(resolvedTarget)
            end
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

            if not addon:IsChatAutoHidden(playerKey) then
                addon:OpenBNetConversation(bnSenderID, displayName)
            end
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
            if not addon:IsChatAutoHidden(playerKey) then
                addon:OpenBNetConversation(bnSenderID, displayName)
            end
            local window = addon.windows[playerKey]
            if window then
                addon:DisplayHistory(window, playerKey)
            end
        end
    end)
end

-- URL Handling
local URL_PATTERNS = {
    -- X://Y url
    "^(%a[%w+.-]+://%S+)",
    "%f[%S](%a[%w+.-]+://%S+)",
    -- www.X.Y url
    "^(www%.[-%w_%%]+%.(%a%a+))",
    "%f[%S](www%.[-%w_%%]+%.(%a%a+))",
    -- X@Y.Z email
    "(%S+@[%w_.-%%]+%.(%a%a+))",
    -- XXX.YYY.ZZZ.WWW:VVVV/UUUUU IPv4 with port and path
    "^([0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d:[0-6]?%d?%d?%d?%d/%S+)",
    "%f[%S]([0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d:[0-6]?%d?%d?%d?%d/%S+)",
    -- XXX.YYY.ZZZ.WWW:VVVV IPv4 with port
    "^([0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d:[0-6]?%d?%d?%d?%d)%f[%D]",
    "%f[%S]([0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d:[0-6]?%d?%d?%d?%d)%f[%D]",
    -- X.Y.Z:WWWW/VVVVV url with port and path
    "^([%w_.-%%]+[%w_-%%]%.(%a%a+):[0-6]?%d?%d?%d?%d/%S+)",
    "%f[%S]([%w_.-%%]+[%w_-%%]%.(%a%a+):[0-6]?%d?%d?%d?%d/%S+)",
    -- X.Y.Z/WWWWW url with path
    "^([%w_.-%%]+[%w_-%%]%.(%a%a+)/%S+)",
    "%f[%S]([%w_.-%%]+[%w_-%%]%.(%a%a+)/%S+)",
    -- X.Y.Z url
    "^([-%w_%%]+%.[-%w_%%]+%.(%a%a+))",
    "%f[%S]([-%w_%%]+%.[-%w_%%]+%.(%a%a+))",
}

--- Format a URL as a clickable hyperlink
-- @param url string The URL to format
-- @return string Formatted hyperlink with cyan color
local function FormatURLAsLink(url)
    if not url or url == "" then return "" end
    -- Escape % characters
    url = url:gsub('%%', '%%%%')
    -- Create a clickable link with custom prefix
    return "|cff00ffff|Hwm_url:" .. url .. "|h[" .. url .. "]|h|r"
end

--- Convert URLs in text to clickable links
-- @param text string Text to process
-- @return string Text with URLs converted to hyperlinks
function addon:ConvertURLsToLinks(text)
    if not text or text == "" then return text end
    
    local result = text
    
    -- Process each pattern
    for _, pattern in ipairs(URL_PATTERNS) do
        result = result:gsub(pattern, FormatURLAsLink)
    end
    
    return result
end

--- Extract plain URL from hyperlink
-- @param link string Hyperlink string (e.g., "wm_url:http://example.com")
-- @return string|nil Plain URL or nil if extraction fails
local function ExtractURL(link)
    if type(link) ~= "string" then return nil end
    
    if link:match("^wm_url:(.+)") then
        return link:match("^wm_url:(.+)")
    end
    
    return nil
end

--- Handle URL hyperlink clicks
-- @param link string The hyperlink that was clicked
-- @param text string Link text (optional)
-- @param button string Mouse button used (optional)
-- @return boolean True if handled, false otherwise
function addon:HandleURLClick(link, text, button)
    addon:Print("HandleURLClick called with link: " .. tostring(link))
    
    local url = ExtractURL(link)
    addon:Print("Extracted URL: " .. tostring(url))
    
    if url then
        self:ShowURLCopyDialog(url)
        return true
    else
        addon:Print("|cffff0000Failed to extract URL from link|r")
    end
    return false
end

-- Hook into hyperlink system
local originalSetHyperlink = ItemRefTooltip.SetHyperlink
ItemRefTooltip.SetHyperlink = function(self, link, ...)
    if link and link:match("^wm_url:") then
        addon:Print("SetHyperlink intercepted wm_url link")
        addon:HandleURLClick(link)
        return
    end
    return originalSetHyperlink(self, link, ...)
end

-- Register custom hyperlink handler
if SetItemRef then
    hooksecurefunc("SetItemRef", function(link, text, button, chatFrame)
        if link and link:match("^wm_url:") then
            addon:Print("SetItemRef intercepted wm_url link")
            addon:HandleURLClick(link, text, button)
        end
    end)
end
