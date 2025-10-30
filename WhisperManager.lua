-- ============================================================================
-- Configuration
-- ============================================================================
local DEFAULT_DEBUG_MODE = true -- Toggle via settings/slash to show diagnostic messages.
-- ============================================================================

-- Create the main addon table
WhisperManager = {};
local addon = WhisperManager;

addon.windows = {};
addon.playerDisplayNames = {};
addon.debugEnabled = DEFAULT_DEBUG_MODE;
addon.recentChats = {};  -- Track recent conversations with read status

local MAX_HISTORY_LINES = 200;
local CHAT_MAX_LETTERS = 245;
local RECENT_CHAT_EXPIRY = 72 * 60 * 60;  -- 72 hours in seconds

-- A debug function that only prints if DEBUG_MODE is true.
local function DebugMessage(...)
    if addon.debugEnabled then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00WhisperManager:|r " .. table.concat({...}, " "));
    end
end

local function TrimWhitespace(value)
    if type(value) ~= "string" then return nil end
    return value:gsub("^%s+", ""):gsub("%s+$", "")
end

function addon:ResolvePlayerIdentifiers(playerName)
    local trimmed = TrimWhitespace(playerName)
    if not trimmed or trimmed == "" then return nil end

    local target = Ambiguate(trimmed, "none") or trimmed
    if not target or target == "" then return nil end

    local namePart, realmPart = target:match("^([^%-]+)%-(.+)$")
    local baseName = namePart or target
    
    -- Use full name-realm as canonical key (prefixed with c_)
    local canonicalKey
    if realmPart and realmPart ~= "" then
        canonicalKey = "c_" .. baseName .. "-" .. realmPart
    else
        -- If no realm, add current realm
        local currentRealm = GetRealmName()
        canonicalKey = "c_" .. baseName .. "-" .. currentRealm
    end

    local display = Ambiguate(trimmed, "short") or baseName

    return canonicalKey, target, display
end

-- Extract display name from a key (works for both c_ and bnet_ keys)
function addon:GetDisplayNameFromKey(playerKey)
    if not playerKey then return "Unknown" end
    
    -- For BNet keys: bnet_Name#1234 -> Name
    if playerKey:match("^bnet_(.+)") then
        local battleTag = playerKey:match("^bnet_(.+)")
        local name = battleTag:match("^([^#]+)") or battleTag
        return name
    end
    
    -- For character keys: c_Name-Realm -> Name
    if playerKey:match("^c_(.+)") then
        local fullName = playerKey:match("^c_(.+)")
        local name = fullName:match("^([^%-]+)") or fullName
        return name
    end
    
    -- Fallback for old format keys
    return playerKey
end

function addon:ExtractWhisperTarget(text)
    if type(text) ~= "string" then return nil end

    local trimmed = TrimWhitespace(text)
    if not trimmed or trimmed == "" then return nil end

    local _, target = trimmed:match("^/([Ww][Hh][Ii][Ss][Pp][Ee][Rr])%s+([^%s]+)")
    if not target then
        _, target = trimmed:match("^/([Ww])%s+([^%s]+)")
    end

    return target and target:gsub("[,.;:]+$", "") or nil
end

function addon:Print(...)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00WhisperManager:|r " .. table.concat({...}, " "))
end

function addon:SetDebugEnabled(enabled)
    addon.debugEnabled = not not enabled
    if type(WhisperManager_Config) == "table" then
        WhisperManager_Config.debug = addon.debugEnabled
    end
    local stateLabel = addon.debugEnabled and "enabled" or "disabled"
    addon:Print(string.format("Debug logging %s.", stateLabel))
end

function addon:SaveWindowPosition(window)
    if not window or not window.playerKey then return end
    if type(WhisperManager_WindowDB) ~= "table" then
        WhisperManager_WindowDB = {}
    end
    local point, relativeTo, relativePoint, xOfs, yOfs = window:GetPoint(1)
    if not point then return end

    local width, height = window:GetSize()
    WhisperManager_WindowDB[window.playerKey] = {
        point = point,
        relativePoint = relativePoint,
        relativeTo = relativeTo and relativeTo:GetName() or nil,
        xOfs = xOfs or 0,
        yOfs = yOfs or 0,
        width = width or 400,
        height = height or 300,
    }
end

function addon:ApplyWindowPosition(window)
    if not window or not window.playerKey then return end
    local state = type(WhisperManager_WindowDB) == "table" and WhisperManager_WindowDB[window.playerKey]
    if state and state.point and state.relativePoint then
        local relative = state.relativeTo and _G[state.relativeTo] or UIParent
        window:ClearAllPoints()
        window:SetPoint(state.point, relative, state.relativePoint, state.xOfs or 0, state.yOfs or 0)
        
        -- Restore saved size if available
        if state.width and state.height then
            window:SetSize(state.width, state.height)
        end
    else
        window:ClearAllPoints()
        window:SetPoint("CENTER")
    end
end

function addon:ResetWindowPositions()
    WhisperManager_WindowDB = {}
    for _, window in pairs(addon.windows) do
        if window and window.ClearAllPoints then
            window:ClearAllPoints()
            window:SetPoint("CENTER")
            addon:SaveWindowPosition(window)
        end
    end
    addon:Print("All whisper window positions reset to center.")
end

function addon:HandleSlashCommand(message)
    local input = TrimWhitespace(message or "") or ""
    if input == "" or input:lower() == "help" then
        addon:Print("Usage:")
        addon:Print("/wm <player> - Open a WhisperManager window.")
        addon:Print("/wm debug [on|off|toggle] - Control diagnostic chat output.")
        addon:Print("/wm resetwindows - Reset saved window positions.")
        addon:Print("/wm reset_all_data - Clear all saved data (history, windows, config).")
        return
    end

    local command, rest = input:match("^(%S+)%s*(.-)$")
    command = command and command:lower() or ""
    if command == "debug" then
        local directive = rest and rest:lower() or ""
        if directive == "on" or directive == "1" or directive == "true" then
            addon:SetDebugEnabled(true)
        elseif directive == "off" or directive == "0" or directive == "false" then
            addon:SetDebugEnabled(false)
        else
            addon:SetDebugEnabled(not addon.debugEnabled)
        end
    elseif command == "resetwindows" then
        addon:ResetWindowPositions()
    elseif command == "reset_all_data" then
        WhisperManager_HistoryDB = {}
        WhisperManager_WindowDB = {}
        WhisperManager_Config = {}
        WhisperManager_RecentChats = {}
        addon:Print("|cffff0000All WhisperManager data has been cleared!|r")
        addon:Print("Please /reload to apply changes.")
    else
        if not addon:OpenConversation(input) then
            addon:Print(string.format("Unable to open a whisper window for '%s'.", input))
        end
    end
