-- Modules/chat.lua - active window implementation renamed to chat.lua

local addon = WhisperManager

-- Note: Combat Lockdown Queue (addon.combatQueue) is defined in Core.lua
-- All window operations use the shared queue managed there

-- Helper Functions
-- ============================================================================

-- Helper function to update all child frame levels relative to the parent window
local function UpdateWindowFrameLevels(win, baseLevel)
    addon:DebugMessage("UpdateWindowFrameLevels fired for window: " .. tostring(win:GetName() or "<unnamed>") .. " baseLevel=" .. tostring(baseLevel))
    win:SetFrameLevel(baseLevel)
    addon:DebugMessage("  FrameLevel set for main window: " .. tostring(win:GetName()) .. " = " .. tostring(baseLevel))
    if win.titleBar then
        win.titleBar:SetFrameLevel(baseLevel + 1)
        addon:DebugMessage("  FrameLevel set for titleBar: " .. tostring(baseLevel + 1))
    end
    if win.History then
        win.History:SetFrameLevel(baseLevel + 10)
        addon:DebugMessage("  FrameLevel set for History: " .. tostring(baseLevel + 10))
    end
    if win.InputContainer then
        win.InputContainer:SetFrameLevel(baseLevel + 5)
        addon:DebugMessage("  FrameLevel set for InputContainer: " .. tostring(baseLevel + 5))
    end
    if win.Input then
        win.Input:SetFrameLevel(baseLevel + 6)
        addon:DebugMessage("  FrameLevel set for Input: " .. tostring(baseLevel + 6))
    end
    if win.closeBtn then
        win.closeBtn:SetFrameLevel(baseLevel + 50)
        addon:DebugMessage("  FrameLevel set for closeBtn: " .. tostring(baseLevel + 50))
    end
    if win.copyBtn then
        win.copyBtn:SetFrameLevel(baseLevel + 49)
        addon:DebugMessage("  FrameLevel set for copyBtn: " .. tostring(baseLevel + 49))
    end
    if win.resizeBtn then
        win.resizeBtn:SetFrameLevel(baseLevel + 48)
        addon:DebugMessage("  FrameLevel set for resizeBtn: " .. tostring(baseLevel + 48))
    end
end

-- Helper function to update input container height dynamically
local function UpdateInputHeight(inputBox)
    if not inputBox or not inputBox:IsVisible() then return end
    
    local container = inputBox:GetParent()
    if not container then return end
    
    C_Timer.After(0, function()
        if not inputBox:IsVisible() then return end
        local text = inputBox:GetText() or ""
        local font, fontSize, flags = inputBox:GetFont()
        fontSize = fontSize or 14

        -- Dynamic top/bottom padding based on font size (minimum 7px)
        local topBottomPadding = math.max(7, math.floor(fontSize / 2))

        local minInputHeight = math.ceil(fontSize) + 4
        local minContainerHeight = minInputHeight + (2 * topBottomPadding)

            if text == "" then
                -- Empty text: size container to minimum and anchor the editbox to fill with padding
                container:SetHeight(minContainerHeight)
                inputBox.__wm_topBottomPadding = topBottomPadding
                inputBox:ClearAllPoints()
                inputBox:SetPoint("TOPLEFT", container, "TOPLEFT", 8, -topBottomPadding)
                inputBox:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -8, topBottomPadding)
                return
        end

        -- Create a hidden FontString for measurement if it doesn't exist
        if not inputBox.measureString then
            inputBox.measureString = inputBox:CreateFontString(nil, "OVERLAY")
            inputBox.measureString:Hide()
        end

        -- Get the actual width available for text and measure
        local left, right = inputBox:GetTextInsets()
        local usableWidth = inputBox:GetWidth()
        if left and right then
            usableWidth = usableWidth - left - right
        end
        if usableWidth <= 0 then usableWidth = 100 end

        inputBox.measureString:SetFont(font, fontSize, flags)
        inputBox.measureString:SetWidth(usableWidth)
        inputBox.measureString:SetText(text)

        local measuredLineHeight = inputBox.measureString:GetLineHeight()
        local lineHeight = math.max(measuredLineHeight or 0, fontSize)
        local numLines = inputBox.measureString:GetNumLines() or 1
        if numLines < 1 then numLines = 1 end

        local textHeight = math.ceil(numLines * lineHeight)

    -- Cap at reasonable max height (now 20 lines)
    local maxTextHeight = 20 * lineHeight
        if textHeight > maxTextHeight then textHeight = maxTextHeight end

        if textHeight < minInputHeight then textHeight = minInputHeight end

        local containerHeight = textHeight + (2 * topBottomPadding)
        if containerHeight < minContainerHeight then containerHeight = minContainerHeight end

            -- Size container and anchor the editbox to fill the internal area with symmetric padding
            container:SetHeight(containerHeight)
            inputBox.__wm_topBottomPadding = topBottomPadding
            inputBox:ClearAllPoints()
            inputBox:SetPoint("TOPLEFT", container, "TOPLEFT", 8, -topBottomPadding)
            inputBox:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -8, topBottomPadding)
    end)
