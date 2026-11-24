-- Guild Trip: Zusatzzeilen in Link-Tooltips (Chat-Ideen 24.11.2026: "Guild Trip weiss mehr als ein Chat-Addon").
-- Module melden sich an: ONE.LinkTips:Register(id, fn). fn(link, kind) gibt nil oder
-- {lines = {{text, r, g, b}, ...}, button = {label = "...", run = function() end}} zurueck.
-- Gilt ueberall gleich, weil alle Chat-Ansichten denselben Weg nehmen:
--  * Maus ueber einem Link (Fenster, Randleiste): GameTooltip:SetHyperlink
--  * Klick auf einen Link (Fenster, Randleiste, Klassisch, auch WoW-Chat): SetItemRef -> ItemRefTooltip:SetHyperlink
-- Der Knopf (z. B. "Navi zum Start") haengt nur unter dem angeklickten Tooltip – nur der laesst sich anklicken.
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local LT = {providers = {}}
ONE.LinkTips = LT

function LT:Register(id, fn)
    if type(id) ~= "string" or type(fn) ~= "function" then return false end
    for _, p in ipairs(self.providers) do if p.id == id then p.fn = fn return true end end
    self.providers[#self.providers + 1] = {id = id, fn = fn}
    return true
end

-- "|cff..|Hquest:123:12|h[Name]|h|r" oder "quest:123:12" -> "quest:123:12", "quest"
function LT.Raw(link)
    if type(link) ~= "string" then return nil end
    local raw = link:match("|H([^|]+)|h") or link
    return raw, raw:match("^(%a+):")
end

function LT.Collect(link)
    local raw, kind = LT.Raw(link)
    if not kind then return nil end
    local lines, button = {}, nil
    for _, p in ipairs(LT.providers) do
        local ok, res = pcall(p.fn, raw, kind)
        if ok and type(res) == "table" then
            for _, l in ipairs(res.lines or {}) do lines[#lines + 1] = l end
            if not button and type(res.button) == "table" and type(res.button.run) == "function" then button = res.button end
        end
    end
    if #lines == 0 and not button then return nil end
    return {lines = lines, button = button}
end

function LT:Button(tt)
    if self.button then return self.button end
    local b = CreateFrame("Button", nil, tt, "UIPanelButtonTemplate")
    b:SetHeight(22)
    b:SetPoint("TOPLEFT", tt, "BOTTOMLEFT", 0, -2)
    b:SetScript("OnClick", function(btn)
        local run = btn.run
        if run then pcall(run) end
    end)
    b:Hide()
    self.button = b
    return b
end

function LT.SetButton(tt, def)
    local b = LT:Button(tt)
    if not def then b.run = nil b:Hide() return end
    b.run = def.run
    b:SetText(def.label or T("Los"))
    local fs = b.GetFontString and b:GetFontString()
    local w = fs and fs.GetStringWidth and fs:GetStringWidth() or 80
    b:SetWidth(math.max(90, w + 24))
    b:Show()
end

function LT.Apply(tt, link)
    if not tt then return end
    local res = LT.Collect(link)
    if res and #res.lines > 0 and tt.AddLine then
        for _, l in ipairs(res.lines) do tt:AddLine(l[1], l[2] or 1, l[3] or 1, l[4] or 1, true) end
        if tt.Show then tt:Show() end
    end
    if tt == rawget(_G, "ItemRefTooltip") then LT.SetButton(tt, res and res.button) end
end

function LT:Install()
    if self.installed or type(hooksecurefunc) ~= "function" then return end
    self.installed = true
    for _, name in ipairs({"GameTooltip", "ItemRefTooltip"}) do
        local tt = rawget(_G, name)
        if type(tt) == "table" and type(tt.SetHyperlink) == "function" then
            hooksecurefunc(tt, "SetHyperlink", function(self, link) pcall(LT.Apply, self, link) end)
        end
    end
    local ref = rawget(_G, "ItemRefTooltip")
    if type(ref) == "table" and ref.HookScript then
        ref:HookScript("OnHide", function() if LT.button then LT.button.run = nil LT.button:Hide() end end)
    end
end
pcall(LT.Install, LT)
