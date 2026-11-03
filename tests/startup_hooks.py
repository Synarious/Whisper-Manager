"""Real core initialization and the boundaries of Blizzard chat post-hooks."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
frames={}; hooks={}; timers={}; notices={}
function CreateFrame()
 local f={events={}}
 function f:RegisterEvent(e) self.events[e]=true end
 function f:UnregisterEvent(e) self.events[e]=nil end
 function f:SetScript(k,fn) self[k]=fn end
 function f:HookScript() end
 function f:IsShown() return true end
 frames[#frames+1]=f
 return f
end
function hooksecurefunc(object,method,fn)
 assert(type(object[method])=='function',method)
 hooks[method]=fn
end
ChatFrameUtil={}
for _,name in ipairs({'ActivateChat','SendTell','InsertLink','OpenChat','SendBNetTell'}) do ChatFrameUtil[name]=function() end end
Constants={ChatFrameConstants={MaxChatWindows=0}}
DEFAULT_CHAT_FRAME={AddMessage=function(self,s) notices[#notices+1]=s end}
UIParent=CreateFrame()
SlashCmdList={}; SOUNDKIT={TELL_MESSAGE=3081}
C_Timer={After=function(delay,fn) timers[#timers+1]=fn end}
C_ChatInfo={InChatMessagingLockdown=function() return locked==true end}
function InCombatLockdown() return false end
function IsInInstance() return false end
function UnitName() error('Saved history must be validated before scanning characters') end
function GetRealmName() return 'Realm' end
function GetCurrentKeyBoardFocus() return focus end
''')
core = lua.execute('return function(...)\n' + (ROOT / 'Core.lua').read_text(encoding='utf-8') + '\nend')
core('Whisper-Manager', lua.table())
for name in ('Modules/RuntimeSafety.lua','UI/Theme.lua','Modules/SchemaValidator.lua','UI/Settings.lua','UI/Window.lua'):
    lua.execute((ROOT / name).read_text(encoding='utf-8'))
lua.execute(r'''
local a=WhisperManager
a.ShowSchemaWarning=function() end
local history={__schema=2,['bnet_Friend#123']={{a='Other-Realm',m='untouched',t=1}}}
WhisperManager_HistoryDB=history
WhisperManager_Config={settings={notificationSound=0}}
assert(not a:Initialize() and not a.initialized and not a:IsSafeToOperate())
assert(WhisperManager_HistoryDB==history and history.__schema==2)
assert(WhisperManager_CharacterDB==nil and a.settings==nil and next(hooks)==nil)
local count=#frames
frames[2].OnEvent(frames[2],'PLAYER_ENTERING_WORLD')
frames[#frames].OnEvent(frames[#frames],'PLAYER_REGEN_ENABLED')
a:SetupHooks(); a:SetupChatHooks()
assert(#frames==count and next(hooks)==nil)
assert(SlashCmdList.WHISPERMANAGER)
SlashCmdList.WHISPERMANAGER('history') -- Disabled commands must not construct UI.
assert(#frames==count and WhisperManager_HistoryDB==history)
for _,invalid in ipairs({'bad schema',math.huge}) do
 history.__schema=invalid; assert(not a:ValidateSchema())
end
history.__schema=1
function UnitName() return 'Me','Realm' end
a.InitializeTRP3Integration=function() end
assert(a:Initialize() and a.initialized and a:IsSafeToOperate())
assert(hooks.ActivateChat and not hooks.OpenChat)
local activate=hooks.ActivateChat
assert(a:Initialize() and hooks.ActivateChat==activate)
a:SetupHooks()
assert(hooks.OpenChat and hooks.InsertLink and hooks.SendTell and hooks.SendBNetTell)

local secret={}
local guarded={}
function issecretvalue(value)
 if rawequal(value,secret) then guarded[value]=true; return true end
 return false
end
ChatFrameUtil.ChooseBoxForSend=function() error('Secret text must be rejected before touching chat frames') end
hooks.OpenChat(secret); assert(guarded[secret]); guarded[secret]=nil
hooks.InsertLink(secret); assert(guarded[secret]); guarded[secret]=nil
hooks.SendTell(secret); assert(guarded[secret]); guarded[secret]=nil
assert(a:TrimWhitespace(secret)==nil and guarded[secret])
local inserts=0
focus={_WhisperManagerInput=true,HasFocus=function() return true end,
 IsVisible=function() return true end,IsShown=function() return true end,
 GetName=function() return 'test input' end,Insert=function() inserts=inserts+1 end}
a.EditBoxInFocus=focus
hooks.InsertLink('|Hitem:42|h[Item]|h'); assert(inserts==1)
locked=true
hooks.InsertLink('|Hitem:42|h[Item]|h'); assert(inserts==1)
hooks.OpenChat('/w Friend text') -- No chat frame access while restricted.
locked=false
hooks.ActivateChat({GetAttribute=function() return secret end,GetName=function() return 'chat' end,
 Insert=function() end,SetText=function() end,HighlightText=function() end})
assert(a:AreConversationKeysEqual('c_Friend-Realm','c_friend-realm'))
assert(not a:AreConversationKeysEqual(secret,'c_friend-realm'))
''')
print('Passed: schema rejection leaves data untouched, startup stays disabled, recovery commands remain available, successful initialization is idempotent and chat hooks reject secrets/restrictions.')
