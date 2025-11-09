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

-- URL detection patterns 
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

-- ============================================================================
-- Embedded: ContextMenu.lua (merged)
-- ============================================================================

--- Open a context menu for a player
-- @param owner table Optional frame to anchor menu to
-- @param playerName string Full player name (with realm)
-- @param displayName string Display name to show in menu
-- @param isBNet boolean Whether this is a BNet player
-- @param bnSenderID number BNet sender ID (if BNet player)
function addon:OpenPlayerContextMenu(owner, playerName, displayName, isBNet, bnSenderID)
    if type(owner) == "string" or owner == nil then
        owner, playerName, displayName, isBNet, bnSenderID = nil, owner, playerName, displayName, isBNet
    end

    if not playerName and not isBNet then return end

    local function menuGenerator(ownerFrame, rootDescription)
        local label = displayName or addon.StripRealmFromName(playerName) or playerName
        if label and label ~= "" then
            rootDescription:CreateTitle(label)
        end

        if not isBNet and playerName and playerName ~= "" then
            rootDescription:CreateButton(WHISPER, function() addon:OpenConversation(playerName) end)
            rootDescription:CreateButton(INVITE, function() C_PartyInfo.InviteUnit(playerName) end)
            rootDescription:CreateButton("Export Chat", function() 
                local playerKey = addon:NormalizePlayerKey(playerName)
                addon:ShowChatExportDialog(playerKey, displayName or playerName)
            end)
            local raidTargetButton = rootDescription:CreateButton(RAID_TARGET_ICON)
            raidTargetButton:CreateButton(RAID_TARGET_NONE, function() SetRaidTarget(playerName, 0) end)
            for i = 1, 8 do
                raidTargetButton:CreateButton(_G["RAID_TARGET_" .. i], function() SetRaidTarget(playerName, i) end)
            end
            rootDescription:CreateButton(ADD_FRIEND, function() C_FriendList.AddFriend(playerName) end)
            rootDescription:CreateButton(PLAYER_REPORT, function()
                local guid = C_PlayerInfo.GUIDFromPlayerName(playerName)
                if guid then C_ReportSystem.OpenReportPlayerDialog(guid, playerName) end
            end)
        elseif isBNet and bnSenderID then
            if ChatFrame_SendBNetTell then
                rootDescription:CreateButton(WHISPER, function() addon:OpenBNetConversation(bnSenderID, displayName) end)
            end
            rootDescription:CreateButton("Export Chat", function() 
                local accountInfo = C_BattleNet.GetAccountInfoByID(bnSenderID)
                if accountInfo and accountInfo.battleTag then
                    local playerKey = "bnet_" .. accountInfo.battleTag
                    addon:ShowChatExportDialog(playerKey, displayName)
                else
                    addon:Print("|cffff0000Could not export chat: BattleTag not found.|r")
                end
            end)
            if BNInviteFriend then
                rootDescription:CreateButton(INVITE, function() BNInviteFriend(bnSenderID) end)
            end
        end

        rootDescription:CreateButton(CANCEL, function() end)
    end

    local createOwner = owner or UIParent
    local menu = nil
    pcall(function() menu = MenuUtil.CreateContextMenu(createOwner, menuGenerator) end)
    if menu and type(menu.Show) == "function" then
        pcall(function() menu:Show() end)
        return
    end
    local ok2, mouseFrame = pcall(function() return GetMouseFocus() end)
    if ok2 and mouseFrame then
        local altMenu = nil
        pcall(function() altMenu = MenuUtil.CreateContextMenu(mouseFrame, menuGenerator) end)
        if altMenu and type(altMenu.Show) == "function" then
            pcall(function() altMenu:Show() end)
            return
        end
    end
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
        text = "URL: ( CTRL+C to Copy )",
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
-- SECTION 2: Chat Export Dialog
-- ============================================================================

