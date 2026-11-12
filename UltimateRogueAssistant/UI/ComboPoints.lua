-- Ultimate Rogue Assistant - UI/ComboPoints
-- Une mini-barre par point, bornee a [i-1, i] : le client remplit la barre i
-- quand la valeur atteint i. Ce montage fonctionne meme si la valeur etait
-- secrete. Les effets (point gagne, maximum atteint) n'utilisent que l'etat
-- lisible fourni par le module ComboPoints.

local _, ns = ...

local ComboPointsUI = ns:NewModule("ComboPointsUI")
local Style = ns.Style

local WIDTH, HEIGHT, GAP, COUNT_WIDTH = 240, 12, 4, 20
local container, countText
local pips = {}
local shownMax = 0

local function Layout(max)
	shownMax = max
	local pipWidth = (WIDTH - COUNT_WIDTH - GAP * (max - 1)) / max
	for i = 1, max do
		local pip = pips[i]
		if not pip then
			pip = Style.CreateBar(container, pipWidth, HEIGHT)
			pip:SetMinMaxValues(i - 1, i)
			pip.pulse = ns.Animations.CreatePulse(pip, 1.25, 0.28)
			pips[i] = pip
		end
		pip:SetWidth(pipWidth)
		pip:ClearAllPoints()
		pip:SetPoint("LEFT", container, "LEFT", (i - 1) * (pipWidth + GAP), 0)
		pip:Show()
	end
	for i = max + 1, #pips do
		pips[i]:Hide()
	end
end

local function Update(_, _, state)
	if state.max ~= shownMax then
		Layout(state.max)
	end
	local color = Style.ProfileColor(state.full and "finisher" or "combo")
	for i = 1, shownMax do
		pips[i]:SetValue(state.points)
		pips[i]:SetStatusBarColor(color[1], color[2], color[3])
	end
	countText:SetText(state.points)
	countText:SetTextColor(color[1], color[2], color[3])
	if state.gained > 0 and pips[state.gained] then
		ns.Animations.Play(pips[state.gained].pulse)
	end
end

function ComboPointsUI:OnProfileChanged()
	if container then
		Update(nil, nil, ns.ComboPoints:GetState())
	end
end

function ComboPointsUI:OnEnable()
	local group = ns.UI.groups.resources
	container = CreateFrame("Frame", nil, group)
	container:SetSize(WIDTH, HEIGHT)
	container:SetPoint("BOTTOM")

	countText = container:CreateFontString(nil, "OVERLAY")
	Style.SetFont(countText, 15)
	countText:SetPoint("RIGHT")

	ns.Events:On("URA_COMBO_UPDATE", self, Update)
	Update(nil, nil, ns.ComboPoints:GetState())
end
