local addon = WhisperManager;

function addon:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WhisperManager]|r " .. tostring(message))
end

function addon:TrimWhitespace(value)
    if type(value) ~= "string" then return nil end
    return value:gsub("^%s+", ""):gsub("%s+$", "")
end

local function StripRealmFromName(name)
    if type(name) ~= "string" then return nil end
    return name:match("^[^%-]+")
end
addon.StripRealmFromName = StripRealmFromName

function addon:FormatEmotesAndSpeech(message)
    if not message or message == "" then return message end
    local emoteColor = ChatTypeInfo["EMOTE"]
    local emoteHex = string.format("|cff%02x%02x%02x", emoteColor.r * 255, emoteColor.g * 255, emoteColor.b * 255)
    local sayColor = ChatTypeInfo["SAY"]
    local sayHex = string.format("|cff%02x%02x%02x", sayColor.r * 255, sayColor.g * 255, sayColor.b * 255)
    local oocHex = "|cff888888"
    message = message:gsub("(%*[^%*|]+%*)", function(emote) return emoteHex .. emote .. "|r" end)
    message = message:gsub('("[^"|]+")' , function(speech) return sayHex .. speech .. "|r" end)
    message = message:gsub("(%(%(.-%)%))", function(ooc) return oocHex .. ooc .. "|r" end)
    message = message:gsub("(%(.-%))", function(ooc) return oocHex .. ooc .. "|r" end)
    return message
end

function addon:TriggerTaskbarAlert()
    FlashClientIcon()
end

function addon:StopTaskbarAlert()
    -- FlashClientIcon stops automatically when the client is focused
end
