-- ============================================================================
-- CopyChat.lua - Copy chat history to copyable text box (Prat-style)
-- ============================================================================

local addon = WhisperManager;

-- Helper function to strip color codes and hyperlinks for plain text
local function StripColorCodes(text)
    if not text then return "" end
    -- Remove color codes
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    -- Remove hyperlinks but keep the text
    text = text:gsub("|H.-|h(.-)|h", "%1")
    text = text:gsub("|H.-|h", "")
    text = text:gsub("|h", "")
    -- Remove textures
    text = text:gsub("|T.-|t", "")
    return text
end

-- ============================================================================
-- Copy Chat Frame (Prat-style scrollable frame)
-- ============================================================================

function addon:CreateCopyChatFrame()
    if self.copyChatFrame then return self.copyChatFrame end
    
    -- Create main frame
    local frame = CreateFrame("Frame", "WhisperManager_CopyChatFrame", UIParent, "BackdropTemplate")
    frame:SetSize(600, 400)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0, 0, 0, 1)
    frame:Hide()
    
    -- Title
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOP", 0, -15)
    frame.title:SetText("Copy Chat History")
    
    -- Instructions
    frame.instructions = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.instructions:SetPoint("TOP", frame.title, "BOTTOM", 0, -5)
    frame.instructions:SetText("CTRL+A to select all, CTRL+C to copy")
    
    -- Close button
    frame.closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.closeBtn:SetPoint("TOPRIGHT", -5, -5)
    frame.closeBtn:SetSize(32, 32)
    
    -- Scroll frame
    frame.scrollFrame = CreateFrame("ScrollFrame", "WhisperManager_CopyChatScrollFrame", frame, "UIPanelScrollFrameTemplate")
    frame.scrollFrame:SetPoint("TOPLEFT", 20, -55)
    frame.scrollFrame:SetPoint("BOTTOMRIGHT", -35, 15)
    
    -- Edit box (multi-line)
    frame.editBox = CreateFrame("EditBox", "WhisperManager_CopyChatEditBox", frame.scrollFrame)
    frame.editBox:SetMultiLine(true)
    frame.editBox:SetFontObject(ChatFontNormal)
    frame.editBox:SetWidth(550)
    frame.editBox:SetMaxLetters(0)
    frame.editBox:SetAutoFocus(false)
    frame.editBox:SetScript("OnEscapePressed", function(self)
        frame:Hide()
    end)
    frame.editBox:SetScript("OnTextChanged", function(self)
        ScrollingEdit_OnTextChanged(self, self:GetParent())
    end)
    frame.editBox:SetScript("OnCursorChanged", function(self, x, y, width, height)
        ScrollingEdit_OnCursorChanged(self, x, y, width, height)
    end)
    
    frame.scrollFrame:SetScrollChild(frame.editBox)
    
    self.copyChatFrame = frame
    return frame
end

-- ============================================================================
-- Show Copy Chat Dialog
-- ============================================================================

function addon:ShowCopyChatDialog(playerKey, displayName)
    if not playerKey then return end
    
    -- Get history for this player
    local history = WhisperManager_HistoryDB and WhisperManager_HistoryDB[playerKey]
    if not history or #history == 0 then
        self:Print("No chat history found for " .. (displayName or playerKey))
        return
    end
    
    -- Create frame if it doesn't exist
    local frame = self:CreateCopyChatFrame()
    
    -- Build text content
    local lines = {}
    local playerName, playerRealm = UnitName("player")
    local realm = (playerRealm or GetRealmName()):gsub("%s+", "")
    local fullPlayerName = playerName .. "-" .. realm
    
    for i, entry in ipairs(history) do
        local timestamp = entry.t or entry.timestamp
        local author = entry.a or entry.author
        local message = entry.m or entry.message
        local isSystemMessage = entry.s
        
        if timestamp and author and message then
            -- Format timestamp
            local timeStr = date("[%m/%d/%Y %H:%M:%S]", timestamp)
            
            if isSystemMessage then
                -- System message
                local plainMessage = StripColorCodes(message)
                lines[#lines + 1] = timeStr .. " [SYSTEM] " .. plainMessage
            else
                -- Regular message - strip color codes and hyperlinks
                local plainMessage = StripColorCodes(message)
                local authorName = author:match("^([^%-]+)") or author
                lines[#lines + 1] = timeStr .. " " .. authorName .. ": " .. plainMessage
            end
        end
    end
    
    local text = table.concat(lines, "\n")
    
    -- Update frame
    frame.title:SetText("Copy Chat History - " .. (displayName or playerKey))
    frame.editBox:SetText(text)
    frame.editBox:SetCursorPosition(0)
    frame.editBox:HighlightText(0)
    
    -- Show frame
    frame:Show()
    frame:Raise()
    
    -- Focus and select all text
    C_Timer.After(0.1, function()
        if frame:IsShown() then
            frame.editBox:SetFocus()
            frame.editBox:HighlightText()
        end
    end)
end

addon:DebugMessage("CopyChat loaded")
