-- Ultimate Rogue Assistant - SpellIcons
-- Icones des techniques, reparties en trois groupes. Le balayage et les
-- chiffres de recharge sont dessines par le client a partir d'un objet de
-- duree ; l'addon ne lit jamais le temps restant.

local _, ns = ...

local SpellIcons = ns:NewModule("SpellIcons")
local Style = ns.Style

local SIZE = { main = 40, defensive = 32, offensive = 32 }
local GAP = 4
local pools = { main = {}, defensive = {}, offensive = {} }   -- icones par groupe
local byKey = {}                                               -- cle -> icone active

local function CreateIcon(parent, size)
	local icon = CreateFrame("Frame", nil, parent)
	icon:SetSize(size, size)

	icon.texture = icon:CreateTexture(nil, "ARTWORK")
	icon.texture:SetAllPoints()
	icon.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
	icon.cooldown:SetAllPoints()
	icon.cooldown:SetHideCountdownNumbers(false)
	icon.cooldown:SetDrawEdge(false)

	icon.border = Style.AddBorder(icon, 1, 1, "OVERLAY")
	icon.glow = Style.AddBorder(icon, 2, 3, "BACKGROUND")

	-- Eclat blanc bref quand la technique redevient disponible.
	icon.flashTexture = icon:CreateTexture(nil, "OVERLAY")
	icon.flashTexture:SetAllPoints()
	icon.flashTexture:SetColorTexture(1, 1, 1, 0.55)
	icon.flashTexture:SetBlendMode("ADD")
	icon.flash = ns.Animations.CreateFlash(icon.flashTexture, 0.45)
	icon.pulse = ns.Animations.CreatePulse(icon, 1.18, 0.35)

	-- Les chiffres sont poses au-dessus du balayage.
	local overlay = CreateFrame("Frame", nil, icon)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(icon.cooldown:GetFrameLevel() + 2)
	icon.charges = overlay:CreateFontString(nil, "OVERLAY")
	Style.SetFont(icon.charges, 11)
	icon.charges:SetPoint("BOTTOMRIGHT", -1, 1)
	return icon
end

local function ApplyStatus(icon, spell)
	local status = spell.status
	local colors = Style.colors
	if status == "ready" then
		icon.texture:SetDesaturated(false)
		icon.texture:SetVertexColor(1, 1, 1)
		icon.border:SetColor(colors.ready[1], colors.ready[2], colors.ready[3], 1)
		icon.glow:SetColor(colors.ready[1], colors.ready[2], colors.ready[3], spell.major and 0.45 or 0.22)
	elseif status == "nopower" then
		icon.texture:SetDesaturated(true)
		icon.texture:SetVertexColor(0.55, 0.65, 0.95)
		icon.border:SetColor(colors.noPower[1], colors.noPower[2], colors.noPower[3], 0.9)
		icon.glow:SetColor(0, 0, 0, 0)
	elseif status == "cooldown" then
		icon.texture:SetDesaturated(true)
		icon.texture:SetVertexColor(0.75, 0.75, 0.75)
		icon.border:SetColor(0, 0, 0, 1)
		icon.glow:SetColor(0, 0, 0, 0)
	else -- "unusable"
		icon.texture:SetDesaturated(false)
		icon.texture:SetVertexColor(0.42, 0.42, 0.42)
		icon.border:SetColor(0, 0, 0, 1)
		icon.glow:SetColor(0, 0, 0, 0)
	end
end

local function UpdateIcon(_, _, spell, becameReady)
	local icon = byKey[spell.key]
	if not icon then
		return
	end
	ApplyStatus(icon, spell)

	if spell.status == "cooldown" then
		local duration = ns.API.GetCooldownDuration(spell.id)
		if duration then
			icon.cooldown:SetCooldownFromDurationObject(duration)
		end
	else
		icon.cooldown:Clear()
	end

	local charges, maxCharges = ns.API.GetSpellCharges(spell.id)
	if maxCharges and maxCharges > 1 then
		icon.charges:SetText(charges)
	else
		icon.charges:SetText("")
	end

	if becameReady then
		ns.Animations.Play(icon.flash)
		if spell.major then
			ns.Animations.Play(icon.pulse)
		end
	end
end

local function Rebuild(_, _, tracked)
	wipe(byKey)
	local used = { main = 0, defensive = 0, offensive = 0 }
	for _, spell in ipairs(tracked) do
		local group = spell.group
		local pool, size = pools[group], SIZE[group]
		local index = used[group] + 1
		used[group] = index
		local icon = pool[index]
		if not icon then
			icon = CreateIcon(ns.UI.groups[group], size)
			pool[index] = icon
		end
		icon:ClearAllPoints()
		icon:SetPoint("LEFT", ns.UI.groups[group], "LEFT", (index - 1) * (size + GAP), 0)
		icon.texture:SetTexture(spell.icon)
		icon:Show()
		byKey[spell.key] = icon
	end
	for group, pool in pairs(pools) do
		for index = used[group] + 1, #pool do
			pool[index]:Hide()
		end
		-- Le groupe epouse son contenu ; ancre par son centre, il reste centre.
		local count, size = math.max(used[group], 1), SIZE[group]
		ns.UI.groups[group]:SetSize(count * (size + GAP) - GAP, size)
	end
end

function SpellIcons:OnEnable()
	ns.Events:On("URA_SPELLS_CHANGED", self, Rebuild)
	ns.Events:On("URA_SPELL_UPDATE", self, UpdateIcon)
	local tracked = ns.Cooldowns:GetTracked()
	Rebuild(nil, nil, tracked)
	for _, spell in ipairs(tracked) do
		UpdateIcon(nil, nil, spell, false)
	end
end
