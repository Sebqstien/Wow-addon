-- Ultimate Rogue Assistant - Movers
-- Deplacement, redimensionnement, opacite et verrouillage des groupes.
-- Chaque groupe est un cadre independant ; sa position est stockee dans le
-- profil actif comme decalage de son centre par rapport au centre de l'ecran.

local _, ns = ...

local Movers = ns:NewModule("Movers")
ns.Movers = Movers

local L = ns.L
local Clamp, Round = ns.Helpers.Clamp, ns.Helpers.Round

local groups = {}        -- cle -> { key, frame, label, overlay }
local order = {}         -- cles dans l'ordre d'enregistrement
local pendingRefresh = false   -- une mise a jour attend la fin du combat
local combatStarted = false    -- vrai des PLAYER_REGEN_DISABLED, avant le verrou du client
local dimmed = false           -- interface estompee (hors combat, sans cible)

local function Settings(key)
	return ns.Profiles:GetCurrent().groups[key]
end

local function IsUnlockedNow()
	return not ns.db.locked and not combatStarted and not ns.API.InCombat()
end

-- L'opacite peut changer a tout moment, y compris en combat.
local function ApplyAlpha(group)
	local profile = ns.Profiles:GetCurrent()
	local alpha = Clamp(profile.groups[group.key].alpha, ns.Config.ALPHA_MIN, ns.Config.ALPHA_MAX)
	if IsUnlockedNow() then
		alpha = 1   -- en mode deverrouille, le groupe est toujours pleinement visible
	elseif dimmed then
		alpha = alpha * Clamp(profile.idleAlpha, 0, 1)
	end
	group.frame:SetAlpha(alpha)
end

------------------------------------------------------------------------
-- Application et sauvegarde
------------------------------------------------------------------------

local function ApplyGroup(group)
	local settings = Settings(group.key)
	local scale = Clamp(settings.scale, ns.Config.SCALE_MIN, ns.Config.SCALE_MAX)
	local frame = group.frame
	frame:SetScale(scale)
	frame:ClearAllPoints()
	-- Les decalages d'ancrage s'expriment dans l'echelle du cadre.
	frame:SetPoint("CENTER", UIParent, "CENTER", settings.x / scale, settings.y / scale)
	-- Un groupe masque reste visible en mode deverrouille, pour pouvoir le placer.
	frame:SetShown(settings.shown or IsUnlockedNow())
	ApplyAlpha(group)
end

local function SavePosition(group)
	local frame = group.frame
	local centerX, centerY = frame:GetCenter()
	local screenX, screenY = UIParent:GetCenter()
	if not centerX or not screenX then
		return
	end
	local scale = frame:GetScale()
	local settings = Settings(group.key)
	settings.x = Round(centerX * scale - screenX, 1)
	settings.y = Round(centerY * scale - screenY, 1)
end

local function RefreshOverlay(group)
	group.overlay:SetShown(IsUnlockedNow())
end

-- Applique reglages et etat de verrouillage a tous les groupes. En combat,
-- l'operation est reportee : un groupe peut contenir des boutons securises.
function Movers:Refresh()
	if ns.API.InCombat() then
		pendingRefresh = true
		return
	end
	pendingRefresh = false
	for _, key in ipairs(order) do
		ApplyGroup(groups[key])
		RefreshOverlay(groups[key])
	end
end

------------------------------------------------------------------------
-- Poignee affichee en mode deverrouille
------------------------------------------------------------------------

local function CursorDistanceFromCenter(frame)
	local centerX, centerY = frame:GetCenter()
	local effectiveScale = frame:GetEffectiveScale()
	local cursorX, cursorY = GetCursorPosition()
	local dx = cursorX - centerX * effectiveScale
	local dy = cursorY - centerY * effectiveScale
	return math.max(math.sqrt(dx * dx + dy * dy), 1)
end

