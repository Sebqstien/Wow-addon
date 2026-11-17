-- Ultimate Priest Assistant - Secrets
-- Dit, pour chaque donnee, si Lua peut la lire ou seulement la transmettre a un
-- widget. Les modules passent par ici et n'appellent jamais issecretvalue.
--
-- Mesures faites en jeu sur un voleur (build 70888) : l'energie est secrete en
-- permanence, les temps de recharge sont secrets en combat, leurs drapeaux
-- restent lisibles. Le mana n'a pas ete mesure : l'addon le traite comme
-- secret et ne fait donc aucun calcul dessus.

local _, ns = ...

local Secrets = {}
ns.Secrets = Secrets

local MANA = Enum.PowerType.Mana
local COMBAT = Enum.AddOnRestrictionType and Enum.AddOnRestrictionType.Combat

-- Vrai si la valeur est opaque pour Lua. Ne provoque jamais d'erreur.
function Secrets.IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

function Secrets.HasRestrictions()
	return C_Secrets ~= nil and C_Secrets.HasSecretRestrictions() == true
end

function Secrets.IsManaSecret()
	return C_Secrets ~= nil and C_Secrets.ShouldUnitPowerBeSecret("player", MANA) == true
end

-- Vrai quand les auras ne sont pas lisibles (en combat, d'apres les mesures).
function Secrets.AreAurasSecret()
	return C_Secrets ~= nil and C_Secrets.ShouldAurasBeSecret() == true
end

function Secrets.IsCombatRestrictionActive()
	return COMBAT ~= nil and C_RestrictedActions ~= nil
		and C_RestrictedActions.IsAddOnRestrictionActive(COMBAT) == true
end

-- Relaie les changements de restriction sur le bus interne.
ns.Events:Register("ADDON_RESTRICTION_STATE_CHANGED", Secrets, function(_, _, restrictionType, state)
	ns.Events:Fire("UPA_RESTRICTION_CHANGED", restrictionType, state)
end)
