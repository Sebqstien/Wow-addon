-- Ultimate Rogue Assistant - Secrets
-- Dit, pour chaque donnee, si Lua peut la lire ou seulement la transmettre a un
-- widget. Les modules passent par ici et n'appellent jamais issecretvalue.
--
-- Mesures faites en jeu (diagnostic du 12/11/2026, build 70888) :
--   energie         : secrete en permanence
--   points de combo : jamais secrets
--   cooldowns       : secrets en combat (startTime, duration), drapeaux lisibles

local _, ns = ...

local Secrets = {}
ns.Secrets = Secrets

local ENERGY = Enum.PowerType.Energy
local COMBO = Enum.PowerType.ComboPoints
local COMBAT = Enum.AddOnRestrictionType and Enum.AddOnRestrictionType.Combat

-- Vrai si la valeur est opaque pour Lua. Ne provoque jamais d'erreur.
function Secrets.IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

function Secrets.HasRestrictions()
	return C_Secrets ~= nil and C_Secrets.HasSecretRestrictions() == true
end

function Secrets.IsEnergySecret()
	return C_Secrets ~= nil and C_Secrets.ShouldUnitPowerBeSecret("player", ENERGY) == true
end

function Secrets.IsComboSecret()
	return C_Secrets ~= nil and C_Secrets.ShouldUnitPowerBeSecret("player", COMBO) == true
end

function Secrets.IsCombatRestrictionActive()
	return COMBAT ~= nil and C_RestrictedActions ~= nil
		and C_RestrictedActions.IsAddOnRestrictionActive(COMBAT) == true
end

-- Relaie les changements de restriction sur le bus interne.
ns.Events:Register("ADDON_RESTRICTION_STATE_CHANGED", Secrets, function(_, _, restrictionType, state)
	ns.Events:Fire("URA_RESTRICTION_CHANGED", restrictionType, state)
end)
