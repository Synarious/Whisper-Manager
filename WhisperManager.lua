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

    -- THE FIX: The line below was the source of all errors. It has been removed.
    -- ChatEdit_SetLastTellTarget(playerKey);
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
    
    -- NEW: Set maximum number of characters allowed in the input box.
    input:SetMaxLetters(CHAT_MAX_LETTERS);
    
    -- NEW: Create the character count indicator.
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

    -- NEW: Add a script to update the character counter as the user types.
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
        local authorColor = (entry.author == "Me") and "|cff949flff" or "|cffffd100";
        local formattedMessage = string.format("%s %s%s:|r %s", timeString, authorColor, entry.author, entry.message);
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
        end
    end);

    hooksecurefunc("ChatFrame_OpenChat", function(text, chatFrame)
        if not text or type(text) ~= "string" then return end;

        -- Look for /w or /whisper commands and extract the target name directly from the text
        local _, _, target = strfind(text, "^/(?:whisper|w)%s+([^%s]+)");
    
        if target then
            local editBox = _G.ChatEdit_ChooseBoxForSend(chatFrame);
            if target ~= "" and strlower(target) ~= strlower(UnitName("player")) then
                -- Call OpenConversation with the parsed target name
                addon:OpenConversation(target);
                -- Clear the input box to prevent the command from being sent in the main chat
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
end

-- Run the addon's initialization function
addon:Initialize();