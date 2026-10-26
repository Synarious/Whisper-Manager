"""Battle.net export regression: plain names, layering, focus, selection and reuse."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
local methods={}
local noop=function() end
function methods:GetText() return self.text end
function methods:SetText(text) self.text=text end
function methods:SetFrameLevel(level) self.level=level end
function methods:GetFrameLevel() return self.level or 0 end
function methods:SetFocus() self.focused=true end
function methods:HighlightText(start,finish) self.highlight={start,finish} end
function methods:IsShown() return self.shown end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false end
function methods:CreateFontString() return CreateFrame('FontString') end
function CreateFrame()
 return setmetatable({},{__index=function(_,key)
  if methods[key] then return methods[key] end
  if key:match('^Set') or key:match('^Enable') or key:match('^Register')
   or key=='ClearAllPoints' or key=='Raise' then return noop end
 end})
end
UIParent=CreateFrame(); ChatFontNormal={}
UnitName=function() return 'Mychar','My Realm' end
GetRealmName=function() return 'My Realm' end
date=function() return '2026-10-24 12:00:00' end
WhisperManager={windows={},DebugMessage=noop,Print=noop,
 GetOverlayParent=function() return UIParent end, RegisterThemeFrame=noop,
 GetDisplayNameFromKey=function(self,key) return key:match('^bnet_([^#]+)') or 'Character' end,
 ResolveBNetID=function(self,author,key) return self:GetDisplayNameFromKey(key) end}
''')
lua.execute((ROOT/'Modules/Dialogs.lua').read_text())
lua.execute(r'''
local a=WhisperManager
local key='bnet_Friend#1234'
WhisperManager_HistoryDB={[key]={
 {t=1,a='|Kp123|k',m='Hello |cffaabbcc|Hitem:42|h[Cool Sword]|h|r'},
 {t=2,a='|Kq456|k',m='*waves* (OOC) |Kq456|k'},
 {timestamp=3,author='Mychar-MyRealm',message='Reply'},
}}
local win=CreateFrame(); win:SetFrameLevel(12000); win:Show()
win.InputContainer=CreateFrame(); win.InputContainer:SetFrameLevel(12030)
a.windows[key]=win
a:ShowChatExportDialog(key,'|Kq456|k',win)
local frame=a.chatExportFrame
local text=frame.editBox:GetText()
assert(text:find('Conversation with: Friend',1,true))
assert(text:find('Friend: Hello [Cool Sword]',1,true))
assert(text:find('Friend: *waves* (OOC) Friend',1,true))
assert(text:find('Mychar: Reply',1,true))
assert(not text:find('|K',1,true) and not text:find('|H',1,true) and not text:find('|c',1,true))
assert(frame:GetFrameLevel()>win:GetFrameLevel()+50)
assert(frame.editBox:GetFrameLevel()>win.InputContainer:GetFrameLevel())
assert(frame.editBox.focused and frame.editBox.highlight[1]==0 and frame.editBox.highlight[2]==nil)
-- Reuse the same dialog for a character and then an empty Battle.net conversation.
WhisperManager_HistoryDB.c_Other={{t=4,a='Other-Realm',m='Character history'}}
a:ShowChatExportDialog('c_Other','Other')
assert(a.chatExportFrame==frame and frame.editBox:GetText():find('Character history',1,true))
a:ShowChatExportDialog('bnet_Empty#1234')
assert(frame.editBox:GetText()=='No messages found for this conversation.')
''')
print('Passed: Battle.net export tokens, legacy history, links/emotes/OOC, dialog layering, copy focus/selection, reuse and empty history.')
