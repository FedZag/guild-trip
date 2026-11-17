-- Regression: GetNumGuildMembers liefert mehrere Werte (Fehler 'base out of range' in 0.4.3a).
local root = arg[1] or "src"
IsInGuild = function() return true end
GetNumGuildMembers = function() return 65, 23, 23 end
GetGuildRosterInfo = function(i)
    return "Spieler" .. i, "Rang", 1, 20, "Krieger", "Durotar", "", "", i <= 23, 0, "WARRIOR"
end
_G.ProjectONE = {}
local guild = {}
assert(loadfile(root .. "/ONE_Guild/Roster.lua"))("ONE_Guild", guild)
assert(#guild.Roster:Members() == 65)
assert(guild.Roster:OnlineCount() == 23)
GetNumGuildMembers = function() return 3, 1, 1 end
assert(#guild.Roster:Members() == 3, "auch mit 1 online (frueher: base out of range)")
print("OK: 0.4.3b - Gildenliste mit mehreren Rueckgabewerten")
