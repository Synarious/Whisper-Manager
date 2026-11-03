"""History retention, identity aliases, pagination, sound and row reuse."""
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
lua = runpy.run_path(str(ROOT / 'tests/theme_smoke.py'))['lua']
lua.execute(r'''
function time() return 1800000000 end
function date(fmt,t) return os.date(fmt,t) end
function UnitName() return 'Me','Realm' end
function GetRealmName() return 'Realm' end
function Ambiguate(s) return s end
ChatTypeInfo={EMOTE={r=1,g=1,b=1},SAY={r=1,g=1,b=1}}
RAID_CLASS_COLORS={}
local a=WhisperManager
a.windows={}
a.CLASS_ID_TO_TOKEN={}; a.CLASS_TOKEN_TO_ID={}
a.TrimWhitespace=function(self,s) return s:match('^%s*(.-)%s*$') end
''')
for name in ('Modules/SchemaValidator.lua', 'Modules/Data.lua', 'Modules/RecentChats.lua', 'UI/HistoryViewer.lua'):
    lua.execute((ROOT / name).read_text(encoding='utf-8'))
lua.execute(r'''
local a=WhisperManager
local month=30*24*60*60
a.schemaValidationPassed=true
a.settings.historyRetentionMode='mode1'
local recent={timestamp=time(),author='Friend-Realm',message='legacy recent'}
local current={t=time(),a='Friend-Realm',m='current'}
WhisperManager_HistoryDB={__schema=1,
 c_Legacy={__display='preserve metadata',recent,{timestamp=time()-12*month,author='Friend',message='expired'}},
 c_Current={current}, c_Order={},
 c_Unknown={{m='unknown timestamp'},{t=time()-12*month,m='preserve entire conversation'}},
 c_Nan={{t=0/0,m='unknown timestamp'}}}
for i=1,10 do WhisperManager_HistoryDB.c_Order[i]={t=time(),m=tostring(i)} end
a:RunHistoryRetentionCleanup()
assert(#WhisperManager_HistoryDB.c_Legacy==1 and WhisperManager_HistoryDB.c_Legacy[1]==recent)
assert(WhisperManager_HistoryDB.c_Legacy.__display=='preserve metadata')
assert(WhisperManager_HistoryDB.c_Current[1]==current)
assert(#WhisperManager_HistoryDB.c_Unknown==2 and #WhisperManager_HistoryDB.c_Nan==1)
for i,e in ipairs(WhisperManager_HistoryDB.c_Order) do assert(e.m==tostring(i)) end
a:RunHistoryRetentionCleanup()
for i,e in ipairs(WhisperManager_HistoryDB.c_Order) do assert(e.m==tostring(i)) end
-- Keep-count protection and the general age cutoff remain independent.
a.settings.historyRetentionMode='mode2'
WhisperManager_HistoryDB.c_Protected={}
for i=1,21 do WhisperManager_HistoryDB.c_Protected[i]={t=time()-5*month,m=tostring(i)} end
a:RunHistoryRetentionCleanup()
assert(#WhisperManager_HistoryDB.c_Protected==20 and WhisperManager_HistoryDB.c_Protected[1].m=='2')
a.settings.historyRetentionMode='none'
local count=#WhisperManager_HistoryDB.c_Protected
a:RunHistoryRetentionCleanup(); assert(#WhisperManager_HistoryDB.c_Protected==count)
a:RunDebugRetentionCleanup()
assert(#WhisperManager_HistoryDB.c_Protected==3 and #WhisperManager_HistoryDB.c_Unknown==2)
a.schemaValidationPassed=false
local snapshot=WhisperManager_HistoryDB.c_Protected
a.settings.historyRetentionMode='mode1'
a:RunHistoryRetentionCleanup(); a:RunDebugRetentionCleanup()
assert(WhisperManager_HistoryDB.c_Protected==snapshot)
a.schemaValidationPassed=true

-- User input and server events reuse the original saved key, without renaming it.
WhisperManager_HistoryDB={__schema=1,['c_Friend-Realm']={current}}
local key,target=a:ResolvePlayerIdentifiers('friend')
assert(key=='c_Friend-Realm' and target=='Friend-Realm')
assert(a:ResolvePlayerIdentifiers('FRIEND-Realm')==key)
assert(a:ResolvePlayerIdentifiers('c_friend-Realm')==key)
local new=a:ResolvePlayerIdentifiers('Newfriend')
assert(a:ResolvePlayerIdentifiers('NEWFRIEND-Realm')==new)
assert(a:ResolvePlayerIdentifiers('Friend-OtherRealm')~=key)

-- The same display renderer honors successive backlog requests.
WhisperManager_HistoryDB[key]={}
for i=1,200 do WhisperManager_HistoryDB[key][i]={t=time(),a='Friend-Realm',m='message'..i} end
local history={lines={}}
function history:Clear() self.lines={} end
function history:AddMessage(s) self.lines[#self.lines+1]=s end
function history:ScrollToBottom() end
function history:SetMaxLines(n) self.capacity=n end
local window={isBNet=false,History=history}
a:DisplayHistory(window,key)
assert(#history.lines==101 and history.lines[2]:find('message101',1,true))
window.__wm_historyRenderLimit=150
a:DisplayHistory(window,key)
assert(#history.lines==151 and history.lines[2]:find('message51',1,true))
window.__wm_historyRenderLimit=200
a:DisplayHistory(window,key)
assert(#history.lines==201 and history.lines[2]:find('message1',1,true))
for i,entry in ipairs(WhisperManager_HistoryDB[key]) do entry.t=time()-(201-i)*86400 end
a:DisplayHistory(window,key)
assert(#history.lines==401 and history.capacity>=#history.lines)
assert(history.lines[2]:find('message1',1,true))

-- Disabled sound has a persistent value distinct from an unset default.
SOUNDKIT.TELL_MESSAGE=3081
local soundCalls=0
PlaySound=function() soundCalls=soundCalls+1 end
a:SetSetting('notificationSound',0)
a:PlayNotificationSound(); a.settings=a:LoadSettings(); a:PlayNotificationSound()
assert(soundCalls==0 and a:GetSetting('notificationSound')==0)
a:SetSetting('notificationSound','None (Disabled)')
a:PlayNotificationSound(); a:PlayNotificationSound()
assert(soundCalls==0 and a:GetSetting('notificationSound')==0)
a:SetSetting('notificationSound',3081); a:PlayNotificationSound(); assert(soundCalls==1)

-- Count all frame/region allocations, including repeated searching and opening.
allocations=0
local create=CreateFrame
function CreateFrame(...)
 allocations=allocations+1
 local frame=create(...)
 frame.GetFontString=function() return nil end
 frame.Clear=function(self) self.lines={} end
 frame.AddMessage=function(self,s) self.lines=self.lines or {}; self.lines[#self.lines+1]=s end
 local texture,font=frame.CreateTexture,frame.CreateFontString
 frame.CreateTexture=function(self,...)
  allocations=allocations+1
  local region=texture(self,...)
  region.SetShown=function(self,shown) if shown then self:Show() else self:Hide() end end
  return region
 end
 frame.CreateFontString=function(self,...) allocations=allocations+1; return font(self,...) end
 return frame
end
a:CreateRecentChatsFrame()
local allocated=allocations
local row=a.recentChatsFrame.rows[1]
for i=1,20 do a:RefreshRecentChats() end
assert(allocations==allocated and a.recentChatsFrame.rows[1]==row)
a.recentChatsFrame.searchBox:SetText('no matching conversation'); a:RefreshRecentChats()
assert(not row:IsShown())
a.recentChatsFrame.searchBox:SetText(''); a:RefreshRecentChats()
assert(row:IsShown() and allocations==allocated)
-- Pool click handlers must follow the new data after reordering/filtering.
local opened
a.OpenConversation=function(self,key) opened=key; return true end
WhisperManager_HistoryDB={__schema=1,['c_New-Realm']={{t=time(),a='New-Realm',m='new'}}}
WhisperManager_RecentChats={}
a:RefreshRecentChats()
row.scripts.OnClick(row,'LeftButton')
assert(opened=='c_New-Realm' and allocations==allocated)

a:ToggleHistoryFrame()
assert(a.historyFrame and a.historyFrame:IsShown())
local browserAllocated=allocations
local browserRow=a.historyFrame.rows[1]
for i=1,20 do a:RefreshHistoryList('') end
assert(allocations==browserAllocated and a.historyFrame.rows[1]==browserRow)
a:RefreshHistoryList('no match'); assert(not browserRow:IsShown())
a:RefreshHistoryList('New'); assert(browserRow:IsShown() and allocations==browserAllocated)
local selected
local showDetail=a.ShowHistoryDetail
a.ShowHistoryDetail=function(self,key) selected=key end
browserRow.scripts.OnClick(); assert(selected=='c_New-Realm')
a.ShowHistoryDetail=showDetail
a:ShowHistoryDetail(selected,'New')
assert(#a.historyFrame.detailScrollFrame.lines==1 and a.historyFrame.detailScrollFrame.lines[1]:find('new',1,true))
a:ToggleHistoryFrame(); assert(not a.historyFrame:IsShown())
a:ToggleHistoryFrame(); assert(a.historyFrame:IsShown() and allocations==browserAllocated)
''')
# Use the client's UTF-8 comparator contract for names outside ASCII.
lua.globals().strcmputf8i = lambda a, b: 0 if a.casefold() == b.casefold() else 1
lua.execute(r'''
WhisperManager_HistoryDB={['c_Élodie-Realm']={}}
assert(WhisperManager:ResolvePlayerIdentifiers('élodie')=='c_Élodie-Realm')
''')
print('Passed: legacy/invalid history retention, stable ordering, metadata, identity aliases, pagination, persistent mute, pooled rows and history access.')
