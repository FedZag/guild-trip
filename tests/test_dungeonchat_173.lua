-- Dungeon-Namen im Chat (ChatNames.lua): Namen und Kuerzel werden zum Guild-Trip-Link, Wortgrenzen,
-- vorhandene Links bleiben, Tooltip-Zeilen, Klick waehlt den Dungeon; alle drei Chat-Ansichten binden es ein.
local root = arg[1] or "src"
_G.ProjectONE = {T = nil, features = {}}
local ONE = _G.ProjectONE
local level = 20
local status = {}
assert(loadfile(root .. "/ONE_Core/LinkTips.lua"))("ONE_Core", {})
local LT = ONE.LinkTips
local dungeons = {}
assert(loadfile(root .. "/ONE_Dungeons/Catalog.lua"))("ONE_Dungeons", dungeons)
dungeons.Model = {
    PlayerLevel = function() return level end,
    Difficulty = function(_, min, max, l)
        if l < min then return "hard", {1, 0, 0} end
        if l <= max then return "fit", {1, .82, 0} end
        return "trivial", {.6, .6, .6}
    end,
    Status = function(_, q) return status[q.id] or "open" end,
    Dungeons = function()
        local out = {}
        for _, e in ipairs(dungeons.Catalog) do
            if e.faction ~= "Alliance" then
                local quests = e.key == "dm" and {{id = 1}, {id = 2}, {id = 3}} or {}
                out[#out + 1] = {key = e.key, entry = e, name = e.name, en = e.en, min = e.min, max = e.max, quests = quests, hasData = e.quests ~= nil}
            end
        end
        return out
    end,
}
assert(loadfile(root .. "/ONE_Dungeons/ChatNames.lua"))("ONE_Dungeons", dungeons)
local DC = dungeons.ChatNames
assert(ONE.DungeonChat == DC)
assert(LT.handlers.gtdungeon and LT.handlers.gtdungeon.plain, "Link-Art angemeldet")
assert(LT.Mark("LFG SFK"):find("|Hgtdungeon:sfk|h", 1, true), "Marker angemeldet")

local function keys(text)
    local out = {}
    for k in DC.Mark(text):gmatch("|Hgtdungeon:([%w_]+)|h") do out[#out + 1] = k end
    return table.concat(out, ",")
end
assert(keys("LFG Todesminen, brauche noch Heiler") == "dm")
assert(keys("wer kommt mit SFK und danach rfc?") == "sfk,rfc")
assert(keys("Burg Shadowfang heute?") == "sfk", "laengerer Name gewinnt, kein Doppel")
assert(keys("Untere Blackrockspitze 2 DD gesucht") == "lbrs")
assert(keys("LF Höhlen des Wehklagens") == "wc")
assert(keys("WC run") == "wc")
assert(keys("muss mal aufs wc") == "", "zweibuchstabige Kuerzel nur gross")
assert(keys("ich sm das mal") == "")
assert(keys("Stratholme, Mara oder BRD?") == "stratlive,mara,brd")
assert(keys("Düsterbruch Tribut") == "dme")
assert(keys("Dramatisch") == "", "keine Treffer mitten im Wort (dm/rfc)")
assert(keys("Smaragd") == "")
assert(keys("bin in Dalaran") == "", "Dalaran = Stadt")
assert(keys("Gnomeregan-Run") == "gnomer", "Bindestrich ist Wortgrenze")
-- vorhandener Link bleibt unberuehrt, Text daneben wird markiert
local item = "|cff0070dd|Hitem:1234::::::::20:::::|h[Todesminen-Klinge]|h|r"
local marked = DC.Mark(item .. " aus DM")
assert(marked:sub(1, #item) == item, "Link veraendert")
assert(select(2, marked:gsub("|Hgtdungeon:", "")) == 1)
-- Text bleibt lesbar: ohne Codes derselbe Wortlaut
local plain = DC.Mark("LFG Todesminen"):gsub("|H.-|h", ""):gsub("|h", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
assert(plain == "LFG Todesminen")
-- abgeschaltet: nichts markiert
ONE.FeatureOn = function(_, id) return id ~= "dungeons.chatNames" end
assert(DC.Mark("LFG Todesminen") == "LFG Todesminen")
ONE.FeatureOn = nil

-- Tooltip-Zeilen
local lines = DC.Lines("dm")
assert(lines[1][1]:find("Todesminen") and lines[1][1]:find("Deadmines"))
assert(lines[2][1]:find("passt zu deiner Stufe"))
assert(lines[3][1]:find("3 offen"))
status = {[1] = "log", [2] = "done"}
assert(DC.Lines("dm")[3][1]:find("2 offen, davon 1 im Questlog"))
status = {[1] = "done", [2] = "done", [3] = "done"}
assert(DC.Lines("dm")[3][1]:find("Alle 3"))
level = 10
assert(DC.Lines("dm")[2][1]:find("zu schwer"))
assert(DC.Lines("stocks")[2][1]:find("anderen Fraktion"), "Allianz-Dungeon fuer Horde")
assert(DC.KeyOf("gtdungeon:sfk") == "sfk" and not DC.IsLink("item:5"))

-- Tooltip fuellen
local tt = {rows = {}}
function tt:SetText(t) self.rows[#self.rows + 1] = t end
function tt:AddLine(t) self.rows[#self.rows + 1] = t end
function tt:Show() self.shown = true end
assert(DC.Tip(tt, "gtdungeon:dm") and tt.shown and #tt.rows >= 3)
assert(not DC.Tip(tt, "item:1"))

-- Klick: Dungeon-Seite mit Auswahl
dungeons.Page = {Refresh = function(self) self.refreshed = true end}
local nav
ONE.UI = {Show = function() end, Navigate = function(_, id) nav = id end}
assert(DC.Open("gtdungeon:brd") and nav == "dungeons" and dungeons.Page.wantKey == "brd" and dungeons.Page.refreshed)

-- Einbindung: alle Ansichten markieren nur die Anzeige, Klick/Umschalt nie an SetItemRef
local function src(p) return assert(io.open(root .. p)):read("*a") end
local m, r, ui, chat, page = src("/ONE_Chat/Messenger.lua"), src("/ONE_Chat/Rail.lua"), src("/ONE_Chat/ChatUI.lua"), src("/ONE_Chat/Chat.lua"), src("/ONE_Dungeons/Page.lua")
assert(m:find("text = M.Marked(text)", 1, true), "Fenster/Randleiste: Anzeige markiert")
assert(m:find("M.LinksIn(M.Marked(text))", 1, true) and m:find("M.SetTip(GameTooltip, l.link)", 1, true))
assert(r:find("M().SetTip(GameTooltip, l.link)", 1, true), "Randleiste: Tooltip")
assert(chat:find("ONE.LinkTips.Mark(text)", 1, true), "Klassisch: Anzeige markiert")
assert(ui:find("local own = LT and LT.Open and LT.Open(link)", 1, true), "Klick abgefangen")
assert(ui:find("if LT and LT.IsPlain and LT.IsPlain(link) then", 1, true), "Umschalt+Klick sendet keinen Link")
assert(page:find("Page.wantKey", 1, true))
assert(src("/ONE_Dungeons/ONE_Dungeons.toc"):find("ChatNames.lua", 1, true))
-- gesendeter/kopierter Text bleibt roh
assert(m:find('M.input:SetText(tostring(e.text or ""))', 1, true))
print("OK test_dungeonchat_173")
