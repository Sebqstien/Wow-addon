-- Ultimate Rogue Assistant - EnergyBar
-- Barre d'energie. La valeur est secrete : elle va directement de l'API aux
-- widgets (barre, texte), et la couleur par seuil est choisie par le client a
-- travers une courbe. Aucune comparaison n'est faite en Lua.

local _, ns = ...

local EnergyBar = ns:NewModule("EnergyBar")
local Style = ns.Style

local WIDTH, HEIGHT = 240, 18
local bar, text, curve
local ticks = {}
local SMOOTH = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut

local function BuildCurve()
	local settings = ns.Profiles:GetCurrent().energy
	local low = ns.Helpers.Clamp(settings.low, 1, 98) / 100
	local mid = ns.Helpers.Clamp(settings.mid, settings.low + 1, 99) / 100
	local function Color(name)
		local color = Style.ProfileColor(name)
		return CreateColor(color[1], color[2], color[3], 1)
	end
	curve = ns.API.CreateStepColorCurve({
		{ 0, Color("energyLow") },
		{ low, Color("energyMid") },
		{ mid, Color("energy") },
	})
	ticks[1]:SetPoint("LEFT", bar, "LEFT", WIDTH * low, 0)
	ticks[2]:SetPoint("LEFT", bar, "LEFT", WIDTH * mid, 0)
end

local function Update()
	local value, maxValue = ns.API.GetEnergy()
	bar:SetMinMaxValues(0, maxValue)
	bar:SetValue(value, SMOOTH)
	text:SetFormattedText("%d", value)
	local color = ns.API.GetEnergyColor(curve)
	bar:GetStatusBarTexture():SetVertexColor(color:GetRGB())
end

function EnergyBar:OnEnable()
	local group = ns.UI.groups.resources
	bar = Style.CreateBar(group, WIDTH, HEIGHT)
	bar:SetPoint("TOP")

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
	ns.Events:On("URA_ENERGY_UPDATE", self, Update)
	Update()
end

function EnergyBar:OnProfileChanged()
	if bar then
		BuildCurve()
		Update()
	end
end
