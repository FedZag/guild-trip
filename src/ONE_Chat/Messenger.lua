-- Guild Trip Chat im Messenger-Stil (Nutzer 21.11.2026, OK zu Vorschau 2 `docs/vorschau_chat_messenger.html`:
-- "ja perfekt. für unser theme gebaut").
-- Links die Liste aller Gespraeche (Kreis mit Anfangsbuchstabe, letzte Nachricht, Uhrzeit, Zaehler),
-- angeheftete oben, Suche ueber alle Gespraeche. Rechts das Gespraech als Sprechblasen: eigene rechts in der
-- Leuchtfarbe des Glases, andere links mit Namen in Klassenfarbe, Systemzeilen klein in der Mitte,
-- Trennzeilen "Heute", gelbe Linie "neue Nachrichten", Haken beim Fluestern (zugestellt), Emojis.
-- Schmales Fenster (unter 430): wie am Handy – erst Liste, dann Gespraech mit Zurueck-Pfeil.
-- Der alte Stil (ChatUI.lua) bleibt waehlbar (Einstellungen › Stil). Messenger ersetzt dafuer die
-- Fenster-Funktionen von chat.UI (Install), alles andere (Senden, Reiter, Verlauf) bleibt in Chat.lua.
local _, chat = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local Chat, UI = chat.Chat, chat.UI
local M = {bubbles = {}, convRows = {}, newFrom = {}, scroll = 0, listScroll = 0, page = "list"}
chat.Messenger = M

local TEX = "Interface\\AddOns\\ONE_Chat\\Textures\\"
local TITLE_H, LIST_W, HEAD_H, FOOT_H, ROW_H, LABEL_H = 30, 196, 38, 36, 40, 16
local NARROW_W = 430
M.NARROW_W = NARROW_W
local GAP, GROUP_GAP = 2, 6
-- Sprechblasen: Rundung und Zipfel (Nutzer 21.11.2026: "mehr wie Sprechblasen"; Bild aus scripts/build_bubble_tail.py)
local BUBBLE_R = 10
local TAIL_TEX = "Interface\\AddOns\\ONE_Chat\\Textures\\BubbleTail"
local TAIL_RING_TEX = "Interface\\AddOns\\ONE_Chat\\Textures\\BubbleTailRing"

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end
local function Text(parent, font)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    fs:SetJustifyH("LEFT")
    return fs
end
local function Me() return type(UnitName) == "function" and Call(UnitName, "player") or nil end
local function Short(n) return Chat.Short(n) end
local function Hex(c) return string.format("|cff%02x%02x%02x", math.floor((c[1] or 1) * 255 + .5), math.floor((c[2] or 1) * 255 + .5), math.floor((c[3] or 1) * 255 + .5)) end
local function ClassRGB(classFile)
    local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if c then return c.r, c.g, c.b end
    return .7, .7, .75
end
local function Tip(owner, fn)
    owner:SetScript("OnEnter", function(btn)
        if not GameTooltip then return end
        GameTooltip:SetOwner(btn, "ANCHOR_TOP")
        for i, l in ipairs(fn() or {}) do
            if i == 1 then GameTooltip:SetText(l[1], l[2] or 1, l[3] or 1, l[4] or 1)
            else GameTooltip:AddLine(l[1], l[2] or .8, l[3] or .8, l[4] or .8, true) end
        end
        GameTooltip:Show()
    end)
    owner:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

-- ===== Glas-Kreise mit Bild (Liste, Kopfzeile, Klasse in der Blase; Nutzer 21.11.2026) =====
local ICON = "Interface\\Icons\\"
local CLASS_ATLAS = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
-- je Art mehrere Kandidaten: der erste, den der Client kennt, wird genommen
M.KIND_ICONS = {
    all = {"INV_Misc_Book_09"},
    guild = {"INV_Shirt_GuildTabard_01"},
    officer = {"INV_Shirt_GuildTabard_01"},
    group = {"Spell_Holy_PrayerOfFortitude", "Spell_Holy_WordFortitude"},
    say = {"Ability_Warrior_RallyingCry", "Ability_Warrior_BattleShout"},
    yell = {"Ability_Warrior_BattleShout"},
    emote = {"Spell_Holy_MindVision", "INV_Misc_Note_01"},
    trade = {"INV_Misc_Coin_01", "INV_Misc_Coin_02"},
    general = {"INV_Misc_Map_01"},
    lfg = {"INV_Misc_Spyglass_02"},
    channel = {"INV_Misc_Note_01"},
    system = {"INV_Misc_Gear_01", "Trade_Engineering"},
    -- Battle.net-Freund (Fluestern aus dem Launcher)
    bnet = {"INV_Misc_Note_02", "INV_Letter_15", "INV_Misc_Note_01"},
}
-- helle Symbole etwas abdunkeln (Spieltest 21.11.2026: Gilde/Gruppe "zu grell")
M.ICON_DIM = {guild = .66, officer = .66, group = .70}
M.iconDim = {}
-- schwarzer Grund hinter dem Symbol, Symbol etwas kleiner (Spieltest 21.11.2026: Gruppe)
M.ICON_BLACK = {group = true}
M.iconBlack = {}
local iconCache = {}
function M.KindIcon(key)
    if not key then return nil end
    if iconCache[key] ~= nil then return iconCache[key] or nil end
    local found = false
    for _, name in ipairs(M.KIND_ICONS[key] or {}) do
        local path = ICON .. name
        local known = type(GetFileIDFromPath) ~= "function" or Call(GetFileIDFromPath, path)
        if known then found = path break end
    end
    iconCache[key] = found
    if found then M.iconDim[found] = M.ICON_DIM[key] M.iconBlack[found] = M.ICON_BLACK[key] end
    return found or nil
end
function M.ClassCoords(classFile)
    local c = classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
    if c then return c[1], c[2], c[3], c[4] end
end
function M.ClassOfGuid(guid)
    if not guid or guid == "" or type(GetPlayerInfoByGUID) ~= "function" then return nil end
    local _, classFile = Call(GetPlayerInfoByGUID, guid)
    return classFile
