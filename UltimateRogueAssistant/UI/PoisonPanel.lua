-- Ultimate Rogue Assistant - PoisonPanel
-- Panneau des poisons : une tuile par arme.
--   clic gauche : applique le poison choisi sur cette arme
--   clic droit  : ouvre le menu des poisons presents dans les sacs
-- C'est le seul fichier qui cree des cadres securises. Leurs attributs ne
-- peuvent changer que hors combat : un choix fait en combat est applique a la
-- fin du combat.

local _, ns = ...

local PoisonPanel = ns:NewModule("PoisonPanel")
local Style = ns.Style
local L = ns.L

local TILE, COLUMN = 36, 146
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local ALERT_COLOR = {
	missing = { 0.82, 0.26, 0.18 },
	expiring = { 0.88, 0.54, 0.16 },
	mismatch = { 0.35, 0.64, 0.90 },
}
local buttons = {}
local attributesDirty = false

-- Reporte sur les boutons securises le poison prefere de chaque main.
local function ApplyAttributes()
	if ns.API.InCombat() then
		attributesDirty = true
		return
	end
	attributesDirty = false
	for hand, button in ipairs(buttons) do
		local itemID = ns.PoisonManager:GetPreferred(hand)
		-- "type1" : seul le clic gauche declenche l'action.
		button:SetAttribute("type1", itemID and "item" or nil)
		button:SetAttribute("item", itemID and ("item:" .. itemID) or nil)
	end
end

local function OpenMenu(hand)
	if ns.API.InCombat() then
		ns:Print(L.COMBAT_BLOCKED)
		return
	end
	local poisons = ns.PoisonManager:GetBagPoisons()
	MenuUtil.CreateContextMenu(buttons[hand], function(_, root)
		root:CreateTitle(hand == 1 and L.MAIN_HAND or L.OFF_HAND)
		if #poisons == 0 then
			root:CreateTitle("|cffd04030" .. L.NO_POISON_IN_BAGS .. "|r")
		end
		for _, poison in ipairs(poisons) do
			local label = string.format("|T%s:16|t %s  |cff909090x%d|r", tostring(poison.icon or QUESTION), poison.name, poison.count)
			root:CreateButton(label, function()
				ns.PoisonManager:SetPreferred(hand, poison.id)
			end)
		end
		if ns.PoisonManager:GetPreferred(hand) then
			root:CreateButton(L.CLEAR_PREFERENCE, function()
				ns.PoisonManager:SetPreferred(hand, nil)
			end)
		end
	end)
end

local function ShowTooltip(button)
	local hand = button.hand
	local state = ns.PoisonManager:GetHands()[hand]
	GameTooltip:SetOwner(button, "ANCHOR_TOP")
	GameTooltip:AddLine(hand == 1 and L.MAIN_HAND or L.OFF_HAND)
	if state.preferred then
		GameTooltip:AddLine(string.format(L.TIP_SELECTED, ns.API.GetItemName(state.preferred) or "?", state.preferredCount), 1, 1, 1)
		GameTooltip:AddLine(L.TIP_APPLY, 0.6, 0.6, 0.6)
	end
	GameTooltip:AddLine(L.TIP_CHOOSE, 0.6, 0.6, 0.6)
	GameTooltip:Show()
end

