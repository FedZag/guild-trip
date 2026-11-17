-- Offline-Test 0.7.0: Gilden-Auftragsbrett.
local root = arg[1] or "src"
local function Region(kind, parent)
    local r = {kind = kind, parent = parent, shown = true, scripts = {}, txt = ""}
    setmetatable(r, {__index = function(_, k)
        if type(k) == "string" and k:match("^%u") and not k:match("^Get") and not k:match("^Is") then return function() end end
    end})
    function r:SetText(t) self.text = t self.txt = t end
    function r:GetText() return self.txt end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:IsShown() return self.shown end
    function r:GetParent() return self.parent end
    function r:SetScript(e, fn) self.scripts[e] = fn end
    function r:CreateTexture() return Region("Texture", self) end
    function r:CreateFontString() return Region("FontString", self) end
    return r
end
CreateFrame = function(kind, _, parent) return Region(kind, parent) end
UIParent = Region("Frame")
local now = 1000000
GetServerTime = function() return now end
UnitName = function() return "Ich" end
local inGuild = true
IsInGuild = function() return inGuild end
local sent = {}
C_ChatInfo = {SendAddonMessage = function(_, msg, ch) sent[#sent + 1] = msg end,
    RegisterAddonMessagePrefix = function() return true end}
local chat
ChatFrame_OpenChat = function(t) chat = t end
local printed, notes = {}, {}

local ONE = {db = {}, modules = {}}
function ONE:Print(t) printed[#printed + 1] = t end
function ONE:Notify(t) notes[#notes + 1] = t end
_G.ProjectONE = ONE
local started
ONE.modules.guild = {GetPeer = function(_, n) if n == "Bob-Realm" then return {name = "Bob-Realm"} end end}
ONE.modules.nav = {StartTo = function(_, n) started = n end}
local guild = {}
assert(loadfile(root .. "/ONE_Guild/Board.lua"))("ONE_Guild", guild)
local B = guild.Board

-- 1) Einstellen: an die Gilde, im eigenen Speicher
local id = B:Slash("  Brauche 10 Leinenstoff | schnell ")
assert(id == 1 and sent[1] == "B|1|1000000|Brauche 10 Leinenstoff   schnell", sent[1])
assert(B:Post("") == nil)
-- hoechstens 3
B:Post("zwei") B:Post("drei")
assert(select(2, B:Post("vier")) == "full" and #sent == 3)
-- 2) Fremder Auftrag kommt an (mit Hinweis), steht in der Liste und unter "Was steht an"
now = now + 60
B:Receive("ONEBRD1", "B|7|" .. (now - 30) .. "|Wer hilft bei Elite?", "GUILD", "Bob-Realm")
assert(#notes == 1 and notes[1] == "Auftrag von Bob: Wer hilft bei Elite?")
local list = B:List()
assert(#list == 4 and list[1].owner == "Bob" and list[1].text == "Wer hilft bei Elite?", list[1].owner)
local feed = B:Feed()
assert(feed[1].text == "Bob sucht: Wer hilft bei Elite?" and feed[1].sort == 12 and feed[1].navi)
feed[1].navi()
assert(started == "Bob-Realm")
assert(feed[2].text:find("^Dein Auftrag: ") and not feed[2].navi)
-- nochmal derselbe: kein zweiter Hinweis
B:Receive("ONEBRD1", "B|7|" .. (now - 30) .. "|Wer hilft bei Elite?", "GUILD", "Bob-Realm")
assert(#notes == 1)
-- 3) Ich helfe: Nachricht + Fluestern
sent = {}
B:Help(list[1])
assert(sent[1] == "BH|7|Bob" and chat == "/w Bob-Realm Ich helfe dir: Wer hilft bei Elite?", chat)
-- 4) Jemand hilft MIR (nur einmal Hinweis)
B:Receive("ONEBRD1", "BH|1|Ich", "GUILD", "Thrall")
B:Receive("ONEBRD1", "BH|1|Ich", "GUILD", "Thrall")
B:Receive("ONEBRD1", "BH|1|Jemand", "GUILD", "Rehgar") -- nicht an mich
assert(#notes == 2 and notes[2] == "Thrall will dir helfen: Brauche 10 Leinenstoff   schnell")
-- 5) Fenster: Zeilen mit Knopf
B:Open()
local f = B.frame
assert(f.shown and f.rows[1].text.text:find("Bob", 1, true) and f.rows[1].action.text == "Ich helfe")
local mineRow
for _, r in ipairs(f.rows) do if r.entry and r.entry.id == 1 and r.entry.mine then mineRow = r end end
assert(mineRow and mineRow.text.text:find("(1 helfen)", 1, true) and mineRow.action.text == "Erledigt")
-- Erledigt per Knopf
sent = {}
mineRow.action.scripts.OnClick(mineRow.action)
assert(sent[1] == "BX|1" and #B:List() == 3)
-- Eingabe im Fenster
f.edit:SetText("Suche Verzauberer")
f.post.scripts.OnClick()
assert(f.edit.txt == "" and sent[2]:find("|Suche Verzauberer$"))
-- 6) Fremder erledigt; Nachfrage beantworten
B:Receive("ONEBRD1", "BX|7", "GUILD", "Bob-Realm")
assert(#B:List() == 3)
sent = {}
B:Receive("ONEBRD1", "BREQ", "GUILD", "Neu")
assert(#sent == 3, "alle eigenen nochmal schicken")
-- 7) Nach 3 Tagen weg; alte/kaputte/fremde Kanaele ignoriert
now = now + 3 * 86400 + 10
assert(#B:List() == 0)
B:Receive("ONEBRD1", "B|8|" .. (now - 4 * 86400) .. "|alt", "GUILD", "Bob")
B:Receive("ONEBRD1", "B|9|" .. now .. "|x", "WHISPER", "Bob")
B:Receive("ONEBRD1", "Quatsch", "GUILD", "Bob")
B:Receive("ONEBRD1", "B|9|" .. now .. "|eigen", "GUILD", "Ich-Realm")
assert(#B:List() == 0)
-- 8) Ohne Gilde
inGuild = false
assert(select(2, B:Post("x")) == "guild")
-- 9) Gespeichert (ueberlebt /reload)
inGuild = true
B:Post("bleibt")
assert(ONE.db.guild.board.mine[ONE.db.guild.board.nextId - 1].text == "bleibt")
-- 10) Lange Texte werden nicht mitten im Umlaut abgeschnitten
local long = string.rep("a", 79) .. "üb"
local okId = B:Post(long)
local stored = ONE.db.guild.board.mine[okId] and ONE.db.guild.board.mine[okId].text
assert(stored == string.rep("a", 79), "Umlaut nicht zerschnitten: " .. #(stored or ""))
print("OK test_board_107")
