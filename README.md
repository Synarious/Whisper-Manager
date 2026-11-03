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
- Right-click the floating button or use `/wmgr history` to browse all saved conversations. Scroll up in a conversation to load older messages.
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
- Recovery keeps every failed draft for the session, including multiple failures in the same conversation. Repeated `/wmgr recover` calls restore the newest remaining draft after you clear its conversation's composer; recovery never resends automatically.

Midnight Compatibility
- Combat alone does not disable ordinary addon windows. Protected frame work uses the client permission API where available and is deferred and coalesced until allowed. Window behavior lives in one implementation.
- Chat restriction transitions and instance protection stop pending whisper sends, preserving unconfirmed drafts. Every message part rechecks restrictions; sending never resumes automatically after a restriction ends.
- Secret chat values are skipped before parsing or saving, and hyperlink tooltips avoid the protected panel manager.
- Supports interface 120105 (12.1.5). Failed schema validation stops runtime hooks and cleanup before saved data is modified.

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

## Releases

After tests pass, every push to `master`, `main`, or `dev` builds a release. You can
also run **Test and release** manually on one of those branches in GitHub Actions.
The workflow increments the final numeric part of the TOC version, commits that
change to the branch, creates an annotated tag, and packages that tagged commit.
For example, `12.100` becomes `12.101` with tag `v12.101`.

Use an `a` or `b` suffix in the TOC to select alpha or beta:
`12.100a` becomes `12.101a` / `v12.101-alpha`, and `12.100b` becomes
`12.101b` / `v12.101-beta`. Both are GitHub prereleases and use the matching
distribution channel. On `dev`, an unsuffixed version defaults to alpha.
Remove the suffix in the TOC when you want a stable release. Long suffixes
(`-alpha`, `-beta`) and numbered suffixes (`a1`, `b2`) are also accepted;
the final base number is always what increments.

Pushing an existing version tag (`v12.101`, `v12.101-alpha`, or `v12.101-beta`)
packages that version without another bump; the tag must match its commit's TOC.
To retry a failed publication after the version commit/tag was pushed, rerun
the workflow on that tag. Branch and tag protections must allow the workflow's
`GITHUB_TOKEN` to write the version commit and release tags.

The downloadable addon ZIP contains only the TOC, files loaded by its TOC/XML,
runtime media, and `LICENSE`, inside `Whisper-Manager/`. README, changelog,
tests, Python tools, and repository/editor metadata stay out of the addon.
The changelog is still used for release notes. Existing optional CurseForge,
WoWInterface, and Wago upload secrets remain supported.
