-- RecentChats.lua - Recent chats UI frame
local addon = WhisperManager;

function addon:CreateRecentChatsFrame()
    local frame = CreateFrame("Frame", "WhisperManager_RecentChats", addon:GetOverlayParent(), "BackdropTemplate")
    frame:SetSize(300, 400)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        addon:SaveRecentChatsPosition()
    end)
    frame:SetScript("OnHide", function(self)
        addon:SaveRecentChatsPosition()
    end)
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    local recentColor = addon:GetSetting("recentChatBackgroundColor") or {r = 0, g = 0, b = 0}
    local recentAlpha = addon:GetSetting("recentChatBackgroundAlpha") or 0.9
    frame:SetBackdropColor(recentColor.r, recentColor.g, recentColor.b, recentAlpha)
    frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    frame:Hide()

    frame:SetScript("OnShow", function(self)
        addon:EnsureFrameOverlay(self)
    end)
    
    -- ESC key handling - don't use UISpecialFrames to avoid conflicts
    frame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Hide()
        end
    end)
    frame:SetPropagateKeyboardInput(true)
    
    -- Title
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOP", 0, -10)
    frame.title:SetText("Recent Chats")

    -- Search box for player name filtering
    frame.searchBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    frame.searchBox:SetSize(200, 24)
    frame.searchBox:SetPoint("TOPLEFT", 10, -52)
    frame.searchBox:SetAutoFocus(false)
    frame.searchBox:SetScript("OnTextChanged", function()
        addon:RefreshRecentChats()
    end)
    frame.searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    frame.searchLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.searchLabel:SetPoint("LEFT", frame.searchBox, "RIGHT", 8, 0)
    frame.searchLabel:SetText("Search")

    -- Session-only toggle: show all history entries (can be heavy on very large histories)
    if addon.__recentChatsShowAll == nil then
        addon.__recentChatsShowAll = false
    end

    frame.showAllCheckbox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    frame.showAllCheckbox:SetSize(24, 24)
    frame.showAllCheckbox:SetPoint("TOPRIGHT", -24, -50)
    frame.showAllCheckbox:SetChecked(addon.__recentChatsShowAll)
    frame.showAllCheckbox:SetScript("OnClick", function(self)
        addon.__recentChatsShowAll = self:GetChecked() == true
        addon:RefreshRecentChats()
    end)
    frame.showAllCheckbox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Show All")
        GameTooltip:AddLine("When unchecked: only last 7 days are shown.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Warning: enabling this may cause lag or crashes on very large histories.", 1.0, 0.3, 0.3, true)
        GameTooltip:Show()
    end)
    frame.showAllCheckbox:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    frame.showAllLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.showAllLabel:SetPoint("LEFT", frame.showAllCheckbox, "RIGHT", 2, 0)
    frame.showAllLabel:SetText("All")
    
    -- Combat status indicator
    frame.combatWarning = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.combatWarning:SetPoint("TOP", 0, -30)
    frame.combatWarning:SetTextColor(1, 0.5, 0)
    frame.combatWarning:SetText("|cffff8800⚔ In Combat - New windows queued|r")
    frame.combatWarning:Hide()
    
    -- Update combat status on show and periodically
    frame:SetScript("OnUpdate", function(self)
        if InCombatLockdown() then
            if not self.combatWarning:IsShown() then
                self.combatWarning:Show()
            end
        else
            if self.combatWarning:IsShown() then
                self.combatWarning:Hide()
            end
        end
    end)
    
    -- Close button
    frame.closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.closeBtn:SetPoint("TOPRIGHT", -2, -2)
    frame.closeBtn:SetSize(24, 24)
    
    -- Scroll frame for chat list (adjust top to account for combat warning)
    frame.scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    frame.scrollFrame:SetPoint("TOPLEFT", 10, -80)
    frame.scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
    
    frame.scrollChild = CreateFrame("Frame", nil, frame.scrollFrame)
    frame.scrollChild:SetSize(260, 1)
    frame.scrollFrame:SetScrollChild(frame.scrollChild)
    
    -- Enable mouse wheel scrolling for recent chats
    frame.scrollFrame:EnableMouseWheel(true)
    frame.scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local scrollBar = self.ScrollBar
        if scrollBar then
            local current = scrollBar:GetValue()
            local _, maxValue = scrollBar:GetMinMaxValues()
            local step = 40 * delta  -- Scroll amount per wheel tick
            scrollBar:SetValue(math.max(0, math.min(maxValue, current - step)))
        end
    end)
    
    addon.recentChatsFrame = frame
    
    -- Initial population
    addon:RefreshRecentChats()
    
    return frame
end

