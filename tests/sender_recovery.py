"""Case-insensitive acknowledgements and multiple independent recovery drafts."""
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
lua = runpy.run_path(str(ROOT / 'tests/message_sender.py'))['lua']
lua.execute(r'''
local a=WhisperManager
timers={}
local w=window('c_friend-Realm','friend-Realm',false)
w.Input.text=string.rep('x',300)
a:SendComposedWhisper(w,w.Input.text)
local before=#sent
a:ConfirmQueuedWhisper('c_Friend-OtherRealm',sent[#sent].text)
assert(w.whisperSendPending and #sent==before)
a:ConfirmQueuedWhisper('c_Friend-Realm',sent[#sent].text)
advanceShortTimer()
assert(#sent==before+1)
a:ConfirmQueuedWhisper('c_FRIEND-REALM',sent[#sent].text)
assert(not w.whisperSendPending)

timers={}
local one=window('c_One-Realm','One-Realm',false)
local two=window('c_Two-Realm','Two-Realm',false)
one.Show=function(self) self.shown=true end
two.Show=one.Show
one.Input.text='first original'; two.Input.text='second original'
a:SendComposedWhisper(one,one.Input.text)
a:SendComposedWhisper(two,two.Input.text)
one.Input.text='new draft one'; two.Input.text='new draft two'
local dispatched=#sent
a:CancelRestrictedWhispers('test cancellation')
assert(not one.whisperSendPending and not two.whisperSendPending)
a:RecoverUnsentWhisper()
assert(two.Input.text=='new draft two' and two.unsentWhisperDraft=='second original')
two.Input.text=''; a:RecoverUnsentWhisper()
assert(two.shown and two.Input.text=='second original' and not two.unsentWhisperDraft)
one.Input.text=''; a:RecoverUnsentWhisper()
assert(one.shown and one.Input.text=='first original' and not one.unsentWhisperDraft)
assert(not a.lastFailedWhisperWindow and #sent==dispatched)
a:RecoverUnsentWhisper(); assert(a.lastNotice=='No saved unsent whisper.')

-- A second failed send in one window must not overwrite the first saved draft.
timers={}
one.Input.text='older failure'; a:SendComposedWhisper(one,one.Input.text)
one.Input.text='draft'; a:CancelRestrictedWhispers('first cancellation')
one.Input.text='newer failure'; a:SendComposedWhisper(one,one.Input.text)
one.Input.text='draft'; a:CancelRestrictedWhispers('second cancellation')
one.Input.text=''; a:RecoverUnsentWhisper()
assert(one.Input.text=='newer failure' and one.unsentWhisperDraft=='older failure')
one.Input.text=''; a:RecoverUnsentWhisper()
assert(one.Input.text=='older failure' and not one.unsentWhisperDraft)
''')
print('Passed: case-insensitive recipient confirmation, realm separation, cancellation of multiple conversations and recovery of every failed draft without resending.')
