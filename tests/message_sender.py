"""Run with Python + lupa: UTF-8/format splitting and acknowledged send queue."""
from pathlib import Path
import re
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
WhisperManager={CHAT_MAX_LETTERS=500, WHISPER_CHUNK_BYTES=245}
function strlenutf8(s) local _,n=s:gsub('[^\128-\191]',''); return n end
function InCombatLockdown() return false end
local a=WhisperManager
a.Print=function(self,s) self.lastNotice=s end
a.StripRealmFromName=function(s) return s:match('^[^-]+') end
sent={}; timers={}
C_Timer={After=function(delay,fn) timers[#timers+1]={delay=delay,fn=fn} end}
C_ChatInfo={SendChatMessage=function(text,kind,lang,target)
 sent[#sent+1]={text=text,target=target,kind=kind}
end}
C_BattleNet={SendWhisper=function(target,text)
 sent[#sent+1]={text=text,target=target,kind='BN'}; return true
end}
function window(key,target,bnet)
 local w={playerKey=key,playerTarget=target,bnSenderID=target,isBNet=bnet}
 w.Input={text='',GetText=function(self) return self.text end,SetText=function(self,s) self.text=s end}
 return w
end
function advanceShortTimer()
 for i,t in ipairs(timers) do
  if t.delay==0.5 then table.remove(timers,i); t.fn(); return end
 end
 error('No scheduled continuation')
end
''')
lua.execute((ROOT/'Modules/RuntimeSafety.lua').read_text())
lua.execute((ROOT/'Modules/MessageSender.lua').read_text())
split=lua.eval('function(text) return WhisperManager:SplitWhisperMessage(text) end')
examples=[
    '*'+('hello there '*35).strip()+'*',
    '('+('OOC comment '*35).strip()+')',
    'Hello *'+('waves warmly '*25).strip()+'* ('+('OOC '*20).strip()+')',
    '(*'+('nested emote '*30).strip()+'*)',
    '*'+('café 你好 😀 '*30).strip()+'*',
]
for text in examples:
    parts=list(split(text).values())
    assert len(parts)>1
    assert all(len(p.encode('utf8'))<=245 for p in parts)
    for part in parts:
        assert part.count('*')%2==0, part
        assert part.count('(')==part.count(')'), part
    clean=lambda s: re.sub(r'\s+',' ',s.translate(str.maketrans('','','*()'))).strip()
    assert clean(' '.join(parts))==clean(text)
for text in ('x'*500, 'é'*500, '你好'*250):
    parts=list(split(text).values())
    assert ''.join(parts)==text
    assert all(len(p.encode('utf8'))<=245 for p in parts)
link='|cffaabbcc|Hitem:12345|h[Wonderful sword]|h|r'
parts=list(split(('word '*45)+link+(' more'*40)).values())
assert sum(link in p for p in parts)==1
assert all(len(p.encode('utf8'))<=245 for p in parts)
# An unmatched parenthesis must not hide a matched emote span.
parts=list(split('*hello (really '+('word '*70)+'*').values())
assert all(p.count('*')%2==0 for p in parts)
result=split('|Hitem:'+('x'*250)+'|h[item]|h')
assert isinstance(result,tuple) and result[0] is None
parts=list(split('*'+('word '*70)).values())
assert sum(p.count('*') for p in parts)==1
lua.execute(r'''
local a=WhisperManager
local w=window('c_Friend','Friend-Realm',false)
local text='*'..string.rep('hello there ',30)..'*'
w.Input.text=text
assert(a:SendComposedWhisper(w,text))
assert(#sent==1 and w.Input.text==text and w.whisperSendPending)
assert(not a:SendComposedWhisper(w,text))
a:ConfirmQueuedWhisper('wrong',sent[1].text)
assert(#sent==1)
a:ConfirmQueuedWhisper(w.playerKey,sent[1].text)
advanceShortTimer()
assert(#sent==2)
a:ConfirmQueuedWhisper(w.playerKey,sent[2].text)
assert(w.Input.text=='' and not w.whisperSendPending)
advanceShortTimer()
-- Battle.net sends all 500 characters in a single call.
local bn=window('bnet_Test#123',42,true)
bn.Input.text=string.rep('b',500)
assert(a:SendComposedWhisper(bn,bn.Input.text))
assert(#sent==3 and #sent[3].text==500)
bn.Input.text='new draft'
a:ConfirmQueuedWhisper(bn.playerKey,sent[3].text)
assert(bn.Input.text=='new draft')
advanceShortTimer()
-- A rejected recipient stops the rest and restores only the unconfirmed portion.
w.Input.text=text
assert(a:SendComposedWhisper(w,text))
a:ConfirmQueuedWhisper(w.playerKey,sent[4].text)
advanceShortTimer()
assert(#sent==5)
a:FailQueuedWhisper('Friend-Realm')
assert(not w.whisperSendPending and w.Input.text==sent[5].text)
advanceShortTimer()
-- Over-limit input never reaches the API.
assert(not a:SendComposedWhisper(w,string.rep('z',501)))
assert(#sent==5)
-- Timeout retains the draft, without retrying an ambiguously delivered whisper.
w.Input.text='timeout test'
assert(a:SendComposedWhisper(w,w.Input.text))
for _,t in ipairs(timers) do if t.delay==10 then t.fn() end end
assert(not w.whisperSendPending and w.Input.text=='timeout test')
advanceShortTimer()
-- Explicit Battle.net failure also retains the draft.
C_BattleNet.SendWhisper=function() return false end
bn.Input.text='cannot send'
a:SendComposedWhisper(bn,bn.Input.text)
assert(not bn.whisperSendPending and bn.Input.text=='cannot send')
advanceShortTimer()
-- Preserve an edited draft on failure and recover the original explicitly.
local new=window('c_Other','Other-Realm',false)
new.Show=function() end
new.Input.text='original text'
a:SendComposedWhisper(new,new.Input.text)
new.Input.text='new draft'
a:FailQueuedWhisper('Other-Realm')
assert(new.Input.text=='new draft' and new.unsentWhisperDraft=='original text')
a:RecoverUnsentWhisper()
assert(new.Input.text=='new draft')
new.Input.text=''
a:RecoverUnsentWhisper()
assert(new.Input.text=='original text' and not new.unsentWhisperDraft)
advanceShortTimer()
-- Different recipients share one ordered queue.
w.Input.text='first recipient'
new.Input.text='second recipient'
local previous=#sent
a:SendComposedWhisper(w,w.Input.text)
a:SendComposedWhisper(new,new.Input.text)
assert(#sent==previous+1 and new.whisperSendPending)
a:ConfirmQueuedWhisper(w.playerKey,w.Input.text)
advanceShortTimer()
assert(#sent==previous+2 and sent[#sent].target=='Other-Realm')
a:ConfirmQueuedWhisper(new.playerKey,new.Input.text)
assert(not new.whisperSendPending and new.Input.text=='')

''')
print('Passed: emote/OOC/nested/mixed splitting, UTF-8, links, unmatched markers, 500-character cap, confirmation ordering, offline/timeout recovery, Battle.net failures and draft preservation.')
