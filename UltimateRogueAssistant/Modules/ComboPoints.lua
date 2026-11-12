-- Ultimate Rogue Assistant - ComboPoints
-- Les points de combo sont portes par la cible et ne sont jamais secrets sur
-- Forever. Par prudence, une valeur secrete reste geree : elle est transmise
-- telle quelle, sans logique.

local _, ns = ...

local ComboPoints = ns:NewModule("ComboPoints")
ns.ComboPoints = ComboPoints

local state = {
	points = 0,      -- valeur a afficher (peut etre opaque)
	max = 5,
	readable = true, -- faux si la valeur est secrete
	gained = 0,      -- rang du dernier point gagne, 0 sinon
	full = false,    -- maximum atteint (toujours faux si non lisible)
}

function ComboPoints:GetState()
	return state
end

-- `silent` : mise a jour sans animation (changement de cible).
local function Update(silent)
	local points, max = ns.API.GetComboPoints()
	local previous = state.readable and state.points or 0
	state.max = (max and max > 0) and max or 5
	state.points = points
	state.readable = not ns.Secrets.IsSecret(points)
	if state.readable then
		state.full = points >= state.max
		state.gained = (not silent and points > previous) and points or 0
	else
		state.full = false
		state.gained = 0
	end
	ns.Events:Fire("URA_COMBO_UPDATE", state)
end

function ComboPoints:OnEnable()
	local function OnPower(_, _, _, powerToken)
		if powerToken == "COMBO_POINTS" then
			Update(false)
		end
	end
	ns.Events:RegisterUnit("UNIT_POWER_FREQUENT", "player", self, OnPower)
	ns.Events:RegisterUnit("UNIT_MAXPOWER", "player", self, OnPower)
	-- Les points suivent la cible : relecture a chaque changement, sans animation.
	ns.Events:Register("PLAYER_TARGET_CHANGED", self, function()
		Update(true)
	end)
	ns.Events:Register("COMBO_TARGET_CHANGED", self, function()
		Update(true)
	end)
	ns.Events:Register("PLAYER_ENTERING_WORLD", self, function()
		Update(true)
	end)
end
