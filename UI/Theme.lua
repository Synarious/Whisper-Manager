-- Shared visual language. Palettes are independent of GuildHelper being installed.
local addon = WhisperManager
local unpack = unpack or table.unpack

addon.THEME_OPTIONS = {
    {value = "guildhelper", name = "GuildHelper (Default)"},
    {value = "midnight", name = "Midnight"},
    {value = "forest", name = "Emerald"},
    {value = "classic", name = "Classic Dark"},
    {value = "custom", name = "Custom Colors"},
}
local themes = {
    guildhelper = {surface = {0.085, 0.075, 0.060, 0.80}, raised = {0.16, 0.135, 0.095, 0.42}, border = {0.62, 0.48, 0.25, 0.65}, accent = {1, 0.82, 0.30, 1}, text = {0.94, 0.87, 0.70, 1}, button = {0.26, 0.21, 0.12, 0.92}},
    midnight = {surface = {0.035, 0.055, 0.10, 0.94}, raised = {0.08, 0.13, 0.23, 0.75}, border = {0.28, 0.46, 0.70, 0.8}, accent = {0.55, 0.78, 1, 1}, text = {0.84, 0.91, 1, 1}, button = {0.12, 0.22, 0.36, 0.95}},
    forest = {surface = {0.035, 0.075, 0.055, 0.92}, raised = {0.09, 0.18, 0.12, 0.65}, border = {0.30, 0.55, 0.36, 0.8}, accent = {0.62, 0.91, 0.65, 1}, text = {0.85, 0.94, 0.83, 1}, button = {0.14, 0.27, 0.17, 0.95}},
    classic = {surface = {0, 0, 0, 0.90}, raised = {0.10, 0.10, 0.10, 0.8}, border = {0.45, 0.45, 0.45, 1}, accent = {1, 0.82, 0, 1}, text = {0.90, 0.90, 0.90, 1}, button = {0.18, 0.18, 0.18, 0.95}},
}
local surfaces = {windowBackground = "surface", titleBar = "raised", inputBox = "surface", recentChatBackground = "surface"}
local registered = setmetatable({}, {__mode = "k"})

function addon:GetTheme()
    return themes[self:GetSetting("theme")] or themes.guildhelper
end

function addon:WriteThemeColors(settings, id)
    local theme = themes[id]
    if not theme then return end
    for prefix, role in pairs(surfaces) do
        local color = theme[role]
        settings[prefix .. "Color"] = {r = color[1], g = color[2], b = color[3]}
        settings[prefix .. "Alpha"] = color[4]
    end
end

function addon:SelectTheme(id)
    self:SetSetting("theme", id)
    self:WriteThemeColors(self.settings, id)
    self:ApplyAppearanceSettings()
end

-- The same fixed-radius corner geometry as GuildHelper, using local assets.
local function roundedShape(frame, outline)
    local shape = {textures = {}}
    local radius = 8
    local function texture()
        local t = frame:CreateTexture(nil, outline and "BORDER" or "BACKGROUND", nil, outline and 0 or -7)
        shape.textures[#shape.textures + 1] = t
        return t
    end
    for _, corner in ipairs({
        {"TOPLEFT", 0, 1, 0, 1}, {"TOPRIGHT", 1, 0, 0, 1},
        {"BOTTOMLEFT", 0, 1, 1, 0}, {"BOTTOMRIGHT", 1, 0, 1, 0},
    }) do
        local t = texture()
        t:SetTexture("Interface\\AddOns\\Whisper-Manager\\Media\\" .. (outline and "RoundedOutline8.tga" or "RoundedCorner.tga"))
        t:SetSize(radius, radius)
        t:SetPoint(corner[1], frame, corner[1], 0, 0)
        t:SetTexCoord(corner[2], corner[3], corner[4], corner[5])
    end
    for _, side in ipairs({"TOP", "BOTTOM"}) do
        local t = texture()
        t:SetTexture("Interface\\Buttons\\WHITE8X8")
        t:SetPoint(side .. "LEFT", frame, side .. "LEFT", radius, 0)
        t:SetPoint(side .. "RIGHT", frame, side .. "RIGHT", -radius, 0)
        t:SetHeight(outline and 1 or radius)
    end
    if outline then
        for _, side in ipairs({"LEFT", "RIGHT"}) do
            local t = texture()
            t:SetTexture("Interface\\Buttons\\WHITE8X8")
            t:SetPoint("TOP" .. side, frame, "TOP" .. side, 0, -radius)
            t:SetPoint("BOTTOM" .. side, frame, "BOTTOM" .. side, 0, radius)
            t:SetWidth(1)
        end
    else
        local t = texture()
        t:SetTexture("Interface\\Buttons\\WHITE8X8")
        t:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -radius)
        t:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, radius)
    end
    function shape:SetColor(color)
        for _, t in ipairs(self.textures) do t:SetVertexColor(unpack(color)) end
    end
    return shape
