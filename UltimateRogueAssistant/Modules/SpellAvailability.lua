-- Ultimate Rogue Assistant - SpellAvailability
-- Traduit les drapeaux du client en un etat de disponibilite unique.
-- Seuls des drapeaux lisibles sont utilises : aucun etat n'est devine.
--
--   "cooldown"  en recharge reelle (le GCD seul ne compte pas)
--   "nopower"   recharge terminee, energie insuffisante selon le client
--   "unusable"  recharge terminee, condition non remplie (camouflage, cible,
--               points de combo...) : le client ne precise pas laquelle
--   "ready"     utilisable maintenant selon le client

local _, ns = ...

local SpellAvailability = ns:NewModule("SpellAvailability")
ns.SpellAvailability = SpellAvailability

-- Met a jour `spell.status`. Renvoie : etat modifie, technique redevenue prete.
function SpellAvailability:Evaluate(spell)
	local status
	if spell.active then
		status = "cooldown"
	elseif spell.usable then
		status = "ready"
	elseif spell.noPower then
		status = "nopower"
	else
		status = "unusable"
	end
	local previous = spell.status
	spell.status = status
	-- "Redevenue prete" : fin d'une recharge reelle, pas un simple retour d'energie.
	return previous ~= status, previous == "cooldown" and status ~= "cooldown"
end
