-- Create the main addon table to hold all our functions and data
WhisperManager = {};
local addon = WhisperManager;

-- A table to keep track of all open whisper windows
addon.windows = {};

-- The maximum number of lines to store per conversation
local MAX_HISTORY_LINES = 200;
local CHAT_MAX_LETTERS = 245; -- Max character length with a safe buffer

--------------------------------------------------------------------
-- Core Functions
--------------------------------------------------------------------

-- This is the main function to open a whisper window for a player.
function addon:OpenConversation(playerName)
    -- Guard against nil, non-string, or empty input.
    if not playerName or type(playerName) ~= "string" or playerName == "" then
        return
    end

    -- Aggressively clean the player name: trim whitespace, then extract the name part.
    local trimmedName = playerName:gsub("^%s+", ""):gsub("%s+$", "")
    local cleanName = trimmedName:match("([^%-]+)") -- Get text before the first hyphen, if any.
    if not cleanName or cleanName == "" then
        cleanName = trimmedName
    end

    -- Add a check to prevent opening a window for oneself.
    if strlower(cleanName) == strlower(UnitName("player"):match("([^%-]+)")) then
        return
    end

    local playerKey = Ambiguate(cleanName, "none")
    -- If Ambiguate fails to resolve the name, use the cleaned name as a fallback.
    if not playerKey or playerKey == "" then
        playerKey = cleanName
    end
    
    -- Final paranoid guard to ensure we have a valid string before proceeding.
    if not playerKey or type(playerKey) ~= "string" or playerKey == "" then
        return
    end

    local win = self.windows[playerKey];

    if not win then
        win = self:CreateWindow(playerKey);
        self.windows[playerKey] = win;
    end

    self:DisplayHistory(win, playerKey);

    local title = _G[win:GetName() .. "Title"];
    title:SetText("Whisper: " .. playerKey);

    win:Show();
    win:Raise();
    _G[win:GetName() .. "Input"]:SetFocus();
end

-- This function creates a new window frame from our XML template.
function addon:CreateWindow(playerKey)
    local frameName = "WhisperManager_" .. playerKey:gsub("[^%w]","");
    local win = CreateFrame("Frame", frameName, UIParent, "WhisperManager_WindowTemplate");

    win.player = playerKey;

    -- Setup main window properties
    win:SetSize(400, 280);
    win:SetPoint("CENTER");
    win:SetClampedToScreen(true);
    win:SetMovable(true);
    win:EnableMouse(true);
    win:RegisterForDrag("LeftButton");
    win:SetScript("OnDragStart", win.StartMoving);
    win:SetScript("OnDragStop", win.StopMovingOrSizing);

    -- Apply the standard window background and border in Lua
    Mixin(win, BackdropTemplateMixin);
    win:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    });

    -- Get references to child frames
    local title = _G[frameName .. "Title"];
    local history = _G[frameName .. "History"];
    local input = _G[frameName .. "Input"];
    local closeButton = _G[frameName .. "CloseButton"];
    
    -- Setup Title
    title:SetFontObject(GameFontNormal);
    title:SetPoint("TOP", win, "TOP", 0, -18);

    -- Manually style the close button
    closeButton:SetParent(win);
    closeButton:SetSize(32, 32);
    closeButton:SetPoint("TOPRIGHT", win, "TOPRIGHT", -6, -6);
    closeButton:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up");
    closeButton:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down");
    closeButton:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight");
    closeButton:SetScript("OnClick", function() win:Hide() end);

    -- LAYOUT: Anchor the input box to the bottom of the main window
    input:SetSize(0, 24);
    input:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 16, 15);
    input:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -16, 15);
    
    -- LAYOUT: Anchor the history frame above the input box
    history:SetPoint("TOPLEFT", win, "TOPLEFT", 16, -40);
    history:SetPoint("BOTTOMRIGHT", input, "TOPRIGHT", 0, 34);
    
    -- Setup History Frame properties
    history:SetMaxLines(MAX_HISTORY_LINES);
    history:SetFading(false);
    history:SetFontObject(ChatFontNormal);

    -- Setup Input Box properties
    input:SetMultiLine(false);
    input:SetAutoFocus(true);
    input:SetHistoryLines(1);
    
    input:SetMaxLetters(CHAT_MAX_LETTERS);
    
    local inputCount = win:CreateFontString(frameName .. "InputCount", "OVERLAY", "GameFontNormalSmall");
    inputCount:SetPoint("BOTTOMRIGHT", input, "BOTTOMRIGHT", -5, 5);
    inputCount:SetTextColor(0.8, 0.8, 0.8);
    inputCount:SetText("0/" .. CHAT_MAX_LETTERS);

    -- Setup Input Box background textures
    local left = _G[frameName .. "InputLeft"];
    local right = _G[frameName .. "InputRight"];
    local mid = _G[frameName .. "InputMid"];
    left:SetTexture("Interface\\ChatFrame\\UI-ChatInputBorder-Left");
    left:SetSize(8, 24);
    left:SetPoint("LEFT", input, "LEFT", -10, 0);
    right:SetTexture("Interface\\ChatFrame\\UI-ChatInputBorder-Right");
    right:SetSize(8, 24);
    right:SetPoint("RIGHT", input, "RIGHT", 10, 0);
    mid:SetTexture("Interface\\ChatFrame\\UI-ChatInputBorder-Mid", true);
    mid:SetPoint("LEFT", left, "RIGHT");
    mid:SetPoint("RIGHT", right, "LEFT");

    -- Setup Input Box scripts
    input:SetScript("OnEnterPressed", function(self)
        local message = self:GetText();
        if message and message ~= "" then
            C_ChatInfo.SendChatMessage(message, "WHISPER", nil, win.player);
            addon:AddMessageToHistory(win.player, "Me", message);
            addon:DisplayHistory(win, win.player);
            self:SetText("");
        end
    end);

    input:SetScript("OnTextChanged", function(self)
        local inputCount = _G[self:GetName() .. "Count"];
        local len = self:GetNumLetters();
        inputCount:SetText(len .. "/" .. CHAT_MAX_LETTERS);

        if len >= CHAT_MAX_LETTERS - 15 then
            inputCount:SetTextColor(1.0, 0.2, 0.2); -- Red
        else
            inputCount:SetTextColor(0.8, 0.8, 0.8); -- Grey
        end
    end);

    return win;
