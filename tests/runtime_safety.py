"""Midnight restriction transitions, per-chunk guards and frame permissions."""
from pathlib import Path
import runpy

ROOT=Path(__file__).resolve().parents[1]
ns=runpy.run_path(str(ROOT/'tests/message_sender.py'))
lua=ns['lua']
lua.execute(r'''
advanceShortTimer()
combat=false; locked=false; instance=false; state=0
Enum={AddOnRestrictionType={Chat=5},AddOnRestrictionState={Inactive=0,Activating=1,Active=2}}
C_ChatInfo.InChatMessagingLockdown=function() return locked end
C_RestrictedActions={GetAddOnRestrictionState=function() return state end,
 CheckAllowProtectedFunctions=function(frame,silent) assert(silent); return not frame.blocked end}
WhisperManager.IsRestrictedChatModeInstance=function() return instance end
WhisperManager.DebugMessage=function() end
function InCombatLockdown() return combat end
function wipe(t) for k in pairs(t) do t[k]=nil end end
function CreateFrame()
 local f={RegisterEvent=function() end,SetScript=function(self,k,fn) self[k]=fn end}
 lifecycle=f; return f
end
''')
lua.execute((ROOT/'UI/Window.lua').read_text())
lua.execute(r'''
local a=WhisperManager
local w=window('c_Midnight','Midnight-Realm',false)
w.Input.text=string.rep('word ',90)
local count=#sent
-- Ordinary world combat alone does not prevent chat or addon frame operations.
combat=true
assert(a:CanChangeAddonFrame({}))
assert(not a:CanChangeAddonFrame({blocked=true}))
assert(a:SendComposedWhisper(w,w.Input.text))
assert(#sent==count+1)
a:ConfirmQueuedWhisper(w.playerKey,sent[#sent].text)
-- A duplicate INFORM must not acknowledge a chunk not yet dispatched.
a:ConfirmQueuedWhisper(w.playerKey,sent[#sent].text)
locked=true
advanceShortTimer()
assert(#sent==count+1 and not w.whisperSendPending and w.Input.text~='')
advanceShortTimer()
-- Starting a new send under either restriction does not call the API.
assert(not a:SendComposedWhisper(w,'blocked'))
assert(#sent==count+1)
locked=false; instance=true
assert(not a:SendComposedWhisper(w,'blocked in instance'))
instance=false
-- Activating is delivered before the API reports lockdown: cancel both in-flight
-- and queued conversations immediately, then require a fresh user send.
local queued=window('c_Queued','Queued-Realm',false)
queued.Input.text='queued text'; w.Input.text='in flight'
a:SendComposedWhisper(w,w.Input.text)
a:SendComposedWhisper(queued,queued.Input.text)
local before=#sent
assert(not locked and state==0)
lifecycle.OnEvent(lifecycle,'ADDON_RESTRICTION_STATE_CHANGED',5,1)
assert(a:GetWhisperRestrictionReason())
assert(not w.whisperSendPending and not queued.whisperSendPending)
assert(w.Input.text=='in flight' and queued.Input.text=='queued text')
assert(not a:SendComposedWhisper(w,'new blocked send'))
lifecycle.OnEvent(lifecycle,'ADDON_RESTRICTION_STATE_CHANGED',5,0)
while true do
 local found
 for i,t in ipairs(timers) do if t.delay==0 or t.delay==0.5 then
  table.remove(timers,i); t.fn(); found=true; break
 end end
 if not found then break end
end
assert(not a:GetWhisperRestrictionReason() and #sent==before)
-- Deferred frame work is coalesced, retained in combat, then flushed once.
local calls=0
a:QueueWindowAction('focus',function() calls=calls+1 end)
a:QueueWindowAction('focus',function() calls=calls+10 end)
a:FlushDeferredWindowActions(); assert(calls==0)
combat=false; a:FlushDeferredWindowActions(); assert(calls==10)
a:QueueWindowAction('recent',function() calls=calls+100 end)
a:CancelDeferredWindowActions(); a:FlushDeferredWindowActions(); assert(calls==10)
-- Fallback for older clients, and fail-closed behavior for unexpected API errors.
C_RestrictedActions=nil; combat=true
assert(a:CanChangeAddonFrame({IsProtected=function() return false end}))
assert(not a:CanChangeAddonFrame({IsProtected=function() return true end}))
C_ChatInfo.InChatMessagingLockdown=function() error('API unavailable temporarily') end
assert(a:GetWhisperRestrictionReason())
C_ChatInfo.InChatMessagingLockdown=nil
assert(not a:GetWhisperRestrictionReason())
issecretvalue=function(v) return type(v)=='table' and v.secret end
assert(not a:SendComposedWhisper(w,{secret=true}))
''')
# Exercise the actual window implementation too.
ns=runpy.run_path(str(ROOT/'tests/theme_smoke.py'))
lua=ns['lua']
lua.execute(r'''
local a=WhisperManager
combat=true
function InCombatLockdown() return combat end
local w=a.windows['bnet_Test#123']
w:Show()
a:FocusWindow(w)
assert(a:CloseWindow(w.playerKey) and not w:IsShown())
a.IsSafeToOperate=function() return true end
w.GetSize=function() return 340,200 end
w.GetCenter=function() return 200,100 end
UIParent.GetCenter=function() return 0,0 end
a:SaveWindowPosition(w,true)
assert(a.sessionWindowPositions[w.playerKey].x==200)
assert(a.sessionWindowSizes[w.playerKey].width==340)
w:Show(); w.IsProtected=function() return true end
assert(not a:CloseWindow(w.playerKey) and w:IsShown())
combat=false; a:FlushDeferredWindowActions()
assert(not w:IsShown())
-- Tooltip hover never enters the protected panel manager.
GameTooltip={SetOwner=function() end,SetHyperlink=function() end,
 Show=function(self) self.shown=true end,Hide=function(self) self.shown=false end}
ShowUIPanel=function() error('protected panel manager called') end
HideUIPanel=ShowUIPanel
w.History.scripts.OnHyperlinkEnter(w.History,'item:42')
assert(GameTooltip.shown)
w.History.scripts.OnHyperlinkLeave(w.History)
assert(not GameTooltip.shown)
-- Instance protection disables chat mode, closes windows, then restores the
-- preference without reopening windows or sending anything automatically.
local restricted=true
a.IsRestrictedChatModeInstance=function() return restricted end
a:SetSetting('chatModeEnabled',true)
w:Show()
a:CheckRuntimeRestrictions()
assert(not a:IsChatModeEnabled() and a.__chatModeRestoreRequested and not w:IsShown())
restricted=false
a:CheckRuntimeRestrictions()
assert(a:IsChatModeEnabled() and not a.__chatModeRestoreRequested and not w:IsShown())
-- The actual constructor can create a new non-secure conversation in combat.
combat=true
a.DisplayHistory=function() end
C_BattleNet.GetAccountInfoByID=function() return {battleTag='CombatFriend#123',accountName='CombatFriend'} end
assert(a:OpenBNetConversation(99,'CombatFriend'))
assert(a.windows['bnet_CombatFriend#123'].wmRoundedFill)
''')
print('Passed: Midnight Activating/Inactive transitions, combat vs chat lockdown, mid-send cancellation, queued drafts, no automatic resend, secret payloads, frame capabilities, deduplication, protected close deferral, safe tooltip handlers.')
