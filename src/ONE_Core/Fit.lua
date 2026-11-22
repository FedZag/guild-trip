local _, ONE = ...

-- Grundregel fuer Texte (22.11.2026, Wunsch: nirgends abgeschnittene Saetze):
--   Fit:Wrap(fs)        Saetze und Hinweise brechen um, das Feld waechst mit (nachfolgende Elemente
--                       haengen an der Unterkante, nicht an festen Hoehen).
--   Fit:Line(fs, hover) Tabellen, Listen, Knoepfe, Namen, kurze Zeilen in festen Kaesten bleiben einzeilig. Passt der Text nicht,
--                       wird die Schrift etwas enger gesetzt (hoechstens 2 Punkte kleiner); reicht
--                       das nicht, zeigt der Tooltip von `hover` den ganzen Text.
-- Einzeilige Texte nur ueber Fit:Line – tests/test_fit_152.lua verbietet SetWordWrap(false) anderswo.
local Fit = {}
ONE.Fit = Fit

Fit.MAX_SHRINK = 2   -- Punkte; kleiner wird es unleserlich
Fit.MIN_SIZE = 9

local function Truncated(fs)
    if fs.IsTruncated then
        local ok, t = pcall(fs.IsTruncated, fs)
        if ok and t ~= nil then return t and true or false end
    end
    local w = fs.GetWidth and fs:GetWidth() or 0
    local sw = fs.GetStringWidth and fs:GetStringWidth() or 0
    return w > 0 and sw > w + .5
end
Fit.Truncated = Truncated

-- Schrift zurueck auf die eigene Groesse, dann – falls noetig – Schritt fuer Schritt enger
local function Shrink(fs)
    if not (fs.GetFont and fs.SetFont) then return end
    if fs.__fitBase then
        local b = fs.__fitBase
        pcall(fs.SetFont, fs, b[1], b[2], b[3])
        fs.__fitBase = nil
    end
    if not Truncated(fs) then return end
    local ok, path, size, flags = pcall(fs.GetFont, fs)
    if not ok or not path or type(size) ~= "number" then return end
    fs.__fitBase = {path, size, flags}
    local s = size
    while Truncated(fs) and s > math.max(Fit.MIN_SIZE, size - Fit.MAX_SHRINK) do
        s = s - 1
        pcall(fs.SetFont, fs, path, s, flags)
    end
end
Fit.Shrink = Shrink

-- steht der Text schon im offenen Tooltip? (z. B. eigener Tooltip mit vollem Namen)
local function InTooltip(text)
    local n = GameTooltip.NumLines and GameTooltip:NumLines() or 0
    for i = 1, n do
        local line = _G["GameTooltipTextLeft" .. i]
        local t = line and line.GetText and line:GetText()
        if t and (t == text or t:find(text, 1, true)) then return true end
    end
    return false
end

