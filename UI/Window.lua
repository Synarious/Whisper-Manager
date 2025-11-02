-- ============================================================================
-- Window.lua - Individual whisper window creation and management
-- ============================================================================

local addon = WhisperManager;

-- ============================================================================
-- Combat Lockdown Queue (WIM Method)
-- ============================================================================

local combatQueue = {};

-- Create combat event handler
local combatFrame = CreateFrame("Frame");
combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED"); -- Entering combat
combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED");  -- Leaving combat
combatFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" then
        -- Process queued operations after combat ends
        local queueCount = #combatQueue
        if queueCount > 0 then
            addon:DebugMessage("Combat ended - processing " .. queueCount .. " queued operations")
            addon:Print("|cff00ff00Combat ended - opening queued whisper windows...|r")
            for _, queuedFunc in ipairs(combatQueue) do
                local success, err = pcall(queuedFunc)
                if not success then
                    addon:DebugMessage("Error processing combat queue:", err)
                end
            end
            wipe(combatQueue)
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        addon:DebugMessage("Entered combat - queueing frame operations")
    end
end)

-- ============================================================================
-- Window Focus Management
-- ============================================================================

function addon:FocusWindow(window)
    if not window then return end
    
    -- Queue operation if in combat (WIM method)
    if InCombatLockdown() then
        self:DebugMessage("In combat - queueing FocusWindow operation")
        table.insert(combatQueue, function() addon:FocusWindow(window) end)
        return
    end
    
    -- Unfocus all other windows - move them to MEDIUM strata
    for _, win in pairs(self.windows) do
        if win ~= window and win:IsShown() then
            win:SetAlpha(self.UNFOCUSED_ALPHA)
            win:SetFrameStrata("MEDIUM")
            -- Update all child frame stratas to match
            if win.InputContainer then
                win.InputContainer:SetFrameStrata("MEDIUM")
            end
            if win.closeBtn then
                win.closeBtn:SetFrameStrata("MEDIUM")
            end
            if win.copyBtn then
                win.copyBtn:SetFrameStrata("MEDIUM")
            end
            if win.resizeBtn then
                win.resizeBtn:SetFrameStrata("MEDIUM")
            end
        end
    end
    
    -- Focus this window - bring to DIALOG strata
    window:SetAlpha(self.FOCUSED_ALPHA)
    window:SetFrameStrata("DIALOG")
    
    -- Update all child frame stratas to match
    if window.InputContainer then
        window.InputContainer:SetFrameStrata("DIALOG")
    end
    if window.copyBtn then
        window.copyBtn:SetFrameStrata("DIALOG")
    end
    if window.resizeBtn then
        window.resizeBtn:SetFrameStrata("DIALOG")
    end
    
    -- Bring to front with new frame level (also protected during combat)
    self.nextFrameLevel = self.nextFrameLevel + 10
    window:SetFrameLevel(self.nextFrameLevel)
    
    -- Set close button to highest level to prevent overlap
    if window.closeBtn then
        window.closeBtn:SetFrameStrata("DIALOG")
        window.closeBtn:SetFrameLevel(self.nextFrameLevel + 100)
    end
    
    window:Raise()
end

-- ============================================================================
-- Window Closing
-- ============================================================================

