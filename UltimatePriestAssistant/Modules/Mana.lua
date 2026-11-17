-- Ultimate Priest Assistant - Mana
-- Le mana est traite comme une valeur secrete : ce module ne porte aucune
-- logique sur sa valeur. Il signale seulement qu'elle a change ; l'interface
-- transmet alors la valeur du client directement aux widgets.

local _, ns = ...

local Mana = ns:NewModule("Mana")
ns.Mana = Mana

local function OnPower(_, _, _, powerToken)
	if powerToken == "MANA" then
		ns.Events:Fire("UPA_MANA_UPDATE")
	end
end

function Mana:OnEnable()
	ns.Events:RegisterUnit("UNIT_POWER_FREQUENT", "player", self, OnPower)
	ns.Events:RegisterUnit("UNIT_MAXPOWER", "player", self, OnPower)
	ns.Events:Register("PLAYER_ENTERING_WORLD", self, function()
		ns.Events:Fire("UPA_MANA_UPDATE")
	end)
end