-- Tooltip-Ergaenzung: alle gekuerzten Texte dieses Bereichs voll anzeigen. Haengt sich hinter das
-- eigene OnEnter des Bereichs: steht dort schon ein Tooltip, kommt der volle Text als Zeile dazu.
local function OnEnter(self)
    if not GameTooltip then return end
    local full = {}
    for _, fs in ipairs(self.__fitTexts or {}) do
        local shown = not fs.IsVisible or fs:IsVisible()
        local text = fs.GetText and fs:GetText()
        if shown and type(text) == "string" and text ~= "" and Truncated(fs) then full[#full + 1] = text end
    end
    if #full == 0 then return end
    local owned = GameTooltip.IsOwned and GameTooltip:IsOwned(self) and GameTooltip:IsShown()
    if not owned then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(full[1], 1, 1, 1, 1, true)
        for i = 2, #full do GameTooltip:AddLine(full[i], 1, 1, 1, true) end
    else
        local added = false
        for _, t in ipairs(full) do
            if not InTooltip(t) then GameTooltip:AddLine(t, 1, 1, 1, true) added = true end
        end
        if not added then return end
    end
    GameTooltip:Show()
end
Fit.OnEnter = OnEnter
local function OnLeave(self)
    if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
end

-- Tooltip-Ergaenzung: alle gekuerzten Texte dieses Bereichs voll anzeigen. Haengt sich hinter das
-- eigene OnEnter des Bereichs (auch wenn das erst spaeter mit SetScript gesetzt wird): steht dort
-- schon ein Tooltip, kommt der volle Text als Zeile dazu.
local function AddHover(hover)
    if hover.__fitHooked or not hover.HookScript then return end
    hover.__fitHooked = true
    if not hover.__fitOverlayOf and hover.EnableMouse and hover.IsMouseEnabled and not hover:IsMouseEnabled() then
        hover:EnableMouse(true)
        if hover.SetPropagateMouseClicks then pcall(hover.SetPropagateMouseClicks, hover, true) end
    end
    hover:HookScript("OnEnter", OnEnter)
    hover:HookScript("OnLeave", OnLeave)
    local setScript = hover.SetScript
    if type(setScript) == "function" then
        hover.SetScript = function(self, event, fn, ...)
            local r = setScript(self, event, fn, ...)
            if event == "OnEnter" then self:HookScript("OnEnter", OnEnter)
            elseif event == "OnLeave" then self:HookScript("OnLeave", OnLeave) end
            return r
        end
    end
end

local function HookText(fs)
    if fs.__fitWrapped then return end
    fs.__fitWrapped = true
    for _, name in ipairs({"SetText", "SetFormattedText"}) do
        local orig = fs[name]
        if type(orig) == "function" then
            fs[name] = function(self, ...)
                if self.__fitBase then
                    local b = self.__fitBase
                    pcall(self.SetFont, self, b[1], b[2], b[3])
                    self.__fitBase = nil
                end
                local r = orig(self, ...)
                if self.__fitLine then Shrink(self) end
                if self.__fitOverlay then Fit.RefreshOverlay(self) end
                return r
            end
        end
    end
end

function Fit.RefreshOverlay(fs)
    local o = fs and fs.__fitOverlay
    if o and o.EnableMouse then o:EnableMouse(fs.__fitLine and Truncated(fs) or false) end
end

-- Unsichtbare Flaeche genau ueber dem Text (fuer freistehende Zeilen ohne eigenen Knopf/Zeile)
function Fit.Overlay(fs)
    if fs.__fitOverlay then return fs.__fitOverlay end
    local parent = fs.GetParent and fs:GetParent()
    if not (parent and CreateFrame) then return nil end
    local ok, o = pcall(CreateFrame, "Frame", nil, parent)
    if not ok or not o then return nil end
    o:SetPoint("TOPLEFT", fs, "TOPLEFT", 0, 0)
    o:SetPoint("BOTTOMRIGHT", fs, "BOTTOMRIGHT", 0, 0)
    if o.SetPropagateMouseClicks then pcall(o.SetPropagateMouseClicks, o, true) end
    o.__fitOverlayOf = fs
    -- nimmt die Maus nur an, solange der Text gekuerzt ist (sonst nichts verdecken)
    if o.EnableMouse then o:EnableMouse(false) end
    if o.HookScript then
        o:HookScript("OnShow", function(self) Fit.RefreshOverlay(self.__fitOverlayOf) end)
        o:HookScript("OnSizeChanged", function(self) Fit.RefreshOverlay(self.__fitOverlayOf) end)
    end
    fs.__fitOverlay = o
    return o
end

-- Einzeilig: kein Umbruch, notfalls etwas enger, voller Text im Tooltip von `hover`
-- (Vorgabe: eine unsichtbare Flaeche ueber dem Text; false = kein Tooltip). Liefert fs.
function Fit:Line(fs, hover)
    if not fs then return fs end
    if fs.SetWordWrap then fs:SetWordWrap(false) end
    if fs.SetMaxLines then pcall(fs.SetMaxLines, fs, 1) end
    HookText(fs)
    -- spaeter doch umbrechen (z. B. Text-Helfer, danach SetWordWrap(true)): dann wirklich umbrechen
    if not fs.__fitWrapHook and type(fs.SetWordWrap) == "function" then
        fs.__fitWrapHook = true
        local setWrap = fs.SetWordWrap
        fs.SetWordWrap = function(self, on, ...)
            local r = setWrap(self, on, ...)
            if on then
                self.__fitLine = nil
                if self.SetMaxLines then pcall(self.SetMaxLines, self, 0) end
            end
            return r
        end
    end
    if hover == nil then
        -- Text auf einem Knopf: der Knopf selbst zeigt den Tooltip (eine Flaeche darueber wuerde Klicks schlucken)
        local parent = fs.GetParent and fs:GetParent()
        local kind = parent and parent.GetObjectType and parent:GetObjectType()
        if kind == "Button" or kind == "CheckButton" then hover = parent else hover = Fit.Overlay(fs) end
    end
    if hover and hover.HookScript then
        hover.__fitTexts = hover.__fitTexts or {}
        local known = false
        for _, f in ipairs(hover.__fitTexts) do if f == fs then known = true end end
        if not known then hover.__fitTexts[#hover.__fitTexts + 1] = fs end
        AddHover(hover)
    end
    fs.__fitLine = true
    return fs
end

-- Umbrechen: Satz bekommt so viele Zeilen wie noetig (keine feste Hoehe, kein "…").
function Fit:Wrap(fs, maxLines)
    if not fs then return fs end
    if fs.SetWordWrap then fs:SetWordWrap(true) end
    if fs.SetNonSpaceWrap then pcall(fs.SetNonSpaceWrap, fs, true) end
    if fs.SetMaxLines then pcall(fs.SetMaxLines, fs, maxLines or 0) end
    if fs.SetHeight then fs:SetHeight(0) end
    if fs.SetJustifyV then fs:SetJustifyV("TOP") end
    fs.__fitWrap = true
    return fs
end

-- Untereinander haengen: jedes Element an die Unterkante des vorigen (waechst ein umbrochener Satz,
-- ruecken die folgenden nach unten). Das erste Element behaelt seinen Platz.
function Fit:Stack(list, gap)
    gap = gap or 4
    for i = 2, #list do
        local prev, cur = list[i - 1], list[i]
        if cur and prev and cur.ClearAllPoints then
            cur:ClearAllPoints()
            cur:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -gap)
        end
    end
end