end

-- ============================================================================
-- Window Focus Management
-- ============================================================================

function addon:FocusWindow(window)
    if not window then return end
    
    -- Queue operation if in combat
    if InCombatLockdown() then
        self:DebugMessage("In combat - queueing FocusWindow operation")
        table.insert(addon.combatQueue, function() addon:FocusWindow(window) end)
        return
    end
    
    -- Dim all other windows but don't change their frame levels
    for _, win in pairs(self.windows) do
        if win ~= window and win:IsShown() then
            win:SetAlpha(self.UNFOCUSED_ALPHA)
        end
    end
    
    -- Focus this window - bring to front with higher frame level
    window:SetAlpha(self.FOCUSED_ALPHA)
    
    -- Increment base level for this window and all its children
    -- Use smaller increments (100 instead of 200) to reduce frame level growth
    self.nextFrameLevel = self.nextFrameLevel + 100
    
    -- Reset frame level counter if it gets too high (WoW has a limit around 10,000)
    if self.nextFrameLevel > 9000 then
        self:DebugMessage("Frame level counter exceeded 9000, resetting to base level")
        self.nextFrameLevel = 1000
    end
    
    UpdateWindowFrameLevels(window, self.nextFrameLevel)
    
    window:Raise()
end

-- ============================================================================
-- Conversation Opening
-- ============================================================================

function addon:OpenConversation(playerName)
    -- Don't open conversations if we're closing windows
    if self.__closingWindow then
        self:DebugMessage("OpenConversation blocked - window closing in progress")
        return false
    end
    
    self:DebugMessage("OpenConversation called for:", playerName)
    local playerKey, playerTarget, displayName = self:ResolvePlayerIdentifiers(playerName)
    if not playerKey then
        self:DebugMessage("|cffff0000ERROR: Unable to resolve player identifiers for|r", playerName)
        return false
    end

    displayName = self:GetDisplayNameFromKey(playerKey)

    local win = self.windows[playerKey]
    
    -- If window doesn't exist and we're in combat, queue the creation
    if not win and InCombatLockdown() then
        self:DebugMessage("In combat - queueing window creation (messages will display after combat)")
        self:Print("|cffff8800Cannot open new whisper window while in combat. Will open after combat ends.|r")
        table.insert(addon.combatQueue, function() addon:OpenConversation(playerName) end)
        return true  -- Return true since we successfully queued the operation
    end
    
    if not win then
        self:DebugMessage("No existing window. Calling CreateWindow.")
        win = self:CreateWindow(playerKey, playerTarget, displayName, false)
        if not win then 
            self:DebugMessage("|cffff0000ERROR: CreateWindow failed to return a window.|r")
            return false 
        end
        self.windows[playerKey] = win
    else
        -- Window exists - update it (works even in combat)
        win.playerTarget = playerTarget
        win.displayName = displayName
        win.playerKey = playerKey
    end

    -- Update display (works in combat for existing windows)
    self:DisplayHistory(win, playerKey)
    if win.title then
        win.title:SetText("Whisper: " .. (displayName or playerTarget))
    end
    self:LoadWindowPosition(win)
    win:Show()
    
    -- Focus window (will queue strata changes if in combat)
    self:FocusWindow(win)
    -- Don't auto-focus input - let user click to focus
    
    -- Mark as read and update recent chats
    self:UpdateRecentChat(playerKey, displayName, false)
    
    return true
end

