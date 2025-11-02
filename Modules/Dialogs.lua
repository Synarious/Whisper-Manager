-- ============================================================================
-- Dialogs.lua - URL copy dialog and chat export dialog
-- ============================================================================
-- This module handles popup dialogs for:
-- - Copying URLs from hyperlinks
-- - Exporting chat history to copyable plain text
-- ============================================================================

local addon = WhisperManager;

-- ============================================================================
-- SECTION 1: URL Detection and Click Handling
-- ============================================================================

-- URL detection patterns (from WIM/Prat)
local URL_PATTERNS = {
    -- X://Y url
    "^(%a[%w+.-]+://%S+)",
    "%f[%S](%a[%w+.-]+://%S+)",
    -- www.X.Y url
    "^(www%.[-%w_%%]+%.(%a%a+))",
    "%f[%S](www%.[-%w_%%]+%.(%a%a+))",
    -- X@Y.Z email
    "(%S+@[%w_.-%%]+%.(%a%a+))",
    -- XXX.YYY.ZZZ.WWW:VVVV/UUUUU IPv4 with port and path
    "^([0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d:[0-6]?%d?%d?%d?%d/%S+)",
    "%f[%S]([0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d:[0-6]?%d?%d?%d?%d/%S+)",
    -- XXX.YYY.ZZZ.WWW:VVVV IPv4 with port
    "^([0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d:[0-6]?%d?%d?%d?%d)%f[%D]",
    "%f[%S]([0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d:[0-6]?%d?%d?%d?%d)%f[%D]",
    -- X.Y.Z:WWWW/VVVVV url with port and path
    "^([%w_.-%%]+[%w_-%%]%.(%a%a+):[0-6]?%d?%d?%d?%d/%S+)",
    "%f[%S]([%w_.-%%]+[%w_-%%]%.(%a%a+):[0-6]?%d?%d?%d?%d/%S+)",
    -- X.Y.Z/WWWWW url with path
    "^([%w_.-%%]+[%w_-%%]%.(%a%a+)/%S+)",
    "%f[%S]([%w_.-%%]+[%w_-%%]%.(%a%a+)/%S+)",
    -- X.Y.Z url
    "^([-%w_%%]+%.[-%w_%%]+%.(%a%a+))",
    "%f[%S]([-%w_%%]+%.[-%w_%%]+%.(%a%a+))",
}

--- Format a URL as a clickable hyperlink
-- @param url string The URL to format
-- @return string Formatted hyperlink with cyan color
local function FormatURLAsLink(url)
    if not url or url == "" then return "" end
    -- Escape % characters
    url = url:gsub('%%', '%%%%')
    -- Create a clickable link with custom prefix
    return "|cff00ffff|Hwm_url:" .. url .. "|h[" .. url .. "]|h|r"
end

--- Convert URLs in text to clickable links
-- @param text string Text to process
-- @return string Text with URLs converted to hyperlinks
function addon:ConvertURLsToLinks(text)
    if not text or text == "" then return text end
    
    local result = text
    
    -- Process each pattern
    for _, pattern in ipairs(URL_PATTERNS) do
        result = result:gsub(pattern, FormatURLAsLink)
    end
    
    return result
end

--- Extract plain URL from hyperlink
-- @param link string Hyperlink string (e.g., "wm_url:http://example.com")
-- @return string|nil Plain URL or nil if extraction fails
local function ExtractURL(link)
    if type(link) ~= "string" then return nil end
    
    if link:match("^wm_url:(.+)") then
        return link:match("^wm_url:(.+)")
    end
    
    return nil
end