end

local function panel(frame, color, border)
    if not frame then return end
    if frame.SetBackdrop then frame:SetBackdrop(nil) end
    frame.wmRoundedFill = frame.wmRoundedFill or roundedShape(frame, false)
    frame.wmRoundedBorder = frame.wmRoundedBorder or roundedShape(frame, true)
    frame.wmRoundedFill:SetColor(color)
    frame.wmRoundedBorder:SetColor(border)
end

function addon:StyleThemeRow(row, index, unread, hidden)
    local t = self:GetTheme()
    row.bg:SetColorTexture(t.raised[1], t.raised[2], t.raised[3], unread and 0.85 or (index % 2 == 0 and 0.42 or 0.20))
    row.highlight:SetColorTexture(t.accent[1], t.accent[2], t.accent[3], 0.15)
    if row.unreadIndicator then row.unreadIndicator:SetColorTexture(unpack(t.accent)) end
    if row.nameText then row.nameText:SetTextColor(unpack((unread or hidden) and t.accent or t.text)) end
end

function addon:StyleThemeControls(root)
    local t = self:GetTheme()
    for _, region in ipairs({root:GetRegions()}) do
        if region:GetObjectType() == "FontString" then
            local r, g, b = region:GetTextColor()
            if region.wmThemeHeading or (r == 1 and math.abs(g - 0.82) < 0.01 and b == 0) then
                region.wmThemeHeading = true
                region:SetTextColor(unpack(t.accent))
            end
        end
    end
    for _, child in ipairs({root:GetChildren()}) do
        -- Only replace labeled action buttons; preserve icon buttons and checkboxes.
        if child:GetObjectType() == "Button" and child.GetText and child:GetText() and child:GetText() ~= "" then
            child:SetNormalTexture(nil)
            child:SetPushedTexture(nil)
            child:SetHighlightTexture(nil)
            for _, name in ipairs({"Left", "Middle", "Right"}) do
                if child[name] then child[name]:Hide() end
            end
            panel(child, t.button, t.border)
            if child:GetFontString() then child:GetFontString():SetTextColor(unpack(t.text)) end
            if not child.wmThemeHover then
                child.wmThemeHover = true
                child:HookScript("OnEnter", function(button) button.wmRoundedBorder:SetColor(addon:GetTheme().accent) end)
                child:HookScript("OnLeave", function(button) button.wmRoundedBorder:SetColor(addon:GetTheme().border) end)
            end
        end
        self:StyleThemeControls(child)
    end
end

