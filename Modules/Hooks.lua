-- ============================================================================
-- Hooks.lua - Chat system hooks for proper WoW integration
-- ============================================================================
-- Based on WIM's approach: Hook into WoW's chat system so our EditBoxes
-- behave like the default chat frame, enabling proper error handling

local addon = WhisperManager

-- Track which EditBox currently has focus
addon.EditBoxInFocus = nil

-- ============================================================================
-- Chat Frame EditBox Hooks
-- ============================================================================

local Hooked_ChatFrameEditBoxes = {}

-- Hook the default chat frame's EditBox to redirect input to our EditBox when focused
local function hookChatFrameEditBox(editBox)
    if editBox and not Hooked_ChatFrameEditBoxes[editBox:GetName()] then
        
        -- Hook Insert() to redirect to our EditBox
        hooksecurefunc(editBox, "Insert", function(self, theText)
            if addon.EditBoxInFocus then
                addon.EditBoxInFocus:Insert(theText)
            end
        end)
        
        -- Hook IsVisible() to report true if our EditBox has focus
        editBox.wmIsVisible = editBox.IsVisible
        editBox.IsVisible = function(self)
            if addon.EditBoxInFocus then
                return true
            else
                return self:wmIsVisible()
            end
        end
        
        -- Hook IsShown() to report true if our EditBox has focus
        editBox.wmIsShown = editBox.IsShown
        editBox.IsShown = function(self)
            if addon.EditBoxInFocus then
                return true
            else
                return self:wmIsShown()
            end
        end
        
        -- Hook SetText() to redirect to our EditBox (except slash commands)
        hooksecurefunc(editBox, "SetText", function(self, theText)
            local firstChar = ""
            if string.len(theText) > 0 then
                firstChar = string.sub(theText, 1, 1)
            end
            -- If a slash command is being set, ignore it. Let WoW take control
            if addon.EditBoxInFocus and firstChar ~= "/" then
                addon.EditBoxInFocus:SetText(theText)
            end
        end)
        
        -- Hook HighlightText() to redirect to our EditBox
        editBox.wmHighlightText = editBox.HighlightText
        editBox.HighlightText = function(self, theStart, theEnd)
            if addon.EditBoxInFocus then
                addon.EditBoxInFocus:HighlightText(theStart, theEnd)
            else
                self:wmHighlightText(theStart, theEnd)
            end
        end
        
        Hooked_ChatFrameEditBoxes[editBox:GetName()] = true
        addon:DebugMessage("Hooked ChatFrame EditBox:", editBox:GetName())
    end
end

-- Hook ChatEdit_ActivateChat to ensure we hook any EditBox that gets activated
hooksecurefunc("ChatEdit_ActivateChat", function(editBox)
    hookChatFrameEditBox(editBox)
end)

-- ============================================================================
-- ChatEdit_GetActiveWindow Hook
-- ============================================================================
-- This is the KEY hook - it makes WoW think our EditBox IS the chat frame

local ChatEdit_GetActiveWindow_orig = ChatEdit_GetActiveWindow
function ChatEdit_GetActiveWindow()
    -- If we have an EditBox in focus, return it instead of the default chat frame
    -- This makes WoW's chat system route messages through our EditBox
    return addon.EditBoxInFocus or ChatEdit_GetActiveWindow_orig()
end

-- ============================================================================
-- Helper Functions
-- ============================================================================

function addon:SetEditBoxFocus(editBox)
    self.EditBoxInFocus = editBox
    if editBox then
        self:DebugMessage("EditBox focus set:", editBox:GetName())
    else
        self:DebugMessage("EditBox focus cleared")
    end
end

function addon:GetEditBoxFocus()
    return self.EditBoxInFocus
end

-- ============================================================================
-- Initialization
-- ============================================================================

function addon:SetupChatHooks()
    -- Hook the default chat frame's EditBox immediately
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox then
        hookChatFrameEditBox(DEFAULT_CHAT_FRAME.editBox)
    end
    
    -- Hook any other visible chat frame EditBoxes
    for i = 1, NUM_CHAT_WINDOWS do
        local chatFrame = _G["ChatFrame" .. i]
        if chatFrame and chatFrame.editBox then
            hookChatFrameEditBox(chatFrame.editBox)
        end
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00WhisperManager:|r Chat hooks installed")
end

-- Initialize hooks when this file loads
C_Timer.After(0, function()
    addon:SetupChatHooks()
end)