end

--------------------------------------------------------------------
-- Core Functions
--------------------------------------------------------------------

-- Helper function to convert timestamp to "time ago" format
local function GetTimeAgo(timestamp)
    local now = time()
    local diff = now - timestamp
    
    if diff < 60 then
        return "Just now"
    elseif diff < 3600 then
        local minutes = math.floor(diff / 60)
        return minutes .. " minute" .. (minutes ~= 1 and "s" or "") .. " ago"
    elseif diff < 86400 then
        local hours = math.floor(diff / 3600)
        return hours .. " hour" .. (hours ~= 1 and "s" or "") .. " ago"
    else
        local days = math.floor(diff / 86400)
        return days .. " day" .. (days ~= 1 and "s" or "") .. " ago"
    end
end

-- Update recent chat entry
function addon:UpdateRecentChat(playerKey, displayName, isBNet)
    if not WhisperManager_RecentChats then
        WhisperManager_RecentChats = {}
    end
    
    local now = time()
    
    -- Clean up old entries (older than 72 hours)
    for key, data in pairs(WhisperManager_RecentChats) do
        if (now - data.lastMessageTime) > RECENT_CHAT_EXPIRY then
            WhisperManager_RecentChats[key] = nil
        end
    end
    
    -- Update or create entry (no displayName needed, extracted from key)
    if not WhisperManager_RecentChats[playerKey] then
        WhisperManager_RecentChats[playerKey] = {
            lastMessageTime = now,
            isRead = false,
            isBNet = isBNet or false,
        }
    else
        WhisperManager_RecentChats[playerKey].lastMessageTime = now
    end
end

-- Mark chat as read
function addon:MarkChatAsRead(playerKey)
    if WhisperManager_RecentChats and WhisperManager_RecentChats[playerKey] then
        WhisperManager_RecentChats[playerKey].isRead = true
    end
end

-- Helper function to update input box height dynamically
local function UpdateInputHeight(inputBox)
    if not inputBox or not inputBox:IsVisible() then return end
    
    C_Timer.After(0, function()
        if not inputBox:IsVisible() then return end
        
        local text = inputBox:GetText() or ""
        if text == "" then
            inputBox:SetHeight(24)  -- Minimum height
            return
        end
        
        -- Create a hidden FontString for measurement if it doesn't exist
        if not inputBox.measureString then
            inputBox.measureString = inputBox:CreateFontString(nil, "OVERLAY")
            inputBox.measureString:Hide()
        end
        
        local font, size, flags = inputBox:GetFont()
        local left, right = inputBox:GetTextInsets()
        local usableWidth = inputBox:GetWidth() - left - right
        
        inputBox.measureString:SetFont(font, size, flags)
        inputBox.measureString:SetWidth(usableWidth)
        inputBox.measureString:SetText(text)
        
        local lineHeight = inputBox.measureString:GetLineHeight() or 14
        local numLines = inputBox.measureString:GetNumLines() or 1
        if numLines < 1 then numLines = 1 end
        
        local padding = 8
        local newHeight = (numLines * lineHeight) + padding
        
        -- Cap at reasonable max height (e.g., 5 lines)
        local maxHeight = (5 * lineHeight) + padding
        if newHeight > maxHeight then newHeight = maxHeight end
        
        -- Ensure minimum height
        if newHeight < 24 then newHeight = 24 end
        
        inputBox:SetHeight(newHeight)
    end)
end

function addon:OpenConversation(playerName)
    -- Don't open conversations if we're closing windows
    if self.__closingWindow then
        DebugMessage("OpenConversation blocked - window closing in progress")
        return false
    end
    
    DebugMessage("OpenConversation called for:", playerName);
    local playerKey, playerTarget, displayName = self:ResolvePlayerIdentifiers(playerName)
    if not playerKey then
        DebugMessage("|cffff0000ERROR: Unable to resolve player identifiers for|r", playerName)
        return false
    end

    displayName = self:GetDisplayNameFromKey(playerKey)

    local win = self.windows[playerKey]
    if not win then
        DebugMessage("No existing window. Calling CreateWindow.");
        win = self:CreateWindow(playerKey, playerTarget, displayName, false)
        if not win then 
            DebugMessage("|cffff0000ERROR: CreateWindow failed to return a window.|r");
            return false 
        end
        self.windows[playerKey] = win
    else
        win.playerTarget = playerTarget
        win.playerDisplay = displayName
        win.playerKey = playerKey
    end

    self:DisplayHistory(win, playerKey)
    if win.Title then
        win.Title:SetText("Whisper: " .. (displayName or playerTarget))
    end
    self:ApplyWindowPosition(win)
    win:Show()
    win:Raise()
    if win.Input then
        win.Input:SetFocus()
    end
    
    -- Mark as read and update recent chats
    self:MarkChatAsRead(playerKey)
    self:UpdateRecentChat(playerKey, displayName, false)
    
    return true
end

function addon:OpenBNetConversation(bnSenderID, displayName)
    DebugMessage("OpenBNetConversation called for BNet ID:", bnSenderID)
    
    -- Get account info to retrieve BattleTag (permanent identifier)
    local accountInfo = C_BattleNet.GetAccountInfoByID(bnSenderID)
    if not accountInfo or not accountInfo.battleTag then
        DebugMessage("|cffff0000ERROR: Could not get BattleTag for BNet ID:|r", bnSenderID)
        return false
    end
    
    -- Use BattleTag as the permanent key (e.g., "bnet_Name#1234")
    local playerKey = "bnet_" .. accountInfo.battleTag
    displayName = accountInfo.accountName or displayName or accountInfo.battleTag
    
    local win = self.windows[playerKey]
    if not win then
        DebugMessage("No existing BNet window. Calling CreateWindow.")
        win = self:CreateWindow(playerKey, bnSenderID, displayName, true)
        if not win then
            DebugMessage("|cffff0000ERROR: CreateWindow failed to return a BNet window.|r")
            return false
        end
        self.windows[playerKey] = win
    else
        -- Update the current session's BNet ID (it may have changed)
        win.bnSenderID = bnSenderID
        win.playerDisplay = displayName
        win.playerKey = playerKey
    end
    
    self:DisplayHistory(win, playerKey)
    if win.Title then
        win.Title:SetText("BNet Whisper: " .. displayName)
    end
    self:ApplyWindowPosition(win)
    win:Show()
    win:Raise()
    if win.Input then
        win.Input:SetFocus()
    end
    
    -- Mark as read and update recent chats
    self:MarkChatAsRead(playerKey)
    self:UpdateRecentChat(playerKey, displayName, true)
    
    return true