local function CreateOverlay(group)
	local frame = group.frame
	local overlay = CreateFrame("Frame", nil, frame)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(frame:GetFrameLevel() + 50)
	overlay:EnableMouse(true)
	overlay:EnableMouseWheel(true)
	overlay:RegisterForDrag("LeftButton")
	overlay:Hide()

	local fill = overlay:CreateTexture(nil, "BACKGROUND")
	fill:SetAllPoints()
	fill:SetColorTexture(0.10, 0.45, 0.85, 0.30)

	-- Contour d'un pixel.
	local function Edge(point1, point2, width, height)
		local edge = overlay:CreateTexture(nil, "BORDER")
		edge:SetColorTexture(0.35, 0.70, 1, 0.9)
		edge:SetPoint(point1)
		edge:SetPoint(point2)
		if width then
			edge:SetWidth(width)
		else
			edge:SetHeight(height)
		end
	end
	Edge("TOPLEFT", "TOPRIGHT", nil, 1)
	Edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
	Edge("TOPLEFT", "BOTTOMLEFT", 1, nil)
	Edge("TOPRIGHT", "BOTTOMRIGHT", 1, nil)

	local label = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetPoint("CENTER", 0, 8)
	label:SetText(group.label)
	local hint = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hint:SetPoint("TOP", label, "BOTTOM", 0, -2)
	hint:SetText(L.MOVER_HINT)

	overlay:SetScript("OnDragStart", function()
		if not ns.API.InCombat() then
			frame:StartMoving()
		end
	end)
	overlay:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		SavePosition(group)
		if not ns.API.InCombat() then
			ApplyGroup(group)
		end
	end)
	overlay:SetScript("OnMouseWheel", function(_, delta)
		Movers:SetScale(group.key, Settings(group.key).scale + delta * 0.05)
	end)

	-- Coin inferieur droit : redimensionnement a la souris.
	local grip = CreateFrame("Button", nil, overlay)
	grip:SetSize(14, 14)
	grip:SetPoint("BOTTOMRIGHT")
	local gripTexture = grip:CreateTexture(nil, "OVERLAY")
	gripTexture:SetAllPoints()
	gripTexture:SetColorTexture(0.35, 0.70, 1, 0.9)

	local startDistance, startScale
	local function OnGripUpdate()
		local scale = startScale * CursorDistanceFromCenter(frame) / startDistance
		Movers:SetScale(group.key, scale)
	end
	grip:SetScript("OnMouseDown", function()
		if ns.API.InCombat() then
			return
		end
		startDistance = CursorDistanceFromCenter(frame)
		startScale = Settings(group.key).scale
		-- Actif uniquement pendant le glissement du coin.
		grip:SetScript("OnUpdate", OnGripUpdate)
	end)
	local function StopGrip()
		grip:SetScript("OnUpdate", nil)
	end
	grip:SetScript("OnMouseUp", StopGrip)
	grip:SetScript("OnHide", StopGrip)

	return overlay
end

------------------------------------------------------------------------
-- Interface publique
------------------------------------------------------------------------

-- Declare un groupe deplacable. `key` doit exister dans les reglages par
-- defaut du profil (Config.PROFILE_DEFAULTS.groups).
function Movers:Register(key, frame, label)
	assert(not groups[key], "groupe deja enregistre : " .. key)
	assert(ns.Config.PROFILE_DEFAULTS.groups[key], "groupe sans reglages par defaut : " .. key)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	local group = { key = key, frame = frame, label = label }
	group.overlay = CreateOverlay(group)
	groups[key] = group
	order[#order + 1] = key
	-- Un cadre qui vient d'etre cree n'est pas encore protege : on peut le placer
	-- tout de suite, meme si l'interface est rechargee en plein combat.
	ApplyGroup(group)
	RefreshOverlay(group)
	return group
end

function Movers:IsLocked()
	return ns.db.locked
end

function Movers:SetLocked(locked)
	ns.db.locked = locked and true or false
	self:Refresh()
	ns.Events:Fire("URA_LOCK_CHANGED", ns.db.locked)
end

function Movers:HasGroup(key)
	return groups[key] ~= nil
end

function Movers:ListGroups()
	return table.concat(order, ", ")
end

-- Renvoie false si le changement est impossible en combat.
function Movers:SetScale(key, scale)
	if ns.API.InCombat() then
		return false
	end
	Settings(key).scale = Round(Clamp(scale, ns.Config.SCALE_MIN, ns.Config.SCALE_MAX), 2)
	ApplyGroup(groups[key])
	return true
end

function Movers:SetAlpha(key, alpha)
	Settings(key).alpha = Round(Clamp(alpha, ns.Config.ALPHA_MIN, ns.Config.ALPHA_MAX), 2)
	ApplyAlpha(groups[key])
	return true
end

-- Affiche ou masque un groupe. Renvoie false si c'est impossible en combat.
function Movers:SetShown(key, shown)
	if ns.API.InCombat() then
		return false
	end
	Settings(key).shown = shown and true or false
	ApplyGroup(groups[key])
	return true
end

function Movers:GetOrder()
	return order
end

function Movers:GetLabel(key)
	return groups[key].label
end

-- Estompe ou retablit tous les groupes.
function Movers:SetDimmed(value)
	dimmed = value and true or false
	for _, key in ipairs(order) do
		ApplyAlpha(groups[key])
	end
end

function Movers:OnEnable()
	-- A l'entree en combat : arret de tout deplacement et masquage des poignees.
	ns.Events:Register("PLAYER_REGEN_DISABLED", self, function()
		combatStarted = true
		for _, key in ipairs(order) do
			local group = groups[key]
			group.frame:StopMovingOrSizing()
			group.overlay:Hide()
			ApplyAlpha(group)
		end
		pendingRefresh = true
	end)
	ns.Events:Register("PLAYER_REGEN_ENABLED", self, function()
		combatStarted = false
		if pendingRefresh then
			self:Refresh()
		end
	end)
	self:Refresh()
end

function Movers:OnProfileChanged()
	self:Refresh()
end
