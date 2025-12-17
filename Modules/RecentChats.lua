-- ============================================================================
-- RecentChats.lua - Recent chats UI frame
-- ============================================================================

local addon = WhisperManager;

function addon:CreateRecentChatsFrame()
    local frame = CreateFrame("Frame", "WhisperManager_RecentChats", addon:GetOverlayParent(), "BackdropTemplate")
    frame:SetSize(300, 400)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata(addon.OVERLAY_STRATA)
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
    frame.scrollFrame:SetPoint("TOPLEFT", 10, -50)
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
    return frame
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
    if not self.recentChatsFrame then
        self:CreateRecentChatsFrame()
        self:LoadRecentChatsPosition()
    end
    
    if self.recentChatsFrame:IsShown() then
        self.recentChatsFrame:Hide()
    else
        -- Close history frame if it's open
        if self.historyFrame and self.historyFrame:IsShown() then
            self.historyFrame:Hide()
        end
        
        self:RefreshRecentChats()
        self.recentChatsFrame:Show()
    end
end

function addon:RefreshRecentChats()
    if not self.recentChatsFrame then return end
    
    -- Clear existing buttons
    local scrollChild = self.recentChatsFrame.scrollChild
    for _, child in ipairs({scrollChild:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end
    
    if not WhisperManager_RecentChats then
        WhisperManager_RecentChats = {}
    end
    
    -- Convert to sorted array
    local chats = {}
    for playerKey, data in pairs(WhisperManager_RecentChats) do
        if playerKey and data and data.lastMessageTime then
            local displayName = self:GetDisplayNameFromKey(playerKey) or "Unknown"
            self:DebugMessage("RecentChats: playerKey =", playerKey, "displayName =", displayName)
            table.insert(chats, {
                playerKey = playerKey,
                displayName = displayName,
                lastMessageTime = data.lastMessageTime,
                isRead = data.isRead or false,
                isBNet = data.isBNet or false,
            })
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
        btn.nameText:SetText(chat.displayName or "Unknown")
        btn.nameText:SetJustifyH("LEFT")
        
        -- Desaturate if read
        if chat.isRead then
            btn.nameText:SetTextColor(0.6, 0.6, 0.6)
        else
            btn.nameText:SetTextColor(1, 1, 1)
        end
        
        -- Time text
        btn.timeText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.timeText:SetPoint("BOTTOMLEFT", 5, 5)
        btn.timeText:SetText(self.GetTimeAgo(chat.lastMessageTime))
        btn.timeText:SetTextColor(0.7, 0.7, 0.7)
        
        -- Click to open
        btn:SetScript("OnClick", function()
            addon:DebugMessage("[RecentChats] Click handler called for playerKey:", chat.playerKey)
            addon:DebugMessage("[RecentChats] isBNet:", chat.isBNet)
            addon:DebugMessage("[RecentChats] displayName:", chat.displayName)
            
            local success = false
            local errorOccurred = false
            
            -- Wrap in pcall to catch any errors
            local pcallSuccess, result = pcall(function()
                if chat.isBNet then
                    -- Extract BattleTag from key
                    local battleTag = chat.playerKey:match("bnet_(.+)")
                    addon:DebugMessage("[RecentChats] Extracted BattleTag:", battleTag)
                    if battleTag then
                        -- Find the current BNet ID for this BattleTag
                        local numBNetTotal, numBNetOnline = BNGetNumFriends()
                        addon:DebugMessage("[RecentChats] Searching", numBNetTotal, "BNet friends")
                        for i = 1, numBNetTotal do
                            local accountInfo = C_BattleNet.GetFriendAccountInfo(i)
                            if accountInfo and accountInfo.battleTag == battleTag then
                                addon:DebugMessage("[RecentChats] Found matching BattleTag, calling OpenBNetConversation")
                                return addon:OpenBNetConversation(accountInfo.bnetAccountID, chat.displayName)
                            end
                        end
                        addon:DebugMessage("[RecentChats] BNet friend not found in friends list")
                        addon:Print("|cffff8800BattleNet friend not found. They may have been removed from your friends list.|r")
                        return false
                    end
                else
                    -- Use the playerKey directly (it has the correct realm)
                    -- OpenConversation/ResolvePlayerIdentifiers will handle the c_ prefix correctly
                    addon:DebugMessage("[RecentChats] Calling OpenConversation with playerKey:", chat.playerKey)
                    return addon:OpenConversation(chat.playerKey)
                end
                return false
            end)
            
            if pcallSuccess then
                success = result
                addon:DebugMessage("[RecentChats] OpenConversation returned:", success)
            else
                errorOccurred = true
                addon:DebugMessage("[RecentChats] ERROR occurred:", result)
                addon:Print("|cffff0000Error opening conversation: " .. tostring(result) .. "|r")
            end
            
            -- Only close the menu if the window was successfully opened/shown
            -- If in combat, the operation is queued and success=false, so keep menu open
            -- If there was an error, also close the menu to prevent confusion
            if success or errorOccurred then
                addon:DebugMessage("[RecentChats] Hiding recent chats frame (success=" .. tostring(success) .. ", error=" .. tostring(errorOccurred) .. ")")
                addon.recentChatsFrame:Hide()
            else
                addon:DebugMessage("[RecentChats] Failed to open conversation or in combat - keeping frame open")
            end
        end)
        
        yOffset = yOffset + 45
    end
    
    scrollChild:SetHeight(math.max(yOffset, 1))
end