end

function addon:CreateWindow(playerKey, playerTarget, displayName, isBNet)
    DebugMessage("CreateWindow called for:", playerKey);
    local sanitizedKey = playerKey:gsub("[^%w]","")
    if sanitizedKey == "" then return nil end
    local frameName = "WhisperManager_" .. sanitizedKey

    if _G[frameName] then return _G[frameName] end

    -- Main Window Frame
    local win = CreateFrame("Frame", frameName, UIParent, "BackdropTemplate")
    win.playerKey = playerKey
    win.playerTarget = playerTarget
    win.playerDisplay = displayName
    win.isBNet = isBNet or false
    if isBNet then
        win.bnSenderID = playerTarget  -- For BNet, playerTarget is the bnSenderID
    end
    win:SetSize(400, 300)
    win:SetPoint("CENTER")
    win:SetClampedToScreen(true)
    win:SetMovable(true)
    win:SetResizable(true)
    win:SetResizeBounds(250, 200, 800, 600)
    win:EnableMouse(true)
    win:SetUserPlaced(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        addon:SaveWindowPosition(frame)
    end)
    win:SetScript("OnHide", function(frame)
        -- Set flag to prevent hooks from triggering during window close
        addon.__closingWindow = true
        
        addon:SaveWindowPosition(frame)
        if frame.Input then
            frame.Input:ClearFocus()
            frame.Input:Hide()
        end
        if frame.InputBg then
            frame.InputBg:Hide()
        end
        if frame.InputBorder then
            frame.InputBorder:Hide()
        end
        
        -- Clear flag after a short delay
        C_Timer.After(0.1, function()
            addon.__closingWindow = false
        end)
    end)
    win:SetScript("OnShow", function(frame)
        addon:ApplyWindowPosition(frame)
        if frame.Input then
            frame.Input:Show()
            frame.Input:SetFocus()
        end
        if frame.InputBg then
            frame.InputBg:Show()
        end
        if frame.InputBorder then
            frame.InputBorder:Show()
        end
    end)
    win:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    win:SetBackdropColor(0, 0, 0, 0.85)
    win:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    -- Title Bar Background
    win.TitleBg = win:CreateTexture(nil, "BACKGROUND")
    win.TitleBg:SetColorTexture(0.1, 0.1, 0.1, 0.9)
    win.TitleBg:SetPoint("TOPLEFT", win, "TOPLEFT", 4, -4)
    win.TitleBg:SetPoint("TOPRIGHT", win, "TOPRIGHT", -4, -4)
    win.TitleBg:SetHeight(28)

    -- Title Text
    win.Title = win:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    win.Title:SetPoint("TOP", win, "TOP", 0, -10)
    local titlePrefix = isBNet and "BNet Whisper: " or "Whisper: "
    win.Title:SetText(titlePrefix .. (displayName or playerTarget or playerKey))
    win.Title:SetTextColor(1, 0.82, 0, 1)
    
    -- Make title clickable for right-click menu
    win.TitleButton = CreateFrame("Button", nil, win)
    win.TitleButton:SetAllPoints(win.Title)
    win.TitleButton:RegisterForClicks("RightButtonUp")
    win.TitleButton:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            -- Open unit popup menu for the player
            if win.playerTarget then
                local dropDown = CreateFrame("Frame", "WhisperManager_DropDown", UIParent, "UIDropDownMenuTemplate")
                local menuList = {
                    {
                        text = win.playerDisplay or win.playerTarget,
                        isTitle = true,
                        notCheckable = true,
                    },
                }
                
                -- Only show regular player options for non-BNet whispers
                if not win.isBNet then
                    table.insert(menuList, {
                        text = WHISPER,
                        func = function()
                            ChatFrame_SendTell(win.playerTarget)
                        end,
                        notCheckable = true,
                    })
                    table.insert(menuList, {
                        text = INVITE,
                        func = function()
                            C_PartyInfo.InviteUnit(win.playerTarget)
                        end,
                        notCheckable = true,
                    })
                    table.insert(menuList, {
                        text = RAID_TARGET_ICON,
                        hasArrow = true,
                        notCheckable = true,
                        menuList = {
                            {
                                text = RAID_TARGET_NONE,
                                func = function()
                                    SetRaidTarget(win.playerTarget, 0)
                                end,
                                notCheckable = true,
                            },
                        },
                    })
                    
                    -- Add raid target icons dynamically
                    for i = 1, 8 do
                        table.insert(menuList[#menuList].menuList, {
                            text = RAID_TARGET_ICON .. " " .. i,
                            func = function()
                                SetRaidTarget(win.playerTarget, i)
                            end,
                            icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. i,
                            notCheckable = true,
                        })
                    end
                    
                    table.insert(menuList, {
                        text = ADD_FRIEND,
                        func = function()
                            C_FriendList.AddFriend(win.playerTarget)
                        end,
                        notCheckable = true,
                    })
                    table.insert(menuList, {
                        text = PLAYER_REPORT,
                        func = function()
                            C_ReportSystem.OpenReportPlayerDialog(C_PlayerInfo.GUIDFromPlayerName(win.playerTarget), win.playerTarget)
                        end,
                        notCheckable = true,
                    })
                end
                
                table.insert(menuList, {
                    text = CANCEL,
                    func = function() end,
                    notCheckable = true,
                })
                
                EasyMenu(menuList, dropDown, "cursor", 0, 0, "MENU")
            end
        end
    end)
    win.TitleButton:SetScript("OnEnter", function(self)
        win.Title:SetTextColor(1, 1, 1, 1)  -- White on hover
    end)
    win.TitleButton:SetScript("OnLeave", function(self)
        win.Title:SetTextColor(1, 0.82, 0, 1)  -- Gold default
    end)

    -- Close Button
    win.CloseButton = CreateFrame("Button", nil, win, "UIPanelCloseButton")
    win.CloseButton:SetSize(24, 24)
    win.CloseButton:SetPoint("TOPRIGHT", win, "TOPRIGHT", -2, -2)

    -- Resize Button
    win.ResizeButton = CreateFrame("Button", nil, win)
    win.ResizeButton:SetSize(16, 16)
    win.ResizeButton:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", 0, 0)
    win.ResizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    win.ResizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    win.ResizeButton:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            win:StartSizing("BOTTOMRIGHT")
        end
    end)
    win.ResizeButton:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            win:StopMovingOrSizing()
            addon:SaveWindowPosition(win)
        end
    end)

    -- Input EditBox (positioned outside/below the main window frame)
    local inputName = frameName .. "Input"
    win.Input = CreateFrame("EditBox", inputName, UIParent)
    win.Input:SetHeight(24)  -- Initial height, will grow dynamically
    win.Input:SetPoint("TOPLEFT", win, "BOTTOMLEFT", 0, -4)
    win.Input:SetPoint("TOPRIGHT", win, "BOTTOMRIGHT", 0, -4)
    
    -- Set font properly for EditBox
    local fontFile, _, fontFlags = ChatFontNormal:GetFont()
    win.Input:SetFont(fontFile, 14, fontFlags)
    win.Input:SetTextColor(1, 1, 1, 1)
    
    -- Enable multiline with proper mouse support
    win.Input:SetMultiLine(true)
    win.Input:SetAutoFocus(false)
    win.Input:SetHistoryLines(32)
    win.Input:SetMaxLetters(CHAT_MAX_LETTERS)
    win.Input:SetAltArrowKeyMode(true)  -- Like WIM
    win.Input:EnableMouse(true)
    win.Input:EnableKeyboard(true)
    win.Input:SetHitRectInsets(0, 0, 0, 0)  -- Fix mouse clicking for multiline
    win.Input:SetTextInsets(6, 6, 4, 4)  -- Add some padding

    -- Input Box Background
    win.InputBg = win:CreateTexture(nil, "BACKGROUND")
    win.InputBg:SetColorTexture(0, 0, 0, 0.6)
    win.InputBg:SetPoint("TOPLEFT", win.Input, "TOPLEFT", -4, 4)
    win.InputBg:SetPoint("BOTTOMRIGHT", win.Input, "BOTTOMRIGHT", 4, -4)

    -- Input Box Border
    win.InputBorder = CreateFrame("Frame", nil, win, "BackdropTemplate")
    win.InputBorder:SetPoint("TOPLEFT", win.Input, "TOPLEFT", -5, 5)
    win.InputBorder:SetPoint("BOTTOMRIGHT", win.Input, "BOTTOMRIGHT", 5, -5)
    win.InputBorder:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    win.InputBorder:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
    win.InputBorder:EnableMouse(false)
    win.InputBorder:SetFrameStrata("LOW")

    -- History ScrollingMessageFrame
    win.History = CreateFrame("ScrollingMessageFrame", nil, win)
    win.History:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -40)
    win.History:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -12, 12)
    win.History:SetMaxLines(MAX_HISTORY_LINES)
    win.History:SetFading(false)
    win.History:SetFontObject(ChatFontNormal)
    win.History:SetJustifyH("LEFT")
    win.History:SetHyperlinksEnabled(true)
    win.History:SetScript("OnHyperlinkClick", ChatFrame_OnHyperlinkShow)
    
    -- Enable mouse wheel scrolling for history
    win.History:EnableMouseWheel(true)
    win.History:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then
            self:ScrollUp()
        else
            self:ScrollDown()
        end
    end)

    -- Character Count
    local inputCount = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    inputCount:SetPoint("BOTTOMRIGHT", win.Input, "TOPRIGHT", -4, 2)
    inputCount:SetTextColor(0.6, 0.6, 0.6)
    inputCount:SetText("0/" .. CHAT_MAX_LETTERS)

    -- Input Box Scripts
    win.Input:SetScript("OnEnterPressed", function(self)
        local message = self:GetText()
        if message and message ~= "" then
            if win.isBNet then
                -- Send BNet whisper
                BNSendWhisper(win.bnSenderID, message)
            else
                -- Send regular whisper
                C_ChatInfo.SendChatMessage(message, "WHISPER", nil, win.playerTarget)
            end
            -- Don't manually add to history here - let the INFORM event handle it
            self:SetText("")
            UpdateInputHeight(self)  -- Reset height after sending
        end
    end)
    win.Input:SetScript("OnTextChanged", function(self)
        local len = self:GetNumLetters()
        inputCount:SetText(len .. "/" .. CHAT_MAX_LETTERS)
        if len >= CHAT_MAX_LETTERS - 15 then
            inputCount:SetTextColor(1.0, 0.3, 0.3)
        elseif len >= CHAT_MAX_LETTERS - 50 then
            inputCount:SetTextColor(1.0, 0.82, 0)
        else
            inputCount:SetTextColor(0.6, 0.6, 0.6)
        end
        
        -- Update input height dynamically as user types
        UpdateInputHeight(self)
    end)
    win.Input:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        -- Hide the window frame, not the parent (UIParent)
        if win and win.Hide then
            win:Hide()
        end
    end)
    
    -- Also update height when the window is resized
    win.Input:SetScript("OnSizeChanged", function(self)
        UpdateInputHeight(self)
    end)
    
    -- Misspelled addon integration
    if _G.Misspelled and _G.Misspelled.WireUpEditBox then
        _G.Misspelled:WireUpEditBox(win.Input)
        DebugMessage("Misspelled integration enabled for EditBox")
    end
    
    DebugMessage("CreateWindow finished successfully for", playerKey);
    addon:ApplyWindowPosition(win)
    return win