function addon:OpenBNetConversation(bnSenderID, displayName)
    self:DebugMessage("OpenBNetConversation called for BNet ID:", bnSenderID)
    
    -- Get account info to retrieve BattleTag (permanent identifier)
    local accountInfo = C_BattleNet.GetAccountInfoByID(bnSenderID)
    if not accountInfo or not accountInfo.battleTag then
        self:DebugMessage("|cffff0000ERROR: Could not get BattleTag for BNet ID:|r", bnSenderID)
        return false
    end
    
    -- Use BattleTag as the permanent key (e.g., "bnet_Name#1234")
    local playerKey = "bnet_" .. accountInfo.battleTag
    displayName = accountInfo.accountName or displayName or accountInfo.battleTag
    
    local win = self.windows[playerKey]
    
    -- If window doesn't exist and we're in combat, queue the creation
    if not win and InCombatLockdown() then
        self:DebugMessage("In combat - queueing BNet window creation (messages will display after combat)")
        self:Print("|cffff8800Cannot open new whisper window while in combat. Will open after combat ends.|r")
        table.insert(addon.combatQueue, function() addon:OpenBNetConversation(bnSenderID, displayName) end)
        return true  -- Return true since we successfully queued the operation
    end
    
    if not win then
        self:DebugMessage("No existing BNet window. Calling CreateWindow.")
        win = self:CreateWindow(playerKey, bnSenderID, displayName, true)
        if not win then
            self:DebugMessage("|cffff0000ERROR: CreateWindow failed to return a BNet window.|r")
            return false
        end
        self.windows[playerKey] = win
    else
        -- Update the current session's BNet ID (it may have changed)
        win.bnSenderID = bnSenderID
        win.displayName = displayName
        win.playerKey = playerKey
    end
    
    self:DisplayHistory(win, playerKey)
    if win.title then
        win.title:SetText("BNet Whisper: " .. displayName)
    end
    self:LoadWindowPosition(win)
    win:Show()
    self:FocusWindow(win)
    -- Don't auto-focus input - let user click to focus
    
    -- Mark as read and update recent chats
    self:UpdateRecentChat(playerKey, displayName, true)
    
    return true
end

-- ============================================================================
-- Backward Compatibility
-- ============================================================================

-- ShowWindow is deprecated - use OpenConversation instead
function addon:ShowWindow(playerKey, displayName)
    if playerKey:match("^bnet_") then
        -- Extract BattleTag and find corresponding BNet ID
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

-- ============================================================================
-- Window Creation (Mirroring HistoryViewer.lua)
-- ============================================================================