--- Show URL copy dialog with extracted URL
-- @param url string URL to display in dialog
function addon:ShowURLCopyDialog(url)
    addon:Print("ShowURLCopyDialog called with URL: " .. tostring(url))
    
    if not url or url == "" then 
        addon:Print("|cffff0000URL is empty or nil!|r")
        return 
    end
    
    -- Unescape any escaped characters
    url = url:gsub('%%%%', '%%')
    
    addon:Print("URL after unescape: " .. tostring(url))
    
    -- Store URL in a variable that the dialog can access
    local urlToShow = url
    
    StaticPopupDialogs["WHISPERMANAGER_SHOW_URL"] = {
        text = "URL: (CTRL+A -> CTRL+C to Copy)",
        button1 = OKAY,
        hasEditBox = 1,
        hasWideEditBox = 1,
        editBoxWidth = 400,
        OnShow = function(self)
            addon:Print("Dialog OnShow called")
            -- Try different ways to get the edit box
            local editBox = self.wideEditBox or self.editBox or _G[self:GetName().."WideEditBox"] or _G[self:GetName().."EditBox"]
            addon:Print("EditBox exists: " .. tostring(editBox ~= nil))
            addon:Print("Dialog name: " .. tostring(self:GetName()))
            
            if editBox then
                addon:Print("Setting text to: " .. tostring(urlToShow))
                editBox:SetText(urlToShow)
                editBox:SetFocus()
                editBox:HighlightText(0)
                editBox:SetMaxLetters(0) -- No limit
                addon:Print("EditBox text is now: " .. tostring(editBox:GetText()))
            else
                addon:Print("|cffff0000Could not find editBox!|r")
                -- Try to find it by iterating children
                for i = 1, self:GetNumChildren() do
                    local child = select(i, self:GetChildren())
                    if child and child:GetObjectType() == "EditBox" then
                        addon:Print("Found EditBox as child " .. i)
                        editBox = child
                        editBox:SetText(urlToShow)
                        editBox:SetFocus()
                        editBox:HighlightText(0)
                        break
                    end
                end
            end
        end,
        OnHide = function(self)
            local editBox = self.wideEditBox or self.editBox or _G[self:GetName().."WideEditBox"] or _G[self:GetName().."EditBox"]
            if editBox then
                editBox:SetText("")
            end
        end,
        OnAccept = function() end,
        EditBoxOnEscapePressed = function(self)
            self:GetParent():Hide()
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        preferredIndex = 3,
    }
    
    addon:Print("About to show popup")
    StaticPopup_Show("WHISPERMANAGER_SHOW_URL")
end

--- Handle URL hyperlink clicks
-- @param link string The hyperlink that was clicked
-- @param text string Link text (optional)
-- @param button string Mouse button used (optional)
-- @return boolean True if handled, false otherwise
function addon:HandleURLClick(link, text, button)
    addon:Print("HandleURLClick called with link: " .. tostring(link))
    
    local url = ExtractURL(link)
    addon:Print("Extracted URL: " .. tostring(url))
    
    if url then
        self:ShowURLCopyDialog(url)
        return true
    else
        addon:Print("|cffff0000Failed to extract URL from link|r")
    end
    return false
end

-- Hook into hyperlink system
local originalSetHyperlink = ItemRefTooltip.SetHyperlink
ItemRefTooltip.SetHyperlink = function(self, link, ...)
    if link and link:match("^wm_url:") then
        addon:Print("SetHyperlink intercepted wm_url link")
        addon:HandleURLClick(link)
        return
    end
    return originalSetHyperlink(self, link, ...)
end

-- Register custom hyperlink handler
if SetItemRef then
    hooksecurefunc("SetItemRef", function(link, text, button, chatFrame)
        if link and link:match("^wm_url:") then
            addon:Print("SetItemRef intercepted wm_url link")
            addon:HandleURLClick(link, text, button)
        end
    end)
end

-- ============================================================================
-- SECTION 2: Chat History Export Dialog
-- ============================================================================

--- Strip color codes and hyperlinks for plain text export
-- @param text string Text with WoW formatting codes
-- @return string Plain text without formatting
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

--- Create the copy chat frame (creates once, reuses after)
-- @return table The copy chat frame
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
    
    -- ESC key handling - don't use UISpecialFrames to avoid conflicts
    frame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Hide()
        end
    end)
    frame:SetPropagateKeyboardInput(true)
    
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

--- Show copy chat dialog with chat history
-- @param playerKey string Canonical player key
-- @param displayName string Display name for title
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

addon:DebugMessage("Dialogs module loaded (URL and Copy Chat)")