end

--------------------------------------------------------------------
-- Emote and Speech Detection (TotalRP3-style)
--------------------------------------------------------------------

-- Format message to detect and colorize emotes (*text*) and speech ("text")
local function FormatEmotesAndSpeech(message)
    if not message or message == "" then return message end
    
    -- Get WoW's emote color (orange)
    local emoteColor = ChatTypeInfo["EMOTE"]
    local emoteHex = string.format("|cff%02x%02x%02x", emoteColor.r * 255, emoteColor.g * 255, emoteColor.b * 255)
    
    -- Get WoW's say color (white)
    local sayColor = ChatTypeInfo["SAY"]
    local sayHex = string.format("|cff%02x%02x%02x", sayColor.r * 255, sayColor.g * 255, sayColor.b * 255)
    
    -- Detect and colorize emotes surrounded by asterisks: *emote*
    message = message:gsub("(%*.-%*)", function(emote)
        return emoteHex .. emote .. "|r"
    end)
    
    -- Detect and colorize speech surrounded by quotes: "speech"
    message = message:gsub('(".-")', function(speech)
        return sayHex .. speech .. "|r"
    end)
    
    return message
end

--------------------------------------------------------------------
-- History Management
--------------------------------------------------------------------

function addon:AddMessageToHistory(playerKey, displayName, author, message)
    if not playerKey then return end
    if not WhisperManager_HistoryDB then WhisperManager_HistoryDB = {} end
    WhisperManager_HistoryDB.__schema = 4  -- Updated schema version (no __display)
    if not WhisperManager_HistoryDB[playerKey] then
        WhisperManager_HistoryDB[playerKey] = {}
    end
    local history = WhisperManager_HistoryDB[playerKey]
    
    -- Use optimized format: m = message, a = author, t = timestamp
    -- For "Me", use actual character name with realm
    local playerName, playerRealm = UnitName("player")
    local fullPlayerName = playerName .. "-" .. (playerRealm or GetRealmName())
    local authorName = (author == "Me") and fullPlayerName or author
    
    table.insert(history, { m = message, a = authorName, t = time() })
    if #history > MAX_HISTORY_LINES then
        table.remove(history, 1)
    end
