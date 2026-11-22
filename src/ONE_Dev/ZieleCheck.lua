-- Pruefung: /trip ziele (22.11.2026) – was meldet das Spiel zu den Zielen meiner offenen Quests, und fuer welche
-- Gegner zeigt Guild Trip das Ausrufezeichen? Spieltest: Loewen und Ebenenschreiter fertig ("Chens leeres
-- Faesschen"), Zeichen blieben. Zeigt je Quest Art/erledigt/Text jedes Ziels und "Zeichen: x von y Gegnern".
local ONE = _G.ProjectONE
ONE:RegisterSlash("ziele", function()
    local nav = ONE.ns and ONE.ns.nav
    local Q = rawget(_G, "GuildTripQuestDB")
    local M = nav and nav.MobInfo
    if not (nav and nav.Quests and M and Q and Q.q) then ONE:Print("Ziele: Navi/Questdaten fehlen.") return end
    local n = 0
    for _, q in ipairs(nav.Quests:Log() or {}) do
        if not q.complete and n < 6 then
            n = n + 1
            local e = Q.q[q.id]
            local open = M.OpenTargets(Q, q.id, q.objectives)
            ONE:Print(("[%d] %s – Zeichen: %d von %d Gegnern, Zuordnung %s"):format(q.id, tostring(q.title), #open,
                #(e and e[8] or {}), (Q.obj and Q.obj[q.id]) and "ja" or "nein"))
            for _, o in ipairs(q.objectives or {}) do
                ONE:Print(("   %s %s %s"):format(tostring(o.type), o.finished and "fertig" or "offen", tostring(o.text)))
            end
        end
    end
    if n == 0 then ONE:Print("Ziele: keine offene Quest im Log.") end
end)
