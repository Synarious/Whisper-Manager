-- ============================================================================
-- HistoryViewer.lua - History viewer and search UI
-- ============================================================================

local addon = WhisperManager;

-- ============================================================================
-- History Frame Creation
-- ============================================================================

function addon:CreateHistoryFrame()
    local frame = CreateFrame("Frame", "WhisperManager_History", UIParent, "BackdropTemplate")
    frame:SetSize(500, 600)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetResizeBounds(400, 400, 800, 800)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        addon:SaveHistoryPosition()
    end)
    frame:SetScript("OnHide", function(self)
        addon:SaveHistoryPosition()
    end)
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.9)
    frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    frame:Hide()
    
    -- Title
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOP", 0, -10)
    frame.title:SetText("Chat History")
    
    -- Close button
    frame.closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.closeBtn:SetPoint("TOPRIGHT", -2, -2)
    frame.closeBtn:SetSize(24, 24)
    
    -- Resize button
    frame.resizeBtn = CreateFrame("Button", nil, frame)
    frame.resizeBtn:SetSize(16, 16)
    frame.resizeBtn:SetPoint("BOTTOMRIGHT")
    frame.resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    frame.resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    frame.resizeBtn:SetScript("OnMouseDown", function()
        frame:StartSizing("BOTTOMRIGHT")
    end)
    frame.resizeBtn:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        addon:SaveHistoryPosition()
    end)
    
    -- Search box
    frame.searchBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    frame.searchBox:SetSize(200, 30)
    frame.searchBox:SetPoint("TOPLEFT", 10, -40)
    frame.searchBox:SetAutoFocus(false)
    frame.searchBox:SetScript("OnTextChanged", function(self)
        addon:FilterHistoryList(self:GetText())
    end)
    frame.searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    
    -- Search label
    frame.searchLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.searchLabel:SetPoint("LEFT", frame.searchBox, "RIGHT", 10, 0)
    frame.searchLabel:SetText("Search")
    
    -- List view (left side)
    frame.listScrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    frame.listScrollFrame:SetPoint("TOPLEFT", 10, -80)
    frame.listScrollFrame:SetPoint("BOTTOMLEFT", 10, 10)
    frame.listScrollFrame:SetWidth(200)
    
    frame.listScrollChild = CreateFrame("Frame", nil, frame.listScrollFrame)
    frame.listScrollChild:SetSize(180, 1)
    frame.listScrollFrame:SetScrollChild(frame.listScrollChild)
    
    -- Enable mouse wheel scrolling for history list
    frame.listScrollFrame:EnableMouseWheel(true)
    frame.listScrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local scrollBar = self.ScrollBar
        if scrollBar then
            local current = scrollBar:GetValue()
            local _, maxValue = scrollBar:GetMinMaxValues()
            local step = 40 * delta
            scrollBar:SetValue(math.max(0, math.min(maxValue, current - step)))
        end
    end)
    
    -- Detail view (right side)
    frame.detailFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.detailFrame:SetPoint("TOPLEFT", frame.listScrollFrame, "TOPRIGHT", 20, 0)
    frame.detailFrame:SetPoint("BOTTOMRIGHT", -10, 10)
    frame.detailFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    frame.detailFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    frame.detailFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    
    -- Detail title
    frame.detailTitle = frame.detailFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.detailTitle:SetPoint("TOP", 0, -10)
    frame.detailTitle:SetText("Select a conversation")
    
    -- Detail scroll frame with proper scrolling support
    frame.detailScrollFrame = CreateFrame("ScrollFrame", nil, frame.detailFrame, "UIPanelScrollFrameTemplate")
    frame.detailScrollFrame:SetPoint("TOPLEFT", 10, -35)
    frame.detailScrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
    
    -- Create scroll child to hold the message text
    frame.detailScrollChild = CreateFrame("Frame", nil, frame.detailScrollFrame)
    frame.detailScrollChild:SetWidth(frame.detailScrollFrame:GetWidth())
    frame.detailScrollChild:SetHeight(1)
    frame.detailScrollFrame:SetScrollChild(frame.detailScrollChild)
    
    -- Update width when frame is resized
    frame:SetScript("OnSizeChanged", function()
        local width = frame.detailScrollFrame:GetWidth()
        if width > 0 then
            frame.detailScrollChild:SetWidth(width)
            frame.detailText:SetWidth(width - 35) -- Account for padding and scrollbar
        end
    end)
    
    -- Create a font string for displaying messages
    frame.detailText = frame.detailScrollChild:CreateFontString(nil, "OVERLAY", "ChatFontNormal")
    frame.detailText:SetPoint("TOPLEFT", 5, -5)
    frame.detailText:SetWidth(frame.detailScrollFrame:GetWidth() - 35) -- Account for padding and scrollbar
    frame.detailText:SetJustifyH("LEFT")
    frame.detailText:SetJustifyV("TOP")
    frame.detailText:SetWordWrap(true)
    frame.detailText:SetNonSpaceWrap(true)
    frame.detailText:SetText("Select a conversation")
    
    -- Enable mouse wheel scrolling
    frame.detailScrollFrame:EnableMouseWheel(true)
    frame.detailScrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local scrollBar = self.ScrollBar or _G[self:GetName().."ScrollBar"]
        if scrollBar then
            local current = scrollBar:GetValue()
            local _, maxValue = scrollBar:GetMinMaxValues()
            local step = 20 * delta
            scrollBar:SetValue(math.max(0, math.min(maxValue, current - step)))
        end
    end)
    
    addon.historyFrame = frame
    return frame
