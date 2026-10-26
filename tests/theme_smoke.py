"""Lua 5.1 smoke test: run with Python and lupa installed."""
from pathlib import Path

from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
for asset in ('RoundedCorner.tga', 'RoundedOutline8.tga', 'IconCopy.tga', 'IconProfile.tga', 'IconInvite.tga', 'IconClose.tga'):
    assert (ROOT / 'Media' / asset).is_file(), f'Missing skin asset: {asset}'

lua = LuaRuntime(unpack_returned_tuples=True)
compile_lua = lua.eval('function(s,n) local f,e=loadstring(s,n); assert(f,e) end')
for path in ROOT.rglob('*.lua'):
    compile_lua(path.read_text(encoding='utf-8-sig'), str(path))

lua.execute(r'''
local methods = {}
local function noop() end
-- Match the client's asset validation rather than accepting every Set* call.
for _, state in ipairs({'Normal','Pushed','Highlight','Disabled'}) do
 methods['Set'..state..'Texture']=function(self, asset)
  assert(type(asset)=='string' or type(asset)=='table', 'Button texture requires an asset; nil is invalid')
  self[state..'TextureAsset']=asset
  if asset ~= '' then
   self[state..'TextureRegion']={
    Hide=function(region) region.hidden=true end,
    SetTexture=function(region,asset) region.asset=asset end,
    SetAlpha=function(region,alpha) region.alpha=alpha end,
   }
  end
 end
 methods['Get'..state..'Texture']=function(self) return self[state..'TextureRegion'] end
end
function methods:SetSize(width,height) self.width=width; self.height=height end
function methods:GetChildren() return unpack(self.children) end
function methods:GetRegions() return unpack(self.regions) end
function methods:GetObjectType() return self.kind end
function methods:GetName() return self.name end
function methods:GetFont() return 'Fonts\\ARIALN.TTF',14,'' end
function methods:GetFrameLevel() return self.level or 1 end
function methods:ClearFocus() end
function methods:Raise() end
function methods:GetText() return self.text or '' end
function methods:GetTextColor() return 1,1,1,1 end
function methods:IsShown() return not self.hidden end
function methods:SetFrameLevel(n) self.level=n end
function methods:SetScript(k,v) self.scripts[k]=v end
function methods:HookScript(k,v) self.scripts[k]=v end
function methods:Show() self.hidden=false end
function methods:Hide() self.hidden=true end
function methods:SetText(s) self.text=s end
function methods:SetBackdrop(b)
 assert(self.hasBackdrop, "SetBackdrop requires BackdropTemplate")
 self.backdrop=b
end
function methods:SetVertexColor(...) self.color={...} end
function methods:SetBackdropColor(...) self.color={...} end
function methods:SetPoint(...) self.points[#self.points+1]={...} end
function methods:ClearAllPoints() self.points={} end
local function object(kind,name,parent)
 local o={kind=kind,name=name,children={},regions={},scripts={},points={}}
 setmetatable(o,{__index=function(_,key)
  if methods[key] then return methods[key] end
  if key:match('^Set') or key:match('^Enable') or key:match('^Register') then return noop end
 end})
 if parent then table.insert(parent.children,o) end
 return o
end
function methods:CreateTexture() local t=object('Texture'); table.insert(self.regions,t); return t end
function methods:CreateFontString() local t=object('FontString'); table.insert(self.regions,t); return t end
function CreateFrame(kind,name,parent,template)
 local frame=object(kind,name,parent)
 frame.hasBackdrop=template and template:find("BackdropTemplate") ~= nil
 return frame
end
function InCombatLockdown() return false end
function IsInInstance() return false end
function wipe(t) for k in pairs(t) do t[k]=nil end end
UIParent=CreateFrame('Frame','UIParent')
ChatFontNormal=object('FontString')
SOUNDKIT={}; C_Timer={After=noop}; WhisperManager_HistoryDB={}
C_BattleNet={SendWhisper=function() return true end}
function strlenutf8(s) local _,n=s:gsub('[^\128-\191]',''); return n end
WhisperManager={windows={},combatQueue={},CHAT_MAX_LETTERS=500,MAX_HISTORY_LINES=100,
 DebugMessage=noop, GetOverlayParent=function() return UIParent end, EnsureFrameOverlay=noop,
 IsChatModeEnabled=function() return true end, SetEditBoxFocus=noop, Print=noop}
''')
# Mirror the order that previously hid the theme integration.
for filename in ('Modules/RuntimeSafety.lua','Modules/MessageSender.lua','UI/Theme.lua','UI/Window.lua','Modules/Chat.lua','UI/Settings.lua','UI/FloatingButton.lua'):
    lua.execute((ROOT / filename).read_text())
