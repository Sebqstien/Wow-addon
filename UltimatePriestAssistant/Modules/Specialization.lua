-- Ultimate Priest Assistant - Specialization
-- Determine la specialisation active : detectee d'apres les points de talents,
-- ou imposee par le joueur. Le choix est memorise par personnage.

local _, ns = ...

local Specialization = ns:NewModule("Specialization")
ns.Specialization = Specialization

local state = {
	detected = nil,     -- cle detectee, nil si indeterminee
	active = nil,       -- cle retenue (choix manuel ou detection), nil si aucune
	points = {},        -- cle -> points depenses
	names = {},         -- cle -> nom du groupe fourni par le jeu
}

local function CharacterEntry()
	local key = ns.API.GetCharacterKey()
	ns.db.chars[key] = ns.db.chars[key] or {}
	return ns.db.chars[key]
end

function Specialization:GetState()
	return state
end

-- Cle de la specialisation active, ou nil si aucune.
function Specialization:GetActive()
	return state.active
end

-- "auto" ou une cle de specialisation.
function Specialization:GetMode()
	local mode = CharacterEntry().spec
	if mode and ns.Data.Presets[mode] and mode ~= "none" then
		return mode
	end
	return "auto"
end

function Specialization:GetName(key)
	return state.names[key] or ns.L["SPEC_" .. string.upper(key)]
end

local function Detect()
	wipe(state.points)
	state.detected = nil
	local groups = ns.API.GetTalentGroups()
	if not groups then
		return
	end
	local best, bestPoints, tie = nil, 0, false
	for _, group in ipairs(groups) do
		local key = ns.Data.SpecByOrder[group.order]
		if key then
			state.points[key] = group.points
			state.names[key] = group.name
			if group.points > bestPoints then
				best, bestPoints, tie = key, group.points, false
			elseif group.points == bestPoints then
				tie = true
			end
		end
	end
	-- Aucun point depense, ou egalite en tete : pas de specialisation detectee.
	if best and not tie then
		state.detected = best
	end
end

function Specialization:Update()
	Detect()
	local mode = self:GetMode()
	local active = mode ~= "auto" and mode or state.detected
	if active ~= state.active then
		state.active = active
		ns.Events:Fire("UPA_SPEC_CHANGED", active)
	end
end

-- Choix manuel : "auto" ou une cle de specialisation.
function Specialization:SetMode(mode)
	CharacterEntry().spec = mode
	self:Update()
end

function Specialization:OnEnable()
	local function Update()
		self:Update()
	end
	ns.Events:Register("TRAIT_CONFIG_UPDATED", self, Update)
	ns.Events:Register("ACTIVE_TALENT_GROUP_CHANGED", self, Update)
	ns.Events:Register("PLAYER_TALENT_UPDATE", self, Update)
	ns.Events:Register("PLAYER_ENTERING_WORLD", self, Update)
	self:Update()
end