function addon:RefreshRecentChats()
    if not addon.recentChatsFrame then return end
    local scrollChild = addon.recentChatsFrame.scrollChild
    if not scrollChild then return end
    
    -- Clear existing children
    local children = {scrollChild:GetChildren()}
    for _, child in ipairs(children) do
        child:Hide()
        child:SetParent(nil)
    end
    
    if not WhisperManager_RecentChats then
        WhisperManager_RecentChats = {}
    end
    
    -- Convert to sorted array using both recent chat data and history data
    local chatsByKey = {}

    for playerKey, data in pairs(WhisperManager_RecentChats) do
        if playerKey and data and data.lastMessageTime then
            local displayName = self:GetDisplayNameFromKey(playerKey) or "Unknown"
            chatsByKey[playerKey] = {
                playerKey = playerKey,
                displayName = displayName,
                lastMessageTime = data.lastMessageTime,
                isRead = data.isRead, -- Can be nil, false, or true
                isBNet = data.isBNet or false,
                autoHideWindow = data.autoHideWindow == true,
            }
        end
    end

    if WhisperManager_HistoryDB then
        for playerKey, history in pairs(WhisperManager_HistoryDB) do
            if playerKey ~= "__schema" and type(history) == "table" and #history > 0 then
                local existing = chatsByKey[playerKey]
                local lastEntry = history[#history]
                local lastMessageTime = (lastEntry and (lastEntry.t or lastEntry.timestamp)) or 0

                if existing then
                    if existing.lastMessageTime == nil or existing.lastMessageTime < lastMessageTime then
                        existing.lastMessageTime = lastMessageTime
                    end
                else
                    chatsByKey[playerKey] = {
                        playerKey = playerKey,
                        displayName = self:GetDisplayNameFromKey(playerKey) or "Unknown",
                        lastMessageTime = lastMessageTime,
                        isRead = true,
                        isBNet = playerKey:match("^bnet_") ~= nil,
                        autoHideWindow = false,
                    }
                end
            end
        end
    end

    local filterText = ""
    if addon.recentChatsFrame and addon.recentChatsFrame.searchBox then
        filterText = addon.recentChatsFrame.searchBox:GetText() or ""
    end
    filterText = filterText:lower()

    local showAll = addon.__recentChatsShowAll == true
    local cutoffTime = time() - (7 * 24 * 60 * 60)

    local chats = {}
    for _, chat in pairs(chatsByKey) do
        local name = (chat.displayName or ""):lower()
        local withinWindow = showAll or ((chat.lastMessageTime or 0) >= cutoffTime)
        if withinWindow and (filterText == "" or name:find(filterText, 1, true)) then
            table.insert(chats, chat)
        end
    end
    
    -- Sort by most recent first
    table.sort(chats, function(a, b)
        return a.lastMessageTime > b.lastMessageTime
    end)
    
    -- Create buttons for each chat
    local yOffset = 0
    for i, chat in ipairs(chats) do
        local btn = CreateFrame("Button", nil, scrollChild)
        btn:SetSize(260, 40)
        btn:SetPoint("TOPLEFT", 0, -yOffset)
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        
        -- Background
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        if chat.autoHideWindow then
            btn.bg:SetColorTexture(0.45, 0.4, 0.1, 0.55)
        else
            btn.bg:SetColorTexture(0.2, 0.2, 0.2, 0.5)
        end
        
        -- Highlight
        btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
        btn.highlight:SetAllPoints()
        btn.highlight:SetColorTexture(0.3, 0.3, 0.3, 0.5)
        
        -- Unread Indicator (Left border strip)
        if chat.isRead == false and not chat.autoHideWindow then
            btn.unreadIndicator = btn:CreateTexture(nil, "OVERLAY")
            btn.unreadIndicator:SetPoint("LEFT", 0, 0)
            btn.unreadIndicator:SetSize(4, 40)
            btn.unreadIndicator:SetColorTexture(0, 1, 0, 1) -- Green strip for unread
            
            -- Also highlight background slightly green
            btn.bg:SetColorTexture(0.2, 0.4, 0.2, 0.5)
        end
        
        -- Name text
        btn.nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btn.nameText:SetPoint("TOPLEFT", 10, -5)
        btn.nameText:SetText(chat.displayName or "Unknown")
        btn.nameText:SetJustifyH("LEFT")
        
        if chat.autoHideWindow then
            btn.nameText:SetTextColor(1.0, 0.9, 0.2)
        elseif chat.isRead ~= false then
            btn.nameText:SetTextColor(0.6, 0.6, 0.6)
        else
            btn.nameText:SetTextColor(1, 1, 1)
        end
        
        -- Time text
        btn.timeText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.timeText:SetPoint("BOTTOMLEFT", 10, 5)
        btn.timeText:SetText(self.GetTimeAgo(chat.lastMessageTime))
        btn.timeText:SetTextColor(0.7, 0.7, 0.7)
        
        -- Click to open
        btn:SetScript("OnClick", function(_, button)
            if button == "RightButton" then
                local newState = not addon:IsChatAutoHidden(chat.playerKey)
                addon:SetChatAutoHidden(chat.playerKey, newState)
                if newState then
                    addon:Print("|cffffff00Auto-hide enabled|r for " .. (chat.displayName or "Unknown") .. ".")
                else
                    addon:Print("|cff00ff00Auto-hide disabled|r for " .. (chat.displayName or "Unknown") .. ".")
                end
                return
            end

            addon:DebugMessage("[RecentChats] Click handler called for playerKey:", chat.playerKey)
            
            -- Mark as read immediately on click
            addon:MarkChatAsRead(chat.playerKey)
            
            local success = false
            local errorOccurred = false
            
            -- Wrap in pcall to catch any errors
            local pcallSuccess, result = pcall(function()
                if chat.isBNet then
                    -- Extract BattleTag from key
                    local battleTag = chat.playerKey:match("bnet_(.+)")
                    if battleTag then
                        -- Find the current BNet ID for this BattleTag
                        local numBNetTotal, numBNetOnline = BNGetNumFriends()
                        for i = 1, numBNetTotal do
                            local accountInfo = C_BattleNet.GetFriendAccountInfo(i)
                            if accountInfo and accountInfo.battleTag == battleTag then
                                return addon:OpenBNetConversation(accountInfo.bnetAccountID, chat.displayName)
                            end
                        end
                        addon:Print("|cffff8800BattleNet friend not found. They may have been removed from your friends list.|r")
                        return false
                    end
                else
                    return addon:OpenConversation(chat.playerKey)
                end
                return false
            end)
            
            if pcallSuccess then
                success = result
            else
                errorOccurred = true
                addon:Print("|cffff0000Error opening conversation: " .. tostring(result) .. "|r")
            end
            
            if success or errorOccurred then
                addon.recentChatsFrame:Hide()
            end
        end)
        
        yOffset = yOffset + 45
    end
    
    scrollChild:SetHeight(math.max(yOffset, 1))
end

function addon:SaveRecentChatsPosition()
    if not self.recentChatsFrame then return end
    if not WhisperManager_Config then WhisperManager_Config = {} end
    
    local point, _, relativePoint, xOfs, yOfs = self.recentChatsFrame:GetPoint(1)
    if point then
        WhisperManager_Config.recentChatsPos = {
            point = point,
            relativePoint = relativePoint,
            xOfs = xOfs,
            yOfs = yOfs,
        }
    end
end

function addon:LoadRecentChatsPosition()
    if not self.recentChatsFrame then return end
    if not WhisperManager_Config or not WhisperManager_Config.recentChatsPos then return end
    
    local pos = WhisperManager_Config.recentChatsPos
    self.recentChatsFrame:ClearAllPoints()
    self.recentChatsFrame:SetPoint(pos.point, addon:GetOverlayParent(), pos.relativePoint, pos.xOfs, pos.yOfs)
end

function addon:ToggleRecentChatsFrame()
    if InCombatLockdown() then
        if self.recentChatsFrame and self.recentChatsFrame:IsShown() then
            self.recentChatsFrame:Hide()
            return
        end

        if not self.__pendingRecentChatsOpen then
            self.__pendingRecentChatsOpen = true
            table.insert(self.combatQueue, function()
                if not addon.__pendingRecentChatsOpen then return end
                addon.__pendingRecentChatsOpen = nil
                if InCombatLockdown() then return end

                local chatModeEnabledAfterCombat = addon.IsChatModeEnabled and addon:IsChatModeEnabled()
                if not chatModeEnabledAfterCombat then
                    addon:CloseAllWindows()
                end

                if not addon.recentChatsFrame then
                    addon:CreateRecentChatsFrame()
                    addon:LoadRecentChatsPosition()
                end

                if addon.recentChatsFrame and not addon.recentChatsFrame:IsShown() then
                    addon:RefreshRecentChats()
                    addon.recentChatsFrame:Show()
                end
            end)
            self:Print("|cffff8800Recent Chats cannot open during combat. It will open after combat ends.|r")
        end
        return
    end

    local chatModeEnabled = self.IsChatModeEnabled and self:IsChatModeEnabled()
    if not chatModeEnabled then
        self:CloseAllWindows()
    end

    if not self.recentChatsFrame then
        self:CreateRecentChatsFrame()
        self:LoadRecentChatsPosition()
    end
    
    if self.recentChatsFrame:IsShown() then
        self.recentChatsFrame:Hide()
    else
        self:RefreshRecentChats()
        self.recentChatsFrame:Show()
    end
end
