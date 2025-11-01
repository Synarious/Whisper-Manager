-- ============================================================================
-- Core.lua - Core addon initialization and utility functions
-- ============================================================================

-- Configuration
local DEFAULT_DEBUG_MODE = true -- Toggle via settings/slash to show diagnostic messages.

-- Create the main addon table
WhisperManager = {};
local addon = WhisperManager;

-- Core properties
addon.windows = {};
addon.playerDisplayNames = {};
addon.debugEnabled = DEFAULT_DEBUG_MODE;
addon.recentChats = {};  -- Track recent conversations with read status
addon.nextFrameLevel = 1;  -- Track frame levels for stacking windows

-- Constants
addon.MAX_HISTORY_LINES = 200;
addon.CHAT_MAX_LETTERS = 245;
addon.RECENT_CHAT_EXPIRY = 72 * 60 * 60;  -- 72 hours in seconds
addon.FOCUSED_ALPHA = 1.0;  -- Full opacity for focused window
addon.UNFOCUSED_ALPHA = 0.65;  -- Reduced opacity for unfocused windows

-- ============================================================================
-- Debug Functions
-- ============================================================================

function addon:DebugMessage(...)
    if self.debugEnabled then
        local args = {...}
        for i = 1, #args do
            args[i] = tostring(args[i])
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00WhisperManager:|r " .. table.concat(args, " "));
    end
end

function addon:Print(...)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00WhisperManager:|r " .. table.concat({...}, " "))
end

function addon:SetDebugEnabled(enabled)
    self.debugEnabled = not not enabled
    if type(WhisperManager_Config) == "table" then
        WhisperManager_Config.debug = self.debugEnabled
    end
    local stateLabel = self.debugEnabled and "enabled" or "disabled"
    self:Print(string.format("Debug logging %s.", stateLabel))
end


function addon:TrimWhitespace(value)
    if type(value) ~= "string" then return nil end
    return value:gsub("^%s+", ""):gsub("%s+$", "")
end

-- ---------------------------------------------------------------------------
-- Player Context Menu Helpers
-- ---------------------------------------------------------------------------

local function StripRealmFromName(name)
    if type(name) ~= "string" then return nil end
    return name:match("^[^%-]+")
end

function addon:OpenPlayerContextMenu(playerName, displayName, isBNet, bnSenderID)
    if not playerName and not isBNet then return end
    
    addon:DebugMessage("OpenPlayerContextMenu called:", playerName, displayName, isBNet, bnSenderID)

    -- Use the modern Menu API introduced in Dragonflight
    local menu = MenuUtil.CreateContextMenu(UIParent, function(owner, rootDescription)
        local label = displayName or StripRealmFromName(playerName) or playerName
        
        if label and label ~= "" then
            rootDescription:CreateTitle(label)
        end

        if not isBNet and playerName and playerName ~= "" then
            rootDescription:CreateButton(WHISPER, function()
                ChatFrame_SendTell(playerName)
            end)
            
            rootDescription:CreateButton(INVITE, function()
                C_PartyInfo.InviteUnit(playerName)
            end)
            
            -- Raid target submenu
            local raidTargetButton = rootDescription:CreateButton(RAID_TARGET_ICON)
            raidTargetButton:CreateButton(RAID_TARGET_NONE, function()
                SetRaidTarget(playerName, 0)
            end)
            for i = 1, 8 do
                raidTargetButton:CreateButton(_G["RAID_TARGET_" .. i], function()
                    SetRaidTarget(playerName, i)
                end)
            end
            
            rootDescription:CreateButton(ADD_FRIEND, function()
                C_FriendList.AddFriend(playerName)
            end)
            
            rootDescription:CreateButton(PLAYER_REPORT, function()
                local guid = C_PlayerInfo.GUIDFromPlayerName(playerName)
                if guid then
                    C_ReportSystem.OpenReportPlayerDialog(guid, playerName)
                end
            end)
        elseif isBNet and bnSenderID then
            if ChatFrame_SendBNetTell then
                rootDescription:CreateButton(WHISPER, function()
                    ChatFrame_SendBNetTell(displayName or playerName)
                end)
            end
            if BNInviteFriend then
                rootDescription:CreateButton(INVITE, function()
                    BNInviteFriend(bnSenderID)
                end)
            end
        end

        rootDescription:CreateButton(CANCEL, function() end)
    end)
    
    addon:DebugMessage("Opening menu...")
end


