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

local MAX_HISTORY_LINES = 200;
local CHAT_MAX_LETTERS = 245;

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
    local canonicalKey
    if realmPart and realmPart ~= "" then
        canonicalKey = strlower(baseName .. "-" .. realmPart)
    else
        canonicalKey = strlower(baseName)
    end

    local display = Ambiguate(trimmed, "short") or target
    if not display or display == "" then
        if realmPart and realmPart ~= "" then
            display = baseName .. "-" .. realmPart
        else
            display = baseName
        end
    end

    return canonicalKey, target, display
end

function addon:RecordDisplayName(playerKey, displayName)
    if playerKey and displayName and displayName ~= "" then
        addon.playerDisplayNames[playerKey] = displayName
    end
    return addon.playerDisplayNames[playerKey]
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
    else
        if not addon:OpenConversation(input) then
            addon:Print(string.format("Unable to open a whisper window for '%s'.", input))
        end
    end
end

--------------------------------------------------------------------
-- Core Functions
--------------------------------------------------------------------

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
    DebugMessage("OpenConversation called for:", playerName);
    local playerKey, playerTarget, displayName = self:ResolvePlayerIdentifiers(playerName)
    if not playerKey then
        DebugMessage("|cffff0000ERROR: Unable to resolve player identifiers for|r", playerName)
        return false
    end

    displayName = displayName and displayName ~= "" and displayName or addon.playerDisplayNames[playerKey] or playerTarget or playerName

    self:RecordDisplayName(playerKey, displayName)

    local win = self.windows[playerKey]
    if not win then
        DebugMessage("No existing window. Calling CreateWindow.");
        win = self:CreateWindow(playerKey, playerTarget, displayName)
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
    
    return true
end

function addon:CreateWindow(playerKey, playerTarget, displayName)
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
    win.Title:SetText("Whisper: " .. (displayName or playerTarget or playerKey))
    win.Title:SetTextColor(1, 0.82, 0, 1)

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

    -- Character Count
    local inputCount = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    inputCount:SetPoint("BOTTOMRIGHT", win.Input, "TOPRIGHT", -4, 2)
    inputCount:SetTextColor(0.6, 0.6, 0.6)
    inputCount:SetText("0/" .. CHAT_MAX_LETTERS)

    -- Input Box Scripts
    win.Input:SetScript("OnEnterPressed", function(self)
        local message = self:GetText()
        if message and message ~= "" then
            C_ChatInfo.SendChatMessage(message, "WHISPER", nil, win.playerTarget)
            addon:AddMessageToHistory(win.playerKey, win.playerDisplay or win.playerTarget, "Me", message)
            addon:DisplayHistory(win, win.playerKey)
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
        local parent = self:GetParent()
        if parent and parent.Hide then
            parent:Hide()
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
-- History Management
--------------------------------------------------------------------

function addon:AddMessageToHistory(playerKey, displayName, author, message)
    if not playerKey then return end
    if not WhisperManager_HistoryDB then WhisperManager_HistoryDB = {} end
    WhisperManager_HistoryDB.__schema = 2
    if not WhisperManager_HistoryDB[playerKey] then
        WhisperManager_HistoryDB[playerKey] = {}
    end
    local history = WhisperManager_HistoryDB[playerKey]
    if displayName and displayName ~= "" then
        history.__display = displayName
        addon:RecordDisplayName(playerKey, displayName)
    end
    table.insert(history, { author = author, message = message, timestamp = time() })
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

    if history.__display and window.Title then
        window.playerDisplay = history.__display
        window.Title:SetText("Whisper: " .. history.__display)
    end

    for _, entry in ipairs(history) do
        local timeString = date("[%H:%M]", entry.timestamp)
        local coloredAuthor
        if entry.author == "Me" then
            coloredAuthor = "|cff9494ffMe|r"
        else
            coloredAuthor = string.format("|cffffd100%s|r", entry.author)
        end
        local safeMessage = entry.message:gsub("%%", "%%%%")
        local formattedMessage = string.format("%s %s: %s", timeString, coloredAuthor, safeMessage)
        historyFrame:AddMessage(formattedMessage)
    end
    historyFrame:ScrollToBottom()
end

--------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------

function addon:Initialize()
    if type(WhisperManager_HistoryDB) ~= "table" then
        WhisperManager_HistoryDB = {}
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

    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "CHAT_MSG_WHISPER" then
            local message, author = ...
            local playerKey, _, displayName = addon:ResolvePlayerIdentifiers(author)
            if not playerKey then return end

            addon:AddMessageToHistory(playerKey, displayName or author, author, message)
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
            addon:OpenConversation(resolvedTarget)
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
                local editBox = chatFrame and chatFrame.editBox or _G.ChatEdit_ChooseBoxForSend(chatFrame)
                if not editBox then return end

                local chatType = editBox:GetAttribute("chatType")
                if chatType ~= "WHISPER" then
                    editBox.__WhisperManagerHandled = nil
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
                editBox.__WhisperManagerHandled = nil
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
        end
    end)
    DebugMessage("Initialize() finished.");
end

addon:Initialize()