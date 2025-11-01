-- ============================================================================
-- Window.lua - Individual whisper window creation and management
-- ============================================================================

local addon = WhisperManager;

-- ============================================================================
-- Window Focus Management
-- ============================================================================

function addon:FocusWindow(window)
    if not window then return end
    
    -- Unfocus all other windows
    for _, win in pairs(self.windows) do
        if win ~= window and win:IsShown() then
            win:SetAlpha(self.UNFOCUSED_ALPHA)
        end
    end
    
    -- Focus this window
    window:SetAlpha(self.FOCUSED_ALPHA)
    
    -- Bring to front with new frame level
    self.nextFrameLevel = self.nextFrameLevel + 10
    window:SetFrameLevel(self.nextFrameLevel)
    window:Raise()
end

-- ============================================================================
-- Helper Functions
-- ============================================================================

-- Helper function to update input container height dynamically
local function UpdateInputHeight(inputBox)
    if not inputBox or not inputBox:IsVisible() then return end
    
    local container = inputBox:GetParent()
    if not container then return end
    
    C_Timer.After(0, function()
        if not inputBox:IsVisible() then return end
        
        local text = inputBox:GetText() or ""
        local font, fontSize, flags = inputBox:GetFont()
        local minInputHeight = (fontSize or 14) + 4
        local minContainerHeight = minInputHeight + 14  -- 7px top + 7px bottom padding
        
        if text == "" then
            inputBox:SetHeight(minInputHeight)
            container:SetHeight(minContainerHeight)
            return
        end
        
        -- Create a hidden FontString for measurement if it doesn't exist
        if not inputBox.measureString then
            inputBox.measureString = inputBox:CreateFontString(nil, "OVERLAY")
            inputBox.measureString:Hide()
        end
        
        local left, right = inputBox:GetTextInsets()
        local usableWidth = inputBox:GetWidth() - left - right
        
        inputBox.measureString:SetFont(font, fontSize, flags)
        inputBox.measureString:SetWidth(usableWidth)
        inputBox.measureString:SetText(text)
        
        local lineHeight = inputBox.measureString:GetLineHeight() or fontSize or 14
        local numLines = inputBox.measureString:GetNumLines() or 1
        if numLines < 1 then numLines = 1 end
        
        local textHeight = numLines * lineHeight
        
        -- Cap at reasonable max height (e.g., 5 lines)
        local maxTextHeight = 5 * lineHeight
        if textHeight > maxTextHeight then textHeight = maxTextHeight end
        
        -- Ensure minimum height (single line + small padding)
        if textHeight < minInputHeight then textHeight = minInputHeight end
        
        -- Container height = input height + padding (14px total: 7 top + 7 bottom)
        local containerHeight = textHeight + 14
        if containerHeight < minContainerHeight then containerHeight = minContainerHeight end
        
        inputBox:SetHeight(textHeight)
        container:SetHeight(containerHeight)
    end)
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
    if not win then
        self:DebugMessage("No existing window. Calling CreateWindow.")
        win = self:CreateWindow(playerKey, playerTarget, displayName, false)
        if not win then 
            self:DebugMessage("|cffff0000ERROR: CreateWindow failed to return a window.|r")
            return false 
        end
        self.windows[playerKey] = win
    else
        win.playerTarget = playerTarget
        win.displayName = displayName
        win.playerKey = playerKey
    end

    self:DisplayHistory(win, playerKey)
    if win.title then
        win.title:SetText("Whisper: " .. (displayName or playerTarget))
    end
    self:LoadWindowPosition(win)
    win:Show()
    self:FocusWindow(win)
    if win.Input then
        win.Input:SetFocus()
    end
    
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
    if win.Input then
        win.Input:SetFocus()
    end
    
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
    end)
    
    -- Focus window on mouse down, but don't consume clicks meant for History frame
    -- WIM method: Check if mouse is over history frame first
    win:SetScript("OnMouseDown", function(self, button)
        -- Don't handle clicks when mouse is over the history frame
        -- Let the history frame handle its own mouse events (higher strata/level)
        if self.History and MouseIsOver(self.History) then
            return
        end
        addon:FocusWindow(self)
    end)
    
    win:SetScript("OnHide", function(self)
        -- Hide input container when window is hidden
        if self.InputContainer then
            self.InputContainer:Hide()
        end
        
        -- Set flag to prevent hooks from triggering during window close
        addon.__closingWindow = true
        addon:SaveWindowPosition(self)
        
        -- Refocus another visible window if one exists
        for _, w in pairs(addon.windows) do
            if w:IsShown() and w ~= self then
                addon:FocusWindow(w)
                break
            end
        end
        
        -- Clear flag after a short delay
        C_Timer.After(0.1, function()
            addon.__closingWindow = false
        end)
    end)
    
    win:SetScript("OnShow", function(self)
        -- Show and position input container when window is shown
        if self.InputContainer then
            self.InputContainer:Show()
            self.InputContainer:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, 1)
            self.InputContainer:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, 1)
        end
        
        addon:LoadWindowPosition(self)
        if self.Input then
            self.Input:SetFocus()
        end
        
        -- Focus this window when shown
        addon:FocusWindow(self)
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
    addon.nextFrameLevel = addon.nextFrameLevel + 10
    win:SetFrameLevel(addon.nextFrameLevel)
    
    -- Title
    win.title = win:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    win.title:SetPoint("TOP", 0, -10)
    win.title:SetText(displayName)
    
    -- Close button
    win.closeBtn = CreateFrame("Button", nil, win, "UIPanelCloseButton")
    win.closeBtn:SetPoint("TOPRIGHT", -2, -2)
    win.closeBtn:SetSize(24, 24)
    
    -- Resize button
    win.resizeBtn = CreateFrame("Button", nil, win)
    win.resizeBtn:SetSize(16, 16)
    win.resizeBtn:SetPoint("BOTTOMRIGHT")
    win.resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    win.resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
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
    
    -- CRITICAL WIM METHOD: Keep same strata as parent (DIALOG) but much higher frame level
    -- Don't change strata or text will render above the window background
    win.History:SetFrameLevel(win:GetFrameLevel() + 50)
    
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
    win.InputContainer:SetHeight(32)  -- Single line height
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
    win.Input:SetPoint("TOPLEFT", win.InputContainer, "TOPLEFT", 8, -7)
    win.Input:SetPoint("TOPRIGHT", win.InputContainer, "TOPRIGHT", -8, -7)
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
    
    -- Set initial height based on font size
    local fontHeight = select(2, win.Input:GetFont()) or 14
    win.Input:SetHeight(fontHeight + 4)
    
    win.Input:SetScript("OnHyperlinkLeave", function(self)
        HideUIPanel(GameTooltip)
    end)
    
    -- Focus window when clicking input box
    win.Input:SetScript("OnMouseDown", function(self)
        addon:FocusWindow(win)
    end)
    
    -- Character Count (positioned at top-right of input container)
    local inputCount = win.InputContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    inputCount:SetPoint("TOPRIGHT", win.InputContainer, "TOPRIGHT", -8, -4)
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
        -- Hide the window frame
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
                    
                    -- Use stored class token if available (performance optimization)
                    if classToken then
                        local classColor = RAID_CLASS_COLORS[classToken]
                        if classColor then
                            classColorHex = string.format("%02x%02x%02x", classColor.r * 255, classColor.g * 255, classColor.b * 255)
                        end
                    end
                    
                    -- Fallback to lookup only if no stored class
                    if not classColorHex then
                        classColorHex = self:GetClassColorForPlayer(author)
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
            -- WIM/Prat3 method: Simple concatenation preserves all escape sequences
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
            
            -- Regular whispers: use stored class color if available, fallback to lookup then gold
            -- Strip realm name from author (Name-Realm -> Name)
            local authorDisplayName = author:match("^([^%-]+)") or author
            local classColorHex
            
            -- Use stored class token if available (performance optimization)
            if classToken then
                local classColor = RAID_CLASS_COLORS[classToken]
                if classColor then
                    classColorHex = string.format("%02x%02x%02x", classColor.r * 255, classColor.g * 255, classColor.b * 255)
                end
            end
            
            -- Fallback to lookup only if no stored class
            if not classColorHex then
                classColorHex = self:GetClassColorForPlayer(author)
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
    end
end

-- ============================================================================
-- Window Show/Hide Management
-- ============================================================================

function addon:CloseWindow(playerKey)
    local win = self.windows[playerKey]
    if win then
        win:Hide()
    end
end

function addon:CloseAllWindows()
    for _, win in pairs(self.windows) do
        win:Hide()
    end
end