--- Close all open whisper windows
function addon:CloseAllWindows()
    local windowsClosed = 0
    for playerKey, win in pairs(self.windows) do
        if win and win:IsShown() then
            win:Hide()
            windowsClosed = windowsClosed + 1
        end
    end
    
    if windowsClosed > 0 then
        self:DebugMessage("Closed " .. windowsClosed .. " window(s)")
    end
    
    return windowsClosed > 0
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
    fontSize = fontSize or 14

    -- Compute dynamic padding based on font size so large fonts get more breathing room.
    -- Keep a sensible minimum of 7px (historical default).
    local topBottomPadding = math.max(7, math.floor(fontSize / 2))

    local minInputHeight = math.ceil(fontSize) + 4
    local minContainerHeight = minInputHeight + (2 * topBottomPadding)  -- top + bottom padding
        
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
        
        -- Get the actual width available for text
        -- Account for text insets if set, otherwise the EditBox width is the usable width
        local left, right = inputBox:GetTextInsets()
        local usableWidth = inputBox:GetWidth()
        if left and right then
            usableWidth = usableWidth - left - right
        end
        
        -- Ensure we have a valid width
        if usableWidth <= 0 then
            usableWidth = 100  -- Fallback minimum width
        end
        
    inputBox.measureString:SetFont(font, fontSize, flags)
    inputBox.measureString:SetWidth(usableWidth)
    inputBox.measureString:SetText(text)

    -- Prefer the measured line height but ensure it's at least the font size.
    local measuredLineHeight = inputBox.measureString:GetLineHeight()
    local lineHeight = math.max(measuredLineHeight or 0, fontSize)
    local numLines = inputBox.measureString:GetNumLines() or 1
        if numLines < 1 then numLines = 1 end
        
    local textHeight = math.ceil(numLines * lineHeight)
        
    -- Cap at reasonable max height (now 20 lines)
    local maxTextHeight = 20 * lineHeight
    if textHeight > maxTextHeight then textHeight = maxTextHeight end
        
        -- Ensure minimum height (single line + small padding)
        if textHeight < minInputHeight then textHeight = minInputHeight end
        
        -- Container height = input height + dynamic padding (top + bottom)
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
        table.insert(combatQueue, function() addon:OpenConversation(playerName) end)
        return false
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
        table.insert(combatQueue, function() addon:OpenBNetConversation(bnSenderID, displayName) end)
        return false
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
    
    -- Ensure settings are loaded first
    if not addon.settings then
        addon.settings = addon:LoadSettings()
    end
    
    -- Set default window size from settings
    local defaultWidth = addon:GetSetting("defaultWindowWidth") or 400
    local defaultHeight = addon:GetSetting("defaultWindowHeight") or 300
    win:SetSize(defaultWidth, defaultHeight)
    
    local spawnX, spawnY
    
    -- Find the currently focused window (highest frame level)
    local focusedWindow = nil
    local highestLevel = 0
    for _, window in pairs(addon.windows) do
        if window and window:IsShown() then
            local level = window:GetFrameLevel()
            if level > highestLevel then
                highestLevel = level
                focusedWindow = window
            end
        end
    end
    
    if focusedWindow then
        -- Position 300px below and 150px left/right of the focused window (alternating)
        local _, _, _, focusedX, focusedY = focusedWindow:GetPoint(1)
        focusedX = focusedX or 0
        focusedY = focusedY or 0
        
        -- Increment cascade counter and determine horizontal offset
        addon.cascadeCounter = addon.cascadeCounter + 1
        local horizontalOffset = (addon.cascadeCounter % 2 == 0) and 150 or -150
        
        spawnX = focusedX + horizontalOffset
        spawnY = focusedY - 300  -- 300px below focused window
        
        addon:DebugMessage("Spawning relative to focused window - Offset:", horizontalOffset, "at X:", spawnX, "Y:", spawnY)
        
        -- Check screen boundaries
        local screenWidth = UIParent:GetWidth()
        local screenHeight = UIParent:GetHeight()
        local minX = -(screenWidth / 2) + defaultWidth / 2 + 50  -- 50px margin from left
        local maxX = (screenWidth / 2) - defaultWidth / 2 - 50   -- 50px margin from right
        local minY = -(screenHeight / 2) + defaultHeight / 2 + 50  -- 50px margin from bottom
        
        -- Clamp to screen boundaries
        if spawnX < minX then spawnX = minX end
        if spawnX > maxX then spawnX = maxX end
        if spawnY < minY then
            -- Window would be off-screen vertically, use default anchor instead
            addon:DebugMessage("Would spawn off-screen (minY:", minY, "), using default anchor")
            spawnX = addon:GetSetting("spawnAnchorX") or 0
            spawnY = addon:GetSetting("spawnAnchorY") or 200
            addon.cascadeCounter = 0  -- Reset counter when reverting to default
        end
    else
        -- No focused window, use default anchor point
        spawnX = addon:GetSetting("spawnAnchorX") or 0
        spawnY = addon:GetSetting("spawnAnchorY") or 200
        addon.cascadeCounter = 0  -- Reset counter
        addon:DebugMessage("No focused window, using default anchor X:", spawnX, "Y:", spawnY)
    end
    
    win:SetPoint("CENTER", UIParent, "CENTER", spawnX, spawnY)
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
    end)
    
    -- ESC key handling to close all whisper windows at once
    win:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            addon:CloseAllWindows()
        end
    end)
    win:SetPropagateKeyboardInput(true)
    
    -- Focus window on mouse down, but don't consume clicks meant for History frame
    -- WIM method: Check if mouse is over history frame first
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
        
        -- Set flag to prevent hooks from triggering during window close
        addon.__closingWindow = true
        
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
        
        -- Don't auto-focus input - let user click to focus
        
        -- Focus this window when shown
        addon:FocusWindow(self)
        
        -- Mark messages as read when window is shown/focused
        if self.playerKey then
            addon:MarkChatAsRead(self.playerKey)
        end
        
        -- ESC key handling is done via OnKeyDown script below
    end)
    
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
    addon.nextFrameLevel = addon.nextFrameLevel + 10
    win:SetFrameLevel(addon.nextFrameLevel)
    
    -- Title
    win.title = win:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    win.title:SetPoint("TOP", 0, -10)
    win.title:SetText(displayName)
    
    -- Copy Chat button (left side of title bar)
    win.copyBtn = CreateFrame("Button", nil, win)
    win.copyBtn:SetPoint("TOPLEFT", 6, -6)
    win.copyBtn:SetSize(20, 20)
    win.copyBtn:SetNormalTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
    win.copyBtn:SetPushedTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Down")
    win.copyBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    win.copyBtn:SetScript("OnClick", function(self)
        addon:ShowCopyChatDialog(win.playerKey, win.displayName)
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
    
    -- Close button
    win.closeBtn = CreateFrame("Button", nil, win, "UIPanelCloseButton")
    win.closeBtn:SetPoint("TOPRIGHT", -2, -2)
    win.closeBtn:SetSize(24, 24)
    -- Set high frame level to prevent being hidden behind other windows
    win.closeBtn:SetFrameLevel(win:GetFrameLevel() + 100)
    
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
    end)
    
    -- History ScrollingMessageFrame (now fills the entire window)
    win.History = CreateFrame("ScrollingMessageFrame", nil, win)
    win.History:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -40)
    win.History:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -12, 12)
    win.History:SetMaxLines(addon.MAX_HISTORY_LINES)
    win.History:SetFading(false)
    -- CRITICAL: Set insert mode to BOTTOM so new messages appear at bottom
    win.History:SetInsertMode("BOTTOM")
    -- Mark as WhisperManager frame so message filter doesn't suppress messages in our own windows
    win.History._WhisperManager = true
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
        -- Note: ShowUIPanel is protected, use GameTooltip:Show() instead
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetHyperlink(link)
        GameTooltip:Show()
    end)
    win.History:SetScript("OnHyperlinkLeave", function(self)
        -- Note: HideUIPanel is protected, use GameTooltip:Hide() instead
        GameTooltip:Hide()
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
    -- We'll compute vertical offset based on dynamic padding so the editbox background scales with font
    -- Anchor will be set after font/padding is computed below; temporarily anchor to container
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
    
    -- Set initial height based on font size (input height + dynamic padding)
    local _, fontHeight = win.Input:GetFont()
    fontHeight = fontHeight or 14
    local topBottomPadding = math.max(7, math.floor(fontHeight / 2))
    local initialInputHeight = math.ceil(fontHeight) + 4
    local initialContainerHeight = initialInputHeight + (2 * topBottomPadding)
    win.Input:SetHeight(initialInputHeight)
    win.InputContainer:SetHeight(initialContainerHeight)
    -- store padding for later use by UpdateInputHeight
    win.Input.__wm_topBottomPadding = topBottomPadding
    -- Re-anchor input vertically using the computed padding so the text sits centered within the container
    win.Input:ClearAllPoints()
    win.Input:SetPoint("TOPLEFT", win.InputContainer, "TOPLEFT", 8, -topBottomPadding)
    win.Input:SetPoint("TOPRIGHT", win.InputContainer, "TOPRIGHT", -8, -topBottomPadding)
    
    win.Input:SetScript("OnHyperlinkLeave", function(self)
        -- Note: HideUIPanel is protected, use GameTooltip:Hide() instead
        GameTooltip:Hide()
    end)
    
    -- Focus window when clicking input box
    win.Input:SetScript("OnMouseDown", function(self)
        addon:FocusWindow(win)
    end)
    
    -- Character Count (positioned at top-right of input container)
    local inputCount = win.InputContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    -- Align character count relative to the dynamic top padding so it stays inside the container
    local countYOffset = -math.max(4, math.floor((win.Input.__wm_topBottomPadding or 7) / 2))
    inputCount:SetPoint("TOPRIGHT", win.InputContainer, "TOPRIGHT", -8, countYOffset)
    inputCount:SetTextColor(0.6, 0.6, 0.6)
    inputCount:SetText("0/" .. addon.CHAT_MAX_LETTERS)

    -- Input Box Scripts
    win.Input:SetScript("OnEnterPressed", function(self)
        local message = self:GetText()
        if not message or message == "" then
            return
        end

        local sent = false

        if win.isBNet then
            if win.bnSenderID then
                BNSendWhisper(win.bnSenderID, message)
                sent = true
            else
                addon:Print("|cffff8800Unable to determine Battle.net target for this whisper.|r")
            end
        else
            local target = win.playerTarget

            if not target or target == "" then
                if win.playerKey and win.playerKey:match("^c_.+") then
                    target = win.playerKey:sub(3)
                elseif win.displayName and win.displayName ~= "" then
                    target = win.displayName
                end
            end

            if not target or target == "" then
                addon:Print("|cffff8800Unable to determine whisper target for this window.|r")
            else
                win.playerTarget = target
                SendChatMessage(message, "WHISPER", nil, target)
                sent = true
            end
        end

        if sent then
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
    addon:LoadWindowHistory(win)
    
    -- Initialize input height (ensures proper sizing on first show)
    C_Timer.After(0.1, function()
        if win.Input and win.Input:IsVisible() then
            UpdateInputHeight(win.Input)
        end
    end)
    
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
