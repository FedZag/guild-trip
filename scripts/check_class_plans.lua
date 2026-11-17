-- Prueft die Leisten-Plaene (ONE_Classes) gegen die Forever-Auslese (ONE_Dev.lua).
-- Aufruf: SV=<Pfad zu ONE_Dev.lua> lua5.1 scripts/check_class_plans.lua [KLASSE]
local classes = {}
_G.ProjectONE = {}
assert(loadfile("src/ONE_Classes/Data.lua"))(nil, classes)
assert(loadfile("src/ONE_Classes/DataClasses.lua"))(nil, classes)
dofile(assert(os.getenv("SV"), "SV fehlt"))
local scan, cat = GuildTripDevDB.spellScan, GuildTripDevDB.spellCatalog
local only = arg and arg[1]
local WAND = classes.Data.WAND

-- Nummer -> Name aus Katalog (alle Klassen) und allen Zauberbuechern
local names, owner = {}, {}
for cls, list in pairs(cat.classes) do
    for _, e in ipairs(list) do
        names[e.base] = names[e.base] or e.name; owner[e.base] = owner[e.base] or cls
        for _, r in ipairs(e.ranks or {}) do if r.id then names[r.id] = names[r.id] or r.name; owner[r.id] = owner[r.id] or cls end end
    end
end
local book = {}
for key, s in pairs(scan) do
    local cls = s.classFile or key
    book[cls] = book[cls] or {}
    for _, tree in ipairs(s.talents or {}) do
        for _, t in ipairs(tree.talents or {}) do
            if t.spell then names[t.spell] = names[t.spell] or t.name; owner[t.spell] = owner[t.spell] or cls end
        end
    end
    for _, tab in pairs(s.spellbook or {}) do
        for _, sp in pairs(tab.spells or {}) do
            if sp.id then names[sp.id] = names[sp.id] or sp.name; book[cls][sp.name or "?"] = sp.id; book[cls][sp.id] = true end
        end
    end
end

for cls, def in pairs(classes.Data.classes) do
    if not only or only == cls then
        print("== " .. cls)
        local seen = {}
        for spec, b in pairs(def.build) do
            for _, bar in ipairs(b.bars or {}) do
                for _, step in ipairs(bar.slots) do
                    for _, id in ipairs(classes.Data.Ids(step[1])) do
                        if id ~= WAND and not seen[id] then
                            seen[id] = true
                            local n = names[id]
                            local status
                            if book[cls] and book[cls][id] then status = "IM BUCH"
                            elseif n and owner[id] == cls then status = "katalog"
                            elseif n then status = "FREMD(" .. tostring(owner[id]) .. ")"
                            else status = "UNBEKANNT" end
                            if status ~= "IM BUCH" and status ~= "katalog" then
                                print(string.format("  %-10s %7d %-14s %s", status, id, step[2], n or ""))
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Talente: welche Plan-Zauber sind in Forever Talente (und in welchem Baum)?
print("\n== Talente")
for key, s in pairs(scan) do
    local cls = s.classFile or key
    if (not only or only == cls) and not key:find("-") and classes.Data.classes[cls] then
        local tnames = {}
        for _, tree in ipairs(s.talents or {}) do
            for _, t in ipairs(tree.talents or {}) do if t.name then tnames[t.name] = t end end
        end
        local hits = {}
        local def = classes.Data.classes[cls]
        for _, b in pairs(def.build) do for _, bar in ipairs(b.bars or {}) do for _, step in ipairs(bar.slots) do
            for _, id in ipairs(classes.Data.Ids(step[1])) do
                local n = names[id]
                if n and tnames[n] and not hits[n] then hits[n] = true; print(string.format("  %-8s %-28s Talent (max %d)", cls, n, tnames[n].maxRanks or 0)) end
            end
        end end end
    end
end
