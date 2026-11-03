# Changelog
== Improvements ==
- Improved folder structure, easier to maintain.
- Reduced settings complexity. 
- Retention limits to be little safer.
- Data view

== Fixes ==
- Fixed retention cleanup deleting recent legacy-format history and reordering messages with equal timestamps; unknown timestamps and conversation metadata are preserved.
- Fixed case-sensitive recipient identities and outgoing confirmations, and retained every failed draft for session recovery.
- Restored the history browser (right-click the floating button or `/wmgr history`) and conversation backlog pagination, including date-divider capacity.
- Reused recent/history list rows across refreshes and fixed the notification sound's persistent disabled option.
- Completed chat hook secret-value guards, stopped runtime startup on schema failures, and declared 12.1.5 interface compatibility.
- Updated regression checks and required tests before a single release packaging step.
- Guarded censored-message text against Midnight secret values.
- Combat whispers now update recent conversations and unread tracking; protected UI refreshes are deferred.
- Temporary chat restrictions no longer overwrite the saved Chat Mode preference.
- Whisper hooks now use messaging restrictions instead of blocking all combat.
- Deferred window visibility now follows the latest open/close request in a stable order.
- Input box background now follows the multiline edit box's actual height, including long unbroken text and font changes.
- Fixed bnet chat export/copy window.
- Combat handling issues.
- History across different characters for bnet whispers. 
- Being unable to view censored messaged.
- Shift linking fixes.
