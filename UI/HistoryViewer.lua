-- History viewer and search UI
local addon = WhisperManager;

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
    frame:SetToplevel(true)
    
    -- Keyboard handling - capture navigation keys and ESC
    -- Allow most keys to propagate to the game (so movement keys still work)
    frame:SetPropagateKeyboardInput(true)
    frame:SetScript("OnKeyDown", function(self, key)
        -- Let common movement keys pass through so player can move with WASD
        if key == "W" or key == "A" or key == "S" or key == "D" then
            return
        end
        -- Close with ESC
        if key == "ESCAPE" then
            self:Hide()
            return
        end

    -- Navigation: move the list scrollbar (if present)
        local listScroll = self.listScrollFrame
        if listScroll and listScroll.ScrollBar then
            local sb = listScroll.ScrollBar
            local minV, maxV = sb:GetMinMaxValues()
            local cur = sb:GetValue()
            if key == "UP" or key == "LEFT" then
                sb:SetValue(math.max(minV, cur - 40))
                return
            elseif key == "DOWN" or key == "RIGHT" then
                sb:SetValue(math.min(maxV, cur + 40))
                return
            elseif key == "PAGEDOWN" then
                sb:SetValue(math.min(maxV, cur + 200))
                return
            elseif key == "PAGEUP" then
                sb:SetValue(math.max(minV, cur - 200))
                return
            end
        end

        -- Detail scroll keyboard handling
        local detail = self.detailScrollFrame
        if detail then
            if key == "PAGEDOWN" then
                detail:ScrollDown()
                return
            elseif key == "PAGEUP" then
                detail:ScrollUp()
                return
            end
        end
    end)
    
    -- Title
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOP", 0, -10)
    frame.title:SetText("Chat History")
    
    -- Close button
    frame.closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.closeBtn:SetPoint("TOPRIGHT", -2, -2)
    frame.closeBtn:SetSize(24, 24)
    frame.closeBtn:SetScript("OnClick", function(self)
        local f = self:GetParent()
        if f then f:Hide() end
    end)
    frame.closeBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Close", 1, 1, 1)
        GameTooltip:Show()
    end)
    frame.closeBtn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
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
    frame.searchBox:SetScript("OnEditFocusGained", function(self) end)
    frame.searchBox:SetScript("OnEditFocusLost", function(self) end)
    
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
    
    -- Export button for detail view
    frame.exportBtn = CreateFrame("Button", nil, frame.detailFrame)
    frame.exportBtn:SetSize(85, 30)
    frame.exportBtn:SetPoint("TOPRIGHT", 25, -6)
    frame.exportBtn:SetNormalFontObject("GameFontNormal")
    frame.exportBtn:SetHighlightFontObject("GameFontHighlight")
    frame.exportBtn:SetText("Export")
    frame.exportBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-Button-Up")
    frame.exportBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-Button-Down")
    frame.exportBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-Button-Highlight", "ADD")
    frame.exportBtn:Hide() -- Hidden until a conversation is selected
    frame.exportBtn:SetScript("OnClick", function(self)
        if self.playerKey then
            addon:ShowChatExportDialog(self.playerKey, self.displayName)
        end
    end)
    frame.exportBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Export Chat", 1, 1, 1)
        GameTooltip:AddLine("Export this conversation to copyable text", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    frame.exportBtn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    -- Detail scroll frame with proper scrolling support
    frame.detailScrollFrame = CreateFrame("ScrollingMessageFrame", nil, frame.detailFrame)
    frame.detailScrollFrame:SetPoint("TOPLEFT", 10, -35)
    frame.detailScrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
    frame.detailScrollFrame:SetFading(false)
    frame.detailScrollFrame:SetMaxLines(addon.MAX_HISTORY_LINES)
    frame.detailScrollFrame:SetFont(addon:GetSetting("fontFamily") or "Fonts\\FRIZQT__.TTF", addon:GetSetting("messageFontSize") or 14, (select(3, ChatFontNormal:GetFont())) or "")
    frame.detailScrollFrame:SetJustifyH("LEFT")
    frame.detailScrollFrame:SetHyperlinksEnabled(true)
    frame.detailScrollFrame:EnableMouse(true)
    frame.detailScrollFrame:SetMouseMotionEnabled(true)
    frame.detailScrollFrame:SetMouseClickEnabled(true)
    
    -- Create scrollbar for detail view
    frame.detailScrollBar = CreateFrame("Slider", nil, frame.detailFrame, "UIPanelScrollBarTemplate")
    frame.detailScrollBar:SetPoint("TOPRIGHT", -5, -40)
    frame.detailScrollBar:SetPoint("BOTTOMRIGHT", -5, 15)
    frame.detailScrollBar:SetMinMaxValues(0, 1)
    frame.detailScrollBar:SetValueStep(1)
    frame.detailScrollBar:SetValue(0)
    frame.detailScrollBar:SetWidth(16)
    frame.detailScrollBar:SetScript("OnValueChanged", function(self, value)
        -- Invert the scroll direction: scrollbar at bottom = scroll offset 0 (showing most recent)
        local _, maxValue = self:GetMinMaxValues()
        local invertedValue = maxValue - value
        frame.detailScrollFrame:SetScrollOffset(math.floor(invertedValue))
    end)
    
    -- Update scrollbar range when messages are displayed
    frame.detailScrollBar.UpdateRange = function()
        local numMessages = frame.detailScrollFrame:GetNumMessages()
        local maxScroll = math.max(0, numMessages)
        frame.detailScrollBar:SetMinMaxValues(0, maxScroll)
        -- Set scrollbar to bottom position (value = maxScroll means bottom of scrollbar)
        frame.detailScrollBar:SetValue(maxScroll)
    end
    frame.detailScrollFrame:SetScript("OnHyperlinkClick", function(self, link, text, button)
        addon:DebugMessage("Hyperlink clicked in history:", link, text, button)
        
        -- Handle chatfilter links manually
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
                     -- Update history DB
                     local playerKey = addon.historyFrame and addon.historyFrame.exportBtn and addon.historyFrame.exportBtn.playerKey
                     if playerKey and WhisperManager_HistoryDB and WhisperManager_HistoryDB[playerKey] then
                         local history = WhisperManager_HistoryDB[playerKey]
                         for i = #history, 1, -1 do
                             if history[i].m and history[i].m:find(link, 1, true) then
                                 history[i].m = newText
                                 break
                             end
                         end
                         -- Refresh display
                         addon:ShowHistoryDetail(playerKey, addon.historyFrame.exportBtn.displayName)
                     end
                 else
                     addon:Print("Unable to reveal message: The original text is no longer in the game memory (session expired).")
                 end
             end
             return
        end

        -- Use SetItemRef which allows other addons to hook and modify behavior
        -- This is the standard WoW API for handling all hyperlink clicks
        SetItemRef(link, text, button, self)
    end)
    frame.detailScrollFrame:SetScript("OnHyperlinkEnter", function(self, link, text, button)
        -- Note: ShowUIPanel is protected, use GameTooltip:Show() instead
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetHyperlink(link)
        GameTooltip:Show()
    end)
    frame.detailScrollFrame:SetScript("OnHyperlinkLeave", function(self)
        -- Note: HideUIPanel is protected, use GameTooltip:Hide() instead
        GameTooltip:Hide()
    end)
    
    -- Enable mouse wheel scrolling
    frame.detailScrollFrame:EnableMouseWheel(true)
    frame.detailScrollFrame:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then
            self:ScrollUp()
        else
            self:ScrollDown()
        end
    end)
    
    -- When shown, ensure this frame receives keyboard input and is focused
    frame:SetScript("OnShow", function(self)
        -- Bring to front
        self:Raise()
        -- Clear any EditBox focus so the frame receives OnKeyDown events
        if self.searchBox and type(self.searchBox.ClearFocus) == "function" then
            pcall(function() self.searchBox:ClearFocus() end)
        end
        -- Clear global keyboard focus (nil) to ensure our frame's OnKeyDown receives keys
        pcall(function() SetKeyboardFocus(nil) end)
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
    self:ToggleRecentChatsFrame()
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
        btn:SetSize(180, 37)
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
        btn.timeText:SetPoint("TOPLEFT", btn.nameText, "BOTTOMLEFT", 0, -2)
        btn.timeText:SetText(self.GetTimeAgo(conv.lastTimestamp))
        btn.timeText:SetTextColor(0.7, 0.7, 0.7)
        
        -- Click to show detail
        btn:SetScript("OnClick", function()
            addon:ShowHistoryDetail(conv.playerKey, conv.displayName)
        end)
        
        yOffset = yOffset + 41
    end
    
    scrollChild:SetHeight(math.max(yOffset, 1))
end

function addon:FilterHistoryList(filterText)
    self:RefreshHistoryList(filterText)
end

function addon:ShowHistoryDetail(playerKey, displayName)
    if not self.historyFrame then return end
    
    local detailTitle = self.historyFrame.detailTitle
    local detailScroll = self.historyFrame.detailScrollFrame
    local exportBtn = self.historyFrame.exportBtn
    
    detailTitle:SetText(displayName)
    detailScroll:Clear()
    
    -- Show export button and store player info
    if exportBtn then
        exportBtn.playerKey = playerKey
        exportBtn.displayName = displayName
        exportBtn:Show()
    end
    
    if not WhisperManager_HistoryDB or not WhisperManager_HistoryDB[playerKey] then
        detailScroll:AddMessage("No message history found.")
        return
    end
    
    local history = WhisperManager_HistoryDB[playerKey]
    local playerName, playerRealm = UnitName("player")
    local realm = (playerRealm or GetRealmName()):gsub("%s+", "")
    local fullPlayerName = playerName .. "-" .. realm
    
    -- Determine if this is a BNet conversation
    local isBNet = playerKey:match("^bnet_") ~= nil
    
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
        
        return string.format("--^-- (%s) %s --^--", relative, dateStr)
    end
    
    for i, entry in ipairs(history) do
        -- Support both old and new format
        local timestamp = entry.t or entry.timestamp
        local author = entry.a or entry.author
        local message = entry.m or entry.message
        -- Convert numeric class ID to class token
        local classToken = nil
        if entry.c then
            classToken = addon.CLASS_ID_TO_TOKEN[entry.c]
        end
        
        -- Resolve BNet IDs (|KpXX|k) to display names for BNet conversations
        if isBNet and author then
            author = addon:ResolveBNetID(author, playerKey)
        end
        
        if timestamp and author and message then
            -- Timestamp with customizable color
            local tsColor = self.settings.timestampColor or {r = 0.8078, g = 0.4863, b = 0.0}
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
            -- Trim any leading whitespace so there is exactly one space after the colon
            formattedText = formattedText:gsub("^%s+", "")
            
            -- Format message - concatenate parts WITHOUT string.format to preserve hyperlinks
            -- Simple concatenation preserves all escape sequences
            local formattedMessage = timeString .. " " .. coloredAuthor .. " " .. messageColor .. formattedText .. "|r"
            detailScroll:AddMessage(formattedMessage)

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
                local label = GetRelativeDateLabel(timestamp)
                detailScroll:AddMessage(label, 0.8078, 0.4863, 0.0)
            end
        end
    end
    
    -- Scroll to bottom and update scrollbar
    C_Timer.After(0, function()
        detailScroll:ScrollToBottom()
        if self.historyFrame and self.historyFrame.detailScrollBar and self.historyFrame.detailScrollBar.UpdateRange then
            self.historyFrame.detailScrollBar.UpdateRange()
        end
    end)
end
