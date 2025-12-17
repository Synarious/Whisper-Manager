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
            rootDescription:CreateButton(WHISPER, function() addon:OpenBNetConversation(bnSenderID, displayName) end)
            rootDescription:CreateButton("Export Chat", function() 
                local accountInfo = C_BattleNet.GetAccountInfoByID(bnSenderID)
                if accountInfo and accountInfo.battleTag then
                    local playerKey = "bnet_" .. accountInfo.battleTag
                    addon:ShowChatExportDialog(playerKey, displayName)
                else
                    addon:Print("|cffff0000Could not export chat: BattleTag not found.|r")
                end
            end)
            rootDescription:CreateButton(INVITE, function() BNInviteFriend(bnSenderID) end)
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

--- Format chat history for export (plain text)
-- @param playerKey string Canonical player key (c_Name-Realm or bnet_Tag)
-- @return string Formatted chat history as plain text
local function FormatChatHistoryForExport(playerKey)
    if not WhisperManager_HistoryDB or not playerKey then
        return "No chat history found."
    end
    
    local history = WhisperManager_HistoryDB[playerKey]
    if not history or #history == 0 then
        return "No messages found for this conversation."
    end
    
    local MAX_LINES = 2500
    local totalMessages = #history
    local startIndex = 1
    local wasTruncated = false
    if totalMessages > MAX_LINES then
        startIndex = totalMessages - MAX_LINES + 1
        wasTruncated = true
    end

    local lines = {}
    local displayName = addon:GetDisplayNameFromKey(playerKey)
    
    -- Add header
    table.insert(lines, "Chat History Export")
    table.insert(lines, "Conversation with: " .. displayName)
    table.insert(lines, "Player Key: " .. playerKey)
    if wasTruncated then
        table.insert(lines, string.format("Showing last %d messages (of %d total)", MAX_LINES, totalMessages))
    else
        table.insert(lines, "Total Messages: " .. totalMessages)
    end
    table.insert(lines, "========================================")
    table.insert(lines, "")
    
    -- Get current player name for comparison
    local playerName, playerRealm = UnitName("player")
    local realm = (playerRealm or GetRealmName()):gsub("%s+", "")
    local fullPlayerName = playerName .. "-" .. realm
    
    -- Format each message (only last MAX_LINES messages)
    for i = startIndex, totalMessages do
        local entry = history[i]
        if not entry then
            -- safety
        else
            local timestamp = entry.t or entry.timestamp
            local author = entry.a or entry.author
            local message = entry.m or entry.message
            
            if timestamp and author and message then
                -- Format timestamp
                local timeString = date("%Y-%m-%d %H:%M:%S", timestamp)
                
                -- Determine if this is a sent or received message
                local authorDisplay
                if author == "Me" or author == playerName or author == fullPlayerName then
                    authorDisplay = "You"
                else
                    -- Resolve BNet IDs if needed
                    if playerKey:match("^bnet_") and author:match("^|Kp%d+|k$") then
                        authorDisplay = addon:ResolveBNetID(author, playerKey)
                    else
                        -- Strip realm from character names for readability
                        authorDisplay = author:match("^([^%-]+)") or author
                    end
                end
                
                -- Strip color codes and hyperlinks from message
                local plainMessage = message
                -- Remove color codes
                plainMessage = plainMessage:gsub("|c%x%x%x%x%x%x%x%x", "")
                plainMessage = plainMessage:gsub("|r", "")
                -- Remove hyperlinks but keep the text
                plainMessage = plainMessage:gsub("|H([^|]+)|h%[?([^%]|]+)%]?|h", "%2")
                plainMessage = plainMessage:gsub("|H([^|]+)|h([^|]+)|h", "%2")
                -- Remove any remaining formatting codes
                plainMessage = plainMessage:gsub("|[Tt]", "\t")
                plainMessage = plainMessage:gsub("|[Nn]", "\n")
                plainMessage = plainMessage:gsub("|K([^|]+)|k", "")
                
                -- Format the line
                local line = string.format("[%s] %s: %s", timeString, authorDisplay, plainMessage)
                table.insert(lines, line)
            end
        end
    end
    
    return table.concat(lines, "\n")
end

