-- ============================================================================
-- URLHandler.lua - URL detection and copy dialog
-- ============================================================================

local addon = WhisperManager;

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

-- ============================================================================
-- URL Detection and Formatting
-- ============================================================================

local function FormatURLAsLink(url)
    if not url or url == "" then return "" end
    -- Escape % characters
    url = url:gsub('%%', '%%%%')
    -- Create a clickable link with custom prefix
    return "|cff00ffff|Hwm_url:" .. url .. "|h[" .. url .. "]|h|r"
end

-- Convert URLs in text to clickable links
function addon:ConvertURLsToLinks(text)
    if not text or text == "" then return text end
    
    local result = text
    
    -- Process each pattern
    for _, pattern in ipairs(URL_PATTERNS) do
        result = result:gsub(pattern, FormatURLAsLink)
    end
    
    return result
end

-- Extract plain URL from hyperlink
local function ExtractURL(link)
    if type(link) ~= "string" then return nil end
    
    if link:match("^wm_url:(.+)") then
        return link:match("^wm_url:(.+)")
    end
    
    return nil
end

-- ============================================================================
-- URL Copy Dialog
-- ============================================================================

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

-- ============================================================================
-- Hyperlink Click Handler
-- ============================================================================

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

addon:DebugMessage("URLHandler loaded")
