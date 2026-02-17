-- Floating button UI
local addon = WhisperManager;

function addon:CreateFloatingButton()
    -- Don't create if it already exists
    if addon.floatingButton and addon.floatingButton:IsShown() then
        return
    end
    
    local btn = CreateFrame("Button", "WhisperManager_FloatingButton", addon:GetOverlayParent())
    btn:SetSize(64, 64)
    btn:SetPoint("CENTER", addon:GetOverlayParent(), "CENTER", 0, 0)
    btn:SetFrameStrata("DIALOG")
    btn:SetToplevel(true)
    btn:SetMovable(true)
    btn:EnableMouse(true)
    btn:RegisterForDrag("LeftButton")
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    
    -- Background
    btn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-Chat-Up")
    btn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    btn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-Chat-Down")
    
    -- Tooltip
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("WhisperManager", 1, 0.82, 0)
        GameTooltip:AddLine("Left Click: Recent Chats", 1, 1, 1)
        GameTooltip:AddLine("SHIFT+Right Click: Settings", 0.7, 0.7, 1)
        GameTooltip:AddLine("ALT+Left Click: Move", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    -- Drag to move with ALT held
    btn:SetScript("OnDragStart", function(self)
        if IsAltKeyDown() then
            self:StartMoving()
        end
    end)
    btn:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        addon:EnsureFrameOverlay(self)
        addon:SaveFloatingButtonPosition()
    end)
    
    -- Click handlers
    btn:SetScript("OnClick", function(self, button)
        if IsAltKeyDown() then
            return  -- Don't trigger clicks while moving
        end
        
        if button == "LeftButton" then
            addon:ToggleRecentChatsFrame()
        elseif button == "RightButton" then
            if IsShiftKeyDown() then
                addon:ToggleSettingsFrame()
            end
        end
    end)
    
    btn:SetScript("OnShow", function(self)
        addon:EnsureFrameOverlay(self)
    end)

    addon:EnsureFrameOverlay(btn)
    addon.floatingButton = btn
    addon:LoadFloatingButtonPosition()
    addon:EnsureFrameOverlay(btn)
end

function addon:SaveFloatingButtonPosition()
    if not self.floatingButton then return end
    if not WhisperManager_Config then WhisperManager_Config = {} end
    
    local point, _, relativePoint, xOfs, yOfs = self.floatingButton:GetPoint(1)
    WhisperManager_Config.buttonPos = {
        point = point,
        relativePoint = relativePoint,
        xOfs = xOfs,
        yOfs = yOfs,
    }
end

function addon:LoadFloatingButtonPosition()
    if not self.floatingButton then return end
    if not WhisperManager_Config or not WhisperManager_Config.buttonPos then return end
    
    local pos = WhisperManager_Config.buttonPos
    self.floatingButton:ClearAllPoints()
    self.floatingButton:SetPoint(pos.point, addon:GetOverlayParent(), pos.relativePoint, pos.xOfs, pos.yOfs)
end

function addon:UpdateFloatingButtonUnreadStatus()
    if not self.floatingButton then return end
    
    local hasUnread = false
    local unreadCount = 0
    if WhisperManager_RecentChats then
        for key, data in pairs(WhisperManager_RecentChats) do
            if data.isRead == false then
                hasUnread = true
                unreadCount = unreadCount + 1
                -- Don't break, count them for debug
            end
        end
    end
    
    if unreadCount > 0 then
        addon:DebugMessage("UpdateFloatingButtonUnreadStatus: Found " .. unreadCount .. " unread conversations.")
    end
    
    if hasUnread then
        -- Create glow if not exists
        if not self.floatingButton.glow then
            self.floatingButton.glow = self.floatingButton:CreateTexture(nil, "OVERLAY")
            self.floatingButton.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
            self.floatingButton.glow:SetBlendMode("ADD")
            self.floatingButton.glow:SetAlpha(0.8)
            self.floatingButton.glow:SetPoint("CENTER", 0, 0)
            self.floatingButton.glow:SetSize(70, 70)
            self.floatingButton.glow:SetVertexColor(0, 1, 0) -- Green glow
            
            -- Animation group
            self.floatingButton.glow.animGroup = self.floatingButton.glow:CreateAnimationGroup()
            self.floatingButton.glow.animGroup:SetLooping("REPEAT")
            
            local alpha = self.floatingButton.glow.animGroup:CreateAnimation("Alpha")
            alpha:SetFromAlpha(0.2)
            alpha:SetToAlpha(1.0)
            alpha:SetDuration(0.8)
            alpha:SetSmoothing("IN_OUT")
            alpha:SetOrder(1)
            
            local alpha2 = self.floatingButton.glow.animGroup:CreateAnimation("Alpha")
            alpha2:SetFromAlpha(1.0)
            alpha2:SetToAlpha(0.2)
            alpha2:SetDuration(0.8)
            alpha2:SetSmoothing("IN_OUT")
            alpha2:SetOrder(2)
        end
        
        self.floatingButton.glow:Show()
        if not self.floatingButton.glow.animGroup:IsPlaying() then
            self.floatingButton.glow.animGroup:Play()
        end
    else
        if self.floatingButton.glow then
            self.floatingButton.glow:Hide()
            self.floatingButton.glow.animGroup:Stop()
        end
    end
end