--- Show chat export dialog with formatted history
-- @param playerKey string Canonical player key (c_Name-Realm or bnet_Tag)
-- @param displayName string Display name for the player (optional)
-- @param parentWindow table Optional parent window to inherit strata/level from
function addon:ShowChatExportDialog(playerKey, displayName, parentWindow)
    if not playerKey then
        addon:Print("|cffff0000Cannot export chat: Invalid player key.|r")
        return
    end
    
    local exportText = FormatChatHistoryForExport(playerKey)
    displayName = displayName or addon:GetDisplayNameFromKey(playerKey)
    
    -- Create or reuse export frame
    local frame = addon.chatExportFrame
    if not frame then
        frame = CreateFrame("Frame", "WhisperManager_ChatExportFrame", addon:GetOverlayParent(), "BackdropTemplate")
        frame:SetSize(600, 500)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata(addon.OVERLAY_STRATA)
        frame:SetFrameLevel(200)
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        frame:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
        frame:SetBackdropColor(0, 0, 0, 0.9)
        frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        frame:SetToplevel(true)
        
        -- Title
        frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        frame.title:SetPoint("TOP", 0, -10)
        frame.title:SetText("Export Chat History")
        
        -- Close button
        frame.closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        frame.closeBtn:SetPoint("TOPRIGHT", -2, -2)
        frame.closeBtn:SetSize(24, 24)
        frame.closeBtn:SetScript("OnClick", function(self)
            self:GetParent():Hide()
        end)
        
        -- Info text
        frame.infoText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        frame.infoText:SetPoint("TOP", 0, -35)
        frame.infoText:SetText("Press CTRL+A to select all, then CTRL+C to copy")
        frame.infoText:SetTextColor(0.8, 0.8, 0.8)
        
        -- Player name label
        frame.playerLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        frame.playerLabel:SetPoint("TOPLEFT", 15, -60)
        frame.playerLabel:SetJustifyH("LEFT")
        
        -- Scroll frame
        frame.scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        frame.scrollFrame:SetPoint("TOPLEFT", 15, -80)
        frame.scrollFrame:SetPoint("BOTTOMRIGHT", -30, 15)
        frame.scrollFrame:EnableMouse(true)
        
        -- Edit box
        frame.editBox = CreateFrame("EditBox", nil, frame.scrollFrame)
        frame.editBox:SetMultiLine(true)
        frame.editBox:SetMaxLetters(0)
        frame.editBox:SetFontObject(ChatFontNormal)
        frame.editBox:SetWidth(550)
        frame.editBox:SetAutoFocus(false)
        frame.editBox:EnableMouse(true)
        frame.editBox:EnableMouseWheel(true)
        frame.editBox:SetScript("OnEscapePressed", function(self)
            frame:Hide()
        end)
        frame.scrollFrame:SetScrollChild(frame.editBox)
        
        -- Make the frame close on ESC key
        frame:SetScript("OnKeyDown", function(self, key)
            if key == "ESCAPE" then
                self:Hide()
            end
        end)
        frame:SetPropagateKeyboardInput(true)
        
        addon.chatExportFrame = frame
    end
    
    -- If opened from a parent window, position relative to it
    if parentWindow and parentWindow:IsShown() then
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", parentWindow, "CENTER", 0, 0)
    else
        -- Center on screen if no parent
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", addon:GetOverlayParent(), "CENTER")
    end
    
    -- Always use overlay strata to appear above full-screen UIs (e.g., Housing)
    -- Increment frame level to ensure each new dialog is on top
    addon.nextDialogLevel = (addon.nextDialogLevel or 200) + 10
    frame:SetFrameStrata(addon.OVERLAY_STRATA)
    frame:SetFrameLevel(addon.nextDialogLevel)

    addon:EnsureFrameOverlay(frame, addon.nextDialogLevel)
    
    -- Update all child frames to use same strata
    if frame.title then
        frame.title:SetDrawLayer("OVERLAY", 7)
    end
    if frame.closeBtn then
        frame.closeBtn:SetFrameStrata(addon.OVERLAY_STRATA)
        frame.closeBtn:SetFrameLevel(addon.nextDialogLevel + 10)
    end
    if frame.scrollFrame then
        frame.scrollFrame:SetFrameStrata(addon.OVERLAY_STRATA)
        frame.scrollFrame:SetFrameLevel(addon.nextDialogLevel + 5)
    end
    if frame.editBox then
        frame.editBox:SetFrameStrata(addon.OVERLAY_STRATA)
        frame.editBox:SetFrameLevel(addon.nextDialogLevel + 6)
    end
    
    -- Update content
    frame.playerLabel:SetText("Conversation with: " .. displayName)
    frame.editBox:SetText(exportText)
    frame.editBox:SetCursorPosition(0)
    frame.editBox:HighlightText(0, 0) -- Clear any highlight
    -- Proactively focus the edit box so CTRL+A / CTRL+C work immediately

    
    -- Show the frame
    frame:Show()
    frame:Raise()
end