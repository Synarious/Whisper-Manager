-- ============================================================================
-- Window.lua - Whisper window creation and management
-- ============================================================================

local addon = WhisperManager;

-- ============================================================================
-- Helper Functions
-- ============================================================================

-- Helper function to update input box height dynamically
local function UpdateInputHeight(inputBox)
    if not inputBox or not inputBox:IsVisible() then return end
    
    C_Timer.After(0, function()
        if not inputBox:IsVisible() then return end
        
        local text = inputBox:GetText() or ""
        if text == "" then
            inputBox:SetHeight(24)  -- Minimum height
            return
        end
        
        -- Create a hidden FontString for measurement if it doesn't exist
        if not inputBox.measureString then
            inputBox.measureString = inputBox:CreateFontString(nil, "OVERLAY")
            inputBox.measureString:Hide()
        end
        
        local font, size, flags = inputBox:GetFont()
        local left, right = inputBox:GetTextInsets()
        local usableWidth = inputBox:GetWidth() - left - right
        
        inputBox.measureString:SetFont(font, size, flags)
        inputBox.measureString:SetWidth(usableWidth)
        inputBox.measureString:SetText(text)
        
        local lineHeight = inputBox.measureString:GetLineHeight() or 14
        local numLines = inputBox.measureString:GetNumLines() or 1
        if numLines < 1 then numLines = 1 end
        
        local padding = 8
        local newHeight = (numLines * lineHeight) + padding
        
        -- Cap at reasonable max height (e.g., 5 lines)
        local maxHeight = (5 * lineHeight) + padding
        if newHeight > maxHeight then newHeight = maxHeight end
        
        -- Ensure minimum height
        if newHeight < 24 then newHeight = 24 end
        
        inputBox:SetHeight(newHeight)
    end)
end

-- ============================================================================
-- Window Position Management
-- ============================================================================

function addon:SaveWindowPosition(window)
    if not window or not window.playerKey then return end
    if type(WhisperManager_WindowDB) ~= "table" then
        WhisperManager_WindowDB = {}
    end
    local point, relativeTo, relativePoint, xOfs, yOfs = window:GetPoint(1)
    if not point then return end

    local width, height = window:GetSize()
    WhisperManager_WindowDB[window.playerKey] = {
        point = point,
        relativePoint = relativePoint,
        relativeTo = relativeTo and relativeTo:GetName() or nil,
        xOfs = xOfs or 0,
        yOfs = yOfs or 0,
        width = width or 400,
        height = height or 300,
    }
end

function addon:ApplyWindowPosition(window)
    if not window or not window.playerKey then return end
    local state = type(WhisperManager_WindowDB) == "table" and WhisperManager_WindowDB[window.playerKey]
    if state and state.point and state.relativePoint then
        local relative = state.relativeTo and _G[state.relativeTo] or UIParent
        window:ClearAllPoints()
        window:SetPoint(state.point, relative, state.relativePoint, state.xOfs or 0, state.yOfs or 0)
        
        -- Restore saved size if available
        if state.width and state.height then
            window:SetSize(state.width, state.height)
        end
    else
        window:ClearAllPoints()
        window:SetPoint("CENTER")
    end
end

function addon:ResetWindowPositions()
    WhisperManager_WindowDB = {}
    for _, window in pairs(addon.windows) do
        if window and window.ClearAllPoints then
            window:ClearAllPoints()
            window:SetPoint("CENTER")
            addon:SaveWindowPosition(window)
        end
    end
    addon:Print("All whisper window positions reset to center.")
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
    
    self:DebugMessage("OpenConversation called for:", playerName);
    local playerKey, playerTarget, displayName = self:ResolvePlayerIdentifiers(playerName)
    if not playerKey then
        self:DebugMessage("|cffff0000ERROR: Unable to resolve player identifiers for|r", playerName)
        return false
    end

    displayName = self:GetDisplayNameFromKey(playerKey)

    local win = self.windows[playerKey]
    if not win then
        self:DebugMessage("No existing window. Calling CreateWindow.");
        win = self:CreateWindow(playerKey, playerTarget, displayName, false)
        if not win then 
            self:DebugMessage("|cffff0000ERROR: CreateWindow failed to return a window.|r");
            return false 
        end
        self.windows[playerKey] = win
    else
        win.playerTarget = playerTarget
        win.playerDisplay = displayName
        win.playerKey = playerKey
    end

    self:DisplayHistory(win, playerKey)
    if win.Title then
        win.Title:SetText("Whisper: " .. (displayName or playerTarget))
    end
    self:ApplyWindowPosition(win)
    win:Show()
    win:Raise()
    if win.Input then
        win.Input:SetFocus()
    end
    
    -- Mark as read and update recent chats
    self:MarkChatAsRead(playerKey)
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
        win.playerDisplay = displayName
        win.playerKey = playerKey
    end
    
    self:DisplayHistory(win, playerKey)
    if win.Title then
        win.Title:SetText("BNet Whisper: " .. displayName)
    end
    self:ApplyWindowPosition(win)
    win:Show()
    win:Raise()
    if win.Input then
        win.Input:SetFocus()
    end
    
    -- Mark as read and update recent chats
    self:MarkChatAsRead(playerKey)
    self:UpdateRecentChat(playerKey, displayName, true)
    
    return true
