local addon = WhisperManager;

-- Current expected schema version
addon.EXPECTED_SCHEMA_VERSION = 1

-- Schema validation state
addon.schemaValidationPassed = false

function addon:ValidateSchema()
    addon:DebugMessage("=== Schema Validation START ===")
    
    -- Check if HistoryDB exists and has a schema version
    if not WhisperManager_HistoryDB then
        -- New installation, no validation needed
        addon:DebugMessage("No existing HistoryDB - new installation")
        addon.schemaValidationPassed = true
        return true
    end
    
    local savedSchema = WhisperManager_HistoryDB.__schema
    
    if not savedSchema then
        -- Very old version without schema - assume schema 1
        savedSchema = 1
    end
    
    addon:DebugMessage("Saved schema version:", savedSchema)
    addon:DebugMessage("Expected schema version:", addon.EXPECTED_SCHEMA_VERSION)
    
    -- Check if saved schema is lower than expected (old version)
    if savedSchema < addon.EXPECTED_SCHEMA_VERSION then
        addon:DebugMessage("|cffff0000Schema too old - blocking addon load|r")
        addon.schemaValidationPassed = false
        addon:ShowSchemaWarning(savedSchema)
        return false
    end
    
    -- Check if saved schema is higher than expected (future version)
    if savedSchema > addon.EXPECTED_SCHEMA_VERSION then
        addon:DebugMessage("|cffff0000Schema too new - blocking addon load|r")
        addon.schemaValidationPassed = false
        addon:ShowSchemaWarning(savedSchema)
        return false
    end
    
    -- Schema matches - validation passed
    addon:DebugMessage("|cff00ff00Schema validation PASSED|r")
    addon.schemaValidationPassed = true
    return true
end

--- Show warning dialog when schema is incompatible
function addon:ShowSchemaWarning(savedSchema)
    -- Create error frame
    local frame = CreateFrame("Frame", "WhisperManager_SchemaWarning", UIParent, "BackdropTemplate")
    frame:SetSize(550, 480)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(9999)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    frame:SetBackdropColor(0.1, 0, 0, 1)
    frame:SetBackdropBorderColor(1, 0, 0, 1)
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOP", 0, -25)
    title:SetText("|cffff0000WhisperManager - Version Mismatch|r")
    
    -- Icon
    local icon = frame:CreateTexture(nil, "OVERLAY")
    icon:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")
    icon:SetSize(64, 64)
    icon:SetPoint("TOP", 0, -75)
    
    -- Message
    local message = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    message:SetPoint("TOP", icon, "BOTTOM", 0, -25)
    message:SetWidth(490)
    message:SetJustifyH("LEFT")
    message:SetSpacing(6)
    
    local errorText
    if savedSchema < addon.EXPECTED_SCHEMA_VERSION then
        errorText = "|cffffffffYour saved data is from an incompatible version of WhisperManager.|r\n\n"
        errorText = errorText .. string.format("|cffaaaaaa  Saved version: |r|cffff6666%d|r\n", savedSchema)
        errorText = errorText .. string.format("|cffaaaaaa  Required version: |r|cff66ff66%d|r\n\n", addon.EXPECTED_SCHEMA_VERSION)
        errorText = errorText .. "|cffff8800Please preform the addon to protect your whisper data.|r\n\n"
        errorText = errorText .. "|cff00ff00What to do:|r\n\n"
        errorText = errorText .. "|cffaaaaaa  1. Back up your whisper data (optional):|r\n"
        errorText = errorText .. "|cffcccccc     <WOW>/WTF/Account/<Account>/SavedVariables/\n     WhisperManager.lua|r\n\n"
        errorText = errorText .. "|cffaaaaaa  2. Type:|r |cff66ff66/wmgr delete_all_data|r\n\n"
        errorText = errorText .. "|cffaaaaaa  3. Type:|r |cff66ff66/reload|r"
    else
        errorText = "|cffffffffYour saved data is from a newer version of WhisperManager.|r\n\n"
        errorText = errorText .. string.format("|cffaaaaaa  Saved version: |r|cff66ff66%d|r\n", savedSchema)
        errorText = errorText .. string.format("|cffaaaaaa  Addon version: |r|cffff6666%d|r\n\n", addon.EXPECTED_SCHEMA_VERSION)
        errorText = errorText .. "|cffff8800Please disable the addon to protect your whisper data.|r\n\n"
        errorText = errorText .. "|cff00ff00What to do:|r\n\n"
        errorText = errorText .. "|cffaaaaaa  1. Update WhisperManager to the latest version|r\n\n"
        errorText = errorText .. "|cff888888     OR|r\n\n"
        errorText = errorText .. "|cffaaaaaa  2. Back up your whisper data, then type:|r\n"
        errorText = errorText .. "|cff66ff66     /wmgr delete_all_data|r\n"
        errorText = errorText .. "|cff66ff66     /reload|r"
    end
    
    message:SetText(errorText)
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeBtn:SetSize(120, 32)
    closeBtn:SetPoint("BOTTOM", 0, 25)
    closeBtn:SetText("OK")
    closeBtn:SetScript("OnClick", function()
        frame:Hide()
    end)
    
    frame:Show()
    
    -- Print to chat
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[WhisperManager] Version mismatch detected - please disable the addon to protect your whisper data|r")
end

--- Check if addon is safe to operate
function addon:IsSafeToOperate()
    return addon.schemaValidationPassed == true
end

addon:DebugMessage("SchemaValidator module loaded")