end

function addon:DisplayHistory(window, playerKey)
    if not WhisperManager_HistoryDB then return end
    local historyFrame = window.History
    historyFrame:Clear()
    local history = WhisperManager_HistoryDB[playerKey]
    if not history then return end

    -- Extract display name from key instead of using __display
    local displayName = self:GetDisplayNameFromKey(playerKey)
    if window.Title then
        window.playerDisplay = displayName
        local titlePrefix = window.isBNet and "BNet Whisper: " or "Whisper: "
        window.Title:SetText(titlePrefix .. displayName)
    end
    
    local playerName, playerRealm = UnitName("player")
    local fullPlayerName = playerName .. "-" .. (playerRealm or GetRealmName())

    for _, entry in ipairs(history) do
        -- Support both old and new format
        local timestamp = entry.t or entry.timestamp
        local author = entry.a or entry.author
        local message = entry.m or entry.message
        
        if timestamp and author and message then
            local timeString = date("[%H:%M]", timestamp)
            local coloredAuthor
            if author == "Me" or author == playerName or author == fullPlayerName then
                coloredAuthor = "|cff9494ffMe|r"
            else
                coloredAuthor = string.format("|cffffd100%s|r", author)
            end
            local safeMessage = message:gsub("%%", "%%%%")
            
            -- Apply emote and speech formatting
            safeMessage = FormatEmotesAndSpeech(safeMessage)
            
            local formattedMessage = string.format("%s %s: %s", timeString, coloredAuthor, safeMessage)
            historyFrame:AddMessage(formattedMessage)
        end
    end
    historyFrame:ScrollToBottom()
end

--------------------------------------------------------------------
-- Floating Button UI
--------------------------------------------------------------------

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

--------------------------------------------------------------------
-- Recent Chats Frame
--------------------------------------------------------------------

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
        table.insert(chats, {
            playerKey = playerKey,
            displayName = self:GetDisplayNameFromKey(playerKey),  -- Extract from key
            lastMessageTime = data.lastMessageTime,
            isRead = data.isRead,
            isBNet = data.isBNet,
        })
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
        btn.nameText:SetText(chat.displayName)
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
        btn.timeText:SetText(GetTimeAgo(chat.lastMessageTime))
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

--------------------------------------------------------------------
-- History/Search Frame
--------------------------------------------------------------------

function addon:CreateHistoryFrame()
    local frame = CreateFrame("Frame", "WhisperManager_History", UIParent, "BackdropTemplate")
    frame:SetSize(500, 600)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetResizeBounds(400, 400, 800, 800)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        addon:SaveHistoryPosition()
    end)
    frame:SetScript("OnHide", function(self)
        addon:SaveHistoryPosition()
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
    
    -- Title
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOP", 0, -10)
    frame.title:SetText("Chat History")
    
    -- Close button
    frame.closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.closeBtn:SetPoint("TOPRIGHT", -2, -2)
    frame.closeBtn:SetSize(24, 24)
    
    -- Resize button
    frame.resizeBtn = CreateFrame("Button", nil, frame)
    frame.resizeBtn:SetSize(16, 16)
    frame.resizeBtn:SetPoint("BOTTOMRIGHT")
    frame.resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    frame.resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    frame.resizeBtn:SetScript("OnMouseDown", function()
        frame:StartSizing("BOTTOMRIGHT")
    end)
    frame.resizeBtn:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        addon:SaveHistoryPosition()
    end)
    
    -- Search box
    frame.searchBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    frame.searchBox:SetSize(200, 30)
    frame.searchBox:SetPoint("TOPLEFT", 10, -40)
    frame.searchBox:SetAutoFocus(false)
    frame.searchBox:SetScript("OnTextChanged", function(self)
        addon:FilterHistoryList(self:GetText())
    end)
    frame.searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    
    -- Search label
    frame.searchLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.searchLabel:SetPoint("LEFT", frame.searchBox, "RIGHT", 10, 0)
    frame.searchLabel:SetText("Search")
    
    -- List view (left side)
    frame.listScrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    frame.listScrollFrame:SetPoint("TOPLEFT", 10, -80)
    frame.listScrollFrame:SetPoint("BOTTOMLEFT", 10, 10)
    frame.listScrollFrame:SetWidth(200)
    
    frame.listScrollChild = CreateFrame("Frame", nil, frame.listScrollFrame)
    frame.listScrollChild:SetSize(180, 1)
    frame.listScrollFrame:SetScrollChild(frame.listScrollChild)
    
    -- Enable mouse wheel scrolling for history list
    frame.listScrollFrame:EnableMouseWheel(true)
    frame.listScrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local scrollBar = self.ScrollBar
        if scrollBar then
            local current = scrollBar:GetValue()
            local _, maxValue = scrollBar:GetMinMaxValues()
            local step = 40 * delta
            scrollBar:SetValue(math.max(0, math.min(maxValue, current - step)))
        end
    end)
    
    -- Detail view (right side)
    frame.detailFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.detailFrame:SetPoint("TOPLEFT", frame.listScrollFrame, "TOPRIGHT", 20, 0)
    frame.detailFrame:SetPoint("BOTTOMRIGHT", -10, 10)
    frame.detailFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    frame.detailFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    frame.detailFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    
    -- Detail title
    frame.detailTitle = frame.detailFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.detailTitle:SetPoint("TOP", 0, -10)
    frame.detailTitle:SetText("Select a conversation")
    
    -- Detail scroll frame with proper scrolling support
    frame.detailScrollFrame = CreateFrame("ScrollFrame", nil, frame.detailFrame, "UIPanelScrollFrameTemplate")
    frame.detailScrollFrame:SetPoint("TOPLEFT", 10, -35)
    frame.detailScrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
    
    -- Create scroll child to hold the message text
    frame.detailScrollChild = CreateFrame("Frame", nil, frame.detailScrollFrame)
    frame.detailScrollChild:SetWidth(frame.detailScrollFrame:GetWidth())
    frame.detailScrollChild:SetHeight(1)
    frame.detailScrollFrame:SetScrollChild(frame.detailScrollChild)
    
    -- Update width when frame is resized
    frame:SetScript("OnSizeChanged", function()
        local width = frame.detailScrollFrame:GetWidth()
        if width > 0 then
            frame.detailScrollChild:SetWidth(width)
            frame.detailText:SetWidth(width - 35) -- Account for padding and scrollbar
        end
    end)
    
    -- Create a font string for displaying messages
    frame.detailText = frame.detailScrollChild:CreateFontString(nil, "OVERLAY", "ChatFontNormal")
    frame.detailText:SetPoint("TOPLEFT", 5, -5)
    frame.detailText:SetWidth(frame.detailScrollFrame:GetWidth() - 35) -- Account for padding and scrollbar
    frame.detailText:SetJustifyH("LEFT")
    frame.detailText:SetJustifyV("TOP")
    frame.detailText:SetWordWrap(true)
    frame.detailText:SetNonSpaceWrap(true)
    frame.detailText:SetText("Select a conversation")
    
    -- Enable mouse wheel scrolling
    frame.detailScrollFrame:EnableMouseWheel(true)
    frame.detailScrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local scrollBar = self.ScrollBar or _G[self:GetName().."ScrollBar"]
        if scrollBar then
            local current = scrollBar:GetValue()
            local _, maxValue = scrollBar:GetMinMaxValues()
            local step = 20 * delta
            scrollBar:SetValue(math.max(0, math.min(maxValue, current - step)))
        end
    end)
    
    addon.historyFrame = frame
    return frame