end

-- ============================================================================
-- Window Creation
-- ============================================================================

function addon:CreateWindow(playerKey, playerTarget, displayName, isBNet)
    self:DebugMessage("CreateWindow called for:", playerKey);
    local sanitizedKey = playerKey:gsub("[^%w]","")
    if sanitizedKey == "" then return nil end
    local frameName = "WhisperManager_" .. sanitizedKey

    if _G[frameName] then return _G[frameName] end

    -- Main Window Frame
    local win = CreateFrame("Frame", frameName, UIParent, "BackdropTemplate")
    win.playerKey = playerKey
    win.playerTarget = playerTarget
    win.playerDisplay = displayName
    win.isBNet = isBNet or false
    if isBNet then
        win.bnSenderID = playerTarget  -- For BNet, playerTarget is the bnSenderID
    end
    win:SetSize(400, 300)
    win:SetPoint("CENTER")
    win:SetClampedToScreen(true)
    win:SetMovable(true)
    win:SetResizable(true)
    win:SetResizeBounds(250, 200, 800, 600)
    win:EnableMouse(true)
    win:SetUserPlaced(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        addon:SaveWindowPosition(frame)
    end)
    win:SetScript("OnHide", function(frame)
        -- Set flag to prevent hooks from triggering during window close
        addon.__closingWindow = true
        
        addon:SaveWindowPosition(frame)
        if frame.Input then
            frame.Input:ClearFocus()
            frame.Input:Hide()
        end
        if frame.InputBg then
            frame.InputBg:Hide()
        end
        if frame.InputBorder then
            frame.InputBorder:Hide()
        end
        
        -- Clear flag after a short delay
        C_Timer.After(0.1, function()
            addon.__closingWindow = false
        end)
    end)
    win:SetScript("OnShow", function(frame)
        addon:ApplyWindowPosition(frame)
        if frame.Input then
            frame.Input:Show()
            frame.Input:SetFocus()
        end
        if frame.InputBg then
            frame.InputBg:Show()
        end
        if frame.InputBorder then
            frame.InputBorder:Show()
        end
    end)
    win:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    win:SetBackdropColor(0, 0, 0, 0.85)
    win:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    -- Title Bar Background
    win.TitleBg = win:CreateTexture(nil, "BACKGROUND")
    win.TitleBg:SetColorTexture(0.1, 0.1, 0.1, 0.9)
    win.TitleBg:SetPoint("TOPLEFT", win, "TOPLEFT", 4, -4)
    win.TitleBg:SetPoint("TOPRIGHT", win, "TOPRIGHT", -4, -4)
    win.TitleBg:SetHeight(28)

    -- Title Text
    win.Title = win:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    win.Title:SetPoint("TOP", win, "TOP", 0, -10)
    local titlePrefix = isBNet and "BNet Whisper: " or "Whisper: "
    win.Title:SetText(titlePrefix .. (displayName or playerTarget or playerKey))
    win.Title:SetTextColor(1, 0.82, 0, 1)
    
    -- Make title clickable for right-click menu
    win.TitleButton = CreateFrame("Button", nil, win)
    win.TitleButton:SetAllPoints(win.Title)
    win.TitleButton:RegisterForClicks("RightButtonUp")
    win.TitleButton:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            -- Open unit popup menu for the player
            if win.playerTarget then
                local dropDown = CreateFrame("Frame", "WhisperManager_DropDown", UIParent, "UIDropDownMenuTemplate")
                local menuList = {
                    {
                        text = win.playerDisplay or win.playerTarget,
                        isTitle = true,
                        notCheckable = true,
                    },
                }
                
                -- Only show regular player options for non-BNet whispers
                if not win.isBNet then
                    table.insert(menuList, {
                        text = WHISPER,
                        func = function()
                            ChatFrame_SendTell(win.playerTarget)
                        end,
                        notCheckable = true,
                    })
                    table.insert(menuList, {
                        text = INVITE,
                        func = function()
                            C_PartyInfo.InviteUnit(win.playerTarget)
                        end,
                        notCheckable = true,
                    })
                    table.insert(menuList, {
                        text = RAID_TARGET_ICON,
                        hasArrow = true,
                        notCheckable = true,
                        menuList = {},
                    })
                    
                    -- Add raid target icons dynamically
                    for i = 1, 8 do
                        table.insert(menuList[#menuList].menuList, {
                            text = _G["RAID_TARGET_"..i],
                            func = function()
                                SetRaidTarget(win.playerTarget, i)
                            end,
                            notCheckable = true,
                        })
                    end
                    
                    table.insert(menuList, {
                        text = ADD_FRIEND,
                        func = function()
                            C_FriendList.AddFriend(win.playerTarget)
                        end,
                        notCheckable = true,
                    })
                    table.insert(menuList, {
                        text = PLAYER_REPORT,
                        func = function()
                            C_ReportSystem.OpenReportPlayerDialog(C_PlayerInfo.GUIDFromPlayerName(win.playerTarget), win.playerTarget)
                        end,
                        notCheckable = true,
                    })
                end
                
                table.insert(menuList, {
                    text = CANCEL,
                    func = function() end,
                    notCheckable = true,
                })
                
                EasyMenu(menuList, dropDown, "cursor", 0, 0, "MENU")
            end
        end
    end)
    win.TitleButton:SetScript("OnEnter", function(self)
        win.Title:SetTextColor(1, 1, 1, 1)  -- White on hover
    end)
    win.TitleButton:SetScript("OnLeave", function(self)
        win.Title:SetTextColor(1, 0.82, 0, 1)  -- Gold default
    end)

    -- Close Button
    win.CloseButton = CreateFrame("Button", nil, win, "UIPanelCloseButton")
    win.CloseButton:SetSize(24, 24)
    win.CloseButton:SetPoint("TOPRIGHT", win, "TOPRIGHT", -2, -2)

    -- Resize Button
    win.ResizeButton = CreateFrame("Button", nil, win)
    win.ResizeButton:SetSize(16, 16)
    win.ResizeButton:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", 0, 0)
    win.ResizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    win.ResizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    win.ResizeButton:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            win:StartSizing("BOTTOMRIGHT")
        end
    end)
    win.ResizeButton:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            win:StopMovingOrSizing()
            addon:SaveWindowPosition(win)
        end
    end)

    -- Input EditBox (positioned outside/below the main window frame)
    local inputName = frameName .. "Input"
    win.Input = CreateFrame("EditBox", inputName, UIParent)
    win.Input:SetHeight(24)  -- Initial height, will grow dynamically
    win.Input:SetPoint("TOPLEFT", win, "BOTTOMLEFT", 0, -4)
    win.Input:SetPoint("TOPRIGHT", win, "BOTTOMRIGHT", 0, -4)
    
    -- Set font properly for EditBox
    local fontFile, _, fontFlags = ChatFontNormal:GetFont()
    win.Input:SetFont(fontFile, 14, fontFlags)
    win.Input:SetTextColor(1, 1, 1, 1)
    
    -- Enable multiline with proper mouse support
    win.Input:SetMultiLine(true)
    win.Input:SetAutoFocus(false)
    win.Input:SetHistoryLines(32)
    win.Input:SetMaxLetters(addon.CHAT_MAX_LETTERS)
    win.Input:SetAltArrowKeyMode(true)  -- Like WIM
    win.Input:EnableMouse(true)
    win.Input:EnableKeyboard(true)
    win.Input:SetHitRectInsets(0, 0, 0, 0)  -- Fix mouse clicking for multiline
    win.Input:SetTextInsets(6, 6, 4, 4)  -- Add some padding

    -- Input Box Background
    win.InputBg = win:CreateTexture(nil, "BACKGROUND")
    win.InputBg:SetColorTexture(0, 0, 0, 0.6)
    win.InputBg:SetPoint("TOPLEFT", win.Input, "TOPLEFT", -4, 4)
    win.InputBg:SetPoint("BOTTOMRIGHT", win.Input, "BOTTOMRIGHT", 4, -4)

    -- Input Box Border
    win.InputBorder = CreateFrame("Frame", nil, win, "BackdropTemplate")
    win.InputBorder:SetPoint("TOPLEFT", win.Input, "TOPLEFT", -5, 5)
    win.InputBorder:SetPoint("BOTTOMRIGHT", win.Input, "BOTTOMRIGHT", 5, -5)
    win.InputBorder:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    win.InputBorder:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
    win.InputBorder:EnableMouse(false)
    win.InputBorder:SetFrameStrata("LOW")

    -- History ScrollingMessageFrame
    win.History = CreateFrame("ScrollingMessageFrame", nil, win)
    win.History:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -40)
    win.History:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -12, 12)
    win.History:SetMaxLines(addon.MAX_HISTORY_LINES)
    win.History:SetFading(false)
    win.History:SetFontObject(ChatFontNormal)
    win.History:SetJustifyH("LEFT")
    win.History:SetHyperlinksEnabled(true)
    win.History:SetScript("OnHyperlinkClick", ChatFrame_OnHyperlinkShow)
    
    -- Enable mouse wheel scrolling for history
    win.History:EnableMouseWheel(true)
    win.History:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then
            self:ScrollUp()
        else
            self:ScrollDown()
        end
    end)

    -- Character Count
    local inputCount = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    inputCount:SetPoint("BOTTOMRIGHT", win.Input, "TOPRIGHT", -4, 2)
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
                C_ChatInfo.SendChatMessage(message, "WHISPER", nil, win.playerTarget)
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
        -- Hide the window frame, not the parent (UIParent)
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
    
    self:DebugMessage("CreateWindow finished successfully for", playerKey);
    addon:ApplyWindowPosition(win)
    return win
end
