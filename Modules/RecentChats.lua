-- ============================================================================
-- RecentChats.lua - Recent chats UI frame
-- ============================================================================

local addon = WhisperManager;

-- ============================================================================
-- Recent Chats Frame Creation
-- ============================================================================

function addon:CreateRecentChatsFrame()
    local frame = CreateFrame("Frame", "WhisperManager_RecentChats", UIParent, "BackdropTemplate")
    frame:SetSize(300, 400)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
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
    frame:SetBackdropColor(0, 0, 0, 0.9)
    frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    frame:Hide()
    
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
    
    -- Close button
    frame.closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.closeBtn:SetPoint("TOPRIGHT", -2, -2)
    frame.closeBtn:SetSize(24, 24)
    
    -- Scroll frame for chat list
    frame.scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    frame.scrollFrame:SetPoint("TOPLEFT", 10, -40)
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
    self.recentChatsFrame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.xOfs, pos.yOfs)
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
            if chat.isBNet then
                -- Extract BattleTag from key
                local battleTag = chat.playerKey:match("bnet_(.+)")
                if battleTag then
                    -- Find the current BNet ID for this BattleTag
                    local numBNetTotal, numBNetOnline = BNGetNumFriends()
                    for i = 1, numBNetTotal do
                        local accountInfo = C_BattleNet.GetFriendAccountInfo(i)
                        if accountInfo and accountInfo.battleTag == battleTag then
                            addon:OpenBNetConversation(accountInfo.bnetAccountID, chat.displayName)
                            break
                        end
                    end
                end
            else
                -- Extract player name from key
                local playerName = chat.displayName
                addon:OpenConversation(playerName)
            end
            addon.recentChatsFrame:Hide()
        end)
        
        yOffset = yOffset + 45
    end
    
    scrollChild:SetHeight(math.max(yOffset, 1))
end