end

function addon:SaveHistoryPosition()
    if not self.historyFrame then return end
    if not WhisperManager_Config then WhisperManager_Config = {} end
    
    local point, _, relativePoint, xOfs, yOfs = self.historyFrame:GetPoint(1)
    local width, height = self.historyFrame:GetSize()
    
    if point then
        WhisperManager_Config.historyPos = {
            point = point,
            relativePoint = relativePoint,
            xOfs = xOfs,
            yOfs = yOfs,
            width = width,
            height = height,
        }
    end
end

function addon:LoadHistoryPosition()
    if not self.historyFrame then return end
    if not WhisperManager_Config or not WhisperManager_Config.historyPos then return end
    
    local pos = WhisperManager_Config.historyPos
    self.historyFrame:ClearAllPoints()
    self.historyFrame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.xOfs, pos.yOfs)
    
    if pos.width and pos.height then
        self.historyFrame:SetSize(pos.width, pos.height)
    end
end

function addon:ToggleHistoryFrame()
    if not self.historyFrame then
        self:CreateHistoryFrame()
        self:LoadHistoryPosition()
    end
    
    if self.historyFrame:IsShown() then
        self.historyFrame:Hide()
    else
        -- Close recent chats frame if it's open
        if self.recentChatsFrame and self.recentChatsFrame:IsShown() then
            self.recentChatsFrame:Hide()
        end
        
        self:RefreshHistoryList()
        self.historyFrame:Show()
    end
end

