-- Ultimate Priest Assistant - BuffPanel
-- Rappels d'ameliorations : une tuile par amelioration surveillee.
--   contour rouge  : absente
--   contour orange : expiration proche
--   clic gauche    : la lance sur soi
-- Ce fichier cree des cadres securises. Leurs attributs et leur visibilite ne
-- changent que hors combat ; un changement demande en combat est applique a
-- la fin du combat.

local _, ns = ...

local BuffPanel = ns:NewModule("BuffPanel")
local Style = ns.Style
local L = ns.L

local TILE, GAP = 32, 5
local ALERT_COLOR = {
	missing = { 0.82, 0.26, 0.18 },
	expiring = { 0.88, 0.54, 0.16 },
}
local buttons = {}
local layoutDirty = false

local function CreateTile(index, parent)
	local button = CreateFrame("Button", "UPABuffButton" .. index, parent, "SecureActionButtonTemplate")
	button:SetSize(TILE, TILE)
	button:SetPoint("LEFT", parent, "LEFT", (index - 1) * (TILE + GAP), 0)
	button:RegisterForClicks("AnyUp", "AnyDown")
	button:SetAttribute("unit", "player")

	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetAllPoints()
	button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	button.border = Style.AddBorder(button, 1, 1, "OVERLAY")
	local highlight = button:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetAllPoints()
	highlight:SetColorTexture(1, 1, 1, 0.15)

	button.time = button:CreateFontString(nil, "OVERLAY")
	Style.SetFont(button.time, 11)
	button.time:SetPoint("BOTTOM", 0, 1)

	button:HookScript("OnEnter", function(self)
		if self.buff then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:AddLine(self.buff.name)
			GameTooltip:AddLine(L.TIP_CAST_SELF, 0.6, 0.6, 0.6)
			GameTooltip:Show()
		end
	end)
	button:HookScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	return button
end

-- Partie protegee : attributs et visibilite des boutons. Hors combat seulement.
local function ApplyLayout()
	if ns.API.InCombat() then
		layoutDirty = true
		return
	end
	layoutDirty = false
	local list = ns.Buffs:GetList()
	for index, button in ipairs(buttons) do
		local buff = list[index]
		button.buff = buff
		if buff then
			-- Une forme a bascule active n'est pas armee : le clic la retirerait.
			local armed = not (buff.toggle and buff.active)
			button:SetAttribute("type1", armed and "spell" or nil)
			button:SetAttribute("spell", buff.name)
			button:Show()
		else
			button:SetAttribute("type1", nil)
			button:Hide()
		end
	end
end

-- Partie libre : apparence, modifiable a tout moment.
local function UpdateVisuals(_, _, list, uncertain)
	for index, button in ipairs(buttons) do
		local buff = list[index]
		if buff and button.buff == buff then
			button.icon:SetTexture(buff.icon)
			button.icon:SetDesaturated(not buff.active)
			local color = ALERT_COLOR[buff.alert]
			if color then
				button.border:SetColor(color[1], color[2], color[3], 1)
			else
				button.border:SetColor(0, 0, 0, 1)
			end
			if buff.active and buff.seconds then
				button.time:SetFormattedText(L.MINUTES_SHORT, math.ceil(buff.seconds / 60))
			else
				button.time:SetText("")
			end
			-- En combat, l'etat affiche est le dernier connu : tuile attenuee.
			button.icon:SetAlpha(uncertain and 0.55 or 1)
		end
	end
	-- L'armement des formes a bascule depend de l'etat lu.
	if not uncertain then
		ApplyLayout()
	end
end

local function Build()
	local group = ns.UI.groups.buffs
	for index = 1, #ns.Data.Buffs do
		buttons[index] = CreateTile(index, group)
	end
	ApplyLayout()
	UpdateVisuals(nil, nil, ns.Buffs:GetList(), ns.Buffs:IsUncertain())
end

function BuffPanel:OnEnable()
	ns.Events:On("UPA_BUFFS_UPDATE", self, UpdateVisuals)
	ns.Events:On("UPA_BUFFS_CHANGED", self, function()
		if #buttons > 0 then
			ApplyLayout()
		end
	end)
	ns.Events:Register("PLAYER_REGEN_ENABLED", self, function()
		if #buttons == 0 then
			Build()
		elseif layoutDirty then
			ApplyLayout()
			UpdateVisuals(nil, nil, ns.Buffs:GetList(), ns.Buffs:IsUncertain())
		end
	end)
	-- Des cadres securises ne se creent pas en combat : on attend la fin.
	if not ns.API.InCombat() then
		Build()
	end
end