local function CreateTile(hand, parent)
	local button = CreateFrame("Button", "URAPoisonButton" .. hand, parent, "SecureActionButtonTemplate")
	button.hand = hand
	button:SetSize(TILE, TILE)
	button:SetPoint("LEFT", parent, "LEFT", (hand - 1) * COLUMN, 0)
	button:RegisterForClicks("AnyUp", "AnyDown")
	button:SetAttribute("target-slot", ns.API.GetInventorySlot(hand))

	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetAllPoints()
	button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	button.border = Style.AddBorder(button, 1, 1, "OVERLAY")

	local highlight = button:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetAllPoints()
	highlight:SetColorTexture(1, 1, 1, 0.15)

	-- Pastille : poison choisi pour cette arme et quantite en sac.
	button.badge = button:CreateTexture(nil, "OVERLAY", nil, 2)
	button.badge:SetSize(16, 16)
	button.badge:SetPoint("BOTTOMRIGHT", 4, -4)
	button.badge:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	button.count = button:CreateFontString(nil, "OVERLAY")
	Style.SetFont(button.count, 10)
	button.count:SetPoint("TOPRIGHT", 3, 3)

	button.name = button:CreateFontString(nil, "OVERLAY")
	Style.SetFont(button.name, 11)
	button.name:SetPoint("TOPLEFT", button, "TOPRIGHT", 7, -3)
	button.name:SetWidth(COLUMN - TILE - 14)
	button.name:SetJustifyH("LEFT")
	button.name:SetWordWrap(false)
	button.detail = button:CreateFontString(nil, "OVERLAY")
	Style.SetFont(button.detail, 10)
	button.detail:SetPoint("TOPLEFT", button.name, "BOTTOMLEFT", 0, -3)
	button.detail:SetTextColor(0.62, 0.64, 0.68)

	button:HookScript("PostClick", function(_, mouseButton, down)
		if mouseButton == "RightButton" then
			if not down then
				OpenMenu(hand)
			end
		else
			ns.PoisonManager:NotifyApplyClick(hand)
		end
	end)
	button:HookScript("OnEnter", ShowTooltip)
	button:HookScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	return button
end

local function UpdateTile(button, state)
	button.icon:SetTexture(state.weaponIcon or QUESTION)
	button.icon:SetDesaturated(not state.hasWeapon)
	button:SetAlpha(state.hasWeapon and 1 or 0.35)

	if state.preferred then
		button.badge:SetTexture(state.preferredIcon or QUESTION)
		button.badge:Show()
		button.count:SetText(state.preferredCount)
		if state.preferredCount > 0 then
			button.count:SetTextColor(1, 1, 1)
		else
			button.count:SetTextColor(0.82, 0.26, 0.18)
		end
	else
		button.badge:Hide()
		button.count:SetText("")
	end

	if not state.hasWeapon then
		button.name:SetText(L.NO_WEAPON)
		button.detail:SetText("")
	elseif state.active then
		button.name:SetText(state.name or L.POISON_ACTIVE)
		local detail = ""
		if state.seconds then
			detail = string.format(L.MINUTES, math.ceil(state.seconds / 60))
		end
		if state.charges and state.charges > 0 then
			detail = detail .. (detail ~= "" and "  " or "") .. string.format(L.CHARGES, state.charges)
		end
		button.detail:SetText(detail)
	else
		button.name:SetText(L.NO_POISON)
		button.detail:SetText("")
	end

	local color = ALERT_COLOR[state.alert]
	if color and state.hasWeapon then
		button.border:SetColor(color[1], color[2], color[3], 1)
		button.name:SetTextColor(color[1], color[2], color[3])
	else
		button.border:SetColor(0, 0, 0, 1)
		button.name:SetTextColor(1, 1, 1)
	end
end

local function Update(_, _, hands)
	for hand, button in ipairs(buttons) do
		UpdateTile(button, hands[hand])
	end
end

local function Build()
	local group = ns.UI.groups.poisons
	Style.AddBackground(group)
	for hand = 1, 2 do
		buttons[hand] = CreateTile(hand, group)
	end
	ApplyAttributes()
	Update(nil, nil, ns.PoisonManager:GetHands())
end

function PoisonPanel:OnEnable()
	ns.Events:On("URA_POISONS_UPDATE", self, Update)
	ns.Events:On("URA_POISON_PREFERENCE_CHANGED", self, ApplyAttributes)
	ns.Events:Register("PLAYER_REGEN_ENABLED", self, function()
		if #buttons == 0 then
			Build()
		elseif attributesDirty then
			ApplyAttributes()
		end
	end)
	-- Des cadres securises ne se creent pas en combat : on attend la fin.
	if not ns.API.InCombat() then
		Build()
	end
end

function PoisonPanel:OnProfileChanged()
	if #buttons > 0 then
		ApplyAttributes()
	end
end