function addon:RefreshHistoryList(filterText)
    if not self.historyFrame then return end
    
    -- Clear existing buttons
    local scrollChild = self.historyFrame.listScrollChild
    for _, child in ipairs({scrollChild:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end
    
    if not WhisperManager_HistoryDB then
        return
    end
    
    -- Convert to sorted array
    local conversations = {}
    for playerKey, history in pairs(WhisperManager_HistoryDB) do
        if playerKey ~= "__schema" and type(history) == "table" and #history > 0 then
            -- Extract display name from key instead of using __display
            local displayName = self:GetDisplayNameFromKey(playerKey)
            -- Support both old and new format
            local lastEntry = history[#history]
            local lastTimestamp = lastEntry.t or lastEntry.timestamp or 0
            
            -- Apply filter if provided
            if not filterText or filterText == "" or 
               displayName:lower():find(filterText:lower(), 1, true) then
                table.insert(conversations, {
                    playerKey = playerKey,
                    displayName = displayName,
                    lastTimestamp = lastTimestamp,
                })
            end
        end
    end
    
    -- Sort by most recent first
    table.sort(conversations, function(a, b)
        return a.lastTimestamp > b.lastTimestamp
    end)
    
    -- Create buttons for each conversation
    local yOffset = 0
    for i, conv in ipairs(conversations) do
        local btn = CreateFrame("Button", nil, scrollChild)
        btn:SetSize(180, 50)
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
        btn.nameText:SetPoint("TOPRIGHT", -5, -5)
        btn.nameText:SetText(conv.displayName)
        btn.nameText:SetJustifyH("LEFT")
        btn.nameText:SetWordWrap(false)
        
        -- Time text
        btn.timeText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.timeText:SetPoint("BOTTOMLEFT", 5, 5)
        btn.timeText:SetText(GetTimeAgo(conv.lastTimestamp))
        btn.timeText:SetTextColor(0.7, 0.7, 0.7)
        
        -- Click to show detail
        btn:SetScript("OnClick", function()
            addon:ShowHistoryDetail(conv.playerKey, conv.displayName)
        end)
        
        yOffset = yOffset + 55
    end
    
    scrollChild:SetHeight(math.max(yOffset, 1))
end

function addon:FilterHistoryList(filterText)
    self:RefreshHistoryList(filterText)
end

function addon:ShowHistoryDetail(playerKey, displayName)
    if not self.historyFrame then return end
    
    local detailTitle = self.historyFrame.detailTitle
    local detailText = self.historyFrame.detailText
    local detailScrollChild = self.historyFrame.detailScrollChild
    local detailScrollFrame = self.historyFrame.detailScrollFrame
    
    detailTitle:SetText(displayName)
    
    -- Set scroll child width to match scroll frame
    local scrollWidth = detailScrollFrame:GetWidth()
    if scrollWidth > 0 then
        detailScrollChild:SetWidth(scrollWidth)
        detailText:SetWidth(scrollWidth - 35) -- Account for padding and scrollbar
    end
    
    if not WhisperManager_HistoryDB or not WhisperManager_HistoryDB[playerKey] then
        detailText:SetText("No message history found.")
        detailScrollChild:SetHeight(detailText:GetStringHeight() + 10)
        return
    end
    
    local history = WhisperManager_HistoryDB[playerKey]
    local messageLines = {}
    local playerName, playerRealm = UnitName("player")
    local fullPlayerName = playerName .. "-" .. (playerRealm or GetRealmName())
    
    for _, entry in ipairs(history) do
        -- Support both old and new format
        local timestamp = entry.t or entry.timestamp
        local author = entry.a or entry.author
        local message = entry.m or entry.message
        
        if timestamp and author and message then
            local timeString = date("[%H:%M]", timestamp)
            local coloredAuthor
            if author == "Me" or author == playerName or author == fullPlayerName then
                coloredAuthor = "|cff9494ffMe|r"
            else
                coloredAuthor = string.format("|cffffd100%s|r", author)
            end
            local safeMessage = message:gsub("%%", "%%%%")
            
            -- Apply emote and speech formatting
            safeMessage = FormatEmotesAndSpeech(safeMessage)
            
            local formattedMessage = string.format("%s %s: %s", timeString, coloredAuthor, safeMessage)
            table.insert(messageLines, formattedMessage)
        end
    end
    
    local fullText = table.concat(messageLines, "\n")
    detailText:SetText(fullText)
    
    -- Update scroll child height based on text height
    local textHeight = detailText:GetStringHeight()
    detailScrollChild:SetHeight(math.max(textHeight + 10, detailScrollFrame:GetHeight()))
    
    -- Scroll to bottom
    C_Timer.After(0, function()
        local scrollBar = detailScrollFrame.ScrollBar
        if scrollBar then
            local _, maxValue = scrollBar:GetMinMaxValues()
            scrollBar:SetValue(maxValue)
        end
    end)
end

--------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------

function addon:Initialize()
    if type(WhisperManager_HistoryDB) ~= "table" then
        WhisperManager_HistoryDB = {}
    end
    
    if type(WhisperManager_RecentChats) ~= "table" then
        WhisperManager_RecentChats = {}
    end

    if not WhisperManager_HistoryDB.__schema or WhisperManager_HistoryDB.__schema < 2 then
        local migrated = {}
        for key, history in pairs(WhisperManager_HistoryDB) do
            if key ~= "__schema" then
                local canonicalKey, _, displayName = addon:ResolvePlayerIdentifiers(key)
                if canonicalKey then
                    if not migrated[canonicalKey] then
                        if type(history) == "table" then
                            migrated[canonicalKey] = history
                        else
                            migrated[canonicalKey] = {}
                        end
                    elseif type(history) == "table" then
                        for _, entry in ipairs(history) do
                            table.insert(migrated[canonicalKey], entry)
                        end
                    end

                    local targetHistory = migrated[canonicalKey]
                    if type(targetHistory) == "table" and displayName then
                        targetHistory.__display = targetHistory.__display or displayName
                    end
                end
            end
        end
        migrated.__schema = 2
        WhisperManager_HistoryDB = migrated
    end

    for key, history in pairs(WhisperManager_HistoryDB) do
        if key ~= "__schema" and type(history) == "table" and history.__display then
            addon.playerDisplayNames[key] = history.__display
        end
    end

    if type(WhisperManager_Config) ~= "table" then
        WhisperManager_Config = {}
    end
    if WhisperManager_Config.debug == nil then
        WhisperManager_Config.debug = DEFAULT_DEBUG_MODE
    end
    addon.debugEnabled = not not WhisperManager_Config.debug

    if type(WhisperManager_WindowDB) ~= "table" then
        WhisperManager_WindowDB = {}
    end

    SLASH_WHISPERMANAGER1 = "/wm"
    SLASH_WHISPERMANAGER2 = "/whispermanager"
    SlashCmdList.WHISPERMANAGER = function(msg)
        addon:HandleSlashCommand(msg)
    end

    DebugMessage("Initialize() started.");

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("CHAT_MSG_WHISPER")
    eventFrame:RegisterEvent("CHAT_MSG_WHISPER_INFORM")
    eventFrame:RegisterEvent("CHAT_MSG_BN_WHISPER")
    eventFrame:RegisterEvent("CHAT_MSG_BN_WHISPER_INFORM")

    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "CHAT_MSG_WHISPER" then
            local message, author = ...
            local playerKey, _, displayName = addon:ResolvePlayerIdentifiers(author)
            if not playerKey then return end

            addon:AddMessageToHistory(playerKey, displayName or author, author, message)
            addon:UpdateRecentChat(playerKey, displayName or author, false)
            addon:OpenConversation(author)
            local window = addon.windows[playerKey]
            if window then
                addon:DisplayHistory(window, playerKey)
            end
        elseif event == "CHAT_MSG_WHISPER_INFORM" then
            local message, target = ...
            local playerKey, resolvedTarget, displayName = addon:ResolvePlayerIdentifiers(target)
            if not playerKey then return end

            addon:AddMessageToHistory(playerKey, displayName or resolvedTarget, "Me", message)
            addon:UpdateRecentChat(playerKey, displayName or resolvedTarget, false)
            addon:OpenConversation(resolvedTarget)
            local window = addon.windows[playerKey]
            if window then
                addon:DisplayHistory(window, playerKey)
            end
        elseif event == "CHAT_MSG_BN_WHISPER" then
            local message, author, _, _, _, _, _, _, _, _, _, _, bnSenderID = ...
            
            -- Get BattleTag for permanent identification
            local accountInfo = C_BattleNet.GetAccountInfoByID(bnSenderID)
            if not accountInfo or not accountInfo.battleTag then
                DebugMessage("|cffff0000ERROR: Could not get BattleTag for incoming BNet whisper|r")
                return
            end
            
            local playerKey = "bnet_" .. accountInfo.battleTag
            local displayName = accountInfo.accountName or author or accountInfo.battleTag
            
            addon:AddMessageToHistory(playerKey, displayName, author, message)
            addon:UpdateRecentChat(playerKey, displayName, true)
            addon:OpenBNetConversation(bnSenderID, author)
            local window = addon.windows[playerKey]
            if window then
                addon:DisplayHistory(window, playerKey)
            end
        elseif event == "CHAT_MSG_BN_WHISPER_INFORM" then
            local message, _, _, _, _, _, _, _, _, _, _, _, bnSenderID = ...
            
            -- Get BattleTag for permanent identification
            local accountInfo = C_BattleNet.GetAccountInfoByID(bnSenderID)
            if not accountInfo or not accountInfo.battleTag then
                DebugMessage("|cffff0000ERROR: Could not get BattleTag for outgoing BNet whisper|r")
                return
            end
            
            local playerKey = "bnet_" .. accountInfo.battleTag
            local displayName = accountInfo.accountName or accountInfo.battleTag
            
            addon:AddMessageToHistory(playerKey, displayName, "Me", message)
            addon:UpdateRecentChat(playerKey, displayName, true)
            addon:OpenBNetConversation(bnSenderID, displayName)
            local window = addon.windows[playerKey]
            if window then
                addon:DisplayHistory(window, playerKey)
            end
        elseif event == "PLAYER_ENTERING_WORLD" then
            DebugMessage("PLAYER_ENTERING_WORLD fired. Setting up hooks.");

            hooksecurefunc("ChatEdit_ExtractTellTarget", function(editBox, text)
                local target = addon:ExtractWhisperTarget(text)
                if not target then return end
                DebugMessage("Hooked /w via ChatEdit_ExtractTellTarget. Target:", target)
                if addon:OpenConversation(target) then
                    _G.ChatEdit_OnEscapePressed(editBox)
                end
            end)

            hooksecurefunc("ChatFrame_OpenChat", function(text, chatFrame)
                -- Don't trigger if we're closing a window
                if addon.__closingWindow then
                    DebugMessage("ChatFrame_OpenChat ignored - window closing")
                    return
                end
                
                local editBox = chatFrame and chatFrame.editBox or _G.ChatEdit_ChooseBoxForSend(chatFrame)
                if not editBox then return end

                local chatType = editBox:GetAttribute("chatType")
                if chatType ~= "WHISPER" then
                    return
                end

                -- Only intercept if text contains /w or /whisper command
                if not text or not text:match("^/[Ww]") then
                    DebugMessage("ChatFrame_OpenChat ignored - no /w command in text")
                    return
                end

                local target = editBox:GetAttribute("tellTarget")
                if not target or target == "" then return end

                if editBox.__WhisperManagerHandled then return end
                editBox.__WhisperManagerHandled = true

                DebugMessage("ChatFrame_OpenChat captured whisper target:", target)

                if addon:OpenConversation(target) then
                    _G.ChatEdit_OnEscapePressed(editBox)
                end
                
                C_Timer.After(0.1, function()
                    editBox.__WhisperManagerHandled = nil
                end)
            end)

            hooksecurefunc("ChatFrame_ReplyTell", function()
                local target = _G.ChatEdit_GetLastTellTarget()
                if target and addon:OpenConversation(target) then
                    local activeEditBox = _G.ChatEdit_ChooseBoxForSend()
                    if activeEditBox then
                        _G.ChatEdit_OnEscapePressed(activeEditBox)
                    end
                end
            end)

            -- [DIAGNOSTIC VERSION] This function will now print detailed information.
            local function AddWhisperManagerButton(owner, rootDescription, contextData)
                DebugMessage("AddWhisperManagerButton fired.")
            
                if not contextData then
                    DebugMessage("|cffff0000ERROR: contextData is nil!|r")
                    return
                end
            
                DebugMessage("Inspecting contextData:")
                if contextData.unit then
                    DebugMessage("- contextData.unit:", contextData.unit)
                else
                    DebugMessage("- contextData.unit: nil")
                end
                if contextData.name then
                    DebugMessage("- contextData.name:", contextData.name)
                else
                    DebugMessage("- contextData.name: nil")
                end
            
                local playerName
                local unit = contextData.unit
                
                -- Try to get name from unit token first
                if unit and UnitExists(unit) and UnitIsPlayer(unit) then
                    local name, realm = UnitName(unit)
                    if name then
                        if realm and realm ~= "" then
                            playerName = string.format("%s-%s", name, realm)
                        else
                            playerName = name
                        end
                    end
                    DebugMessage("Player name found from unit token:", playerName)
                end
                
                -- Fallback to contextData.name if available
                if not playerName and contextData.name and contextData.name ~= "" then
                    playerName = contextData.name
                    DebugMessage("Player name found from contextData.name:", playerName)
                end
            
                if playerName then
                    DebugMessage("Successfully determined playerName:", playerName)
                    local playerKey = addon:ResolvePlayerIdentifiers(playerName)
                    if playerKey then
                        DebugMessage("Adding button to the menu...")
                        rootDescription:CreateDivider()
                        rootDescription:CreateButton("Open in WhisperManager", function()
                            DebugMessage("Menu button clicked for:", playerName)
                            addon:OpenConversation(playerName)
                        end)
                        DebugMessage("Button added successfully.")
                    else
                        DebugMessage("|cffffff00INFO: Could not normalize player key.|r")
                    end
                else
                    DebugMessage("|cffffff00INFO: Could not determine a player name. Not adding button.|r")
                end
            end

            local tagsToModify = {
                "MENU_UNIT_TARGET",
                "MENU_UNIT_FOCUS",
                "MENU_UNIT_FRIEND",
                "MENU_UNIT_CHAT_PLAYER",
                "MENU_UNIT_PLAYER",
                "MENU_UNIT_ENEMY_PLAYER",
                "MENU_UNIT_RAID_PLAYER",
                "MENU_UNIT_SELF",
            }
            for i = 1, 4 do 
                table.insert(tagsToModify, "MENU_UNIT_PARTY"..i)
                table.insert(tagsToModify, "MENU_UNIT_RAID"..i)
            end
            for i = 1, 40 do
                table.insert(tagsToModify, "MENU_UNIT_RAID_PLAYER"..i)
            end
            for _, tag in ipairs(tagsToModify) do 
                Menu.ModifyMenu(tag, AddWhisperManagerButton) 
            end

            self:UnregisterEvent("PLAYER_ENTERING_WORLD")
            DebugMessage("Hooks installed.");
            
            -- Create floating button after hooks are set up
            addon:CreateFloatingButton()
        end
    end)
    DebugMessage("Initialize() finished.");
end

addon:Initialize()