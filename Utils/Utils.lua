-- ============================================================================
-- Utils.lua - General utility functions
-- ============================================================================
-- This module contains general-purpose utility functions used across the addon.
-- ============================================================================

local addon = WhisperManager;

-- ============================================================================
-- String Utilities
-- ============================================================================

--- Trim leading/trailing whitespace from a string
-- @param value any Value to trim (should be string)
-- @return string|nil Trimmed string or nil if not a string
function addon:TrimWhitespace(value)
    if type(value) ~= "string" then return nil end
    return value:gsub("^%s+", ""):gsub("%s+$", "")
end

--- Strip realm suffix from player name
-- @param name string Player name (possibly with realm)
-- @return string|nil Name without realm
local function StripRealmFromName(name)
    if type(name) ~= "string" then return nil end
    return name:match("^[^%-]+")
end

-- Export for use in other modules
addon.StripRealmFromName = StripRealmFromName

-- ============================================================================
-- Message Formatting
-- ============================================================================

--- Format message to detect and colorize emotes (*text*), speech ("text"), and OOC text ((text))
-- IMPORTANT: This function preserves hyperlinks (|H....|h....|h sequences)
-- @param message string Message text to format
-- @return string Formatted message with colored emotes, speech, and OOC
function addon:FormatEmotesAndSpeech(message)
    if not message or message == "" then return message end
    
    -- Get WoW's emote color (orange)
    local emoteColor = ChatTypeInfo["EMOTE"]
    local emoteHex = string.format("|cff%02x%02x%02x", emoteColor.r * 255, emoteColor.g * 255, emoteColor.b * 255)
    
    -- Get WoW's say color (white)
    local sayColor = ChatTypeInfo["SAY"]
    local sayHex = string.format("|cff%02x%02x%02x", sayColor.r * 255, sayColor.g * 255, sayColor.b * 255)
    
    -- Gray color for OOC text
    local oocHex = "|cff888888"
    
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
    
    -- Detect and colorize OOC text surrounded by parentheses: (text) or ((text))
    -- Use non-greedy match and avoid matching inside hyperlinks
    message = message:gsub("(%(%(.-%)%))", function(ooc)
        return oocHex .. ooc .. "|r"
    end)
    message = message:gsub("(%(.-%))", function(ooc)
        return oocHex .. ooc .. "|r"
    end)
    
    return message
end

-- ============================================================================
-- Notification Functions
-- ============================================================================

--- Trigger a Windows taskbar alert (flash the window)
-- Flashes continuously until the game window is focused
function addon:TriggerTaskbarAlert()
    -- Don't start a new alert if one is already running
    if self.isFlashing then return end
    
    -- Create a frame that flashes to get the user's attention
    if not self.alertFrame then
        self.alertFrame = CreateFrame("Frame", "WhisperManager_AlertFrame", UIParent)
        self.alertFrame:SetSize(1, 1)
        self.alertFrame:SetPoint("CENTER")
        self.alertFrame:SetFrameStrata("TOOLTIP")
        self.alertFrame:Hide()
    end
    
    local alertFrame = self.alertFrame
    self.isFlashing = true
    
    -- Flash continuously until window is focused
    local flashCount = 0
    local function Flash()
        -- Stop flashing if window is focused (not minimized/in background)
        -- GetTime() changes when window is focused, indicating player interaction
        if not self.isFlashing or (flashCount > 0 and addon.lastFlashCheck and GetTime() ~= addon.lastFlashCheck) then
            alertFrame:Hide()
            self.isFlashing = false
            self:DebugMessage("Taskbar alert stopped (window focused)")
            return
        end
        
        addon.lastFlashCheck = GetTime()
        
        flashCount = flashCount + 1
        if flashCount % 2 == 1 then
            alertFrame:Show()
        else
            alertFrame:Hide()
        end
        
        -- Continue flashing indefinitely
        C_Timer.After(0.5, Flash)
    end
    
    Flash()
    
    self:DebugMessage("Taskbar alert started (will flash until window focused)")
end

--- Stop taskbar alert flashing (called when window is focused)
function addon:StopTaskbarAlert()
    if self.isFlashing then
        self.isFlashing = false
        if self.alertFrame then
            self.alertFrame:Hide()
        end
        self:DebugMessage("Taskbar alert manually stopped")
    end
end
