-- Ultimate Rogue Assistant - Energy
-- L'energie est secrete en permanence sur Forever : ce module ne peut donc
-- porter aucune logique sur sa valeur. Il signale seulement qu'elle a change ;
-- l'interface transmet alors la valeur du client directement aux widgets.

local _, ns = ...

local Energy = ns:NewModule("Energy")
ns.Energy = Energy

local function OnPower(_, _, _, powerToken)
	if powerToken == "ENERGY" then
		ns.Events:Fire("URA_ENERGY_UPDATE")
	end
end

function Energy:OnEnable()
	ns.Events:RegisterUnit("UNIT_POWER_FREQUENT", "player", self, OnPower)
	ns.Events:RegisterUnit("UNIT_MAXPOWER", "player", self, OnPower)
	ns.Events:Register("PLAYER_ENTERING_WORLD", self, function()
		ns.Events:Fire("URA_ENERGY_UPDATE")
	end)
end