end
-- legt um eine runde Textur (av) Bild, Ring und Glanz an
function M.GlassAvatar(parent, av, inset)
    local G = ONE.Glass
    local a = {av = av, parent = parent}
    a.icon = parent:CreateTexture(nil, "ARTWORK", nil, 1)
    a.inset = inset or 2
    a.icon:SetPoint("TOPLEFT", av, "TOPLEFT", a.inset, -a.inset)
    a.icon:SetPoint("BOTTOMRIGHT", av, "BOTTOMRIGHT", -a.inset, a.inset)
    a.icon:Hide()
    if parent.CreateMaskTexture and a.icon.AddMaskTexture and G then
        local ok, m = pcall(parent.CreateMaskTexture, parent)
        if ok and m then
            m:SetTexture(G.tex.circle, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            m:SetAllPoints(a.icon)
            pcall(a.icon.AddMaskTexture, a.icon, m)
        end
    end
    a.shine = parent:CreateTexture(nil, "OVERLAY", nil, 1)
    a.shine:SetAllPoints(av)
    if G then a.shine:SetTexture(G.tex.orb) end
    a.ring = parent:CreateTexture(nil, "OVERLAY", nil, 2)
    a.ring:SetAllPoints(av)
    if G then a.ring:SetTexture(G.tex.ring) end
    return a
end
-- icon = Pfad (+ Ausschnitt) oder nil (dann Buchstabe im farbigen Glas)
function M.PaintAvatar(a, p, cr, cg, cb, icon, coords, letter, letterText)
    if not a then return end
    local t = p.tint
    if icon then
        a.icon:SetTexture(icon)
        if coords then a.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        else a.icon:SetTexCoord(.08, .92, .08, .92) end
        local d = M.iconDim[icon] or 1
        a.icon:SetVertexColor(d, d, d, .92)
        a.icon:Show()
        local black = M.iconBlack[icon]
        local ins = black and a.inset + 2 or a.inset
        a.icon:ClearAllPoints()
        a.icon:SetPoint("TOPLEFT", a.av, "TOPLEFT", ins, -ins)
        a.icon:SetPoint("BOTTOMRIGHT", a.av, "BOTTOMRIGHT", -ins, ins)
        if black then a.av:SetVertexColor(0, 0, 0, .95)
        else a.av:SetVertexColor(t[1] + (cr - t[1]) * .25, t[2] + (cg - t[2]) * .25, t[3] + (cb - t[3]) * .25, .55) end
        if letter then letter:Hide() end
    else
        a.icon:Hide()
        a.av:SetVertexColor(cr * .55, cg * .55, cb * .55, .55)
        if letter then
            letter:SetText("|cffffffff" .. (letterText or "") .. "|r")
            letter:Show()
        end
    end
    a.av:Show()
    a.ring:SetVertexColor(cr, cg, cb, .65)
    a.ring:Show()
    a.shine:SetVertexColor(1, 1, 1, .30)
    a.shine:Show()
end
function M.HideAvatar(a)
    if not a then return end
    a.av:Hide() a.icon:Hide() a.ring:Hide() a.shine:Hide()
end

-- ===== Farben (Glas des Chats) =====
function M:Palette()
    local G = ONE.Glass
    if G and G.Palette then return G:Palette(Chat:GlassStore()) end
    return {tint = {.04, .05, .07}, glow = {1, .82, 0}, title = {1, .82, 0}, alpha = .8, onGlow = {.07, .06, .03}}
end
-- Farbe {r, g, b} aus den Einstellungen pruefen (sonst nil)
function M.ValidColor(c)
    if type(c) ~= "table" then return nil end
    for i = 1, 3 do if type(c[i]) ~= "number" or c[i] < 0 or c[i] > 1 then return nil end end
    return c
end
-- Staerke der Blasenfarbe: 1 = normal (Spieltest 21.11.), kleiner dezenter, groesser kraeftiger
M.STRENGTHS = {.5, 1, 1.8, 2.6}
function M.BubbleStrength()
    local v = Chat:Settings().bubbleStrength
    for _, x in ipairs(M.STRENGTHS) do if v == x then return v end end
    return 1
end
-- Blasen: eigene in der Leuchtfarbe (gedaempft), andere hell auf dem Glas
-- Sprechblase aus Glas (Nutzer 21.11.2026): durchscheinende Flaeche, heller Rand, Glanz oben.
-- Andere leicht in der Farbe ihrer Art (Gilde gruen, Gruppe blau …), eigene in der Leuchtfarbe.
-- Liefert Flaeche (r, g, b, a) und Rand (r, g, b, a).
function M.BubbleColor(p, out, failed, kind)
    -- Spieltest 21.11.2026: "viel zu hell, durchscheinender, nur ein leichter Akzent", dann "noch etwas weniger"
    if failed then return .55, .14, .14, .45, 1, .45, .45, .32 end
    -- Einstellungen (22.11.2026): eigene Blasenfarbe statt Leuchtfarbe, Staerke der Farbe
    local s = Chat:Settings()
    local f = M.BubbleStrength()
    local t, g = p.tint, M.ValidColor(s.ownBubble) or p.glow
    if out then
        local k = math.min(.8, .20 * f)
        return t[1] + (g[1] - t[1]) * k, t[2] + (g[2] - t[2]) * k, t[3] + (g[3] - t[3]) * k, math.min(.85, .40 + (f - 1) * .1),
            g[1], g[2], g[3], math.min(.8, .22 * f)
    end
    local r, gg, b = t[1] + (1 - t[1]) * .09, t[2] + (1 - t[2]) * .09, t[3] + (1 - t[3]) * .09
    local c = kind and s.bubbleColors ~= false and Chat.kindByKey[kind] and Chat.kindByKey[kind].color
    if type(c) == "table" and c[1] then
        local k = math.min(.6, .035 * f * f)
        r, gg, b = r + (c[1] - r) * k, gg + (c[2] - gg) * k, b + (c[3] - b) * k
        return r, gg, b, .34, c[1], c[2], c[3], math.min(.7, .12 * f)
    end
    return r, gg, b, .34, 1, 1, 1, .09
end

-- ===== Gespraeche =====
-- Alle Ansichten: Reiter + Fluestergespraeche, je {view, title, whisper, tab, last, unread, muted, pinned}
function M.ViewTitle(view)
    if type(view) == "string" and view:sub(1, 2) == "w:" then return view:sub(3) end
    local tab = Chat:Tab(view)
    return tab and T(tab.label) or "?"
end
function M.LastEntry(view)
    local buf = Chat.buffers[view]
    return buf and buf[#buf] or nil
end
function M.IsPinned(view)
    for i, v in ipairs(Chat:Settings().pinned) do if v == view then return i end end
end
function M.SetPinned(view, on)
    local list = Chat:Settings().pinned
    for i = #list, 1, -1 do if list[i] == view then table.remove(list, i) end end
    if on then list[#list + 1] = view end
end
function M.IsMuted(view) return Chat:Settings().muted[view] == true end
function M.SetMuted(view, on) Chat:Settings().muted[view] = on and true or nil end

function M.Conversations()
    local out = {}
    for _, t in ipairs(Chat:Tabs()) do
        local last = M.LastEntry(t.id)
        out[#out + 1] = {view = t.id, title = T(t.label), tab = t, last = last and last.time or 0}
    end
    for _, w in ipairs(Chat.whispers) do
        local view = Chat.WhisperView(w.name)
        local last = M.LastEntry(view)
        out[#out + 1] = {view = view, title = w.name, whisper = w.name, last = math.max(last and last.time or 0, w.last or 0)}
    end
    for i, c in ipairs(out) do
        c.order = i
        c.unread = Chat.unread[c.view] or 0
        c.muted = M.IsMuted(c.view)
        c.pinned = M.IsPinned(c.view)
    end
    -- angeheftete in ihrer Reihenfolge, dann nach letzter Nachricht (neueste oben)
    table.sort(out, function(a, b)
        if a.pinned or b.pinned then
            if a.pinned and b.pinned then return a.pinned < b.pinned end
            return a.pinned ~= nil
        end
        if a.last ~= b.last then return a.last > b.last end
        return a.order < b.order
    end)
    return out
end

-- Farbe des Kreises: Fluestern = Klassenfarbe, sonst Farbe der Art
function M.AvatarColor(c)
    if c.whisper then
        local info = M.PersonInfo(c.whisper)
        if info and info.classFile then return ClassRGB(info.classFile) end
        local last = M.LastEntry(c.view)
        if last and last.guid and type(GetPlayerInfoByGUID) == "function" then
            local _, classFile = Call(GetPlayerInfoByGUID, last.guid)
            if classFile then return ClassRGB(classFile) end
        end
        if Chat.IsBN(c.whisper) then return .30, .70, 1 end -- Battle.net-Blau
        return .75, .55, .85
    end
    local tab = c.tab
    local key = tab and (Chat.kindByKey[tab.id] and tab.id or tab.send)
    if tab and tab.id == "system" then return 1, 1, .45 end
    if tab and tab.id == "all" then return .7, .7, .75 end
    if key == "say" then key = "emote" end
    local kind = key and Chat.kindByKey[key]
    local col = kind and kind.color or {.65, .65, .7}
    return col[1], col[2], col[3]
end

-- Bild im Kreis: Fluestern = Klassen-Symbol, sonst Symbol der Art (nil = Buchstabe)
function M.AvatarIcon(c)
    if c.whisper then
        local info = M.PersonInfo(c.whisper)
        local classFile = info and info.classFile
        if not classFile then
            local last = M.LastEntry(c.view)
            classFile = last and M.ClassOfGuid(last.guid)
        end
        local l, r, t, b = M.ClassCoords(classFile)
        if l then return CLASS_ATLAS, {l, r, t, b} end
        if Chat.IsBN(c.whisper) then return M.KindIcon("bnet") end
        return nil
    end
    local tab = c.tab
    if tab and (tab.id == "all" or tab.id == "system") then return M.KindIcon(tab.id) end
    local key = tab and (Chat.kindByKey[tab.id] and tab.id or tab.send)
    return M.KindIcon(key)
end

-- Battle.net-Freund: "Battle.net · Charakter · Ort" bzw. "Battle.net · offline"
function M.BNLine(info)
    if not info.online then return "Battle.net · " .. T("offline") end
    local parts = {"Battle.net"}
    if info.character and info.character ~= "" then parts[#parts + 1] = info.character end
    if info.zone and info.zone ~= "" then parts[#parts + 1] = info.zone end
    return table.concat(parts, " · ")
end
-- Gilde/Freunde: Klasse, Stufe, Ort, online, zuletzt online
function M.PersonInfo(name)
    local short = Short(name)
    if Chat.IsBN(short) then
        local b = Chat.BNInfo(Chat.BNFind(short))
        if not b then return nil end
        return {bn = true, online = b.online, zone = b.zone, character = b.character, level = b.level}
    end
    if type(GetNumGuildMembers) == "function" and type(GetGuildRosterInfo) == "function" then
        for i = 1, (Call(GetNumGuildMembers) or 0) do
            local full, _, _, level, class, zone, _, _, online, _, classFile = Call(GetGuildRosterInfo, i)
            if full and Short(full) == short then
                local info = {level = level, class = class, zone = zone, online = online and true or false, classFile = classFile}
                if not info.online and type(GetGuildRosterLastOnline) == "function" then
                    local y, mo, d, h = Call(GetGuildRosterLastOnline, i)
                    info.lastOnline = {y or 0, mo or 0, d or 0, h or 0}
                end
                return info
            end
        end
    end
    if C_FriendList and type(C_FriendList.GetFriendInfo) == "function" then
        local f = Call(C_FriendList.GetFriendInfo, short)
        if type(f) == "table" then
            return {level = f.level, class = f.className, zone = f.area, online = f.connected and true or false}
        end
    end
end
function M.OfflineText(info)
    local lo = info and info.lastOnline
    if not lo then return T("offline") end
    if lo[1] > 0 then return T("offline seit %d Jahren", lo[1]) end
    if lo[2] > 0 then return lo[2] == 1 and T("offline seit 1 Monat") or T("offline seit %d Monaten", lo[2]) end
    if lo[3] > 0 then return lo[3] == 1 and T("offline seit 1 Tag") or T("offline seit %d Tagen", lo[3]) end
    if lo[4] > 0 then return lo[4] == 1 and T("offline seit 1 Std.") or T("offline seit %d Std.", lo[4]) end
    return T("gerade offline")
end

-- Zeit in der Liste: heute Uhrzeit, sonst "Gestern" bzw. Datum
function M.ListTime(t)
    if not t or t == 0 or type(date) ~= "function" then return "" end
    local now = (type(time) == "function" and time()) or t
    if date("%Y%m%d", t) == date("%Y%m%d", now) then return date("%H:%M", t) end
    if date("%Y%m%d", t) == date("%Y%m%d", now - 86400) then return T("Gestern") end
    return date("%d.%m.", t)
end
function M.DayLabel(t)
    if type(date) ~= "function" then return "" end
    local now = (type(time) == "function" and time()) or t
    if date("%Y%m%d", t) == date("%Y%m%d", now) then return T("Heute") end
    if date("%Y%m%d", t) == date("%Y%m%d", now - 86400) then return T("Gestern") end
    return date("%d.%m.%Y", t)
end

-- Text fuer die Anzeige: Emojis/WoW-Zeichen als Bilder, eigener Name gold
function M.Show(text, size)
    local s = Chat:Settings()
    text = tostring(text or "")
    local me = Me()
    if me and me ~= "" and text:find(me, 1, true) then
        text = text:gsub(me:gsub("%p", "%%%0"), "|cffffd100" .. me .. "|r")
    end
    if s.emojiImages ~= false and chat.Emoji then text = chat.Emoji.Render(text, size, {noAscii = s.asciiSmileys == false}) end
    return text
end
-- Vorschau in der Liste: eine Zeile ohne Links
function M.Preview(entry)
    if not entry then return "" end
    local text = tostring(entry.text or ""):gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local who = ""
    if entry.kind ~= "system" then
        if entry.inform or Short(entry.author) == Me() then who = T("Du") .. ": "
        elseif entry.author and entry.author ~= "" then who = Short(entry.author) .. ": " end
    end
    return M.Show(who .. text, 12)
end

-- ===== Verlauf eines Gespraechs als Eintraege fuer die Blasen =====
-- {type = "day"/"new"/"sys"/"bubble", entry, out, cont, name}
function M.Items(view, newFrom)
    local items = {}
    local buf = Chat:Buffer(view)
    local whisper = type(view) == "string" and view:sub(1, 2) == "w:"
    local me = Me()
    local lastDay, prev
    for i, e in ipairs(buf) do
        local day = type(date) == "function" and date("%Y%m%d", e.time or 0) or ""
        if day ~= lastDay then
            items[#items + 1] = {type = "day", text = M.DayLabel(e.time or 0)}
            lastDay, prev = day, nil
        end
        if newFrom and i == newFrom then
            items[#items + 1] = {type = "new", count = #buf - i + 1}
            prev = nil
        end
        if e.kind == "system" or e.event == "CHAT_MSG_TEXT_EMOTE" then
            items[#items + 1] = {type = "sys", entry = e}
            prev = nil
        elseif e.kind == "emote" then
            items[#items + 1] = {type = "sys", entry = e, emote = true}
            prev = nil
        else
            local out = e.inform or (me and Short(e.author) == me) or false
            local cont = prev and prev.out == out and Short(prev.entry.author) == Short(e.author)
                and (e.time or 0) - (prev.entry.time or 0) < 300 or false
            local it = {type = "bubble", entry = e, out = out, cont = cont,
                name = not out and not whisper and not cont}
            -- im Reiter "Alle": Art vor den Namen
            if view == "all" and not out and not cont then it.kind = e.kind end
            items[#items + 1] = it
            prev = it
        end
    end
    return items
end

-- ===== Aufbau =====
function M:Install()
    UI.style = "messenger"
    UI.flat, UI.glass, UI.modern = false, true, false
    UI.Build = function() return M:Build() end
    UI.Show = function(_, view) return M:ShowView(view) end
    UI.Hide = function() return M:Hide() end
    UI.Toggle = function() if M.frame and M.frame:IsShown() then M:Hide() else M:ShowView() end end
    UI.Refresh = function() return M:Refresh() end
    UI.Render = function() return M:Render() end
    UI.OnMessage = function(_, entry, views, update) return M:OnMessage(entry, views, update) end
    UI.ApplyLook = function() return M:ApplyLook() end
    UI.SetFontSize = function(_, size) Chat:Settings().fontSize = size M:Render() end
    UI.LayoutRows = function() return M:Refresh() end
    UI.RefreshHead = function() return M:RefreshHead() end
    UI.AskWhisper = function() return M:AskWhisper() end
    UI.WakeUp = function() if M.frame then M.frame.__fadeWait = 0 end end
end

function M:Build()
    if self.frame then return self.frame end
    local G = ONE.Glass
    local before = G and G.surfaces and #G.surfaces or 0
    if G then G.forceLook = "glass" end
    local ok, err = pcall(self.BuildFrame, self)
    if G then G.forceLook = nil end
    -- Glas-Teile des Chats: eigene Farben, Deckkraft ueber "Hintergrund" (wie ChatUI)
    self.surfaces = {}
    if G and G.surfaces then
        for i = before + 1, #G.surfaces do
            local sf = G.surfaces[i]
            sf.store = function() return Chat:GlassStore() end
            if sf.kind == "window" then sf.scale = function() return tonumber(Chat:Settings().opacity) or 1 end end
            self.surfaces[#self.surfaces + 1] = sf
            if G.Paint then G:Paint(sf) end
        end
        if not self.glassHooked and G.OnChange then
            self.glassHooked = true
            G:OnChange(function() M:Paint() M:Refresh() M:Render() end)
        end
    end
    if not ok then error(err, 0) end
    UI.frame = self.frame
    if UI.HookInsertLink then UI:HookInsertLink() end
    self:Paint()
    return self.frame
end

function M:BuildFrame()
    local s = Chat:Settings()
    local f = CreateFrame("Frame", "GuildTripChatWindow", UIParent)
    self.frame = f
    f:SetSize(s.width or 640, s.height or 420)
    if s.point then f:SetPoint(s.point[1], UIParent, s.point[2], s.point[3], s.point[4]) else f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 40, 160) end
    f:SetFrameStrata("MEDIUM")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:SetResizable(true)
    if f.SetResizeBounds then f:SetResizeBounds(UI.MIN_W or 280, 240, 1200, 900) end
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetClampedToScreen(true)
    f:SetScript("OnDragStart", function(fr) if not Chat:Settings().locked then fr:StartMoving() end end)
    f:SetScript("OnDragStop", function(fr) fr:StopMovingOrSizing() UI:SaveGeometry() end)
    if ONE.Glass and ONE.Glass.Surface then
        ONE.Glass:Surface(f, "window")
    else
        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(f)
        bg:SetColorTexture(.04, .05, .07, .9)
    end
    if ONE.Widgets and ONE.Widgets.ResizeHandles then
        self.resize = ONE.Widgets:ResizeHandles(f, {size = 6, onStop = function() UI:SaveGeometry() M:Refresh() M:Render() end})
    end

    -- Titelleiste: Name, Beute, Zahnrad (Einstellungen im Chat), Schliessen
    local title = Text(f, "GameFontNormal")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -9)
    title:SetText(T("Guild Trip Chat"))
    self.title = title
    ONE.Widgets:CloseButton(f, "TOPRIGHT", -4, -2, function() M:Hide() end)
    local gear = CreateFrame("Button", nil, f)
    gear:SetSize(18, 18)
    gear:SetPoint("TOPRIGHT", f, "TOPRIGHT", -36, -6)
    local gt = gear:CreateTexture(nil, "ARTWORK")
    gt:SetAllPoints(gear)
    gt:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    gear:SetScript("OnClick", function() UI:OpenSettings() end)
    Tip(gear, function() return {{T("Chat-Einstellungen")}} end)
    self.gear = gear
    local loot = CreateFrame("Button", nil, f)
    loot:SetSize(18, 18)
    loot:SetPoint("RIGHT", gear, "LEFT", -6, 0)
    local lt = loot:CreateTexture(nil, "ARTWORK")
    lt:SetAllPoints(loot)
    lt:SetTexture("Interface\\Icons\\INV_Misc_Bag_10")
    loot:SetScript("OnClick", function() if chat.Loot then chat.Loot:Toggle() end end)
    Tip(loot, function() return {{T("Beute-Fenster")}, {T("Wer hat welchen Gegenstand bekommen")}} end)

    self:BuildList(f)
    self:BuildMain(f)
    -- Erst jetzt: WoW meldet Groessen-Aenderungen schon waehrend des Aufbaus (Spieltest 21.11.2026,
    -- Fehler "main nil" in Layout beim Anlegen eines Knopfs)
    f:SetScript("OnSizeChanged", function() M:Layout() end)
    self:ApplyLook()
    f:Hide()
    UI.current = UI.current or "guild"
    return f
end

-- ===== Liste links =====
function M:BuildList(f)
    local list = CreateFrame("Frame", nil, f)
    list:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -TITLE_H)
    list:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 8)
    list:SetWidth(LIST_W)
    if ONE.Glass and ONE.Glass.Surface then ONE.Glass:Surface(list, "column") end
    if list.SetClipsChildren then list:SetClipsChildren(true) end
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
        M.listScroll = math.max(0, (M.listScroll or 0) - delta * 2)
        M:LayoutList()
    end)
    self.list = list
    -- Suche + "+" (neues Gespraech)
    local ok, search = pcall(CreateFrame, "EditBox", nil, list, "InputBoxTemplate")
    if not ok or not search then search = CreateFrame("EditBox", nil, list) end
    for _, key in ipairs({"Left", "Right", "Middle"}) do
        local t = rawget(search, key)
        if type(t) == "table" and t.Hide then t:Hide() end
    end
    search:SetPoint("TOPLEFT", list, "TOPLEFT", 8, -6)
    search:SetPoint("TOPRIGHT", list, "TOPRIGHT", -34, -6)
    search:SetHeight(20)
    search:SetAutoFocus(false)
    if search.SetTextInsets then search:SetTextInsets(8, 8, 0, 0) end
    if search.SetFontObject and GameFontHighlightSmall then search:SetFontObject(GameFontHighlightSmall) end
    if ONE.Glass and ONE.Glass.Surface then ONE.Glass:Surface(search, "card") end
    local ph = Text(list, "GameFontDisableSmall")
    ph:SetPoint("LEFT", search, "LEFT", 9, 0)
    ph:SetText(T("Suchen …"))
    local function Changed()
        local txt = search:GetText() or ""
        ph:SetShown(txt == "" and not (search.HasFocus and search:HasFocus()))
        M.search = txt:match("^%s*(.-)%s*$")
        M.listScroll = 0
        M:LayoutList()
    end
    search:SetScript("OnTextChanged", Changed)
    search:SetScript("OnEditFocusGained", Changed)
    search:SetScript("OnEditFocusLost", Changed)
    search:SetScript("OnEscapePressed", function(b) b:SetText("") b:ClearFocus() end)
    search:SetScript("OnEnterPressed", function(b) b:ClearFocus() end)
    self.searchBox, self.searchPh = search, ph
    local add = CreateFrame("Button", nil, list)
    add:SetSize(22, 22)
    add:SetPoint("LEFT", search, "RIGHT", 4, 0)
    local at = Text(add, "GameFontNormalLarge")
    at:SetPoint("CENTER", add, "CENTER", 0, 1)
    at:SetText("+")
    self.addText = at
    local hl = add:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(add)
    hl:SetColorTexture(1, 1, 1, .08)
    add:SetScript("OnClick", function(btn) M:NewMenu(btn) end)
    Tip(add, function() return {{T("Neues Gespräch")}, {T("Flüstern an jemanden oder eigenen Reiter anlegen")}} end)
    self.addButton = add
end

function M:NewMenu(owner)
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(owner, function(_, root)
            root:CreateButton(T("Flüstern an …"), function() M:AskWhisper() end)
            root:CreateButton(T("Neuer Reiter …"), function() if UI.EditTab then UI:EditTab() end end)
        end)
    else
        M:AskWhisper()
    end
end

local function NewConvRow(list)
    local b = CreateFrame("Button", nil, list)
    b:SetHeight(ROW_H)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.sel = b:CreateTexture(nil, "BACKGROUND")
    b.sel:SetAllPoints(b)
    b.sel:Hide()
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints(b)
    b.hl:SetColorTexture(1, 1, 1, .06)
    local G = ONE.Glass
    b.av = b:CreateTexture(nil, "ARTWORK")
    b.av:SetSize(24, 24)
    b.av:SetPoint("LEFT", b, "LEFT", 8, 0)
    b.av:SetTexture(G and G.tex.circle or (TEX .. "Dot"))
    b.letter = Text(b, "GameFontNormalSmall")
    b.letter:SetPoint("CENTER", b.av, "CENTER", 0, 0)
    b.letter:SetJustifyH("CENTER")
    b.glass = M.GlassAvatar(b, b.av, 2)
    -- online: gruener Punkt mit dunklem Rand unten rechts am Kreis (wie im Messenger), ueber Ring und Glanz
    b.onlineRim = b:CreateTexture(nil, "OVERLAY", nil, 5)
    b.onlineRim:SetSize(11, 11)
    b.onlineRim:SetPoint("BOTTOMRIGHT", b.av, "BOTTOMRIGHT", 2, -2)
    b.onlineRim:SetTexture(G and G.tex.circle or (TEX .. "Dot"))
    b.onlineRim:SetVertexColor(.05, .06, .07, 1)
    b.online = b:CreateTexture(nil, "OVERLAY", nil, 6)
    b.online:SetSize(7, 7)
    b.online:SetPoint("CENTER", b.onlineRim, "CENTER", 0, 0)
    b.online:SetTexture(G and G.tex.circle or (TEX .. "Dot"))
    b.online:SetVertexColor(.30, .90, .35)
    b.name = Text(b, "GameFontHighlight")
    b.name:SetPoint("TOPLEFT", b.av, "TOPRIGHT", 8, 1)
    b.name:SetPoint("RIGHT", b, "RIGHT", -44, 0)
    if b.name.SetWordWrap then b.name:SetWordWrap(false) end
    b.time = Text(b, "GameFontDisableSmall")
    b.time:SetPoint("TOPRIGHT", b, "TOPRIGHT", -8, -6)
    b.time:SetJustifyH("RIGHT")
    b.preview = Text(b, "GameFontDisableSmall")
    b.preview:SetPoint("BOTTOMLEFT", b.av, "BOTTOMRIGHT", 8, 0)
    b.preview:SetPoint("RIGHT", b, "RIGHT", -30, 0)
    if b.preview.SetWordWrap then b.preview:SetWordWrap(false) end
    b.badge = b:CreateTexture(nil, "OVERLAY")
    b.badge:SetSize(18, 16)
    b.badge:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -7, 5)
    b.badge:SetTexture(TEX .. "Pill")
    b.count = Text(b, "GameFontHighlightSmall")
    b.count:SetPoint("CENTER", b.badge, "CENTER", 0, 0)
    b.count:SetJustifyH("CENTER")
    b.label = Text(b, "GameFontDisableSmall")
    b.label:SetPoint("LEFT", b, "LEFT", 10, 0)
    return b
end

-- Liste fuellen: normal (angeheftet / Gespraeche) oder Suchergebnisse
function M:ListRows()
    local rows = {}
    local q = (self.search or ""):lower()
    if q ~= "" then
        local hits, seen = {}, {}
        -- "Alle" zuletzt: ein Treffer gehoert zum eigentlichen Gespraech (Fluestern, Gilde …)
        local convs = M.Conversations()
        table.sort(convs, function(a, b)
            if (a.view == "all") ~= (b.view == "all") then return b.view == "all" end
            return a.order < b.order
        end)
        for _, c in ipairs(convs) do
            if c.title:lower():find(q, 1, true) then rows[#rows + 1] = {conv = c} end
            for i = #Chat:Buffer(c.view), 1, -1 do
                local e = Chat:Buffer(c.view)[i]
                if not seen[e] then
                    local plain = tostring(e.text or ""):gsub("|H.-|h(.-)|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):lower()
                    if plain:find(q, 1, true) or Short(e.author or ""):lower():find(q, 1, true) then
                        seen[e] = true
                        hits[#hits + 1] = {conv = c, hit = e}
                    end
                end
            end
        end
        table.sort(hits, function(a, b) return (a.hit.time or 0) > (b.hit.time or 0) end)
        if #hits > 0 then rows[#rows + 1] = {label = T("NACHRICHTEN")} end
        for i = 1, math.min(40, #hits) do rows[#rows + 1] = hits[i] end
        if #rows == 0 then rows[#rows + 1] = {label = T("Nichts gefunden")} end
        return rows
    end
    -- Bereiche (Spieltest 21.11.2026): Angeheftet, Gespraeche, Fluestern eigens, System & Addons ganz unten
    local groups = {{label = T("ANGEHEFTET")}, {label = T("GESPRÄCHE")}, {label = T("FLÜSTERN")}, {label = T("SYSTEM")}}
    for _, c in ipairs(M.Conversations()) do
        local g = c.pinned and 1 or (c.whisper and 3) or (c.view == "system" and 4) or 2
        groups[g][#groups[g] + 1] = c
    end
    for _, g in ipairs(groups) do
        if #g > 0 then
            rows[#rows + 1] = {label = g.label, gap = #rows > 0}
            for _, c in ipairs(g) do rows[#rows + 1] = {conv = c} end
        end
    end
    return rows
end

function M:LayoutList()
    local list = self.list
    if not (list and self.frame and self.frame:IsShown()) then return end
    local p = self:Palette()
    local g = p.glow
    if self.addText then self.addText:SetTextColor(g[1], g[2], g[3]) end
    local rows = self:ListRows()
    local h = list:GetHeight() or 300
    local maxScroll = math.max(0, #rows - 3)
    self.listScroll = math.min(self.listScroll or 0, maxScroll)
    local y = 32
    local n = 0
    for i = 1 + self.listScroll, #rows do
        if y > h then break end
        local r = rows[i]
        n = n + 1
        local b = self.convRows[n] or NewConvRow(list)
        self.convRows[n] = b
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -y)
        b:SetPoint("TOPRIGHT", list, "TOPRIGHT", 0, -y)
        if r.label then
            if r.gap then y = y + GROUP_GAP end
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -y)
            b:SetPoint("TOPRIGHT", list, "TOPRIGHT", 0, -y)
            b:SetHeight(LABEL_H)
            for _, part in ipairs({b.av, b.letter, b.online, b.onlineRim, b.name, b.time, b.preview, b.badge, b.count, b.sel}) do part:Hide() end
            M.HideAvatar(b.glass)
            b.label:SetText(r.label)
            b.label:Show()
            b:SetScript("OnClick", nil)
            b:SetScript("OnEnter", nil)
            b:EnableMouse(false)
            y = y + LABEL_H
        else
            b:EnableMouse(true)
            b:SetHeight(ROW_H)
            b.label:Hide()
            self:FillConvRow(b, r, p)
            y = y + ROW_H
        end
        b:Show()
    end
    for i = n + 1, #self.convRows do self.convRows[i]:Hide() end
end

function M:FillConvRow(b, r, p)
    local c = r.conv
    local g = p.glow
    local cr, cg, cb = M.AvatarColor(c)
    local icon, coords = M.AvatarIcon(c)
    M.PaintAvatar(b.glass, p, cr, cg, cb, icon, coords, b.letter, UI.First and UI.First(c.title) or c.title:sub(1, 1))
    local info = c.whisper and M.PersonInfo(c.whisper)
    b.online:SetShown(info and info.online or false)
    b.onlineRim:SetShown(info and info.online or false)
    b.name:SetText(c.title)
    b.name:Show()
    local selected = c.view == UI.current and not r.hit
    b.sel:SetColorTexture(g[1], g[2], g[3], .14)
    b.sel:SetShown(selected)
    local entry = r.hit or M.LastEntry(c.view)
    b.time:SetText(M.ListTime(r.hit and r.hit.time or c.last))
    b.time:Show()
    local draft = not r.hit and Chat.drafts and Chat.drafts[c.view]
    if draft and draft ~= "" and c.view ~= UI.current then
        b.preview:SetText("|cffe06060" .. T("Entwurf:") .. "|r " .. M.Show(draft, 12))
    elseif c.muted and not entry then
        b.preview:SetText(T("stumm"))
    else
        b.preview:SetText(M.Preview(entry))
    end
    b.preview:Show()
    local unread = r.hit and 0 or c.unread
    if unread > 0 then
        b.badge:Show()
        b.count:Show()
        if c.muted then b.badge:SetVertexColor(.38, .38, .4) else b.badge:SetVertexColor(g[1] * .8, g[2] * .8, g[3] * .8) end
        local dark = not c.muted and p.onGlow and p.onGlow[1] < .5
        b.count:SetText((dark and "|cff111111" or "|cffffffff") .. tostring(math.min(unread, 99)) .. "|r")
        b.badge:SetWidth(unread > 9 and 24 or 18)
    else
        b.badge:Hide()
        b.count:Hide()
    end
    b:SetScript("OnClick", function(btn, button)
        if button == "RightButton" then M:ConvMenu(btn, c) return end
        if r.hit then M.jump = r.hit end
        M.page = "chat"
        M:ShowView(c.view)
    end)
    Tip(b, function()
        local out = {{c.title, cr, cg, cb}}
        if info then
            out[#out + 1] = {info.bn and M.BNLine(info) or info.online and string.format("%s %s · %s", info.class or "", tostring(info.level or ""), info.zone or "") or M.OfflineText(info)}
        end
        if c.muted then out[#out + 1] = {T("stummgeschaltet: kein Ton, grauer Zähler")} end
        out[#out + 1] = {T("Rechtsklick: Anheften, Stumm, …"), .6, .6, .6}
        return out
    end)
end

-- Rechtsklick auf ein Gespraech
function M:ConvMenu(owner, c)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateButton(c.pinned and T("Lösen") or T("Anheften"), function() M.SetPinned(c.view, not c.pinned) M:Refresh() end)
        root:CreateButton(c.muted and T("Ton an") or T("Stummschalten"), function() M.SetMuted(c.view, not c.muted) M:Refresh() end)
        if (Chat.unread[c.view] or 0) > 0 then
            root:CreateButton(T("Als gelesen markieren"), function() Chat:MarkRead(c.view) M:Refresh() end)
        end
        if c.whisper then
            if ONE.PlayerMenu then root:CreateButton(T("Namens-Menü …"), function() ONE.PlayerMenu:Open(owner, c.whisper) end) end
            root:CreateButton(T("Gespräch schließen"), function() UI:CloseWhisper(c.view) end)
        elseif c.tab and not c.tab.builtin and UI.EditTab then
            root:CreateButton(T("Reiter bearbeiten …"), function() UI:EditTab(c.tab) end)
        end
    end)
end

-- ===== Gespraech rechts =====
function M:BuildMain(f)
    local main = CreateFrame("Frame", nil, f)
    self.main = main
    -- Kopfzeile
    local head = CreateFrame("Frame", nil, main)
    head:SetPoint("TOPLEFT", main, "TOPLEFT", 0, 0)
    head:SetPoint("TOPRIGHT", main, "TOPRIGHT", 0, 0)
    head:SetHeight(HEAD_H)
    self.head = head
    local back = CreateFrame("Button", nil, head)
    back:SetSize(22, 22)
    back:SetPoint("LEFT", head, "LEFT", 2, 0)
    local bt = back:CreateTexture(nil, "ARTWORK")
    bt:SetAllPoints(back)
    bt:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    back:SetScript("OnClick", function() M.page = "list" M:Layout() end)
    Tip(back, function() return {{T("Zurück zur Liste")}} end)
    self.back = back
    local av = head:CreateTexture(nil, "ARTWORK")
    av:SetSize(26, 26)
    av:SetTexture(ONE.Glass and ONE.Glass.tex.circle or (TEX .. "Dot"))
    self.headAv = av
    local letter = Text(head, "GameFontNormal")
    letter:SetPoint("CENTER", av, "CENTER", 0, 0)
    letter:SetJustifyH("CENTER")
    self.headLetter = letter
    self.headGlass = M.GlassAvatar(head, av, 2)
    local name = Text(head, "GameFontNormal")
    name:SetPoint("TOPLEFT", av, "TOPRIGHT", 8, 1)
    name:SetPoint("RIGHT", head, "RIGHT", -60, 0)
    if name.SetWordWrap then name:SetWordWrap(false) end
    self.headName = name
    -- Fluestern: Name oben anklickbar (Spieltest 22.11.2026: Umschalt+Klick fuer Gildeneinladung ging nicht,
    -- weil im Fluestergespraech kein Name in den Blasen steht). Umschalt+Klick = wie ein Name im WoW-Chat
    -- (Einladungsdialog, Eingabefeld), Klick = Namens-Menue
    local hit = CreateFrame("Button", nil, head)
    hit:SetPoint("TOPLEFT", name, "TOPLEFT", -2, 2)
    hit:SetPoint("BOTTOMRIGHT", name, "BOTTOMRIGHT", 2, -2)
    if hit.RegisterForClicks then pcall(hit.RegisterForClicks, hit, "LeftButtonUp", "RightButtonUp") end
    hit:SetScript("OnClick", function(btn, button) M:HeadNameClick(btn, button) end)
    Tip(hit, function() return {{T("Umschalt+Klick: Name einfügen (z. B. Gildeneinladung)")}, {T("Klick: Namens-Menü"), .6, .6, .6}} end)
    self.headHit = hit
    local sub = Text(head, "GameFontDisableSmall")
    sub:SetPoint("BOTTOMLEFT", av, "BOTTOMRIGHT", 8, -1)
    sub:SetPoint("RIGHT", head, "RIGHT", -60, 0)
    if sub.SetWordWrap then sub:SetWordWrap(false) end
    self.headSub = sub
    -- Fluestern: Namens-Menue und Schliessen
    self.headMenu = ONE.Widgets:Button(head, "···", 28, 20, "RIGHT", -30, 0, function(btn)
        local view = UI.current or ""
        if view:sub(1, 2) == "w:" and ONE.PlayerMenu then ONE.PlayerMenu:Open(btn, view:sub(3)) end
    end)
    Tip(self.headMenu, function() return {{T("Namens-Menü")}, {T("Einladen, Navi, Ignorieren …")}} end)
    if ONE.Widgets.IconButton then
        self.headClose = ONE.Widgets:IconButton(head, "Interface\\AddOns\\ONE_Core\\Textures\\Common\\CloseGlyph.tga", 20, "RIGHT", -4, 0,
            function() UI:CloseWhisper(UI.current) end, "secondary", 9)
        Tip(self.headClose, function() return {{T("Gespräch schließen")}} end)
    end
    local line = head:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", head, "BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", head, "BOTTOMRIGHT", 0, 0)
    line:SetColorTexture(1, 1, 1, .08)

    -- Verlauf (Sprechblasen)
    local log = CreateFrame("Frame", nil, main)
    log:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -2)
    log:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", 0, FOOT_H + 2)
    if log.SetClipsChildren then log:SetClipsChildren(true) end
    log:EnableMouseWheel(true)
    log:SetScript("OnMouseWheel", function(_, delta)
        M.scroll = math.max(0, math.min(M.maxScroll or 0, (M.scroll or 0) + delta * 2))
        if M.scroll == 0 then M.newBelow = 0 end
        M:LayoutLog()
    end)
    self.log = log
    UI.log = nil
    local empty = Text(log, "GameFontDisable")
    empty:SetPoint("CENTER", log, "CENTER", 0, 0)
    empty:SetJustifyH("CENTER")
    self.empty = empty

    -- Knopf "nach unten" mit Zahl neuer Nachrichten
    local down = CreateFrame("Button", nil, main)
    down:SetSize(26, 26)
    down:SetPoint("BOTTOMRIGHT", log, "BOTTOMRIGHT", -8, 6)
    if down.SetFrameLevel and main.GetFrameLevel then down:SetFrameLevel((main:GetFrameLevel() or 1) + 10) end
    if ONE.Glass and ONE.Glass.Surface then ONE.Glass:Surface(down, "button") end
    local dt = down:CreateTexture(nil, "ARTWORK")
    dt:SetSize(20, 20)
    dt:SetPoint("CENTER", down, "CENTER", 0, -1)
    dt:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
    down.count = Text(down, "GameFontHighlightSmall")
    down.count:SetPoint("BOTTOM", down, "TOP", 0, -2)
    down:SetScript("OnClick", function() M.scroll = 0 M.newBelow = 0 M:LayoutLog() end)
    Tip(down, function() return {{T("Nach unten")}} end)
    down:Hide()
    self.down = down

    -- Eingabe: Emoji-Knopf, Feld, Senden
    local foot = CreateFrame("Frame", nil, main)
    foot:SetPoint("BOTTOMLEFT", main, "BOTTOMLEFT", 0, 0)
    foot:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", 0, 0)
    foot:SetHeight(FOOT_H)
    self.foot = foot
    local emo = CreateFrame("Button", nil, foot)
    emo:SetSize(26, 26)
    emo:SetPoint("LEFT", foot, "LEFT", 2, 0)
    if ONE.Glass and ONE.Glass.Surface then emo.glass = ONE.Glass:Surface(emo, "select") end
    local et = emo:CreateTexture(nil, "ARTWORK")
    et:SetSize(18, 18)
    et:SetPoint("CENTER", emo, "CENTER", 0, 0)
    et:SetTexture(chat.Emoji and (chat.Emoji.DIR .. "1f60a") or (TEX .. "Dot"))
    emo:SetScript("OnClick", function() M:TogglePicker() end)
    Tip(emo, function() return {{T("Emojis und WoW-Zeichen")}, {T("Emojis sehen nur Spieler mit Guild Trip als Bild, andere lesen den Code (z. B. :daumen:). WoW-Zeichen wie {Stern} sieht jeder.")}} end)
    self.emojiButton = emo
    local send = ONE.Widgets:Button(foot, T("Senden"), 62, 24, "RIGHT", -2, 0, function() M:SendInput() end, "primary")
    self.sendButton = send
    local ok, box = pcall(CreateFrame, "EditBox", "GuildTripChatInput", foot, "InputBoxTemplate")
    if not ok or not box then box = CreateFrame("EditBox", "GuildTripChatInput", foot) end
    for _, key in ipairs({"Left", "Right", "Middle", "LeftDisabled", "RightDisabled", "MiddleDisabled"}) do
        local t = rawget(box, key)
        if type(t) == "table" and t.Hide then t:Hide() end
    end
    box:SetPoint("LEFT", emo, "RIGHT", 6, 0)
    box:SetPoint("RIGHT", send, "LEFT", -6, 0)
    box:SetHeight(24)
    box:SetAutoFocus(false)
    box:SetMaxLetters(1020)
    if box.SetTextInsets then box:SetTextInsets(10, 10, 0, 0) end
    if ONE.Glass and ONE.Glass.Surface then ONE.Glass:Surface(box, "card") end
    box:SetScript("OnEnterPressed", function() M:SendInput() end)
    box:SetScript("OnEscapePressed", function(b)
        if M.picker and M.picker:IsShown() then M.picker:Hide() return end
        b:ClearFocus()
    end)
    box:SetScript("OnTabPressed", function() UI:CycleWhisper(IsShiftKeyDown and IsShiftKeyDown()) end)
    local ph = Text(foot, "GameFontDisableSmall")
    ph:SetPoint("LEFT", box, "LEFT", 11, 0)
    ph:SetPoint("RIGHT", box, "RIGHT", -8, 0)
    if ph.SetWordWrap then ph:SetWordWrap(false) end
    self.placeholder = ph
    local function Placeholder()
        ph:SetShown((box:GetText() or "") == "" and not (box.HasFocus and box:HasFocus()))
    end
    self.UpdatePlaceholder = Placeholder
    box:SetScript("OnTextChanged", Placeholder)
    -- schmal auf der Liste (z. B. Enter bei ersetztem WoW-Chat): zum Gespraech wechseln
    box:SetScript("OnEditFocusGained", function()
        Placeholder()
        if M:IsNarrow() and M.page ~= "chat" then M.page = "chat" M:Layout() end
    end)
    box:SetScript("OnEditFocusLost", Placeholder)
    self.input = box
    UI.input = box
    UI.UpdatePlaceholder = Placeholder
end

function M:SendInput()
    local box = self.input
    if not box then return end
    local text = box:GetText() or ""
    local sent, err = Chat:Send(UI.current, text)
    if sent then
        if box.AddHistoryLine then box:AddHistoryLine(text) end
        box:SetText("")
        if Chat.drafts then Chat.drafts[UI.current] = nil end
        M.scroll, M.newBelow = 0, 0
        if self.picker then self.picker:Hide() end
    elseif err then
        ONE:Print(err)
    end
end

-- ===== Emoji-Auswahl =====
M.PICK_GROUPS = {{"recent", "Zuletzt"}, {"faces", "Gesichter"}, {"hands", "Gesten"}, {"hearts", "Herzen"}, {"things", "WoW"}, {"marks", "Zeichen"}}
function M:BuildPicker()
    if self.picker then return self.picker end
    local pk = CreateFrame("Frame", nil, self.main)
    pk:SetPoint("BOTTOMLEFT", self.log, "BOTTOMLEFT", 4, 4)
    pk:SetPoint("BOTTOMRIGHT", self.log, "BOTTOMRIGHT", -4, 4)
    pk:SetHeight(150)
    if pk.SetFrameLevel and self.main.GetFrameLevel then pk:SetFrameLevel((self.main:GetFrameLevel() or 1) + 20) end
    pk:EnableMouse(true)
    if ONE.Glass and ONE.Glass.Surface then
        local G = ONE.Glass
        G.forceLook = "glass"
        local sf = G:Surface(pk, "card")
        G.forceLook = nil
        if sf then
            sf.store = function() return Chat:GlassStore() end
            self.surfaces[#self.surfaces + 1] = sf
            -- Auswahl liegt ueber den Blasen: nicht durchsichtig
            sf.onPaint = function(s2, p) s2.fill:SetColor(p.tint[1], p.tint[2], p.tint[3], .97) end
            G:Paint(sf)
        end
    end
    pk.tabs = {}
    for i, grp in ipairs(M.PICK_GROUPS) do
        local b = CreateFrame("Button", nil, pk)
        b:SetHeight(16)
        b.text = Text(b, "GameFontHighlightSmall")
        b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
        b.text:SetText(T(grp[2]))
        b:SetWidth(math.max(30, (b.text.GetStringWidth and b.text:GetStringWidth() or 40) + 8))
        b.under = b:CreateTexture(nil, "ARTWORK")
        b.under:SetHeight(2)
        b.under:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, -1)
        b.under:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, -1)
        b.key = grp[1]
        b:SetScript("OnClick", function() M.pickGroup = grp[1] M:FillPicker() end)
        pk.tabs[i] = b
    end
    pk.hint = Text(pk, "GameFontDisableSmall")
    pk.hint:SetPoint("BOTTOMLEFT", pk, "BOTTOMLEFT", 8, 6)
    pk.hint:SetPoint("BOTTOMRIGHT", pk, "BOTTOMRIGHT", -8, 6)
    if pk.hint.SetWordWrap then pk.hint:SetWordWrap(false) end
    pk.cells = {}
    pk:Hide()
    self.picker = pk
    self.pickGroup = self.pickGroup or "recent"
    return pk
end
function M:TogglePicker()
    local pk = self:BuildPicker()
    if pk:IsShown() then pk:Hide() else pk:Show() self:FillPicker() end
    if self.emojiButton and self.emojiButton.glass then
        self.emojiButton.glass.on = pk:IsShown()
        if ONE.Glass then ONE.Glass:Paint(self.emojiButton.glass) end
    end
end
function M:FillPicker()
    local pk = self.picker
    if not (pk and pk:IsShown()) then return end
    local p = self:Palette()
    local g = p.glow
    -- Reiter (umbrechen, wenn schmal)
    local w = (pk:GetWidth() or 300) - 16
    local x, y = 8, -6
    for _, b in ipairs(pk.tabs) do
        local bw = b:GetWidth() or 40
        if x + bw > w + 8 then x, y = 8, y - 18 end
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", pk, "TOPLEFT", x, y)
        x = x + bw + 6
        local on = b.key == self.pickGroup
        b.under:SetColorTexture(g[1], g[2], g[3], 1)
        b.under:SetShown(on)
        b.text:SetTextColor(on and g[1] or .7, on and g[2] or .7, on and g[3] or .7)
    end
    local top = -y + 22
    local items = chat.Emoji and chat.Emoji.PickerItems(self.pickGroup, Chat:Settings()) or {}
    local size, step = 22, 26
    local cols = math.max(4, math.floor(w / step))
    local rowsFit = math.max(1, math.floor(((pk:GetHeight() or 150) - top - 22) / step))
    for i, it in ipairs(items) do
        local c = pk.cells[i]
        if not c then
            c = CreateFrame("Button", nil, pk)
            c:SetSize(size, size)
            c.icon = c:CreateTexture(nil, "ARTWORK")
            c.icon:SetAllPoints(c)
            c.hl = c:CreateTexture(nil, "HIGHLIGHT")
            c.hl:SetPoint("TOPLEFT", c, "TOPLEFT", -2, 2)
            c.hl:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 2, -2)
            c.hl:SetColorTexture(1, 1, 1, .12)
            pk.cells[i] = c
        end
        local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
        if row < rowsFit then
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", pk, "TOPLEFT", 8 + col * step, -top - row * step)
            if it.kind == "mark" then c.icon:SetTexture(chat.Emoji.MARK_TEX .. it.n) else c.icon:SetTexture(chat.Emoji.Texture(it.item)) end
            c:SetScript("OnClick", function() M:InsertCode(it.code) end)
            c:SetScript("OnEnter", function()
                pk.hint:SetText(it.name .. "  |cff9a9a9a" .. it.code .. "|r" .. (it.kind == "mark" and ("  |cff9a9a9a" .. T("(sieht jeder)") .. "|r") or ""))
            end)
            c:SetScript("OnLeave", function() M:PickerHint() end)
            c:Show()
        else
            c:Hide()
        end
    end
    for i = #items + 1, #pk.cells do pk.cells[i]:Hide() end
    self:PickerHint()
end
function M:PickerHint()
    local pk = self.picker
    if not pk then return end
    pk.hint:SetText(self.pickGroup == "marks" and T("WoW-Zeichen sieht jeder – auch ohne Guild Trip.")
        or T("Emojis: Bild nur mit Guild Trip, sonst steht der Code da."))
end
function M:InsertCode(code)
    local box = self.input
    if not box then return end
    local cur = box:GetText() or ""
    local pre = (cur ~= "" and not cur:find("%s$")) and " " or ""
    if box.Insert then box:Insert(pre .. code .. " ") else box:SetText(cur .. pre .. code .. " ") end
    if box.SetFocus then box:SetFocus() end
    if chat.Emoji then chat.Emoji.Remember(Chat:Settings(), code) end
    if self.UpdatePlaceholder then self.UpdatePlaceholder() end
end

-- ===== Blasen =====
local function NewBubble(log)
    local r = CreateFrame("Frame", nil, log)
    r:EnableMouse(true)
    local G = ONE.Glass
    if G and G.Nine then
        r.bg = G:Nine(r, G.tex.round, .25, "BACKGROUND", 1)
    end
    -- Zipfel an der ersten Blase einer Folge (wie WhatsApp), ersetzt die obere aeussere Ecke
    r.tail = r:CreateTexture(nil, "BACKGROUND", nil, 1)
    r.tail:SetTexture(TAIL_TEX)
    r.tail:Hide()
    -- Glas: Rand (auch um den Zipfel) und Glanz oben
    if G and G.Nine then r.edge = G:Nine(r, G.tex.roundRing, .25, "BACKGROUND", 2) end
    r.tailEdge = r:CreateTexture(nil, "BACKGROUND", nil, 2)
    r.tailEdge:SetTexture(TAIL_RING_TEX)
    r.tailEdge:Hide()
    r.sheen = r:CreateTexture(nil, "BACKGROUND", nil, 3)
    if G and G.tex then r.sheen:SetTexture(G.tex.sheen) end
    r.sheen:Hide()
    r.flat = r:CreateTexture(nil, "BACKGROUND", nil, 1)
    r.flat:Hide()
    r.who = Text(r, "GameFontNormalSmall")
    -- kleines Klassen-Symbol (Glas) vor dem Namen
    r.clsAv = r:CreateTexture(nil, "ARTWORK")
    r.clsAv:SetSize(14, 14)
    if G and G.tex then r.clsAv:SetTexture(G.tex.circle) end
    r.cls = M.GlassAvatar(r, r.clsAv, 1)
    M.HideAvatar(r.cls)
    if r.who.SetWordWrap then r.who:SetWordWrap(false) end
    r.text = Text(r, "ChatFontNormal")
    if r.text.SetWordWrap then r.text:SetWordWrap(true) end
    if r.text.SetNonSpaceWrap then r.text:SetNonSpaceWrap(true) end
    r.time = Text(r, "GameFontDisableSmall")
    r.time:SetJustifyH("RIGHT")
    r.tick = r:CreateTexture(nil, "OVERLAY")
    r.tick:SetSize(11, 11)
    r.note = Text(r, "GameFontDisableSmall")
    r.note:SetJustifyH("RIGHT")
    r.line1 = r:CreateTexture(nil, "ARTWORK")
    r.line1:SetHeight(1)
    r.line2 = r:CreateTexture(nil, "ARTWORK")
    r.line2:SetHeight(1)
    -- Links: Gegenstand zeigen (Vorschau), anklicken wie im WoW-Chat, Namen -> Namens-Menue
    if r.SetHyperlinksEnabled then pcall(r.SetHyperlinksEnabled, r, true) end
    pcall(r.SetScript, r, "OnHyperlinkClick", function(self, link, text, button)
        if UI.ShiftLink and UI.ShiftLink(link, text, button, self) then return end
        local kind, rest = tostring(link):match("^(%a+):(.*)$")
        if kind == "player" and ONE.PlayerMenu then
            local name, lineID = rest:match("^([^:]+):?(%d*)")
            ONE.PlayerMenu:Open(self, name, {lineID = tonumber(lineID)})
            return
        end
        if type(SetItemRef) == "function" then pcall(SetItemRef, link, text, button, self) end
    end)
    pcall(r.SetScript, r, "OnHyperlinkEnter", function(self, link)
        local kind = tostring(link):match("^(%a+):")
        if not (GameTooltip and kind) or kind == "player" or kind == "trade" then return end
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        if pcall(GameTooltip.SetHyperlink, GameTooltip, link) then GameTooltip:Show() else GameTooltip:Hide() end
    end)
    pcall(r.SetScript, r, "OnHyperlinkLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    r:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" and self.item then M:BubbleMenu(self, self.item) end
    end)
    return r
end

-- Groesse der Emojis, wenn eine Nachricht nur aus Emojis besteht
function M.BigEmojiSize(fsize) return math.floor((fsize or 14) * 2.2) end

-- Name oben im Fluestergespraech: Spielername dazu (Battle.net-Freund: sein Charakter, wenn er WoW spielt)
function M.HeadPlayer(view)
    if type(view) ~= "string" or view:sub(1, 2) ~= "w:" then return nil end
    local name = view:sub(3)
    if Chat.IsBN and Chat.IsBN(name) then
        local b = Chat.BNInfo and Chat.BNInfo(Chat.BNFind(name))
        return b and b.online and b.character and b.character ~= "" and b.character or nil
    end
    return name
end
function M:HeadNameClick(owner, button)
    local name = M.HeadPlayer(UI.current)
    if not name then return end
    local link = "player:" .. name
    if UI.ShiftLink and UI.ShiftLink(link, "[" .. name .. "]", button or "LeftButton", owner) then return end
    if ONE.PlayerMenu then ONE.PlayerMenu:Open(owner, name) end
end

-- Rechtsklick auf eine Blase: Antworten, Text kopieren, Namens-Menue
function M:BubbleMenu(owner, item)
    local e = item.entry
    if not (e and MenuUtil and MenuUtil.CreateContextMenu) then return end
    local name = Short(e.author or "")
    MenuUtil.CreateContextMenu(owner, function(_, root)
        if not item.out and name ~= "" and item.type == "bubble" then
            root:CreateButton(T("Antworten"), function()
                if (UI.current or ""):sub(1, 2) ~= "w:" then M:InsertCode("@" .. name) else if M.input then M.input:SetFocus() end end
            end)
            if ONE.PlayerMenu then root:CreateButton(T("Namens-Menü …"), function() ONE.PlayerMenu:Open(owner, name) end) end
        end
        root:CreateButton(T("Text kopieren"), function()
            if not M.input then return end
            M.input:SetText(tostring(e.text or ""))
            M.input:SetFocus()
            if M.input.HighlightText then M.input:HighlightText() end
            ONE:Print(T("Text steht im Eingabefeld und ist markiert – Strg+C kopiert ihn."))
        end)
    end)
end

local function SetBg(r, on, cr, cg, cb, ca)
    if r.bg then
        r.bg:SetShown(on)
        if on then r.bg:SetColor(cr, cg, cb, ca) end
    end
    if r.tail and on then r.tail:SetVertexColor(cr, cg, cb, ca) end
    if not on then
        if r.edge then r.edge:SetShown(false) end
        if r.tailEdge then r.tailEdge:Hide() end
        if r.sheen then r.sheen:Hide() end
    end
end

-- Hoehe eines Eintrags; legt die Teile innerhalb der Zeile an
function M:FillBubble(r, it, W, p)
    local s = Chat:Settings()
    r.item = it
    for _, part in ipairs({r.who, r.text, r.time, r.tick, r.note, r.line1, r.line2, r.flat, r.tail, r.tailEdge, r.sheen}) do part:Hide() end
    M.HideAvatar(r.cls)
    SetBg(r, false)
    local file = ChatFontNormal and ChatFontNormal.GetFont and ChatFontNormal:GetFont()
    if file and r.text.SetFont then pcall(r.text.SetFont, r.text, file, s.fontSize or 14, "") end
    local fsize = s.fontSize or 14
    local g = p.glow
    if it.type == "day" or it.type == "sys" then
        local txt
        if it.type == "day" then txt = it.text
        elseif it.emote then txt = (Chat.ClassColorCode(it.entry.guid, false) or "|cffff8040") .. Short(it.entry.author) .. "|r |cffff9a5a" .. M.Show(it.entry.text, 0) .. "|r"
        else txt = M.Show(it.entry.text, 0) end
        local small = it.type == "day"
        r.text:SetFontObject(small and GameFontDisableSmall or GameFontHighlightSmall)
        r.text:SetJustifyH("CENTER")
        r.text:SetWidth(math.floor(W * .9) - 20)
        r.text:SetText(txt)
        if not small and not it.emote then r.text:SetTextColor(.85, .80, .55) else r.text:SetTextColor(1, 1, 1) end
        local tw = math.min(math.floor(W * .9) - 20, (r.text:GetStringWidth() or 60) + 2)
        r.text:SetWidth(tw)
        local th = r.text:GetStringHeight() or 12
        local bw, bh = tw + 20, th + (small and 4 or 6)
        r:SetSize(bw, bh)
        r.text:ClearAllPoints()
        r.text:SetPoint("CENTER", r, "CENTER", 0, 0)
        r.text:Show()
        SetBg(r, true, 1, 1, 1, small and .07 or .05)
        if it.type == "sys" and not it.emote then SetBg(r, true, g[1], g[2], g[3], .08) end
        if r.bg then r.bg:Place(math.min(8, math.floor(bh / 2)), 0, r) end
        return bh, "CENTER"
    end
    if it.type == "new" then
        r:SetSize(W - 16, 16)
        r.text:SetFontObject(GameFontNormalSmall)
        r.text:SetJustifyH("CENTER")
        r.text:SetWidth(W - 16)
        r.text:SetText(it.count == 1 and T("1 neue Nachricht") or T("%d neue Nachrichten", it.count))
        r.text:SetTextColor(g[1], g[2], g[3])
        r.text:ClearAllPoints()
        r.text:SetPoint("CENTER", r, "CENTER", 0, 0)
        r.text:Show()
        local tw = math.min(W - 40, (r.text:GetStringWidth() or 100) + 16)
        r.line1:SetColorTexture(g[1], g[2], g[3], .5)
        r.line2:SetColorTexture(g[1], g[2], g[3], .5)
        r.line1:ClearAllPoints() r.line1:SetPoint("LEFT", r, "LEFT", 0, 0) r.line1:SetWidth(math.max(1, (W - 16 - tw) / 2))
        r.line2:ClearAllPoints() r.line2:SetPoint("RIGHT", r, "RIGHT", 0, 0) r.line2:SetWidth(math.max(1, (W - 16 - tw) / 2))
        r.line1:Show() r.line2:Show()
        return 16, "CENTER"
    end
    -- Sprechblase
    local e = it.entry
    r.text:SetFontObject(ChatFontNormal or GameFontHighlight)
    if file and r.text.SetFont then pcall(r.text.SetFont, r.text, file, fsize, "") end
    r.text:SetJustifyH("LEFT")
    local tc = M.ValidColor(s.bubbleText)
    if tc then r.text:SetTextColor(tc[1], tc[2], tc[3]) else r.text:SetTextColor(1, 1, 1) end
    local big = s.bigEmoji ~= false and s.emojiImages ~= false and chat.Emoji and chat.Emoji.OnlyEmoji(e.text)
    local maxW = math.floor(W * .78)
    local pad = 10
    local inner = maxW - 2 * pad
    local txt = M.Show(e.text, big and M.BigEmojiSize(fsize) or 0)
    r.text:SetWidth(inner)
    r.text:SetText(txt)
    local tw = r.text:GetStringWidth() or 60
    -- Name (Gruppen, Gilde …), im Reiter "Alle" mit Art
    local whoW, whoH, clsW = 0, 0, 0
    if it.name then
        local code = Chat.ClassColorCode(e.guid, false)
        local kind = it.kind and Chat.kindByKey[it.kind]
        local shown = (code or "|cffd0d0d0") .. Short(e.author) .. "|r"
        local link = "|Hplayer:" .. (e.author or "") .. ":" .. tostring(e.lineID or 0) .. "|h" .. shown .. "|h"
        if kind then link = link .. "  " .. Hex(kind.color) .. T(kind.label) .. "|r" end
        r.who:SetText(link)
        local classFile = s.classIcons ~= false and M.ClassOfGuid(e.guid)
        local l, rr, tt, bb = M.ClassCoords(classFile)
        if l and r.cls then
            clsW = 17
            local cr2, cg2, cb2 = ClassRGB(classFile)
            M.PaintAvatar(r.cls, p, cr2, cg2, cb2, CLASS_ATLAS, {l, rr, tt, bb})
        end
        whoW, whoH = (r.who:GetStringWidth() or 40) + 2 + clsW, 13
        r.who:Show()
    end
    -- Uhrzeit (+ Haken) unten rechts in der Blase
    local stamp = (type(date) == "function" and date("%H:%M", e.time or 0)) or ""
    r.time:SetText(stamp)
    local timeW = (r.time:GetStringWidth() or 26) + 2
    local tickW = 0
    local whisperOut = it.out and e.kind == "whisper"
    if whisperOut and (e.delivered or e.pending) then
        tickW = 13
        r.tick:SetTexture(e.pending and "Interface\\RaidFrame\\ReadyCheck-Waiting" or "Interface\\RaidFrame\\ReadyCheck-Ready")
    end
    local lineH = fsize + 2
    local th = r.text:GetStringHeight() or lineH
    local oneLine = th <= lineH * 1.5
    local stampW = timeW + tickW
    local bw, bh, timeBelow
    if oneLine and tw + 8 + stampW <= inner then
        bw = math.max(tw + 8 + stampW, whoW) + 2 * pad
        timeBelow = false
    else
        bw = math.max(math.min(tw, inner), whoW, stampW) + 2 * pad
        timeBelow = true
    end
    r.text:SetWidth(bw - 2 * pad - (timeBelow and 0 or (8 + stampW)))
    th = r.text:GetStringHeight() or th
    bh = 5 + whoH + th + (timeBelow and 12 or 0) + 4
    -- grosses Emoji: WoW zaehlt die Bildhoehe nicht zur Texthoehe -> selbst rechnen, Namenszeile mitzaehlen
    if big then bh = 4 + whoH + (it.name and 1 or 0) + math.max(th, M.BigEmojiSize(fsize)) + 4 end
    -- Blase
    local cr, cg, cb, ca, er, eg, eb, ea = M.BubbleColor(p, it.out, e.failed, e.kind)
    r.flat:ClearAllPoints()
    local noteH = e.failed and 13 or 0
    r:SetSize(bw, bh + noteH)
    if not big then
        SetBg(r, true, cr, cg, cb, ca)
        if r.bg then
            -- Blase ohne die Zeile "nicht zugestellt"
            local holder = r.bgHolder or CreateFrame("Frame", nil, r)
            r.bgHolder = holder
            holder:ClearAllPoints()
            holder:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
            holder:SetPoint("TOPRIGHT", r, "TOPRIGHT", 0, 0)
            holder:SetHeight(bh)
            r.bg:Place(BUBBLE_R, 0, holder)
            -- erste Blase einer Folge: Zipfel oben aussen statt runder Ecke
            local corner = r.bg.pieces and r.bg.pieces[it.out and 3 or 1]
            if not it.cont and corner and r.tail then
                corner:Hide()
                r.tail:ClearAllPoints()
                r.tail:SetSize(2 * BUBBLE_R, BUBBLE_R)
                if it.out then
                    r.tail:SetPoint("TOPLEFT", holder, "TOPRIGHT", -BUBBLE_R, 0)
                    r.tail:SetTexCoord(1, 0, 0, 1)
                else
                    r.tail:SetPoint("TOPRIGHT", holder, "TOPLEFT", BUBBLE_R, 0)
                    r.tail:SetTexCoord(0, 1, 0, 1)
                end
                r.tail:Show()
            end
            -- Glas: Rand und Glanz
            if r.edge then
                r.edge:SetShown(true)
                r.edge:SetColor(er, eg, eb, ea)
                r.edge:Place(BUBBLE_R, 0, holder)
                local ec = r.edge.pieces[it.out and 3 or 1]
                if not it.cont and ec and r.tailEdge then
                    ec:Hide()
                    r.tailEdge:ClearAllPoints()
                    r.tailEdge:SetAllPoints(r.tail)
                    r.tailEdge:SetTexCoord(it.out and 1 or 0, it.out and 0 or 1, 0, 1)
                    r.tailEdge:SetVertexColor(er, eg, eb, ea)
                    r.tailEdge:Show()
                end
            end
            if r.sheen then
                r.sheen:ClearAllPoints()
                r.sheen:SetPoint("TOPLEFT", holder, "TOPLEFT", BUBBLE_R - 2, -1)
                r.sheen:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -(BUBBLE_R - 2), -1)
                r.sheen:SetHeight(math.max(6, math.floor(bh * .45)))
                r.sheen:SetVertexColor(1, 1, 1, it.out and .06 or .04)
                r.sheen:Show()
            end
        end
    end
    if it.name then
        r.who:ClearAllPoints()
        r.who:SetPoint("TOPLEFT", r, "TOPLEFT", pad + clsW, -4)
        if clsW > 0 then
            r.clsAv:ClearAllPoints()
            r.clsAv:SetPoint("RIGHT", r.who, "LEFT", -3, 0)
        end
    end
    r.text:ClearAllPoints()
    r.text:SetPoint("TOPLEFT", r, "TOPLEFT", pad, -(4 + whoH + (it.name and 1 or 0)))
    r.text:Show()
    if not big then
        r.time:ClearAllPoints()
        r.time:SetPoint("BOTTOMRIGHT", r, "TOPRIGHT", -(pad + tickW), -(bh - 3))
        r.time:SetTextColor(it.out and .82 or .6, it.out and .85 or .6, it.out and .82 or .62)
        r.time:Show()
        if tickW > 0 then
            r.tick:ClearAllPoints()
            r.tick:SetPoint("LEFT", r.time, "RIGHT", 2, 0)
            r.tick:Show()
        end
    end
    if e.failed then
        r.note:SetText("|cffe07070" .. T("nicht zugestellt – %s ist offline", Short(e.author)) .. "|r")
        r.note:ClearAllPoints()
        r.note:SetPoint("TOPRIGHT", r, "TOPRIGHT", -2, -(bh + 1))
        r.note:Show()
    end
    -- gesprungen (Suche): kurz hervorheben
    if M.highlight == e and r.bg then
        r.bg:SetColor(math.min(1, cr + .25), math.min(1, cg + .2), cb, 1)
        if r.tail then r.tail:SetVertexColor(math.min(1, cr + .25), math.min(1, cg + .2), cb, 1) end
    end
    return bh + noteH, it.out and "RIGHT" or "LEFT"
end

-- Blasen von unten nach oben setzen (scroll = wie viele Eintraege unten ausgeblendet sind)
function M:LayoutLog()
    local log = self.log
    if not (log and self.frame and self.frame:IsShown()) then return end
    local items = self.items or {}
    local W = log:GetWidth() or 300
    local H = log:GetHeight() or 200
    local p = self:Palette()
    self.maxScroll = math.max(0, #items - 1)
    self.scroll = math.min(self.scroll or 0, self.maxScroll)
    local y, n = 6, 0
    for i = #items - self.scroll, 1, -1 do
        if y > H then break end
        n = n + 1
        local r = self.bubbles[n] or NewBubble(log)
        self.bubbles[n] = r
        local h, side = self:FillBubble(r, items[i], W, p)
        r:ClearAllPoints()
        -- Platz fuer den Zipfel lassen
        if side == "RIGHT" then r:SetPoint("BOTTOMRIGHT", log, "BOTTOMRIGHT", -(6 + BUBBLE_R), y)
        elseif side == "LEFT" then r:SetPoint("BOTTOMLEFT", log, "BOTTOMLEFT", 6 + BUBBLE_R, y)
        else r:SetPoint("BOTTOM", log, "BOTTOM", 0, y) end
        r:Show()
        local nextIt = items[i - 1]
        local tight = items[i].cont and nextIt and nextIt.type == "bubble"
        y = y + h + (tight and GAP or GAP + 4)
    end
    for i = n + 1, #self.bubbles do self.bubbles[i]:Hide() end
    if self.empty then
        if #items == 0 then
            local view = UI.current or ""
            self.empty:SetText(view:sub(1, 2) == "w:" and T("Noch keine Nachrichten – schreib unten los.") or T("Noch keine Nachrichten."))
            self.empty:Show()
        else
            self.empty:Hide()
        end
    end
    if self.down then
        if self.scroll > 0 then
            self.down:Show()
            local nb = self.newBelow or 0
            self.down.count:SetText(nb > 0 and ("|cffffd100" .. nb .. "|r") or "")
        else
            self.down:Hide()
        end
    end
end

-- Verlauf neu aufbauen (scroll bleibt; Sprung aus der Suche setzt ihn)
function M:Render()
    if not self.frame then return end
    local view = UI.current or "guild"
    self.items = M.Items(view, self.newFrom[view])
    if self.jump then
        for i = #self.items, 1, -1 do
            if self.items[i].entry == self.jump then self.scroll = math.max(0, #self.items - i - 2) break end
        end
        self.highlight = self.jump
        self.jump = nil
    end
    self:LayoutLog()
end

-- ===== Kopfzeile =====
function M:RefreshHead()
    if not self.head then return end
    local view = UI.current or "guild"
    local whisper = view:sub(1, 2) == "w:"
    local c = {view = view, title = M.ViewTitle(view), whisper = whisper and view:sub(3) or nil, tab = not whisper and Chat:Tab(view) or nil}
    local r, g, b = M.AvatarColor(c)
    local p = self:Palette()
    local icon, coords = M.AvatarIcon(c)
    M.PaintAvatar(self.headGlass, p, r, g, b, icon, coords, self.headLetter, UI.First and UI.First(c.title) or "?")
    if whisper then self.headName:SetTextColor(r, g, b) else self.headName:SetTextColor(p.title[1], p.title[2], p.title[3]) end
    self.headName:SetText(c.title)
    local sub = ""
    local chatType = Chat:Target(view)
    if whisper then
        local info = M.PersonInfo(c.whisper)
        if info then
            sub = info.bn and M.BNLine(info)
                or info.online and string.format("%s · %s %s · %s", info.class or "", T("Stufe"), tostring(info.level or "?"), info.zone or "")
                or M.OfflineText(info)
        else
            sub = T("Flüstern")
        end
    elseif view == "guild" and type(GetNumGuildMembers) == "function" then
        local total, online = Call(GetNumGuildMembers)
        if total and total > 0 then sub = T("%d von %d online", online or 0, total) end
    elseif view == "system" then
        sub = T("Meldungen von WoW und Addons")
    elseif not chatType then
        sub = T("nur lesen")
    else
        local tab = Chat:Tab(view)
        local kind = tab and tab.send and Chat.kindByKey[tab.send]
        if kind then sub = T("schreibt in: %s", T(kind.label)) end
    end
    if M.IsMuted(view) then sub = (sub ~= "" and (sub .. "  ·  ") or "") .. T("stumm") end
    self.headSub:SetText(sub)
    self.headMenu:SetShown(whisper and ONE.PlayerMenu ~= nil)
    if self.headHit then self.headHit:SetShown(whisper and true or false) end
    if self.headClose then self.headClose:SetShown(whisper) end
    local to = whisper and c.whisper or (chatType and M.SendLabel(view)) or nil
    if self.placeholder then
        self.placeholder:SetText(to and T("Nachricht an %s …", to) or T("Hier kann man nur lesen."))
    end
    if self.UpdatePlaceholder then self.UpdatePlaceholder() end
end
function M.SendLabel(view)
    local tab = Chat:Tab(view)
    local kind = tab and tab.send and Chat.kindByKey[tab.send]
    return kind and T(kind.label) or M.ViewTitle(view)
end

-- ===== Anordnen (breit / schmal) =====
function M:IsNarrow()
    local w = self.frame and self.frame:GetWidth()
    return type(w) == "number" and w < NARROW_W
end
function M:Layout()
    local f = self.frame
    if not f then return end
    local list, main = self.list, self.main
    -- Noch im Aufbau (Teile fehlen): nichts anordnen
    if not (list and main and self.back and self.head and self.headAv) then return end
    local narrow = self:IsNarrow()
    main:ClearAllPoints()
    list:ClearAllPoints()
    if narrow then
        list:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -TITLE_H)
        list:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 8)
        main:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -TITLE_H)
        main:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 8)
        if self.page == "chat" then list:Hide() main:Show() else list:Show() main:Hide() end
    else
        list:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -TITLE_H)
        list:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 8)
        list:SetWidth(LIST_W)
        main:SetPoint("TOPLEFT", list, "TOPRIGHT", 8, 0)
        main:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 8)
        list:Show() main:Show()
    end
    self.back:SetShown(narrow)
    self.headAv:ClearAllPoints()
    self.headAv:SetPoint("LEFT", self.head, "LEFT", narrow and 26 or 4, 0)
    if self.sendButton then self.sendButton:SetWidth(narrow and 54 or 62) end
    if self.settingsPanel and self.settingsPanel:IsShown() and UI.LayoutSettingsPanel then UI:LayoutSettingsPanel() end
    self:LayoutList()
    self:LayoutLog()
    if self.picker and self.picker:IsShown() then self:FillPicker() end
end

-- ===== Fenster =====
function M:Paint()
    local p = self:Palette()
    if self.title then self.title:SetTextColor(p.title[1], p.title[2], p.title[3]) end
end
function M:ApplyLook()
    local f, s = self.frame, Chat:Settings()
    if not f then return end
    local G = ONE.Glass
    for _, sf in ipairs(self.surfaces or {}) do if G and G.Paint then G:Paint(sf) end end
    f:SetMovable(not s.locked)
    local idle = tonumber(s.idleAlpha) or 1
    if idle >= 1 then
        f:SetScript("OnUpdate", nil)
        f:SetAlpha(1)
    else
        f.__fadeWait = 0
        f:SetScript("OnUpdate", function(frame, elapsed) UI:FadeStep(frame, elapsed or 0) end)
    end
end
function M:Refresh()
    if not (self.frame and self.frame:IsShown()) then return end
    self:LayoutList()
    self:RefreshHead()
end

-- Gespraech zeigen (und Fenster oeffnen). Entwurf des alten Gespraechs merken, "neue Nachrichten" setzen.
function M:ShowView(view)
    self:Build()
    local old = UI.current
    if view and view ~= old then
        Chat.drafts = Chat.drafts or {}
        if self.input and old then
            local t = self.input:GetText() or ""
            Chat.drafts[old] = t ~= "" and t or nil
        end
        if self.input then self.input:SetText(Chat.drafts[view] or "") end
        UI.current = view
        self.scroll, self.newBelow, self.highlight = 0, 0, nil
        self.newFrom[old or ""] = nil
        if self.picker then self.picker:Hide() end
    end
    if not (Chat:Tab(UI.current) or (UI.current or ""):sub(1, 2) == "w:") then UI.current = "guild" end
    if view then self.page = "chat" end
    local cur = UI.current
    local n = Chat.unread[cur] or 0
    if n > 0 then self.newFrom[cur] = #Chat:Buffer(cur) - n + 1 end
    Chat.current, Chat.visible = cur, true
    Chat:MarkRead(cur)
    self.frame:Show()
    self:ApplyLook()
    self:Layout()
    self:Render()
    self:Refresh()
    if self.UpdatePlaceholder then self.UpdatePlaceholder() end
    if ONE.MinimapButton and ONE.MinimapButton.ClearAlert then pcall(ONE.MinimapButton.ClearAlert, ONE.MinimapButton, "chat") end
end
function M:Hide()
    if self.frame then self.frame:Hide() end
    Chat.visible = false
end

-- Neue Nachricht (update = Haken/nicht zugestellt an einer schon gezeigten Nachricht)
function M:OnMessage(entry, views, update)
    local shown = self.frame and self.frame:IsShown()
    if shown then
        if Chat:Settings().wakeOnMessage ~= false then UI:WakeUp() end
        local here = false
        for _, v in ipairs(views or {}) do if v == UI.current then here = true end end
        -- im schmalen Fenster auf der Liste: Gespraech gilt nicht als gelesen
        if here and self:IsNarrow() and self.page ~= "chat" then
            here = false
            if not update and not entry.inform then Chat.unread[UI.current] = (Chat.unread[UI.current] or 0) + 1 end
        end
        if here then
            Chat:MarkRead(UI.current)
            if not update and (self.scroll or 0) > 0 then
                self.newBelow = (self.newBelow or 0) + 1
                -- Blick bleibt, wo er ist
                self.scroll = self.scroll + 1
            end
            self:Render()
        end
        self:Refresh()
    end
    if update then return end
    local sound = Chat:SoundFor(entry, views)
    if sound then Chat:PlaySound(sound) end
    if entry.kind == "whisper" and not entry.inform then
        local s = Chat:Settings()
        if s.blink and type(FlashClientIcon) == "function" then pcall(FlashClientIcon) end
        if not shown and ONE.MinimapButton and ONE.MinimapButton.SetAlert then
            pcall(ONE.MinimapButton.SetAlert, ONE.MinimapButton, "chat", T("Neue Flüsternachricht von %s", Short(entry.author)), "chat")
        end
    end
end

-- Neues Fluestergespraech: Name eingeben
function M:AskWhisper()
    self:Build()
    if not self.askBox then
        local ok, b = pcall(CreateFrame, "EditBox", nil, self.list, "InputBoxTemplate")
        if not ok or not b then b = CreateFrame("EditBox", nil, self.list) end
        b:SetPoint("TOPLEFT", self.searchBox, "TOPLEFT", 0, 0)
        b:SetPoint("BOTTOMRIGHT", self.searchBox, "BOTTOMRIGHT", 0, 0)
        if b.SetFrameLevel and self.list.GetFrameLevel then b:SetFrameLevel((self.list:GetFrameLevel() or 1) + 30) end
        b:SetAutoFocus(true)
        b.hint = Text(b, "GameFontDisableSmall")
        b.hint:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 2, -2)
        b.hint:SetText(T("Name eingeben, Enter"))
        b:SetScript("OnEnterPressed", function(box)
            local name = (box:GetText() or ""):match("^%s*(.-)%s*$")
            box:SetText("") box:Hide()
            if name ~= "" then M.page = "chat" M:ShowView(Chat:OpenWhisper(name)) if M.input then M.input:SetFocus() end end
        end)
        b:SetScript("OnEscapePressed", function(box) box:SetText("") box:Hide() end)
        b:SetScript("OnEditFocusLost", function(box) box:Hide() end)
        self.askBox = b
    end
    self.askBox:Show()
    self.askBox:SetFocus()
end
