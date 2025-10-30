-- ============================================================================
-- WhisperManager.lua - Main addon file
-- ============================================================================
-- This addon provides a custom whisper interface similar to WIM (WoW Instant Messenger)
-- with multi-line input, history management, and TotalRP3-style emote/speech formatting.
--
-- All functionality is split into separate modules for better maintainability:
-- - Core.lua: Core initialization, debug functions, and utilities
-- - PlayerUtils.lua: Player identification and name resolution
-- - History.lua: Message history management
-- - Window.lua: Whisper window creation and management
-- - RecentChats.lua: Recent chats UI
-- - HistoryViewer.lua: History viewer and search UI
-- - FloatingButton.lua: Floating button UI
-- - Events.lua: Event handlers and hooks
--
-- The modules are loaded via WhisperManager.xml
-- ============================================================================

local addon = WhisperManager;

-- ============================================================================
-- Main Initialization
-- ============================================================================

function addon:Initialize()
    -- Initialize core systems
    self:InitializeCore()
    
    -- Register events
    self:RegisterEvents()
end

-- Start the addon
addon:Initialize()
