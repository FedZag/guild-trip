-- Pruefung: /trip online <Name> (22.11.2026) – warum zeigt der Fluesterchat keinen gruenen Punkt, obwohl die
-- Rezepte-Seite "online" sagt? Gibt aus, wie WoW den Namen in der Gildenliste liefert, und was der Chat daraus
-- macht. Ergebnis auch in GuildTripDevDB.onlineCheck (nach /reload in den SavedVariables lesbar).
local ONE = _G.ProjectONE
local function DevDB() return (ONE.DevDB and ONE:DevDB()) or ONE.db end

local function Run(arg)
    local want = (arg and arg ~= "" and arg or "Staub"):lower()
    local out = {asked = want, roster = {}, at = time and time() or 0}
    local total = type(GetNumGuildMembers) == "function" and GetNumGuildMembers() or 0
    out.total = total
    for i = 1, total or 0 do
        local ok, n, _, _, _, _, _, _, _, online = pcall(GetGuildRosterInfo, i)
        if ok and type(n) == "string" and n:lower():find(want, 1, true) then
            out.roster[#out.roster + 1] = {i = i, name = n, bytes = n:gsub(".", function(c) return c:byte() .. " " end), online = online and true or false}
        end
    end
    local chat = ONE.ns and ONE.ns.chat
    local Chat, M = chat and chat.Chat, chat and chat.Messenger
    out.whispers = {}
    for _, w in ipairs(Chat and Chat.whispers or {}) do
        if tostring(w.name):lower():find(want, 1, true) then
            local info = M and M.PersonInfo and M.PersonInfo(w.name)
            out.whispers[#out.whispers + 1] = {name = w.name, bytes = tostring(w.name):gsub(".", function(c) return c:byte() .. " " end),
                found = info and true or false, online = info and info.online or false}
        end
    end
    local db = DevDB()
    if db then db.onlineCheck = out end
    ONE:Print(("Online-Pruefung '%s': Gildenliste %d Eintraege."):format(want, total or 0))
    for _, r in ipairs(out.roster) do ONE:Print(("  Gildenliste #%d: [%s] %s"):format(r.i, r.name, r.online and "online" or "offline")) end
    if #out.roster == 0 then ONE:Print("  Gildenliste: nicht gefunden") end
    for _, w in ipairs(out.whispers) do
        ONE:Print(("  Fluestern: [%s] gefunden=%s online=%s"):format(w.name, tostring(w.found), tostring(w.online)))
    end
    if #out.whispers == 0 then ONE:Print("  Fluestern: kein Gespraech mit diesem Namen") end
end

ONE:RegisterSlash("online", function(arg) Run(arg) end)