-- Format message to detect and colorize emotes (*text*) and speech ("text")
-- IMPORTANT: This function must preserve hyperlinks (|H....|h....|h sequences)
function addon:FormatEmotesAndSpeech(message)
    if not message or message == "" then return message end
    
    -- Get WoW's emote color (orange)
    local emoteColor = ChatTypeInfo["EMOTE"]
    local emoteHex = string.format("|cff%02x%02x%02x", emoteColor.r * 255, emoteColor.g * 255, emoteColor.b * 255)
    
    -- Get WoW's say color (white)
    local sayColor = ChatTypeInfo["SAY"]
    local sayHex = string.format("|cff%02x%02x%02x", sayColor.r * 255, sayColor.g * 255, sayColor.b * 255)
    
    -- Detect and colorize emotes surrounded by asterisks: *emote*
    -- Use non-greedy match and avoid matching inside hyperlinks
    message = message:gsub("(%*[^%*|]+%*)", function(emote)
        return emoteHex .. emote .. "|r"
    end)
    
    -- Detect and colorize speech surrounded by quotes: "speech"
    -- Use non-greedy match and avoid matching inside hyperlinks
    message = message:gsub('("[^"|]+")' , function(speech)
        return sayHex .. speech .. "|r"
    end)
    
    return message
end

-- ============================================================================
-- Slash Command Handling
-- ============================================================================

function addon:HandleSlashCommand(message)
    local input = self:TrimWhitespace(message or "") or ""
    if input == "" or input:lower() == "help" then
        self:Print("Usage:")
        self:Print("/wm <player> - Open a WhisperManager window.")
        self:Print("/wm debug [on|off|toggle] - Control diagnostic chat output.")
        self:Print("/wm resetwindows - Reset saved window positions.")
        self:Print("/wm reset_all_data - Clear all saved data (history, windows, config).")
        return
    end

    local command, rest = input:match("^(%S+)%s*(.-)$")
    command = command and command:lower() or ""
    if command == "debug" then
        local directive = rest and rest:lower() or ""
        if directive == "on" or directive == "1" or directive == "true" then
            self:SetDebugEnabled(true)
        elseif directive == "off" or directive == "0" or directive == "false" then
            self:SetDebugEnabled(false)
        else
            self:SetDebugEnabled(not self.debugEnabled)
        end
    elseif command == "resetwindows" then
        self:ResetWindowPositions()
    elseif command == "reset_all_data" then
        WhisperManager_HistoryDB = {}
        WhisperManager_WindowDB = {}
        WhisperManager_Config = {}
        WhisperManager_RecentChats = {}
        self:Print("|cffff0000All WhisperManager data has been cleared!|r")
        self:Print("Please /reload to apply changes.")
    else
        if not self:OpenConversation(input) then
            self:Print(string.format("Unable to open a whisper window for '%s'.", input))
        end
    end
end

-- ============================================================================
-- Initialization
-- ============================================================================

function addon:InitializeCore()
    -- Initialize databases
    if type(WhisperManager_HistoryDB) ~= "table" then
        WhisperManager_HistoryDB = {}
    end
    
    if type(WhisperManager_RecentChats) ~= "table" then
        WhisperManager_RecentChats = {}
    end

    -- Migrate old history format if needed
    if not WhisperManager_HistoryDB.__schema or WhisperManager_HistoryDB.__schema < 2 then
        local migrated = {}
        for key, history in pairs(WhisperManager_HistoryDB) do
            if key ~= "__schema" then
                local canonicalKey, _, displayName = addon:ResolvePlayerIdentifiers(key)
                if canonicalKey then
                    if not migrated[canonicalKey] then
                        migrated[canonicalKey] = type(history) == "table" and history or {}
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

    -- Load display names
    for key, history in pairs(WhisperManager_HistoryDB) do
        if key ~= "__schema" and type(history) == "table" and history.__display then
            addon.playerDisplayNames[key] = history.__display
        end
    end

    -- Initialize config
    if type(WhisperManager_Config) ~= "table" then
        WhisperManager_Config = {}
    end
    if WhisperManager_Config.debug == nil then
        WhisperManager_Config.debug = DEFAULT_DEBUG_MODE
    end
    addon.debugEnabled = not not WhisperManager_Config.debug

    -- Initialize window DB
    if type(WhisperManager_WindowDB) ~= "table" then
        WhisperManager_WindowDB = {}
    end

    -- Register slash commands
    SLASH_WHISPERMANAGER1 = "/wm"
    SLASH_WHISPERMANAGER2 = "/whispermanager"
    SlashCmdList.WHISPERMANAGER = function(msg)
        addon:HandleSlashCommand(msg)
    end

    -- Load settings
    addon.settings = addon:LoadSettings()
    
    -- Hook ChatEdit_InsertLink to support shift-clicking items/achievements into our edit boxes
    local originalChatEdit_InsertLink = ChatEdit_InsertLink
    ChatEdit_InsertLink = function(link)
        if addon.activeEditBox and addon.activeEditBox:IsVisible() and addon.activeEditBox:HasFocus() then
            -- Insert the link into our active WhisperManager edit box
            addon.activeEditBox:Insert(link)
            return true
        else
            -- Fall back to default behavior
            return originalChatEdit_InsertLink(link)
        end
    end

    self:DebugMessage("Core initialized.");
end