function addon:CreateWindow(playerKey, playerTarget, displayName, isBNet)
    -- Return existing window if it exists
    if self.windows[playerKey] then
        return self.windows[playerKey]
    end
    
    -- Create new window
    local frameName = "WhisperManager_Window_" .. playerKey:gsub("[^%w]", "")
    local win = CreateFrame("Frame", frameName, UIParent, "BackdropTemplate")
    win:SetSize(400, 300)
    win:SetPoint("CENTER")
    win:SetFrameStrata("DIALOG")
    win:SetMovable(true)
    win:SetResizable(true)
    win:SetResizeBounds(250, 200, 800, 600)
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    
    -- Store metadata
    win.playerKey = playerKey
    win.playerTarget = playerTarget
    win.displayName = displayName
    win.isBNet = isBNet or false
    if isBNet then
        win.bnSenderID = playerTarget  -- For BNet, playerTarget is the bnSenderID
    end
    
    win:SetScript("OnDragStart", function(self)
        self:StartMoving()
        addon:FocusWindow(self)
    end)
    win:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        addon:SaveWindowPosition(self)
        UpdateWindowFrameLevels(self, addon.nextFrameLevel)
    end)
    
    -- Focus window on mouse down, but don't consume clicks meant for History frame
    -- WCheck if mouse is over history frame first
    win:SetScript("OnMouseDown", function(self, button)
        -- Don't handle clicks when mouse is over the history frame
        -- Let the history frame handle its own mouse events (higher strata/level)
        if self.History and MouseIsOver(self.History) then
            return
        end
        addon:FocusWindow(self)
        
        -- Mark messages as read when window is focused
        if self.playerKey then
            addon:MarkChatAsRead(self.playerKey)
        end
    end)
    
    win:SetScript("OnHide", function(self)
        -- Hide input container when window is hidden
        if self.InputContainer then
            self.InputContainer:Hide()
        end
        
        addon:SaveWindowPosition(self)
        
        -- Refocus another visible window if one exists (skip if in combat)
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
        -- Show and position input container when window is shown
        if self.InputContainer then
            self.InputContainer:Show()
            self.InputContainer:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, 1)
            self.InputContainer:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, 1)
        end
        addon:LoadWindowPosition(self)
        -- Don't auto-focus input - let user click to focus
        -- Focus this window when shown
        addon:FocusWindow(self)
        -- Mark messages as read when window is shown/focused
        if self.playerKey then
            addon:MarkChatAsRead(self.playerKey)
        end
        -- Reapply frame levels to ensure correct layering
        UpdateWindowFrameLevels(self, addon.nextFrameLevel)
    end)
    -- Reapply frame levels after window resize
    win:SetScript("OnSizeChanged", function(self)
        UpdateWindowFrameLevels(self, addon.nextFrameLevel)
    end)
    -- Also reapply frame levels after SetSize is called directly
    local origSetSize = win.SetSize
    win.SetSize = function(self, ...)
        origSetSize(self, ...)
        UpdateWindowFrameLevels(self, addon.nextFrameLevel)
    end

    -- Reapply frame levels after showing/hiding key child frames
    if win.closeBtn then
        win.closeBtn:SetScript("OnShow", function(self)
            UpdateWindowFrameLevels(win, addon.nextFrameLevel)
        end)
    end
    if win.copyBtn then
        win.copyBtn:SetScript("OnShow", function(self)
            UpdateWindowFrameLevels(win, addon.nextFrameLevel)
        end)
    end
    if win.resizeBtn then
        win.resizeBtn:SetScript("OnShow", function(self)
            UpdateWindowFrameLevels(win, addon.nextFrameLevel)
        end)
    end
    if win.InputContainer then
        win.InputContainer:SetScript("OnShow", function(self)
            UpdateWindowFrameLevels(win, addon.nextFrameLevel)
        end)
    end
    
    -- Mark messages as read when mouse enters the window
    win:SetScript("OnEnter", function(self)
        if self.playerKey then
            addon:MarkChatAsRead(self.playerKey)
        end
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
    
    -- Assign unique frame level for proper stacking
    -- Use smaller increments so levels don't grow too fast
    addon.nextFrameLevel = (addon.nextFrameLevel or 1000) + 100
    local baseLevel = addon.nextFrameLevel
    
    -- Title bar background
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
    
    -- Title (create on titleBar frame so it renders above the background)
    win.title = win.titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    win.title:SetPoint("TOP", win.titleBar, "TOP", 0, -7)
    win.title:SetText(displayName)
    
    -- Copy Chat button (left side of title bar)
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
    win.copyBtn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    -- TRP3 Button (to the right of Copy Chat History)
    win.trp3Btn = CreateFrame("Button", nil, win)
    win.trp3Btn:SetPoint("LEFT", win.copyBtn, "RIGHT", 4, 0)
    win.trp3Btn:SetSize(20, 20)
    -- Use a note-like icon similar to the copy button
    win.trp3Btn:SetNormalTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
    win.trp3Btn:SetPushedTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Down")
    win.trp3Btn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    -- Match the copy button's frame level so both render and receive clicks consistently
    win.trp3Btn:SetFrameLevel(baseLevel + 49)
    win.trp3Btn:Hide() -- Hide by default
    addon:DebugMessage("TRP3 button icon set to note-style texture for window: " .. tostring(win:GetName()))

    win.trp3Btn:SetScript("OnClick", function(self)
        if addon.settings and addon.settings.enableTRP3Button then
            local charRealm = win.playerTarget
            if charRealm and not charRealm:find("-") then
                local _, realm = UnitName("player")
                charRealm = charRealm .. "-" .. (realm or GetRealmName()):gsub("%s+", "")
            end
            if charRealm then
                -- Try TRP3 API first
                if TRP3_API and TRP3_API.register then
                    if TRP3_API.register.openPageByUnitID then
                        TRP3_API.register.openPageByUnitID(charRealm)
                        return
                    elseif TRP3_API.register.openPage then
                        TRP3_API.register.openPage(charRealm)
                        return
                    end
                end
                -- Fallback: pre-fill and send the command in chat edit box
                local command = "/trp3 open " .. charRealm
                ChatFrame_OpenChat(command)
                C_Timer.After(0.1, function()
                    local editBox = ChatEdit_GetActiveWindow()
                    if editBox then
                        ChatEdit_SendText(editBox)
                    end
                end)
            end
        end
    end)
    win.trp3Btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Open TRP3", 1, 1, 1)
        GameTooltip:AddLine("Click to open Total RP3 profile for this character.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    win.trp3Btn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    -- Show/hide TRP3 button based on settings
    if addon.settings and addon.settings.enableTRP3Button then
        win.trp3Btn:Show()
    else
        win.trp3Btn:Hide()
    end
    
    -- Close button (UIPanelCloseButton template is available via Blizzard_ChatFrame dependency)
    win.closeBtn = CreateFrame("Button", nil, win, "UIPanelCloseButton")
    win.closeBtn:SetPoint("TOPRIGHT", -2, -2)
    win.closeBtn:SetSize(24, 24)
    win.closeBtn:SetFrameLevel(baseLevel + 50)
    
    -- Override the default OnClick (hiding existing frames is safe even in combat)
    win.closeBtn:SetScript("OnClick", function(self)
        win:Hide()
    end)
    
    -- Resize button
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
        addon:SaveWindowPosition(win)
    end)
    
    -- History ScrollingMessageFrame (now fills the entire window)
    win.History = CreateFrame("ScrollingMessageFrame", nil, win)
    win.History:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -40)
    win.History:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -12, 12)
    win.History:SetMaxLines(addon.MAX_HISTORY_LINES)
    win.History:SetFading(false)
    -- Apply font settings (with fallback)
    local messageFontPath = addon:GetSetting("fontFamily") or "Fonts\\FRIZQT__.TTF"
    local messageSize = addon:GetSetting("messageFontSize") or 14
    local _, _, messageFlags = ChatFontNormal:GetFont()
    win.History:SetFont(messageFontPath, messageSize, messageFlags or "")
    win.History:SetJustifyH("LEFT")
    win.History:SetHyperlinksEnabled(true)
    win.History:EnableMouse(true)
    win.History:SetMouseMotionEnabled(true)
    win.History:SetMouseClickEnabled(true)
    
    -- Frame level will be set by UpdateWindowFrameLevels
    
    -- Enable mouse wheel scrolling for history
    win.History:EnableMouseWheel(true)
    win.History:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then
            self:ScrollUp()
        else
            self:ScrollDown()
        end
    end)
    
    -- Hyperlink handlers: Use SetItemRef which properly integrates with other addons
    win.History:SetScript("OnHyperlinkClick", function(self, link, text, button)
        addon:DebugMessage("Hyperlink clicked in window:", link, text, button)
        -- Use SetItemRef which allows other addons to hook and modify behavior
        -- This is the standard WoW API for handling all hyperlink clicks
        SetItemRef(link, text, button, self)
    end)
    win.History:SetScript("OnHyperlinkEnter", function(self, link, text, button)
        ShowUIPanel(GameTooltip)
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetHyperlink(link)
        GameTooltip:Show()
    end)
    win.History:SetScript("OnHyperlinkLeave", function(self)
        HideUIPanel(GameTooltip)
    end)
    
    -- Input Container Frame (separate frame below main window)
    local frameName = "WhisperManager_Window_" .. playerKey:gsub("[^%w]", "")
    local containerName = frameName .. "InputContainer"
    win.InputContainer = CreateFrame("Frame", containerName, UIParent, "BackdropTemplate")
    win.InputContainer:SetPoint("TOPLEFT", win, "BOTTOMLEFT", 0, 1)  -- 1px offset to connect seamlessly
    win.InputContainer:SetPoint("TOPRIGHT", win, "BOTTOMRIGHT", 0, 1)
    win.InputContainer:SetFrameStrata("DIALOG")
    win.InputContainer:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    win.InputContainer:SetBackdropColor(0, 0, 0, 0.9)
    win.InputContainer:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
    
    -- Make input container move with window
    win.InputContainer:SetScript("OnShow", function(self)
        self:SetPoint("TOPLEFT", win, "BOTTOMLEFT", 0, 1)
        self:SetPoint("TOPRIGHT", win, "BOTTOMRIGHT", 0, 1)
    end)
    
    -- Input EditBox (inside the container)
    local inputName = frameName .. "Input"
    win.Input = CreateFrame("EditBox", inputName, win.InputContainer)
    -- Anchor will be adjusted after initial font/padding computation below
    win.Input:SetPoint("TOPLEFT", win.InputContainer, "TOPLEFT", 8, 0)
    win.Input:SetPoint("TOPRIGHT", win.InputContainer, "TOPRIGHT", -8, 0)
    win.Input:SetMultiLine(true)
    win.Input:SetAutoFocus(false)
    win.Input:SetHistoryLines(32)
    win.Input:SetMaxLetters(addon.CHAT_MAX_LETTERS)
    win.Input:SetAltArrowKeyMode(true)
    
    -- Set font properly for EditBox with settings (with fallback)
    local fontPath = addon:GetSetting("fontFamily") or "Fonts\\FRIZQT__.TTF"
    local inputSize = addon:GetSetting("inputFontSize") or 14
    local _, _, fontFlags = ChatFontNormal:GetFont()
    win.Input:SetFont(fontPath, inputSize, fontFlags or "")
    win.Input:SetTextColor(1, 1, 1, 1)
    
    -- Set initial height and container height based on font size
    local _, fontHeight = win.Input:GetFont()
    fontHeight = fontHeight or 14
    local topBottomPadding = math.max(7, math.floor(fontHeight / 2))
    local initialInputHeight = math.ceil(fontHeight) + 4
    local initialContainerHeight = initialInputHeight + (2 * topBottomPadding)
    win.Input:SetHeight(initialInputHeight)
    win.InputContainer:SetHeight(initialContainerHeight)
    win.Input.__wm_topBottomPadding = topBottomPadding
    -- Re-anchor input using computed padding so text is centered vertically inside the container
    win.Input:ClearAllPoints()
    win.Input:SetPoint("TOPLEFT", win.InputContainer, "TOPLEFT", 8, -topBottomPadding)
    win.Input:SetPoint("TOPRIGHT", win.InputContainer, "TOPRIGHT", -8, -topBottomPadding)
    
    win.Input:SetScript("OnHyperlinkLeave", function(self)
        HideUIPanel(GameTooltip)
    end)
    
    -- Focus window when clicking input box
    win.Input:SetScript("OnMouseDown", function(self)
        addon:FocusWindow(win)
    end)
    
    -- Character Count (positioned at top-right of input container)
    local inputCount = win.InputContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    local countYOffset = -math.max(4, math.floor((win.Input.__wm_topBottomPadding or 7) / 2))
    inputCount:SetPoint("TOPRIGHT", win.InputContainer, "TOPRIGHT", -8, countYOffset)
    inputCount:SetTextColor(0.6, 0.6, 0.6)
    inputCount:SetText("0/" .. addon.CHAT_MAX_LETTERS)

    -- Input Box Scripts
    win.Input:SetScript("OnEnterPressed", function(self)
        local message = self:GetText()
        if message and message ~= "" then
            if win.isBNet then
                -- Send BNet whisper
                BNSendWhisper(win.bnSenderID, message)
            else
                -- Send regular whisper
                SendChatMessage(message, "WHISPER", nil, win.playerTarget)
            end
            -- Don't manually add to history here - let the INFORM event handle it
            self:SetText("")
            UpdateInputHeight(self)  -- Reset height after sending
        end
    end)
    win.Input:SetScript("OnTextChanged", function(self)
        local len = self:GetNumLetters()
        inputCount:SetText(len .. "/" .. addon.CHAT_MAX_LETTERS)
        if len >= addon.CHAT_MAX_LETTERS - 15 then
            inputCount:SetTextColor(1.0, 0.3, 0.3)
        elseif len >= addon.CHAT_MAX_LETTERS - 50 then
            inputCount:SetTextColor(1.0, 0.82, 0)
        else
            inputCount:SetTextColor(0.6, 0.6, 0.6)
        end
        
        -- Update input height dynamically as user types
        UpdateInputHeight(self)
    end)
    win.Input:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        -- Hide the window frame (safe even in combat for existing frames)
        if win and win.Hide then
            win:Hide()
        end
    end)
    
    -- Also update height when the window is resized
    win.Input:SetScript("OnSizeChanged", function(self)
        UpdateInputHeight(self)
    end)
    
    -- Misspelled addon integration
    if _G.Misspelled and _G.Misspelled.WireUpEditBox then
        _G.Misspelled:WireUpEditBox(win.Input)
        self:DebugMessage("Misspelled integration enabled for EditBox")
    end
    
    -- Store window and load history
    self.windows[playerKey] = win
    addon:LoadWindowPosition(win)
    addon:LoadWindowHistory(win)
    
    -- Final frame level update to ensure all UI elements are properly layered
    UpdateWindowFrameLevels(win, baseLevel)
    
    return win