function addon:StyleThemeFrame(frame, role)
    if not self:CanChangeAddonFrame(frame) then
        self:QueueWindowAction("theme:" .. tostring(frame), function() self:StyleThemeFrame(frame, role) end)
        return
    end
    local t = self:GetTheme()
    local prefix = role == "recent" and "recentChatBackground" or "windowBackground"
    local c = self:GetSetting(prefix .. "Color")
    panel(frame, {c.r, c.g, c.b, self:GetSetting(prefix .. "Alpha")}, t.border)
    if not frame.wmHeader then
        frame.wmHeader = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
        frame.wmHeader:SetPoint("TOPLEFT", 5, -5)
        frame.wmHeader:SetPoint("TOPRIGHT", -5, -5)
        frame.wmHeader:SetHeight(30)
        frame.wmDivider = frame:CreateTexture(nil, "ARTWORK")
        frame.wmDivider:SetPoint("TOPLEFT", 12, -36)
        frame.wmDivider:SetPoint("TOPRIGHT", -12, -36)
        frame.wmDivider:SetHeight(1)
    end
    frame.wmHeader:SetColorTexture(unpack(t.raised))
    frame.wmDivider:SetColorTexture(unpack(t.border))
    -- Conversation windows already have a separate title bar and history spacing.
    frame.wmHeader:SetShown(role ~= "whisper" and role ~= "preview")
    frame.wmDivider:SetShown(role ~= "whisper" and role ~= "preview")
    if frame.title then
        frame.title:SetTextColor(unpack(t.accent))
        frame.title:ClearAllPoints()
        frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -11)
        frame.title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", role == "whisper" and -66 or -32, -11)
        frame.title:SetFontObject("GameFontNormal")
        frame.title:SetJustifyH("LEFT")
        frame.title:SetWordWrap(false)
    end
    if frame.searchBox then
        for _, name in ipairs({"Left", "Middle", "Right"}) do
            if frame.searchBox[name] then frame.searchBox[name]:Hide() end
        end
        panel(frame.searchBox, t.surface, t.border)
        frame.searchBox:SetTextInsets(8, 8, 0, 0)
        frame.searchBox:SetTextColor(unpack(t.text))
    end
    if role == "whisper" or role == "preview" then
        if frame.titleBar then
            local color = self:GetSetting("titleBarColor")
            frame.titleBar:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
            frame.titleBar:SetBackdropColor(color.r, color.g, color.b, self:GetSetting("titleBarAlpha"))
        end
        if frame.InputContainer then
            local color = self:GetSetting("inputBoxColor")
            panel(frame.InputContainer, {color.r, color.g, color.b, self:GetSetting("inputBoxAlpha")}, t.border)
        end
        if role == "whisper" then
            -- Put the name first and group utility icons beside the close button.
            for _, spec in ipairs({{frame.copyBtn, -36}, {frame.trp3Btn, -62}, {frame.ginviteBtn, -88}}) do
                if spec[1] then
                    spec[1]:ClearAllPoints()
                    spec[1]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", spec[2], -8)
                end
            end
            local function updateTitleInsets()
                local rightInset = frame.ginviteBtn and frame.ginviteBtn:IsShown() and 118
                    or (frame.trp3Btn and frame.trp3Btn:IsShown() and 92 or 66)
                frame.title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -rightInset, -11)
            end
            updateTitleInsets()
            if not frame.wmTitleInsetHooks then
                frame.wmTitleInsetHooks = true
                for _, button in pairs({trp3 = frame.trp3Btn, invite = frame.ginviteBtn}) do
                    button:HookScript("OnShow", updateTitleInsets)
                    button:HookScript("OnHide", updateTitleInsets)
                end
            end
            frame.wmDivider:Show()
            if not frame.wmHistoryPanel then
                frame.wmHistoryPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
                frame.wmHistoryPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -43)
                frame.wmHistoryPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
            end
            frame.wmHistoryPanel:SetFrameLevel(frame:GetFrameLevel() + 2)
            panel(frame.wmHistoryPanel, {t.raised[1], t.raised[2], t.raised[3], 0.18}, {t.border[1], t.border[2], t.border[3], 0.35})
            frame.History:ClearAllPoints()
            frame.History:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -51)
            frame.History:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 18)
        end
    end
    if frame.detailFrame then panel(frame.detailFrame, t.raised, t.border) end
    self:StyleThemeControls(frame)
end

function addon:RegisterThemeFrame(frame, role)
    registered[frame] = role
    self:StyleThemeFrame(frame, role)
end

function addon:RefreshTheme()
    for frame, role in pairs(registered) do self:StyleThemeFrame(frame, role) end
    if self.settingsFrame and self.settingsFrame.RefreshThemeSwatches then self.settingsFrame:RefreshThemeSwatches() end
    if self.recentChatsFrame then self:RefreshRecentChats() end
    if self.historyFrame then self:RefreshHistoryList(self.historyFrame.searchBox:GetText() or "") end
end