end

--------------------------------------------------------------------
-- History Management
--------------------------------------------------------------------

function addon:AddMessageToHistory(playerName, author, message)
    if not WhisperManager_HistoryDB[playerName] then
        WhisperManager_HistoryDB[playerName] = {};
    end
    local history = WhisperManager_HistoryDB[playerName];
    table.insert(history, { author = author, message = message, timestamp = time() });
    if #history > MAX_HISTORY_LINES then
        table.remove(history, 1);
    end
end

function addon:DisplayHistory(window, playerName)
    local historyFrame = _G[window:GetName() .. "History"];
    historyFrame:Clear();
    local history = WhisperManager_HistoryDB[playerName];
    if not history then return end

    for _, entry in ipairs(history) do
        local timeString = date("[%H:%M]", entry.timestamp);
        local coloredAuthor;

        if entry.author == "Me" then
            -- Using a valid purple color for messages you send.
            coloredAuthor = "|cff9494ffMe|r"; 
        else
            -- Using the original yellow color for the other person's messages.
            coloredAuthor = string.format("|cffffd100%s|r", entry.author);
        end
        
        -- Escape any '%' characters in the message itself to prevent formatting errors.
        local safeMessage = entry.message:gsub("%%", "%%%%");
        
        -- Construct the final formatted line.
        local formattedMessage = string.format("%s %s: %s", timeString, coloredAuthor, safeMessage);
        historyFrame:AddMessage(formattedMessage);
    end

    historyFrame:ScrollToBottom();
end


--------------------------------------------------------------------
-- Event Handling and Initialization
--------------------------------------------------------------------

function addon:Initialize()
    if type(WhisperManager_HistoryDB) ~= "table" then
        WhisperManager_HistoryDB = {};
    end

    local eventFrame = CreateFrame("Frame");
    eventFrame:RegisterEvent("CHAT_MSG_WHISPER");
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD");

    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "CHAT_MSG_WHISPER" then
            local message, author = ...;
            addon:OpenConversation(author);
            if author then
                local playerKey = Ambiguate(author, "none") or author
                addon:AddMessageToHistory(playerKey, author, message);
                if addon.windows[playerKey] then
                    addon:DisplayHistory(addon.windows[playerKey], playerKey);
                end
            end
        elseif event == "PLAYER_ENTERING_WORLD" then
            -- Hook into chat commands
            hooksecurefunc("ChatFrame_OpenChat", function(text, chatFrame)
                if not text or type(text) ~= "string" then return end
                local _, _, target = strfind(text, "^/(?:whisper|w)%s+([^%s]+)");
                if target then
                    local editBox = _G.ChatEdit_ChooseBoxForSend(chatFrame);
                    if target ~= "" and strlower(target) ~= strlower(UnitName("player")) then
                        addon:OpenConversation(target);
                        _G.ChatEdit_OnEscapePressed(editBox);
                    end
                end
            end);
            
            hooksecurefunc("ChatFrame_ReplyTell", function()
                local target = _G.ChatEdit_GetLastTellTarget();
                if target and target ~= "" and strlower(target) ~= strlower(UnitName("player")) then
                     addon:OpenConversation(target);
                     local editBox = _G.ChatEdit_ChooseBoxForSend();
                     _G.ChatEdit_OnEscapePressed(editBox);
                end
            end);

            -- Hook into the right-click menu system with added safety checks
            hooksecurefunc("UnitPopup_ShowMenu", function(menu, which, unit, name)
                -- Apply safety checks to prevent UI taint.
                if menu:IsForbidden() or UIDROPDOWNMENU_MENU_LEVEL ~= 1 then
                    return
                end

                local playerName
                if unit and UnitIsPlayer(unit) and not UnitIsUnit(unit, "player") then
                    playerName = name or UnitName(unit)
                elseif not unit and name and (which == "FRIEND" or which == "CHAT_PLAYER") then
                    playerName = name
                end

                if playerName and playerName ~= UNKNOWN_OBJECT_NAME and playerName ~= UNKNOWN then
                    local info = {
                        text = "Open in WhisperManager",
                        notCheckable = true,
                        func = function()
                            addon:OpenConversation(playerName)
                        end,
                        -- This button does not create a submenu, so it is safe.
                    }
                    UIDropDownMenu_AddButton(info)
                end
            end)

            -- Unregister the event so this block only runs once per login.
            self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        end
    end);
end

-- Run the addon's initialization function
addon:Initialize();