end

function addon:SaveHistoryPosition()
    if not self.historyFrame then return end
    if not WhisperManager_Config then WhisperManager_Config = {} end
    
    local point, _, relativePoint, xOfs, yOfs = self.historyFrame:GetPoint(1)
    local width, height = self.historyFrame:GetSize()
    
    if point then
        WhisperManager_Config.historyPos = {
            point = point,
            relativePoint = relativePoint,
            xOfs = xOfs,
            yOfs = yOfs,
            width = width,
            height = height,
        }
    end
end

function addon:LoadHistoryPosition()
    if not self.historyFrame then return end
    if not WhisperManager_Config or not WhisperManager_Config.historyPos then return end
    
    local pos = WhisperManager_Config.historyPos
    self.historyFrame:ClearAllPoints()
    self.historyFrame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.xOfs, pos.yOfs)
    
    if pos.width and pos.height then
        self.historyFrame:SetSize(pos.width, pos.height)
    end
end

function addon:ToggleHistoryFrame()
    if not self.historyFrame then
        self:CreateHistoryFrame()
        self:LoadHistoryPosition()
    end
    
    if self.historyFrame:IsShown() then
        self.historyFrame:Hide()
    else
        -- Close recent chats frame if it's open
        if self.recentChatsFrame and self.recentChatsFrame:IsShown() then
            self.recentChatsFrame:Hide()
        end
        
        self:RefreshHistoryList()
        self.historyFrame:Show()
    end
end