--- Format chat history as plain text for export
-- @param playerKey string Canonical player key
-- @param displayName string Display name for the conversation
-- @return string Formatted chat text
local function FormatChatForExport(playerKey, displayName)
    if not WhisperManager_HistoryDB or not WhisperManager_HistoryDB[playerKey] then
        return "No chat history found."
    end
    
    local history = WhisperManager_HistoryDB[playerKey]
    local lines = {}
    
    -- Check if this is a BNet conversation
    local isBNet = playerKey and playerKey:match("^bnet_") ~= nil
    
    -- Add header
    table.insert(lines, "========================================")
    table.insert(lines, "Chat Export: " .. (displayName or playerKey))
    table.insert(lines, "Exported: " .. date("%Y-%m-%d %H:%M:%S", time()))
    table.insert(lines, "========================================")
    table.insert(lines, "")
    
    -- Get player info
    local playerName, playerRealm = UnitName("player")
    local realm = (playerRealm or GetRealmName()):gsub("%s+", "")
    local fullPlayerName = playerName .. "-" .. realm
    
    -- Process each message
    for i, entry in ipairs(history) do
        local timestamp = entry.t or entry.timestamp
        local author = entry.a or entry.author
        local message = entry.m or entry.message
        
        if timestamp and author and message then
            -- Resolve BNet IDs for BNet conversations
            if isBNet and author then
                author = addon:ResolveBNetID(author, playerKey)
            end
            
            -- Format timestamp
            local timeString = date("%H:%M:%S", timestamp)
            
            -- Determine author display name
            local authorDisplay
            if author == "Me" or author == playerName or author == fullPlayerName then
                authorDisplay = playerName .. " (You)"
            else
                -- For BNet, use the displayName; for regular whispers, strip realm
                if isBNet then
                    authorDisplay = displayName or author
                else
                    authorDisplay = author:match("^([^%-]+)") or author
                end
            end
            
            -- Strip color codes and hyperlinks from message
            local plainMessage = message:gsub("|c%x%x%x%x%x%x%x%x", "")  -- Remove color codes
            plainMessage = plainMessage:gsub("|r", "")  -- Remove reset codes
            plainMessage = plainMessage:gsub("|H.-|h", "")  -- Remove hyperlink starts
            plainMessage = plainMessage:gsub("|h", "")  -- Remove hyperlink ends
            plainMessage = plainMessage:gsub("|T.-|t", "")  -- Remove textures
            plainMessage = plainMessage:gsub("|K.-|k", "")  -- Remove BNet tags
            plainMessage = plainMessage:gsub("|n", "\n")  -- Convert newlines
            
            -- Add formatted line
            table.insert(lines, string.format("[%s] %s: %s", timeString, authorDisplay, plainMessage))
        end
    end
    
    return table.concat(lines, "\n")
end

--- Create and show chat export dialog
-- @param playerKey string Canonical player key
-- @param displayName string Display name for the conversation
function addon:ShowChatExportDialog(playerKey, displayName)
    if not playerKey then
        addon:Print("|cffff0000No player selected for chat export.|r")
        return
    end
    
    -- Format the chat history
    local chatText = FormatChatForExport(playerKey, displayName)
    
    -- Create the export dialog frame if it doesn't exist
    if not WhisperManagerChatExportFrame then
        local frame = CreateFrame("Frame", "WhisperManagerChatExportFrame", UIParent, "DialogBoxFrame")
        frame:SetSize(600, 400)
        frame:SetPoint("CENTER")
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:SetClampedToScreen(true)
        frame:SetFrameStrata("DIALOG")
        frame:SetToplevel(true)
        
        -- Make frame draggable
        frame:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then
                self:StartMoving()
            end
        end)
        frame:SetScript("OnMouseUp", function(self)
            self:StopMovingOrSizing()
        end)
        
        -- Title
        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -15)
        title:SetText("Chat Export")
        frame.Title = title
        
        -- Subtitle with player name
        local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        subtitle:SetPoint("TOP", title, "BOTTOM", 0, -5)
        frame.Subtitle = subtitle
        
        -- Instructions
        local instructions = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        instructions:SetPoint("TOP", subtitle, "BOTTOM", 0, -10)
        instructions:SetText("Press CTRL+A to select all, then CTRL+C to copy")
        instructions:SetTextColor(0.7, 0.7, 0.7)
        frame.Instructions = instructions
        
        -- Create scroll frame for the text
        local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", instructions, "BOTTOMLEFT", -10, -10)
        scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 45)
        
        -- Create edit box for the chat text
        local editBox = CreateFrame("EditBox", nil, scrollFrame)
        editBox:SetMultiLine(true)
        editBox:SetAutoFocus(false)
        editBox:SetFontObject(ChatFontNormal)
        editBox:SetWidth(scrollFrame:GetWidth() - 10)
        editBox:SetMaxLetters(0)  -- No limit
        editBox:SetScript("OnEscapePressed", function(self)
            frame:Hide()
        end)
        editBox:SetScript("OnTextChanged", function(self, userInput)
            -- Auto-resize the editbox height based on content
            if not userInput then
                local text = self:GetText()
                local _, lineCount = text:gsub("\n", "\n")
                local height = math.max(scrollFrame:GetHeight(), (lineCount + 1) * 14)
                self:SetHeight(height)
            end
        end)
        
        scrollFrame:SetScrollChild(editBox)
        frame.ScrollFrame = scrollFrame
        frame.EditBox = editBox
        
        -- Close button
        local closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        closeButton:SetSize(100, 22)
        closeButton:SetPoint("BOTTOM", 0, 15)
        closeButton:SetText("Close")
        closeButton:SetScript("OnClick", function()
            frame:Hide()
        end)
        frame.CloseButton = closeButton
        
        -- Copy All button
        local copyButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        copyButton:SetSize(100, 22)
        copyButton:SetPoint("RIGHT", closeButton, "LEFT", -10, 0)
        copyButton:SetText("Select All")
        copyButton:SetScript("OnClick", function()
            editBox:SetFocus()
            editBox:HighlightText(0)
        end)
        frame.CopyButton = copyButton
    end
    
    local frame = WhisperManagerChatExportFrame
    
    -- Update content
    frame.Subtitle:SetText(displayName or playerKey)
    frame.EditBox:SetText(chatText)
    frame.EditBox:SetCursorPosition(0)
    
    -- Auto-select all text
    C_Timer.After(0.1, function()
        frame.EditBox:SetFocus()
        frame.EditBox:HighlightText(0)
    end)
    
    frame:Show()
end

