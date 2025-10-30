-- ============================================================================
-- FloatingButton.lua - Floating button UI
-- ============================================================================

local addon = WhisperManager;

-- ============================================================================
-- Floating Button Functions
-- ============================================================================

function addon:CreateFloatingButton()
    local btn = CreateFrame("Button", "WhisperManager_FloatingButton", UIParent)
    btn:SetSize(40, 40)
    btn:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
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
        GameTooltip:AddLine("Right Click: History/Search", 1, 1, 1)
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
            addon:ToggleHistoryFrame()
        end
    end)
    
    addon.floatingButton = btn
    addon:LoadFloatingButtonPosition()
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
    self.floatingButton:SetPoint(pos.point, UIParent, pos.relativePoint, pos.xOfs, pos.yOfs)
end