function addon:RefreshHistoryList(filterText)
    if not self.historyFrame then return end
    
    -- Clear existing buttons
    local scrollChild = self.historyFrame.listScrollChild
    for _, child in ipairs({scrollChild:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end
    
    if not WhisperManager_HistoryDB then
        return
    end
    
    -- Convert to sorted array
    local conversations = {}
    for playerKey, history in pairs(WhisperManager_HistoryDB) do
        if playerKey ~= "__schema" and type(history) == "table" and #history > 0 then
            -- Extract display name from key instead of using __display
            local displayName = self:GetDisplayNameFromKey(playerKey)
            -- Support both old and new format
            local lastEntry = history[#history]
            local lastTimestamp = lastEntry.t or lastEntry.timestamp or 0
            
            -- Apply filter if provided
            if not filterText or filterText == "" or 
               displayName:lower():find(filterText:lower(), 1, true) then
                table.insert(conversations, {
                    playerKey = playerKey,
                    displayName = displayName,
                    lastTimestamp = lastTimestamp,
                })
            end
        end
    end
    
    -- Sort by most recent first
    table.sort(conversations, function(a, b)
        return a.lastTimestamp > b.lastTimestamp
    end)
    
    -- Create buttons for each conversation
    local yOffset = 0
    for i, conv in ipairs(conversations) do
        local btn = CreateFrame("Button", nil, scrollChild)
        btn:SetSize(180, 50)
        btn:SetPoint("TOPLEFT", 0, -yOffset)
        
        -- Background
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetColorTexture(0.2, 0.2, 0.2, 0.5)
        
        -- Highlight
        btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
        btn.highlight:SetAllPoints()
        btn.highlight:SetColorTexture(0.3, 0.3, 0.3, 0.5)
        
        -- Name text
        btn.nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btn.nameText:SetPoint("TOPLEFT", 5, -5)
        btn.nameText:SetPoint("TOPRIGHT", -5, -5)
        btn.nameText:SetText(conv.displayName)
        btn.nameText:SetJustifyH("LEFT")
        btn.nameText:SetWordWrap(false)
        
        -- Time text
        btn.timeText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.timeText:SetPoint("BOTTOMLEFT", 5, 5)
        btn.timeText:SetText(self.GetTimeAgo(conv.lastTimestamp))
        btn.timeText:SetTextColor(0.7, 0.7, 0.7)
        
        -- Click to show detail
        btn:SetScript("OnClick", function()
            addon:ShowHistoryDetail(conv.playerKey, conv.displayName)
        end)
        
        yOffset = yOffset + 55
    end
    
    scrollChild:SetHeight(math.max(yOffset, 1))
end

function addon:FilterHistoryList(filterText)
    self:RefreshHistoryList(filterText)
end

function addon:ShowHistoryDetail(playerKey, displayName)
    if not self.historyFrame then return end
    
    local detailTitle = self.historyFrame.detailTitle
    local detailText = self.historyFrame.detailText
    local detailScrollChild = self.historyFrame.detailScrollChild
    local detailScrollFrame = self.historyFrame.detailScrollFrame
    
    detailTitle:SetText(displayName)
    
    -- Set scroll child width to match scroll frame
    local scrollWidth = detailScrollFrame:GetWidth()
    if scrollWidth > 0 then
        detailScrollChild:SetWidth(scrollWidth)
        detailText:SetWidth(scrollWidth - 35) -- Account for padding and scrollbar
    end
    
    if not WhisperManager_HistoryDB or not WhisperManager_HistoryDB[playerKey] then
        detailText:SetText("No message history found.")
        detailScrollChild:SetHeight(detailText:GetStringHeight() + 10)
        return
    end
    
    local history = WhisperManager_HistoryDB[playerKey]
    local messageLines = {}
    local playerName, playerRealm = UnitName("player")
    local realm = (playerRealm or GetRealmName()):gsub("%s+", "")
    local fullPlayerName = playerName .. "-" .. realm
    
    for _, entry in ipairs(history) do
        -- Support both old and new format
        local timestamp = entry.t or entry.timestamp
        local author = entry.a or entry.author
        local message = entry.m or entry.message
        
        if timestamp and author and message then
            local timeString = date("[%H:%M]", timestamp)
            local coloredAuthor
            if author == "Me" or author == playerName or author == fullPlayerName then
                coloredAuthor = "|cff9494ffMe|r"
            else
                coloredAuthor = string.format("|cffffd100%s|r", author)
            end
            local safeMessage = message:gsub("%%", "%%%%")
            
            -- Apply emote and speech formatting
            safeMessage = self:FormatEmotesAndSpeech(safeMessage)
            
            local formattedMessage = string.format("%s %s: %s", timeString, coloredAuthor, safeMessage)
            table.insert(messageLines, formattedMessage)
        end
    end
    
    local fullText = table.concat(messageLines, "\n")
    detailText:SetText(fullText)
    
    -- Update scroll child height based on text height
    local textHeight = detailText:GetStringHeight()
    detailScrollChild:SetHeight(math.max(textHeight + 10, detailScrollFrame:GetHeight()))
    
    -- Scroll to bottom
    C_Timer.After(0, function()
        local scrollBar = detailScrollFrame.ScrollBar
        if scrollBar then
            local _, maxValue = scrollBar:GetMinMaxValues()
            scrollBar:SetValue(maxValue)
        end
    end)
end