end

-- ============================================================================
-- Window History Management
-- ============================================================================

function addon:LoadWindowHistory(win)
    if not win or not win.History then return end
    
    local playerKey = win.playerKey
    local displayName = win.displayName
    
    win.History:Clear()
    
    if not WhisperManager_HistoryDB or not WhisperManager_HistoryDB[playerKey] then
        win.History:AddMessage("No message history found.")
        return
    end
    
    local history = WhisperManager_HistoryDB[playerKey]
    local playerName, playerRealm = UnitName("player")
    local realm = (playerRealm or GetRealmName()):gsub("%s+", "")
    local fullPlayerName = playerName .. "-" .. realm
    
    -- Determine if this is a BNet conversation
    local isBNet = playerKey:match("^bnet_") ~= nil
    
    for _, entry in ipairs(history) do
        -- Support both old and new format
        local timestamp = entry.t or entry.timestamp
        local author = entry.a or entry.author
        local message = entry.m or entry.message
        local classToken = entry.c  -- Get stored class token
        
        if timestamp and author and message then
            -- Timestamp with customizable color
            local tsColor = self.settings.timestampColor or {r = 0.5, g = 0.5, b = 0.5}
            local tsColorHex = string.format("%02x%02x%02x", tsColor.r * 255, tsColor.g * 255, tsColor.b * 255)
            local timeString = "|cff" .. tsColorHex .. date("%H:%M", timestamp) .. "|r"
            
            local coloredAuthor
            local messageColor
            if author == "Me" or author == playerName or author == fullPlayerName then
                -- Use customizable send color for message text
                if isBNet then
                    local color = self.settings.bnetSendColor or {r = 0.0, g = 0.66, b = 1.0}
                    local colorHex = string.format("%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
                    messageColor = "|cff" .. colorHex
                else
                    local color = self.settings.whisperSendColor or {r = 1.0, g = 0.5, b = 1.0}
                    local colorHex = string.format("%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
                    messageColor = "|cff" .. colorHex
                end
                
                -- Use player's class color for name only, brackets use message color
                local _, playerClass = UnitClass("player")
                local classColor = playerClass and RAID_CLASS_COLORS[playerClass]
                local classColorHex
                if classColor then
                    classColorHex = string.format("%02x%02x%02x", classColor.r * 255, classColor.g * 255, classColor.b * 255)
                else
                    classColorHex = "ffd100"
                end
                -- Format: brackets in message color, name in class color
                coloredAuthor = string.format("|Hplayer:%s|h%s[|r|cff%s%s|r%s]:|h", fullPlayerName, messageColor, classColorHex, playerName, messageColor)
            else
                -- Color based on whisper type (receive)
                if isBNet then
                    -- Use the display name for BNet
                    local bnetDisplayName = displayName or author
                    -- For BNet, use a fixed color for the name (cyan) - BNet names aren't clickable in the same way
                    local color = self.settings.bnetReceiveColor or {r = 0.0, g = 0.66, b = 1.0}
                    local colorHex = string.format("%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
                    messageColor = "|cff" .. colorHex
                    coloredAuthor = "|TInterface\\ChatFrame\\UI-ChatIcon-Blizz:14:14:0:-1|t|cff00ddff" .. bnetDisplayName .. "|r"
                else
                    -- Use customizable receive color for whisper message text
                    local color = self.settings.whisperReceiveColor or {r = 1.0, g = 0.5, b = 1.0}
                    local colorHex = string.format("%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
                    messageColor = "|cff" .. colorHex
                    
                    -- Regular whispers: use stored class color if available, fallback to lookup then gold
                    -- Strip realm name from author (Name-Realm -> Name)
                    local authorDisplayName = author:match("^([^%-]+)") or author
                    local classColorHex
                    
                    -- Use stored class token (converted from numeric ID)
                    if classToken then
                        local classColor = RAID_CLASS_COLORS[classToken]
                        if classColor then
                            classColorHex = string.format("%02x%02x%02x", classColor.r * 255, classColor.g * 255, classColor.b * 255)
                        end
                    end
                    
                    local nameColorHex = classColorHex or "ffd100"  -- Class color or gold
                    -- Format: brackets in message color, name in class color
                    coloredAuthor = string.format("|Hplayer:%s|h%s[|r|cff%s%s|r%s]:|h", author, messageColor, nameColorHex, authorDisplayName, messageColor)
                end
            end
            
            -- CRITICAL: Don't use gsub on message - preserve hyperlinks as-is
            -- Apply emote and speech formatting (this function preserves hyperlinks)
            local formattedText = self:FormatEmotesAndSpeech(message)
            
            -- Format message - concatenate parts WITHOUT string.format to preserve hyperlinks
            -- Simple concatenation preserves all escape sequences
            local formattedMessage = timeString .. " " .. coloredAuthor .. " " .. messageColor .. formattedText .. "|r"
            win.History:AddMessage(formattedMessage)
        end
    end
    
    -- Scroll to bottom
    C_Timer.After(0, function()
        win.History:ScrollToBottom()
    end)
end

function addon:AddMessageToWindow(playerKey, author, message, timestamp)
    local win = self.windows[playerKey]
    if not win or not win.History then return end
    
    local displayName = win.displayName
    local playerName, playerRealm = UnitName("player")
    local realm = (playerRealm or GetRealmName()):gsub("%s+", "")
    local fullPlayerName = playerName .. "-" .. realm
    
    -- Determine if this is a BNet conversation
    local isBNet = playerKey:match("^bnet_") ~= nil
    
    -- Get class token if available (for non-BNet)
    local classToken = nil
    if not isBNet and author ~= "Me" and author ~= playerName and author ~= fullPlayerName then
        -- Try to get class token from recent history entry
        local history = WhisperManager_HistoryDB[playerKey]
        if history and #history > 0 then
            classToken = history[#history].c
        end
    end
    
    -- Timestamp with customizable color
    local tsColor = self.settings.timestampColor or {r = 0.5, g = 0.5, b = 0.5}
    local tsColorHex = string.format("%02x%02x%02x", tsColor.r * 255, tsColor.g * 255, tsColor.b * 255)
    local timeString = "|cff" .. tsColorHex .. date("%H:%M", timestamp) .. "|r"
    
    local coloredAuthor
    local messageColor
    if author == "Me" or author == playerName or author == fullPlayerName then
        -- Use customizable send color for message text
        if isBNet then
            local color = self.settings.bnetSendColor or {r = 0.0, g = 0.66, b = 1.0}
            local colorHex = string.format("%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
            messageColor = "|cff" .. colorHex
        else
            local color = self.settings.whisperSendColor or {r = 1.0, g = 0.5, b = 1.0}
            local colorHex = string.format("%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
            messageColor = "|cff" .. colorHex
        end
        
        -- Use player's class color for name only, brackets use message color
        local _, playerClass = UnitClass("player")
        local classColor = playerClass and RAID_CLASS_COLORS[playerClass]
        local classColorHex
        if classColor then
            classColorHex = string.format("%02x%02x%02x", classColor.r * 255, classColor.g * 255, classColor.b * 255)
        else
            classColorHex = "ffd100"
        end
        -- Format: brackets in message color, name in class color
        coloredAuthor = string.format("|Hplayer:%s|h%s[|r|cff%s%s|r%s]:|h", fullPlayerName, messageColor, classColorHex, playerName, messageColor)
    else
        -- Color based on whisper type (receive)
        if isBNet then
            -- Use the display name for BNet
            local bnetDisplayName = displayName or author
            local color = self.settings.bnetReceiveColor or {r = 0.0, g = 0.66, b = 1.0}
            local colorHex = string.format("%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
            messageColor = "|cff" .. colorHex
            coloredAuthor = "|TInterface\\ChatFrame\\UI-ChatIcon-Blizz:14:14:0:-1|t|cff00ddff" .. bnetDisplayName .. "|r"
        else
            -- Use customizable receive color for whisper message text
            local color = self.settings.whisperReceiveColor or {r = 1.0, g = 0.5, b = 1.0}
            local colorHex = string.format("%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
            messageColor = "|cff" .. colorHex
            
            -- Regular whispers: use stored class color if available, default to gold
            -- Strip realm name from author (Name-Realm -> Name)
            local authorDisplayName = author:match("^([^%-]+)") or author
            local classColorHex
            
            -- Use stored class token (converted from numeric ID)
            if classToken then
                local classColor = RAID_CLASS_COLORS[classToken]
                if classColor then
                    classColorHex = string.format("%02x%02x%02x", classColor.r * 255, classColor.g * 255, classColor.b * 255)
                end
            end
            
            local nameColorHex = classColorHex or "ffd100"  -- Class color or gold
            -- Format: brackets in message color, name in class color
            coloredAuthor = string.format("|Hplayer:%s|h%s[|r|cff%s%s|r%s]:|h", author, messageColor, nameColorHex, authorDisplayName, messageColor)
        end
    end
    
    -- CRITICAL: Don't use gsub on message - preserve hyperlinks as-is
    -- Apply emote and speech formatting (this function preserves hyperlinks)
    local formattedText = self:FormatEmotesAndSpeech(message)
    
    -- Format message - concatenate parts WITHOUT string.format to preserve hyperlinks
    local formattedMessage = timeString .. " " .. coloredAuthor .. " " .. messageColor .. formattedText .. "|r"
    win.History:AddMessage(formattedMessage)
    
    -- Scroll to bottom
    C_Timer.After(0, function()
        if win.History then
            win.History:ScrollToBottom()
        end
    end)
end

-- ============================================================================
-- Window Position Management
-- ============================================================================

function addon:SaveWindowPosition(window)
    -- SCHEMA PROTECTION: Block if validation failed
    if not addon:IsSafeToOperate() then return end
    
    if not window then return end
    if not WhisperManager_Config then WhisperManager_Config = {} end
    if not WhisperManager_Config.windowPositions then
        WhisperManager_Config.windowPositions = {}
    end
    
    local playerKey = window.playerKey
    local point, _, relativePoint, xOfs, yOfs = window:GetPoint(1)
    local width, height = window:GetSize()
    
    if point then
        WhisperManager_Config.windowPositions[playerKey] = {
            point = point,
            relativePoint = relativePoint,
            xOfs = xOfs,
            yOfs = yOfs,
            width = width,
            height = height,
        }
    end
end

function addon:LoadWindowPosition(window)
    if not window then return end
    if not WhisperManager_Config or not WhisperManager_Config.windowPositions then return end
    
    local playerKey = window.playerKey
    local pos = WhisperManager_Config.windowPositions[playerKey]
    
    if pos then
        window:ClearAllPoints()
        window:SetPoint(pos.point, UIParent, pos.relativePoint, pos.xOfs, pos.yOfs)
        if pos.width and pos.height then
            window:SetSize(pos.width, pos.height)
        end
        -- Ensure frame levels are reapplied after restoring position/size
        UpdateWindowFrameLevels(window, addon.nextFrameLevel)
    end
end

-- ============================================================================
-- Window Show/Hide Management
-- ============================================================================

function addon:CloseWindow(playerKey)
    -- Hiding existing frames is safe even in combat
    local win = self.windows[playerKey]
    if win then
        win:Hide()
        return true
    end
    return false
end

function addon:CloseAllWindows()
    -- Hiding existing frames is safe even in combat
    local closed = 0
    for _, win in pairs(self.windows) do
        if win:IsShown() then
            win:Hide()
            closed = closed + 1
        end
    end
    return closed > 0
end