lua.execute(r'''
local a=WhisperManager
a.settings=a:LoadSettings()
a.LoadWindowPosition=function() end
a.LoadWindowHistory=function() end
local win=a:CreateWindow('bnet_Test#123',42,'Test',true)
assert(win.wmRoundedFill, 'Active Chat.lua constructor must register its theme')
assert(win.backdrop==nil, 'Legacy tooltip border must be removed')
assert(win.InputContainer.wmRoundedBorder, 'Reply field must receive theme')
assert(not win.wmHistoryPanel, 'History should use compact borderless spacing')
assert(win.title.points[1][2]==win, 'Title must anchor to outer window')
assert(win.titleBar.points[1][4]==1 and win.titleBar.points[1][5]==-1, 'Title background must meet the inside edge of the border')
assert(win.titleBar.wmRoundedFill and win.titleBar.backdrop==nil, 'Title background must follow rounded window corners')
assert(win.title.points[1][5]==win.title.points[2][5], 'Title top anchors must agree')
assert(not win.InputContainer:IsShown(), 'Reply must stay hidden until the conversation opens')
assert(win.copyBtn.wmIcon and win.trp3Btn.wmIcon and win.closeBtn.wmIcon, 'All header buttons must finish styling')
assert(win.trp3Btn.wmIcon:GetObjectType()=='Texture', 'Profile must use an icon texture')
assert(win.closeBtn.backdrop==nil, 'Icon buttons should have no heavy border')
for _,button in ipairs({win.copyBtn,win.trp3Btn,win.ginviteBtn,win.closeBtn}) do
 assert(not button:GetNormalTexture() and not button:GetPushedTexture(), 'Header construction must not install legacy button art')
end
-- Simulate an existing native state texture being automatically shown on click.
win.copyBtn:SetPushedTexture('legacy-pushed-art')
a:StyleThemeFrame(win,'whisper')
local pushed=win.copyBtn:GetPushedTexture()
pushed.hidden=false
assert(pushed.asset=='' and pushed.alpha==0, 'Native click state must stay invisible even when re-shown')
local launcher=CreateFrame('Button')
launcher.glow=launcher:CreateTexture()
a.floatingButton=launcher
a:SetSetting('floatingButtonSize',40)
a:ApplyFloatingButtonSize()
assert(launcher.width==40 and launcher.height==40, 'Launcher must resize immediately')
assert(launcher.glow.width==40*70/64, 'Unread glow must follow launcher size')
a.floatingButton=nil
assert(win.History.points[1][5]==-34, 'History must clear compact header')
for _,id in ipairs({'midnight','forest','classic','guildhelper'}) do
 a:SelectTheme(id)
 assert(win.wmRoundedFill.textures[1].color[1]==a:GetTheme().surface[1])
 assert(win.InputContainer.wmRoundedBorder.textures[1].color[1]==a:GetTheme().border[1])
end
assert(a:CreateWindow('bnet_Test#123',42,'Test',true)==win)
-- Reproduce the first Battle.net right-click, before any messages exist.
local savedEnforce,savedDisplay,savedFocus=a.EnforceChatModeRestrictions,a.DisplayHistory,a.FocusWindow
C_BattleNet.GetAccountInfoByID=function() return {battleTag='First#123',accountName='First'} end
a.EnforceChatModeRestrictions=function() end
a.DisplayHistory=function() end
a.FocusWindow=function() end
assert(a:OpenBNetConversation(43,'First'), 'First Battle.net open must succeed before sending')
local first=a.windows['bnet_First#123']
assert(first and first:IsShown(), 'First Battle.net open must show the conversation')
assert(first.copyBtn.wmIcon and first.closeBtn.wmIcon, 'First open must finish button styling')
a.EnforceChatModeRestrictions,a.DisplayHistory,a.FocusWindow=savedEnforce,savedDisplay,savedFocus
win.Input:SetText(string.rep('b',500))
win.Input.scripts.OnEnterPressed(win.Input)
assert(win.whisperSendPending and #win.Input:GetText()==500)
a:ConfirmQueuedWhisper(win.playerKey,win.Input:GetText())
assert(not win.whisperSendPending and win.Input:GetText()=='')
WhisperManager_Config={settings={windowBackgroundColor={r=.3,g=.2,b=.1}}}
a.settings=a:LoadSettings()
assert(a:GetSetting('theme')=='custom' and a:GetSetting('windowBackgroundColor').r==.3)
''')
print('Passed: Lua 5.1 syntax, active window constructor, rounded chrome, reply styling, layout, theme switching, custom migration.')
