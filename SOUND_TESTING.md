# WhisperManager Sound Testing Guide

## Quick Test Steps

1. **Reload UI**: Type `/reload` in game chat to load the latest changes

2. **Test Preview Sound**:
   - Open WhisperManager Settings (usually `/wm` or the floating button)
   - Scroll down to "Notification Settings" section
   - You should see a dropdown for "Notification Sound"
   - Click the "Preview Sound" button
   - You should hear a sound play (or see a message in chat if sound fails)

3. **Check Chat Output**:
   - When you click "Preview Sound", look at your chat window
   - You should see colored messages from WhisperManager:
     - Green message: "Attempting to play sound..."
     - Either green: "Playing notification sound on channel..." OR Red: "ERROR: Failed to play sound"

## Debugging

### If Preview Sound Makes No Sound:

1. **Check In-Game Audio Settings**:
   - Make sure WoW volume is not muted
   - Check Master volume setting in WoW's sound options
   - Try changing the "Sound Channel" to "SFX" or "Dialog"

2. **Check Chat Output**:
   - Type `/reload` and wait for addon to load
   - Click "Preview Sound" button
   - Look for messages in chat (they will show even if no sound plays)

3. **Verify Sound Files Exist**:
   - The current sound options use these files:
     - `Sound\Interface\iLvlInvalid.ogg` (Quest Alert)
     - `Sound\Interface\ChatFrame_NewChannel.ogg` (Chat Alert)
     - `Sound\Interface\AlarmClockWarning.ogg` (Warning)
     - `Sound\Interface\LevelUpTone.ogg` (Ding)
     - `Sound\Interface\PvPAlertEnemyNear.ogg` (PvP Alert)

### Test on Whisper Receive:

1. Have another player/account whisper you
2. You should hear the notification sound automatically
3. A chat message should appear: "Playing notification sound on channel: Master"
4. Optional: Windows taskbar should flash (if enabled)

## Sound Channel Options

- **Master**: Overall game volume
- **SFX**: Sound effects volume (recommended)
- **Music**: Music volume
- **Ambience**: Ambient sounds volume
- **Dialog**: Voice/dialog volume

Try "SFX" if you're not hearing anything - it's the most commonly used channel for alerts.

## Reset to Defaults

If settings get messed up:
1. Click "Reset Defaults" button in Settings
2. Type `/reload`
3. Try the preview sound again
