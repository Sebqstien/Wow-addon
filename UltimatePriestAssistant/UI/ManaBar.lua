-- Ultimate Priest Assistant - ManaBar
-- Barre de mana. La valeur est traitee comme secrete : elle va directement de
-- l'API aux widgets (barre, texte), et la couleur par seuil est choisie par le
-- client a travers une courbe. Aucune comparaison n'est faite en Lua.

local _, ns = ...

local ManaBar = ns:NewModule("ManaBar")
local Style = ns.Style

local WIDTH, HEIGHT = 240, 18
local bar, text, curve
local ticks = {}
local SMOOTH = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut

local function BuildCurve()
	local settings = ns.Profiles:GetCurrent().mana
	local low = ns.Helpers.Clamp(settings.low, 1, 98) / 100
	local mid = ns.Helpers.Clamp(settings.mid, settings.low + 1, 99) / 100
	local function Color(name)
		local color = Style.ProfileColor(name)
		return CreateColor(color[1], color[2], color[3], 1)
	end
	curve = ns.API.CreateStepColorCurve({
		{ 0, Color("manaLow") },
		{ low, Color("manaMid") },
		{ mid, Color("mana") },
	})
	ticks[1]:SetPoint("LEFT", bar, "LEFT", WIDTH * low, 0)
	ticks[2]:SetPoint("LEFT", bar, "LEFT", WIDTH * mid, 0)
end

local function Update()
	local value, maxValue = ns.API.GetMana()
	bar:SetMinMaxValues(0, maxValue)
	bar:SetValue(value, SMOOTH)
	text:SetFormattedText("%d", value)
	local color = ns.API.GetManaColor(curve)
	bar:GetStatusBarTexture():SetVertexColor(color:GetRGB())
end

function ManaBar:OnEnable()
	local group = ns.UI.groups.resources
	bar = Style.CreateBar(group, WIDTH, HEIGHT)
	bar:SetPoint("CENTER")

	for i = 1, 2 do
		local tick = bar:CreateTexture(nil, "OVERLAY")
		tick:SetSize(1, HEIGHT)
		tick:SetColorTexture(0, 0, 0, 0.6)
		ticks[i] = tick
	end

	text = bar:CreateFontString(nil, "OVERLAY")
	Style.SetFont(text, 13)
	text:SetPoint("CENTER")

	BuildCurve()
	ns.Events:On("UPA_MANA_UPDATE", self, Update)
	Update()
end

function ManaBar:OnProfileChanged()
	if bar then
		BuildCurve()
		Update()
	end
end
