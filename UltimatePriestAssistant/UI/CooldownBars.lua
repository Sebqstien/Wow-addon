-- Ultimate Priest Assistant - CooldownBars
-- Barres horizontales des recharges en cours. La barre et le compteur sont
-- animes par le client a partir d'un objet de duree. Les barres suivent
-- l'ordre de la base : un tri par temps restant est impossible, ce temps
-- etant secret en combat.

local _, ns = ...

local CooldownBars = ns:NewModule("CooldownBars")
local Style = ns.Style

local WIDTH, HEIGHT, GAP = 240, 16, 3
local REMAINING = Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime
local IMMEDIATE = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate
local bars = {}        -- cle -> barre
local order = {}       -- cles des techniques ayant une barre, dans l'ordre
local formatter

local function CreateBar(spell)
	local group = ns.UI.groups.bars
	local bar = Style.CreateBar(group, WIDTH - HEIGHT - 2, HEIGHT)
	local color = Style.colors.cooldownBar
	bar:SetStatusBarColor(color[1], color[2], color[3], 0.85)

	bar.icon = bar:CreateTexture(nil, "ARTWORK")
	bar.icon:SetSize(HEIGHT, HEIGHT)
	bar.icon:SetPoint("RIGHT", bar, "LEFT", -2, 0)
	bar.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	bar.icon:SetTexture(spell.icon)

	bar.name = bar:CreateFontString(nil, "OVERLAY")
	Style.SetFont(bar.name, 11)
	bar.name:SetPoint("LEFT", 4, 0)
	bar.name:SetText(spell.name)

	bar.time = bar:CreateFontString(nil, "OVERLAY")
	Style.SetFont(bar.time, 11)
	bar.time:SetPoint("RIGHT", -4, 0)
	bar.binding = ns.API.CreateDurationText(bar.time, formatter)

	bar:Hide()
	return bar
end

-- Empile les barres visibles depuis le haut du groupe.
local function Layout()
	local shown = 0
	for _, key in ipairs(order) do
		local bar = bars[key]
		if bar:IsShown() then
			bar:ClearAllPoints()
			bar:SetPoint("TOPRIGHT", ns.UI.groups.bars, "TOPRIGHT", 0, -shown * (HEIGHT + GAP))
			shown = shown + 1
		end
	end
end

local function UpdateBar(_, _, spell)
	local bar = bars[spell.key]
	if not bar then
		return
	end
	local wasShown = bar:IsShown()
	local duration = spell.status == "cooldown" and ns.Profiles:GetCurrent().showBars
		and ns.API.GetCooldownDuration(spell.id)
	if duration then
		bar:SetTimerDuration(duration, IMMEDIATE, REMAINING)
		bar.binding:SetDuration(duration)
		bar.binding:SetEnabled(true)
		bar:Show()
	else
		bar.binding:SetEnabled(false)
		bar:Hide()
	end
	if wasShown ~= bar:IsShown() then
		Layout()
	end
end

local function Rebuild(_, _, tracked)
	for _, bar in pairs(bars) do
		bar.binding:SetEnabled(false)
		bar:Hide()
	end
	wipe(order)
	for _, spell in ipairs(tracked) do
		if spell.bar then
			if not bars[spell.key] then
				bars[spell.key] = CreateBar(spell)
			end
			bars[spell.key].icon:SetTexture(spell.icon)
			bars[spell.key].name:SetText(spell.name)
			order[#order + 1] = spell.key
		end
	end
end

function CooldownBars:OnEnable()
	formatter = ns.API.CreateDurationFormatter()
	ns.Events:On("UPA_SPELLS_CHANGED", self, Rebuild)
	ns.Events:On("UPA_SPELL_UPDATE", self, UpdateBar)
	local tracked = ns.Cooldowns:GetTracked()
	Rebuild(nil, nil, tracked)
	for _, spell in ipairs(tracked) do
		UpdateBar(nil, nil, spell)
	end
end
