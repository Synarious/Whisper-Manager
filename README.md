# Whisper Manager
Addon inspired by WoW Instant Messenger (WIM), but seeks to expand upon it with added features and fixes. It's a powerful addon for people who whisper frequently. It stores history far longer than other chat addons while reducing data bloat to keep your game running fast.

Unique Features
- Global chat history, pick-up where you left on any character.
- Recent chat list.
- Missed whisper pop-ups on login. 
- Emote/OOC highlighting (for the RP community).
- Resize text font.
- Resize input (editbox) font.
- Easily search player history.
- Movable windows and buttons that remember their position - across all your characters. No fuss needed.
- Expanding input box (see your full messages before sending).
- Advanced data retention (recent & long-term history).

Theme Options
- GuildHelper is the default: translucent charcoal panels, bronze borders, parchment text, and gold accents.
- Open Whisper Manager Settings and use Appearance & Theme to choose GuildHelper, Midnight, Emerald, Classic Dark, or Custom Colors. Changes apply immediately.
- Fine-tune panel colors and transparency under Window Appearance. Editing a color selects Custom Colors; Reset Defaults restores GuildHelper. Existing personalized colors are preserved on upgrade.

Long Whispers
- Compose up to 500 characters. Battle.net whispers are sent as one message; character whispers split at word boundaries into UTF-8-safe chunks of up to 245 bytes.
- Matched `*emotes*` and `(OOC)` spans close and reopen across chunks so each part can display correctly in TRP3. Item links stay intact; oversized links are rejected without discarding the draft.
- The counter shows the number of parts. Parts send in order after outgoing confirmations, with a short pause between them. Unconfirmed text stays in the composer if sending fails. If you edited the draft while waiting, the unsent text is saved separately; clear the new draft and use `/wmgr recover` to restore it.

Midnight Compatibility
- Combat alone does not disable ordinary addon windows. Protected frame work uses the client permission API where available and is deferred and coalesced until allowed. Window behavior lives in one implementation.
- Chat restriction transitions and instance protection stop pending whisper sends, preserving unconfirmed drafts. Every message part rechecks restrictions; sending never resumes automatically after a restriction ends.
- Secret chat values are skipped before parsing or saving, and hyperlink tooltips avoid the protected panel manager.

Other Features
- UI and font scaling
- Copy chat button.
- Easy URL copying.
- Windows taskbar icon flash (on an unread message).
- Notification sounds.
- Resize window/position.
- Change font.
- Mispelled Support

Roadmap/Future
- Deleting a specific user's history.
- Clearing recent chat history manually.
- Midnight support - Its currently working, just need improve how it disables inside dungeon/raids. 

# Project Info
https://github.com/Synarious/Whisper-Manager
