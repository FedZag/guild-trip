-- Guild Trip: Seiten ohne WoW "nachzeichnen" (Entwicklerwerkzeug, wird nicht mitgeliefert).
-- Laedt alle Addons mit einer nachgebauten WoW-Oberflaeche, oeffnet jede Seite und
-- schreibt Lage/Text/Bild aller sichtbaren Elemente als JSON. Das Bild daraus macht
-- scripts/render_ui.py (HTML-Vorschau, Bilder aus den eigenen TGA-Dateien).
-- Aufruf: lua5.1 scripts/render_ui.lua <ausgabe.json> [book] [seite,seite,...]
-- Kein echter Grafiktest: Blizzard-Vorlagen werden nur grob angedeutet.
local out, mode, only = arg[1] or "ui.json", arg[2] or "native", arg[3]
local root = (arg[0]:match("^(.*)/scripts/") or ".")
local unpack = unpack or table.unpack

-- ===== Elemente =====
local all, nextId = {}, 0
local LAYERS = {BACKGROUND=1, BORDER=2, ARTWORK=3, OVERLAY=4, HIGHLIGHT=5}
local FONTS = {
    GameFontNormal={12,"gold"}, GameFontNormalSmall={10,"gold"}, GameFontNormalLarge={16,"gold"},
    GameFontNormalHuge={20,"gold"}, GameFontHighlight={12,"white"}, GameFontHighlightSmall={10,"white"},
    GameFontHighlightLarge={16,"white"}, GameFontHighlightMedium={14,"white"}, GameFontDisable={12,"grey"},
    GameFontDisableSmall={10,"grey"}, GameFontNormalMed3={14,"gold"}, GameFontNormalMed2={13,"gold"},
    GameFontHighlightHuge={20,"white"}, GameFontRed={12,"red"}, GameFontGreen={12,"green"},
    QuestTitleFont={16,"gold"}, SystemFont_Shadow_Med1={12,"white"}, ChatFontNormal={13,"white"},
    NumberFontNormal={12,"white"}, GameFontWhite={12,"white"}, GameFontNormalOutline={12,"gold"},
}
local Element
local proto = {}
local function stubFn() return nil end
local mt = {__call = function() return nil end, __index = function(o, k)
    local v = proto[k]
    if v ~= nil then return v end
    if type(k) ~= "string" or not k:match("^%u") then return nil end
    if k:match("^Get") or k:match("^Is") or k:match("^Has") or k:match("^Can") then return stubFn end
    if k:match("^Set") or k:match("^Enable") or k:match("^Disable") or k:match("^Register") or k:match("^Unregister")
        or k:match("^Hook") or k:match("^Lock") or k:match("^Unlock") or k:match("^Start") or k:match("^Stop")
        or k:match("^Play") or k:match("^Add") or k:match("^Clear") or k:match("^Update") or k:match("^Refresh")
        or k:match("^Insert") or k:match("^Scroll") or k:match("^Raise") or k:match("^Lower") or k:match("^Click") then
        return stubFn
    end
    -- unbekannte Vorlagen-Teile (Text, CloseButton, NineSlice ...) entstehen bei Bedarf
    local child = Element(k == "Text" and "FontString" or "Frame", o, nil, nil, true)
    child.part = k
    if child.kind == "FontString" then child.fontObj = "GameFontHighlight" end
    rawset(o, k, child)
    return child
end}
Element = function(kind, parent, name, tpl, implicit)
    nextId = nextId + 1
    local o = setmetatable({id=nextId, kind=kind, parent=parent, children={}, regions={}, points={},
        shown=true, scripts={}, tpl=tpl, name=name, alpha=1, implicit=implicit}, mt)
    if parent then
        if kind == "FontString" or kind == "Texture" or kind == "Line" then parent.regions[#parent.regions+1] = o
        else parent.children[#parent.children+1] = o end
    end
    all[#all+1] = o
    if name then _G[name] = o end
    if tpl and type(tpl) == "string" then
        if tpl:find("PortraitFrameTemplate") or tpl:find("ButtonFrameTemplate") then
            o.CloseButton = Element("Button", o, nil, "UIPanelCloseButton")
            o.CloseButton:SetSize(24, 24) o.CloseButton:SetPoint("TOPRIGHT", o, "TOPRIGHT", 2, 2)
            o.TitleText = Element("FontString", o) o.TitleText.fontObj = "GameFontNormal"
            o.TitleText:SetPoint("TOP", o, "TOP", 0, -5)
            o.SetTitle = function(self, t) self.TitleText:SetText(t) end
        end
        if kind == "CheckButton" then
            o.Text = Element("FontString", o) o.Text.fontObj = "GameFontHighlight"
            o.Text:SetPoint("LEFT", o, "RIGHT", 2, 0)
            o.text = o.Text
        end
        if kind == "Button" or kind == "CheckButton" then o.fontObj = "GameFontNormal" end
    end
    return o
end
function proto:SetPoint(p, rel, rp, x, y)
    if type(rel) == "number" then rel, rp, x, y = nil, nil, rel, rp end
    if type(rel) == "string" then rel = _G[rel] end
    rel = rel or self.parent or _G.UIParent
    rp = rp or p
    for i, q in ipairs(self.points) do if q[1] == p then table.remove(self.points, i) break end end
    self.points[#self.points+1] = {p, rel, rp, x or 0, y or 0}
end
function proto:ClearAllPoints() self.points = {} end
function proto:SetAllPoints(rel)
    rel = rel or self.parent
    self.points = {{"TOPLEFT", rel, "TOPLEFT", 0, 0}, {"BOTTOMRIGHT", rel, "BOTTOMRIGHT", 0, 0}}
end
function proto:GetNumPoints() return #self.points end
function proto:GetPoint(i) local q = self.points[i or 1] if q then return q[1], q[2], q[3], q[4], q[5] end end
function proto:SetSize(w, h) self.w, self.h = w, h end
function proto:SetWidth(w) self.w = w end
function proto:SetHeight(h) self.h = h end
function proto:SetScale(s) self.scale = s end
function proto:GetScale() return self.scale or 1 end
function proto:GetWidth() self._rect = nil local r = self:Rect() return r and (r[3] - r[1]) or self.w or 0 end
function proto:GetHeight() self._rect = nil local r = self:Rect() return r and (r[4] - r[2]) or self.h or 0 end
function proto:GetSize() return self:GetWidth(), self:GetHeight() end
function proto:GetEffectiveScale() return 1 end
function proto:SetParent(p)
    if self.parent then
        local list = (self.kind == "FontString" or self.kind == "Texture") and self.parent.regions or self.parent.children
        for i, c in ipairs(list) do if c == self then table.remove(list, i) break end end
    end
    self.parent = p
    if p then
        local list = (self.kind == "FontString" or self.kind == "Texture") and p.regions or p.children
        list[#list+1] = self
    end
end
function proto:GetParent() return self.parent end
function proto:Show() self.shown = true if self.scripts.OnShow then pcall(self.scripts.OnShow, self) end end
function proto:Hide() local was = self.shown self.shown = false if was and self.scripts.OnHide then pcall(self.scripts.OnHide, self) end end
function proto:SetShown(v) if v then self:Show() else self:Hide() end end
function proto:IsShown() return self.shown end
function proto:IsVisible()
    local o = self
    while o do if not o.shown then return false end o = o.parent end
    return true
end
function proto:SetAlpha(a) self.alpha = a end
function proto:GetAlpha() return self.alpha end
function proto:SetText(t) self.text = t ~= nil and tostring(t) or nil end
function proto:SetFormattedText(f, ...) self.text = string.format(f, ...) end
function proto:GetText() return self.text end
function proto:SetFontObject(f) self.fontObj = type(f) == "string" and f or (type(f) == "table" and f.fontName) or self.fontObj end
function proto:SetNormalFontObject(f) self:SetFontObject(f) end
function proto:SetHighlightFontObject() end
function proto:SetFont(path, size, flags) self.fontPath, self.fontSize = path, size return true end
function proto:GetFont() return self.fontPath or "Fonts\\FRIZQT__.TTF", self:FontSize(), "" end
function proto:FontSize()
    if self.fontSize then return self.fontSize end
    local f = FONTS[self.fontObj or "GameFontNormal"]
    return f and f[1] or 12
end
function proto:SetTextColor(r, g, b, a) self.color = {r, g, b, a or 1} end
function proto:GetTextColor() local c = self.color or {1, .82, 0, 1} return c[1], c[2], c[3], c[4] end
function proto:SetJustifyH(v) self.justH = v end
function proto:SetJustifyV(v) self.justV = v end
function proto:SetWordWrap(v) self.wrap = v end
function proto:SetMaxLines(n) self.maxLines = n end
function proto:GetStringWidth() return #(self.text or "") * self:FontSize() * 0.5 end
function proto:GetUnboundedStringWidth() return self:GetStringWidth() end
function proto:GetStringHeight() return self:FontSize() + 2 end
function proto:GetLineHeight() return self:FontSize() + 2 end
function proto:SetTexture(t, ...) self.tex = t self.colorTex = nil end
function proto:GetTexture() return self.tex end
function proto:SetAtlas(a) self.atlas = a end
function proto:SetColorTexture(r, g, b, a) self.colorTex = {r, g, b, a or 1} self.tex = nil end
function proto:SetVertexColor(r, g, b, a) self.vertex = {r, g, b, a or 1} end
function proto:GetVertexColor() local c = self.vertex or {1,1,1,1} return c[1], c[2], c[3], c[4] end
function proto:SetTexCoord(...) self.coords = {...} end
function proto:SetGradient(orient, c1, c2)
    if type(c1) == "table" and type(c2) == "table" then
        self.grad = {orient, {c1.r or 0, c1.g or 0, c1.b or 0, c1.a or 1}, {c2.r or 0, c2.g or 0, c2.b or 0, c2.a or 1}}
    end
end
function proto:SetDrawLayer(l, sub) self.layer, self.sub = l, sub end
function proto:GetDrawLayer() return self.layer or "ARTWORK", self.sub or 0 end
function proto:SetFrameLevel(l) self.level = l end
function proto:GetFrameLevel() return self.level or ((self.parent and self.parent:GetFrameLevel() or 0) + 1) end
function proto:SetFrameStrata(s) self.strata = s end
function proto:GetFrameStrata() return self.strata or (self.parent and self.parent:GetFrameStrata()) or "MEDIUM" end
function proto:SetScript(k, f) self.scripts[k] = f end
function proto:GetScript(k) return self.scripts[k] end
function proto:HookScript(k, f)
    local old = self.scripts[k]
    self.scripts[k] = function(...) if old then old(...) end return f(...) end
end
function proto:HasScript() return true end
function proto:GetObjectType() return self.kind end
function proto:IsObjectType(t) return self.kind == t end
function proto:GetName() return self.name end
function proto:GetChildren() return unpack(self.children) end
function proto:GetRegions() return unpack(self.regions) end
function proto:GetNumChildren() return #self.children end
function proto:CreateTexture(name, layer, tpl, sub)
    local t = Element("Texture", self, name) t.layer, t.sub = layer, sub return t
end
function proto:CreateMaskTexture() return Element("Frame", nil) end
function proto:CreateLine(name, layer) local t = Element("Texture", self, name) t.layer = layer t.line = true return t end
function proto:CreateFontString(name, layer, font)
    local t = Element("FontString", self, name) t.layer = layer t.fontObj = font or "GameFontNormal" return t
end
function proto:CreateAnimationGroup() return Element("Frame", nil) end
function proto:CreateAnimation() return Element("Frame", nil) end
function proto:GetFontString()
    if self.kind ~= "Button" and self.kind ~= "CheckButton" then return nil end
    if not self.fs then
        self.fs = Element("FontString", self) self.fs.fontObj = self.fontObj or "GameFontNormal" self.fs.isButtonText = true
        self.fs:SetPoint("CENTER", self, "CENTER", 0, 0)
    end
    return self.fs
end
function proto:SetFontString(fs) self.fs = fs end
function proto:GetChecked() return self.checked end
function proto:SetChecked(v) self.checked = v and true or false end
function proto:SetEnabled(v) self.disabled = not v end
function proto:Enable() self.disabled = false end
function proto:Disable() self.disabled = true end
function proto:IsEnabled() return not self.disabled end
for _, n in ipairs({"Normal", "Pushed", "Disabled", "Highlight", "CheckedTexture"}) do
    proto["Get" .. n .. "Texture"] = function(self)
        self["_t" .. n] = self["_t" .. n] or Element("Texture", self) self["_t" .. n].shown = false
        return self["_t" .. n]
    end
end
function proto:GetCheckedTexture() return self:GetCheckedTextureTexture() end
function proto:SetValue(v) self.value = v end
function proto:GetValue() return self.value or 0 end
function proto:GetMinMaxValues() return 0, 1 end
function proto:GetVerticalScroll() return 0 end
function proto:GetVerticalScrollRange() return 0 end
function proto:GetHorizontalScroll() return 0 end
function proto:SetScrollChild(c) self.scrollChild = c c.parent = c.parent or self end
function proto:GetScrollChild() return self.scrollChild end
function proto:GetNumLetters() return #(self.text or "") end
function proto:HasFocus() return false end
function proto:GetCursorPosition() return 0 end
function proto:GetNumMessages() return 0 end
function proto:AddMessage(t, r, g, b) self.msgs = self.msgs or {} self.msgs[#self.msgs + 1] = {t = t, c = {r or 1, g or 1, b or 1}} end
function proto:Clear() self.msgs = {} end
function proto:IsMouseOver() return false end
function proto:IsMouseEnabled() return true end
function proto:IsMovable() return true end
function proto:GetID() return self.idv or 0 end
function proto:SetID(v) self.idv = v end
function proto:GetAttribute(k) return self.attrs and self.attrs[k] end
function proto:SetAttribute(k, v) self.attrs = self.attrs or {} self.attrs[k] = v end
function proto:IsForbidden() return false end
function proto:IsProtected() return false end
function proto:GetDebugName() return self.name or ("obj" .. self.id) end
function proto:EnableMouse() end
function proto:IsEventRegistered() return false end
function proto:GetLeft() local r = self:Rect() return r and r[1] end
function proto:GetRight() local r = self:Rect() return r and r[3] end
function proto:GetTop() local r = self:Rect() return r and r[4] end
function proto:GetBottom() local r = self:Rect() return r and r[2] end
function proto:GetCenter() local r = self:Rect() if r then return (r[1]+r[3])/2, (r[2]+r[4])/2 end end
function proto:GetRect() local r = self:Rect() if r then return r[1], r[2], r[3]-r[1], r[4]-r[2] end end

-- ===== Lage berechnen (WoW: y nach oben) =====
local function AnchorXY(r, p)
    local x = (p:find("LEFT") and r[1]) or (p:find("RIGHT") and r[3]) or (r[1]+r[3])/2
    local y = (p:find("TOP") and r[4]) or (p:find("BOTTOM") and r[2]) or (r[2]+r[4])/2
    return x, y
end
function proto:NaturalSize()
    local w, h = self.w, self.h
    if self.kind == "FontString" then
        local fs = self:FontSize()
        if not w or w == 0 then w = math.max(4, #(self.text or "") * fs * 0.52) end
        if not h or h == 0 then
            local cpl = math.max(1, math.floor(w / (fs * 0.52)))
            local lines = 1
            for line in ((self.text or "") .. "\n"):gmatch("(.-)\n") do lines = lines + math.max(0, math.ceil(#line / cpl) - 1) + 1 end
            lines = lines - 1
            if self.wrap == false then lines = 1 end
            if self.maxLines then lines = math.min(lines, self.maxLines) end
            h = math.max(1, lines) * (fs + 2)
        end
    end
    return w or 0, h or 0
end
function proto:Rect(depth)
    if self._rect then return self._rect end
    depth = (depth or 0) + 1
    if depth > 60 then return nil end
    if self == _G.UIParent then self._rect = {0, 0, 1600, 900} return self._rect end
    local W, H = self:NaturalSize()
    local L, R, T, B, CX, CY
    if #self.points == 0 then
        if self.kind == "FontString" or self.kind == "Texture" then
            -- ohne Anker: ganze Elternflaeche (Texturen) bzw. nicht sichtbar
            if self.kind == "Texture" and self.parent then
                local pr = self.parent:Rect(depth) if pr then self._rect = pr return pr end
            end
            return nil
        end
        if self.parent and self.parent.scrollChild == self then
            local pr = self.parent:Rect(depth)
            if pr then self._rect = {pr[1], pr[4] - (H > 0 and H or 0), pr[1] + (W > 0 and W or pr[3]-pr[1]), pr[4]} return self._rect end
        end
        return nil
    end
    for _, q in ipairs(self.points) do
        local p, rel, rp, x, y = q[1], q[2], q[3], q[4], q[5]
        local rr = rel and rel.Rect and rel:Rect(depth)
        if not rr then return nil end
        local ax, ay = AnchorXY(rr, rp)
        ax, ay = ax + x, ay + y
        if p:find("LEFT") then L = ax elseif p:find("RIGHT") then R = ax else CX = ax end
        if p:find("TOP") then T = ay elseif p:find("BOTTOM") then B = ay else CY = ay end
    end
    if L and R then elseif L then R = L + W elseif R then L = R - W elseif CX then L, R = CX - W/2, CX + W/2 else return nil end
    if T and B then elseif T then B = T - H elseif B then T = B + H elseif CY then B, T = CY - H/2, CY + H/2 else return nil end
    self._rect = {L, B, R, T}
    return self._rect
end

-- ===== WoW-Umgebung =====
local function Stub(name)
    local s = {}
    return setmetatable(s, {__index = function(t, k) local v = Stub(name .. "." .. tostring(k)) rawset(t, k, v) return v end,
        __call = function() return nil end})
end
UIParent = Element("Frame", nil, "UIParent")
WorldFrame = Element("Frame", nil, "WorldFrame")
Minimap = Element("Frame", UIParent, "Minimap") Minimap:SetSize(140, 140) Minimap:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -20)
GameTooltip = Element("Frame", UIParent, "GameTooltip") GameTooltip.shown = false
ChatFrame1 = Element("Frame", UIParent, "ChatFrame1") ChatFrame1:SetSize(430, 180) ChatFrame1:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 20, 120)
DEFAULT_CHAT_FRAME = ChatFrame1
WorldMapFrame = Element("Frame", UIParent, "WorldMapFrame") WorldMapFrame.shown = false
WorldMapFrame.ScrollContainer = Element("Frame", WorldMapFrame)
CreateFrame = function(kind, name, parent, tpl)
    local o = Element(kind, parent, name, tpl)
    if kind == "EditBox" then o.fontObj = "ChatFontNormal" end
    return o
end
CreateFont = function(name) local f = {fontName = name} function f:SetFont(_, size) FONTS[name] = {size or 12, "white"} end function f:SetTextColor() end function f:SetShadowOffset() end function f:SetShadowColor() end function f:CopyFontObject() end function f:SetJustifyH() end function f:SetSpacing() end function f:GetFont() return "x", 12, "" end _G[name] = f return f end
for k in pairs(FONTS) do _G[k] = {fontName = k, GetFont = function() return "Fonts\\FRIZQT__.TTF", FONTS[k][1], "" end,
    SetFont = function() end, SetTextColor = function() end, GetTextColor = function() return 1, 1, 1, 1 end,
    CopyFontObject = function() end, SetShadowOffset = function() end, SetShadowColor = function() end} end
UISpecialFrames, SlashCmdList, STATICPOPUP_NUMDIALOGS, StaticPopupDialogs = {}, {}, 4, {}
NUM_CHAT_WINDOWS = 10
RAID_CLASS_COLORS = setmetatable({}, {__index = function() return {r=1, g=.8, b=.4, colorStr="ffffcc66"} end})
LOCALIZED_CLASS_NAMES_MALE = setmetatable({}, {__index = function(_, k) return k end})
ITEM_QUALITY_COLORS = setmetatable({}, {__index = function() return {r=1, g=1, b=1, hex="|cffffffff"} end})
SOUNDKIT = setmetatable({}, {__index = function() return 1 end})
WOW_PROJECT_ID, WOW_PROJECT_CLASSIC, WOW_PROJECT_MAINLINE = 2, 2, 1
CALENDAR_INVITESTATUS_INVITED = 1
GetTime = function() return 1000 end
GetServerTime = function() return 1763380800 end
GetLocale = function() return "deDE" end
GetRealmName = function() return "Testrealm" end
GetNormalizedRealmName = GetRealmName
GetBuildInfo = function() return "1.60.1", "1", "", 11500 end
UnitName = function(u) if u == "player" then return "Testheld" end end
UnitGUID = function() return "Player-1-0001" end
UnitClass = function() return "Krieger", "WARRIOR", 1 end
UnitRace = function() return "Orc", "Orc" end
UnitLevel = function() return 24 end
UnitFactionGroup = function() return "Horde", "Horde" end
UnitSex = function() return 2 end
UnitExists = function(u) return u == "player" end
UnitIsDeadOrGhost = function() return false end
UnitAffectingCombat = function() return false end
UnitPower = function() return 0 end
UnitHealth = function() return 1 end
UnitHealthMax = function() return 1 end
UnitXP = function() return 0 end
UnitXPMax = function() return 1 end
UnitIsAFK = function() return false end
IsInGuild = function() return true end
GetGuildInfo = function() return "Die Testgilde", "Mitglied", 3 end
GetNumGuildMembers = function() return 0, 0, 0 end
GetGuildRosterMOTD = function() return "Donnerstag 20 Uhr Gildenausflug!" end
GetGuildRosterInfo = function() return nil end
C_GuildInfo = Stub("C_GuildInfo")
IsInGroup = function() return false end
IsInRaid = function() return false end
GetNumGroupMembers = function() return 0 end
InCombatLockdown = function() return false end
IsLoggedIn = function() return true end
IsShiftKeyDown = function() return false end
IsControlKeyDown = function() return false end
IsAltKeyDown = function() return false end
GetCursorPosition = function() return 0, 0 end
GetScreenWidth = function() return 1600 end
GetScreenHeight = function() return 900 end
GetCVar = function() return "0" end
GetCVarBool = function() return false end
SetCVar = function() end
PlaySound = function() return true end
PlaySoundFile = function() return true end
StopSound = function() end
hooksecurefunc = function(a, b, c) if type(a) == "table" and type(a[b]) == "function" then local old = a[b] a[b] = function(...) old(...) c(...) end end end
securecall = function(f, ...) return f(...) end
issecurevariable = function() return true end
debugstack = function() return "" end
geterrorhandler = function() return print end
seterrorhandler = function() end
date = os.date
time = os.time
strsplit = function(sep, s, n)
    local t = {} for p in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do t[#t+1] = p end return unpack(t)
end
strtrim = function(s) return (s or ""):match("^%s*(.-)%s*$") end
strjoin = function(sep, ...) return table.concat({...}, sep) end
strlower, strupper, strlen, strsub, strfind, strmatch, format, gsub, strrep =
    string.lower, string.upper, string.len, string.sub, string.find, string.match, string.format, string.gsub, string.rep
tinsert, tremove, wipe, tContains = table.insert, table.remove, function(t) for k in pairs(t) do t[k] = nil end return t end,
    function(t, v) for _, x in ipairs(t) do if x == v then return true end end return false end
CopyTable = function(t) local c = {} for k, v in pairs(t) do c[k] = type(v) == "table" and CopyTable(v) or v end return c end
floor, ceil, abs, max, min, sqrt = math.floor, math.ceil, math.abs, math.max, math.min, math.sqrt
Mixin = function(o, ...) for _, m in ipairs({...}) do for k, v in pairs(m) do o[k] = v end end return o end
CreateFromMixins = function(...) return Mixin({}, ...) end
CreateColor = function(r, g, b, a) return {r=r, g=g, b=b, a=a, GetRGB=function() return r, g, b end,
    WrapTextInColorCode = function(_, t) return t end, GenerateHexColor = function() return "ffffffff" end} end
PanelTemplates_SetNumTabs = function(f, n) f.numTabs = n end
PanelTemplates_SetTab = function(f, i)
    f.selectedTab = i
    for j, t in ipairs(f.Tabs or {}) do t.selectedTab = (j == i) end
end
PanelTemplates_DeselectTab = function(t) t.selectedTab = false end
PanelTemplates_TabResize = function(t) t.w = math.max(60, #(t.text or "") * 6.5 + 30) t.h = 32 end
PanelTemplates_UpdateTabs = function() end
C_Timer = {After = function() end, NewTicker = function() return {Cancel = function() end} end,
    NewTimer = function() return {Cancel = function() end} end}
C_AddOns = {IsAddOnLoaded = function() return false end, GetAddOnMetadata = function(_, k) if k == "Version" then return "0.6.7-alpha" end end,
    LoadAddOn = function() return false end, GetAddOnEnableState = function() return 0 end}
IsAddOnLoaded = function() return false end
GetAddOnMetadata = C_AddOns.GetAddOnMetadata
C_Map = {GetBestMapForUnit = function() return 1411 end, GetPlayerMapPosition = function() return nil end,
    GetMapInfo = function(id) if id == 1414 then return {mapID = id, name = "Kalimdor", mapType = 2, parentMapID = 947} end
        return {mapID = id, name = "Durotar", mapType = 3, parentMapID = 1414} end,
    GetWorldPosFromMapPos = function() return nil end, GetMapRectOnMap = function() return nil end}
C_Calendar = Stub("C_Calendar")
C_DateAndTime = {GetCurrentCalendarTime = function() local d = os.date("*t", 1763380800)
    return {year = d.year, month = d.month, monthDay = d.day, weekday = d.wday, hour = 18, minute = 30} end}
C_ChatInfo = {RegisterAddonMessagePrefix = function() return true end, SendAddonMessage = function() return true end,
    IsAddonMessagePrefixRegistered = function() return true end}
C_FriendList = Stub("C_FriendList")
C_GossipInfo = Stub("C_GossipInfo")
C_QuestLog = Stub("C_QuestLog")
C_Item = Stub("C_Item")
C_Spell = Stub("C_Spell")
C_SpellBook = Stub("C_SpellBook")
C_TradeSkillUI = Stub("C_TradeSkillUI")
C_SuperTrack = Stub("C_SuperTrack")
C_TaxiMap = Stub("C_TaxiMap")
C_Container = Stub("C_Container")
C_PartyInfo = Stub("C_PartyInfo")
C_LFGList = Stub("C_LFGList")
C_BattleNet = Stub("C_BattleNet")
C_Texture = Stub("C_Texture")
C_ClassTrainer = Stub("C_ClassTrainer")
C_Traits = Stub("C_Traits")
C_ClassTalents = Stub("C_ClassTalents")
C_CVar = {GetCVar = function() return "0" end, GetCVarBool = function() return false end, SetCVar = function() end}
C_Minimap = Stub("C_Minimap")
C_VoiceChat = Stub("C_VoiceChat")
Enum = Stub("Enum")
Enum.UIMapType = {Cosmic = 0, World = 1, Continent = 2, Zone = 3, Dungeon = 4, Micro = 5, Orphan = 6}
NineSliceUtil = {ApplyLayoutByName = function(f, layout) f.nine = layout end}
MenuUtil = Stub("MenuUtil")
ChatFrame_AddMessageEventFilter = function() end
ChatFrame_GetMessageEventFilters = function() return {} end
GetChannelList = function() return end
GetNumTalentTabs = function() return 3 end
GetTalentTabInfo = function(i) return ({"Waffen", "Furor", "Schutz"})[i], nil, 0 end
GetNumTalents = function() return 0 end
GetTalentInfo = function() return nil end
GetNumSkillLines = function() return 0 end
GetSkillLineInfo = function() return nil end
GetProfessions = function() return nil end
GetNumQuestLogEntries = function() return 0, 0 end
GetQuestLogTitle = function() return nil end
GetMoney = function() return 0 end
GetCoinTextureString = function(m) return tostring(m) end
GetSpellInfo = function(id) return "Zauber " .. tostring(id), nil, 136243 end
GetSpellTexture = function() return 136243 end
GetItemInfo = function() return nil end
GetItemInfoInstant = function() return nil end
GetItemQualityColor = function() return 1, 1, 1, "ffffffff" end
GetInventoryItemLink = function() return nil end
GetInventorySlotInfo = function() return 1 end
GetActionInfo = function() return nil end
GetMacroInfo = function() return nil end
GetNumMacros = function() return 0, 0 end
IsPlayerSpell = function() return false end
IsSpellKnown = function() return false end
GetBindingKey = function() return nil end
GetBindingText = function(k) return k end
SetOverrideBindingClick = function() end
ClearOverrideBindings = function() end
FlashClientIcon = function() end
DoEmote = function() end
SendChatMessage = function() end
GuildRoster = function() end
GetGameTime = function() return 18, 30 end
RequestTimePlayed = function() end
GetZoneText = function() return "Durotar" end
GetSubZoneText = function() return "" end
GetRealZoneText = function() return "Durotar" end
GetMinimapZoneText = function() return "Durotar" end
IsInInstance = function() return false, "none" end
GetInstanceInfo = function() return "Durotar", "none" end
GetDifficultyInfo = function() return "Normal" end
UnitPosition = function() return 0, 0, 0, 1 end
GetPlayerFacing = function() return 0 end
GetFramerate = function() return 60 end
collectgarbage = collectgarbage
debugprofilestop = function() return 0 end
ReloadUI = function() end
StaticPopup_Show = function() end
ToggleDropDownMenu = function() end
UIDropDownMenu_Initialize = function() end
UIDropDownMenu_SetWidth = function() end
UIDropDownMenu_SetText = function() end
UIDropDownMenu_CreateInfo = function() return {} end
UIDropDownMenu_AddButton = function() end
EasyMenu = function() end
CloseDropDownMenus = function() end
GameTooltip_SetDefaultAnchor = function() end
ShowUIPanel = function(f) if f then f:Show() end end
HideUIPanel = function(f) if f then f:Hide() end end
Settings = Stub("Settings")
InterfaceOptions_AddCategory = function() end
BNGetNumFriends = function() return 0, 0 end
GetFriendInfo = function() return nil end
C_Reputation = Stub("C_Reputation")
CalendarFrame = nil
ReportFrame = nil
ERR_FRIEND_ADDED_S = "%s ist jetzt Freund"
LOOT_ITEM = "%s erhält Beute: %s." LOOT_ITEM_SELF = "Ihr erhaltet Beute: %s." LOOT_ITEM_MULTIPLE = "%s erhält Beute: %sx%d."
LOOT_ITEM_SELF_MULTIPLE = "Ihr erhaltet Beute: %sx%d." LOOT_ITEM_PUSHED_SELF = "Ihr bekommt: %s." LOOT_ITEM_PUSHED_SELF_MULTIPLE = "Ihr bekommt: %sx%d."
LOOT_ITEM_BONUS_ROLL = "%s" LOOT_ITEM_BONUS_ROLL_SELF = "%s" LOOT_ITEM_PUSHED = "%s" LOOT_ITEM_PUSHED_MULTIPLE = "%s"
LOOT_ITEM_CREATED_SELF = "%s" LOOT_ITEM_CREATED_SELF_MULTIPLE = "%s"
CHAT_FRAMES = {"ChatFrame1"}
NORMAL_FONT_COLOR = CreateColor(1, .82, 0) HIGHLIGHT_FONT_COLOR = CreateColor(1, 1, 1) GRAY_FONT_COLOR = CreateColor(.5, .5, .5)
RED_FONT_COLOR = CreateColor(1, .1, .1) GREEN_FONT_COLOR = CreateColor(.1, 1, .1)
-- unbekannte Gross-Globals mit C_ oder Enum werden Platzhalter, sonst nil
setmetatable(_G, {__index = function(t, k)
    if type(k) == "string" and k:match("^C_") then local s = Stub(k) rawset(t, k, s) return s end
    return nil
end})

-- ===== Gespeicherte Daten (erfunden) =====
ProjectONEDB = {theme = {selected = "native", uiSounds = false}, soundEnabled = false, minimap = {hidden = true},
    seenVersion = "0.6.7-alpha", loginSummaryEnabled = false, toastEnabled = false,
    dungeons = {pass = {Testheld = {d = {wc = {first = 1763000000, last = 1763300000, runs = 2}, rfc = {first = 1762500000, runs = 1},
        dm = {first = 1763350000, runs = 1}}, t = {{id = "x", title = "Brachland-Treffen", time = 1763200000, count = 8}}}}}}
if mode == "book" then ProjectONEDB.theme.selected = "book" ProjectONEDB.theme.book = true end

-- ===== Addons laden =====
local errors = {}
local namespaces = {}
local function LoadAddon(name)
    local toc = io.open(root .. "/src/" .. name .. "/" .. name .. ".toc")
    if not toc then return end
    local ns = {}
    for line in toc:read("*a"):gmatch("[^\r\n]+") do
        if not line:match("^#") and line:match("%.lua%s*$") then
            local file = line:match("^%s*(.-)%s*$"):gsub("\\", "/")
            local chunk, err = loadfile(root .. "/src/" .. name .. "/" .. file)
            if chunk then
                local ok, e = pcall(chunk, name, ns)
                if not ok then errors[#errors+1] = name .. "/" .. file .. ": " .. tostring(e) end
            else errors[#errors+1] = err end
        end
    end
    toc:close()
    namespaces[name] = ns
    return ns
end
local function Fire(event, ...)
    for _, o in ipairs(all) do
        local f = o.scripts.OnEvent
        if f then local ok, e = pcall(f, o, event, ...) if not ok then errors[#errors+1] = event .. ": " .. tostring(e) end end
    end
end
for _, a in ipairs({"ONE_Core", "ONE_Guild", "ONE_Nav", "ONE_Classes", "ONE_Crafting", "ONE_Dungeons", "ONE_Chat"}) do
    LoadAddon(a)
    Fire("ADDON_LOADED", a)
end
Fire("PLAYER_LOGIN")
Fire("PLAYER_ENTERING_WORLD", true, false)
local ONE = _G.ProjectONE
-- Buch-Aussehen: falls die Auswahl anders gespeichert wird, direkt anschalten
if mode == "book" and ONE.Book and not ONE.Book:IsActive() then
    errors[#errors+1] = "Buch-Aussehen nicht aktiv - Schalter in render_ui.lua anpassen"
end

-- ===== Seiten oeffnen und aufzeichnen =====
local function Num(v) return math.floor(v * 10 + .5) / 10 end
local function Fine(v) return math.floor(v * 1000 + .5) / 1000 end
local function Color(c) if c then return {Fine(c[1] or 1), Fine(c[2] or 1), Fine(c[3] or 1), Fine(c[4] or 1)} end end
local function Visible(o)
    while o do
        if not o.shown then return false end
        if o.alpha == 0 then return false end
        o = o.parent
    end
    return true
end
local function Str(v) if type(v) == "string" then return v elseif type(v) == "table" and type(v.fontName) == "string" then return v.fontName end end
local function Dump(frame)
    for _, o in ipairs(all) do o._rect = nil end
    local list = {}
    local function Add(o, z, clip)
        local r = o:Rect()
        if not r or (r[3] - r[1]) <= 0 and o.kind ~= "FontString" then return end
        local fr = frame:Rect()
        local e = {k = o.kind, x = Num(r[1] - fr[1]), y = Num(fr[4] - r[4]), w = Num(r[3] - r[1]), h = Num(r[4] - r[2]), z = z}
        e.tpl = Str(o.tpl) e.nine = o.nine
        if o.part then e.part = o.part end
        if o.kind == "FontString" then
            if type(o.text) ~= "string" or o.text == "" then return end
            e.t = o.text e.fs = o:FontSize() e.f = Str(o.fontObj) e.c = Color(o.color) e.jh = o.justH
            if o.isButtonText then e.btn = true end
        elseif o.kind == "Texture" then
            if o.layer == "HIGHLIGHT" then return end
            if not o.tex and not o.colorTex and not o.atlas then return end
            e.tex = type(o.tex) == "string" and o.tex or (type(o.tex) == "number" and tostring(o.tex)) or nil e.atlas = Str(o.atlas)
            e.col = Color(o.colorTex) e.v = Color(o.vertex) if o.grad then e.grad = {o.grad[1], Color(o.grad[2]), Color(o.grad[3])} end e.a = o.alpha ~= 1 and o.alpha or nil
            e.l = LAYERS[o.layer or "ARTWORK"] or 3
            if o.coords then local c = {} for i, v in ipairs(o.coords) do if type(v) == "number" then c[i] = Fine(v) end end e.tc = c end
        else
            if type(o.text) == "string" and o.text ~= "" then e.t = o.text e.f = Str(o.fontObj) end
            if o.selectedTab ~= nil then e.sel = o.selectedTab end
            if o.msgs and #o.msgs > 0 then
                local lh, y = 16, r[2]
                local fr2 = frame:Rect()
                for i = #o.msgs, math.max(1, #o.msgs - 20), -1 do
                    y = y + lh
                    if y > r[4] then break end
                    list[#list + 1] = {k = "FontString", x = Num(r[1] - fr2[1]), y = Num(fr2[4] - y), w = Num(r[3] - r[1]), h = lh,
                        z = z + 1, t = o.msgs[i].t, fs = 13, f = "ChatFontNormal", c = Color(o.msgs[i].c)}
                end
            end
            if o.checked ~= nil then e.chk = o.checked end
            if o.disabled then e.dis = true end
            if o.a ~= nil then end
        end
        list[#list+1] = e
    end
    local z = 0
    local function Walk(o)
        if not Visible(o) then return end
        z = z + 1
        if o.kind ~= "Texture" and o.kind ~= "FontString" then Add(o, z) end
        local regs = {}
        for _, r in ipairs(o.regions) do regs[#regs+1] = r end
        table.sort(regs, function(a, b)
            local la, lb = LAYERS[a.layer or "ARTWORK"] or 3, LAYERS[b.layer or "ARTWORK"] or 3
            if la ~= lb then return la < lb end
            if (a.sub or 0) ~= (b.sub or 0) then return (a.sub or 0) < (b.sub or 0) end
            return a.id < b.id
        end)
        for _, r in ipairs(regs) do if Visible(r) then z = z + 1 Add(r, z) end end
        local kids = {}
        for _, c in ipairs(o.children) do kids[#kids+1] = c end
        table.sort(kids, function(a, b)
            local la, lb = a:GetFrameLevel(), b:GetFrameLevel()
            if la ~= lb then return la < lb end
            return a.id < b.id
        end)
        for _, c in ipairs(kids) do Walk(c) end
    end
    Walk(frame)
    return list
end
local function Json(v, ind)
    local t = type(v)
    if t == "table" then
        if #v > 0 or next(v) == nil then
            local p = {} for _, x in ipairs(v) do p[#p+1] = Json(x) end return "[" .. table.concat(p, ",") .. "]"
        end
        local p, keys = {}, {}
        for k in pairs(v) do keys[#keys+1] = tostring(k) end
        table.sort(keys)
        for _, k in ipairs(keys) do p[#p+1] = string.format("%q", k) .. ":" .. Json(v[k]) end
        return "{" .. table.concat(p, ",") .. "}"
    elseif t == "string" then
        return '"' .. v:gsub('[%c"\\]', function(c)
            if c == "\n" then return "\\n" elseif c == '"' then return '\\"' elseif c == "\\" then return "\\\\" end
            return string.format("\\u%04x", c:byte()) end) .. '"'
    elseif t == "number" then return tostring(v)
    elseif t == "boolean" then return tostring(v) end
    return "null"
end

local pages = {}
local wanted = {}
if only then for p in only:gmatch("[^,]+") do wanted[#wanted+1] = p end end
if #wanted == 0 then
    for _, id in ipairs(ONE.UI.tabIds or {}) do wanted[#wanted+1] = id end
    for id in pairs(ONE.UI.views) do wanted[#wanted+1] = id end
end
local function DumpChat()
    local ns = namespaces.ONE_Chat
    local C, U = ns and ns.Chat, ns and ns.UI
    if not (C and U) then errors[#errors + 1] = "Chat fehlt" return end
    local samples = {
        {"CHAT_MSG_GUILD", "Wer kommt heute mit in die Todesminen?", "Brakka-Testrealm"},
        {"CHAT_MSG_GUILD", "Ich! Bin in 10 min am Eingang.", "Zul'tik-Testrealm"},
        {"CHAT_MSG_WHISPER", "Hast du noch Leinenstoff?", "Morgra-Testrealm"},
        {"CHAT_MSG_PARTY", "Pull in 3", "Tharok-Testrealm"},
        {"CHAT_MSG_CHANNEL", "LFM Höhlen des Wehklagens, Heiler gesucht", "Nyx-Testrealm", "", "2. Handel", "", 0, 2, "Handel"},
        {"CHAT_MSG_GUILD", "Gz zu Stufe 24!", "Testheld-Testrealm"},
    }
    for i, m in ipairs(samples) do
        pcall(C.OnEvent, C, m[1], m[2], m[3], "", m[5] or "", "", "", 0, m[8] or 0, m[9] or "", 0, i, "Player-1-000" .. i)
    end
    local ok, e = pcall(U.Show, U, "all")
    if not ok then errors[#errors + 1] = "Chat zeigen: " .. tostring(e) end
    local f = U.frame
    if not f then return end
    f:ClearAllPoints() f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    local okD, list = pcall(Dump, f)
    if okD then pages[#pages + 1] = {id = "chat", w = f.w, h = f.h, items = list}
    else errors[#errors + 1] = "Dump chat: " .. tostring(list) end
end
-- Kleine Fenster der 0.7.x mit Beispieldaten ("fenster")
local function DumpWindows()
    local function Add(id, f)
        if not f then errors[#errors + 1] = "Fenster " .. id .. " fehlt" return end
        f:ClearAllPoints() f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        f:Show()
        local okD, list = pcall(Dump, f)
        if okD then pages[#pages + 1] = {id = id, w = f.w, h = f.h, items = list}
        else errors[#errors + 1] = "Dump " .. id .. ": " .. tostring(list) end
    end
    local function Try(id, fn)
        local ok, e = pcall(fn)
        if not ok then errors[#errors + 1] = id .. ": " .. tostring(e) end
    end
    local guild, classes, dg = namespaces.ONE_Guild, namespaces.ONE_Classes, namespaces.ONE_Dungeons
    Try("hilferuf", function()
        guild.Help:Show({name = "Bob", full = "Bob", level = 19, dist = 420, text = "Elite am Wegkreuz, schnell!"})
        Add("hilferuf", guild.Help.frame)
    end)
    Try("rueckblick", function()
        dg.Recap:Show({name = "Die Todesminen", key = "dm", secs = 2520, record = true,
            group = {Bob = true, Gildi = true, Tester = true, Thrall = true, Rehgar = true},
            bosses = {"Rhahk'Zor", "Sneed", "Gilnid", "Edwin VanCleef"}, deaths = {Bob = 2, Tester = 1},
            loot = {{who = "Bob", link = "|cff0070dd|Hitem:2::|h[Schwert des Kapitäns]|h|r"}, {who = "Gildi", link = "|cff1eff00|Hitem:3::|h[Grüner Umhang]|h|r"}}})
        Add("rueckblick", dg.Recap.frame)
    end)
    Try("buffen", function()
        local N = classes.Nearby
        local offer = {name = "Machtwort: Seelenstärke", icon = 135987, ranks = {}, also = {}}
        local offer2 = {name = "Göttlicher Willen", icon = 135898, ranks = {}, also = {}}
        N.MyOffers = function() return {offer, offer2} end
        N.Scan = function() return {
            {name = "Bob", unit = "party1", level = 21, classFile = "MAGE", tag = "group", missing = {{offer = offer, spell = 1}, {offer = offer2, spell = 2}}},
            {name = "Gildi", unit = "nameplate1", level = 18, classFile = "WARRIOR", tag = "guild", missing = {{offer = offer, spell = 1}}},
            {name = "Wanderer", level = 40, classFile = "ROGUE", missing = {{offer = offer, spell = 1}}},
        } end
        N:Update()
        Add("buffen", N.frame)
    end)
end

local frame = ONE.UI.frame
frame:ClearAllPoints() frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:Show()
for _, id in ipairs(wanted) do
  local mod, sub = id:match("^(%w+):(%w+)$")
  if mod and namespaces["ONE_" .. mod:sub(1, 1):upper() .. mod:sub(2)] then
      local ns = namespaces["ONE_" .. mod:sub(1, 1):upper() .. mod:sub(2)]
      if ns.Page then ns.Page.view = sub end
      id = mod
  end
  if id == "fenster" then DumpWindows() elseif id == "chat" then DumpChat() else
    local ok, e = pcall(function() ONE.UI:Navigate(id) ONE.UI:Refresh() end)
    if not ok then errors[#errors+1] = "Seite " .. id .. ": " .. tostring(e) end
    local okD, list = pcall(Dump, frame)
    if okD then pages[#pages+1] = {id = id, w = frame.w, h = frame.h, items = list}
    else errors[#errors+1] = "Dump " .. id .. ": " .. tostring(list) end
  end
end
local f = assert(io.open(out, "w"))
f:write(Json({mode = mode, pages = pages, errors = errors}))
f:close()
print(string.format("%d Seiten, %d Fehler -> %s", #pages, #errors, out))
for i, e in ipairs(errors) do if i <= 25 then print("  " .. e) end end
