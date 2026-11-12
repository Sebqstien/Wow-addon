-- Ultimate Rogue Assistant - Data/Spells
-- Base extensible des techniques suivies.
--
-- `id` peut etre l'identifiant de n'importe quel rang : la technique est
-- retrouvee dans le grimoire par son nom, puis suivie avec l'identifiant du
-- rang reellement appris. Une entree dont l'identifiant est inconnu du client,
-- ou dont le sort n'est pas appris, est simplement ignoree.
--
-- Champs :
--   key      identifiant interne stable (sauvegarde, personnalisation)
--   id       identifiant de sort (un rang quelconque)
--   group    groupe d'affichage : "main", "defensive", "offensive"
--   tree     arbre de talents associe (information)
--   bar      affiche une barre de recharge
--   major    technique importante : effet de disponibilite plus marque
--
-- Les techniques suivies par defaut et leur ordre sont definis par
-- specialisation dans Data/Talents.lua.
--
-- Identifiants releves sur le client 1.60.1.70888 (voleur niveau 32) ou repris
-- de la numerotation Classic pour les techniques non encore apprises.

local _, ns = ...

ns.Data = ns.Data or {}

ns.Data.Spells = {
	-- Sorts principaux
	{ key = "sinister_strike", id = 1760, group = "main", tree = "combat" },
	{ key = "backstab", id = 2590, group = "main", tree = "subtlety" },
	{ key = "eviscerate", id = 8623, group = "main" },
	{ key = "slice_and_dice", id = 5171, group = "main" },
	{ key = "rupture", id = 8639, group = "main", tree = "assassination" },
	{ key = "kidney_shot", id = 408, group = "main", bar = true, major = true },
	{ key = "kick", id = 1767, group = "main", bar = true, major = true },
	{ key = "gouge", id = 8629, group = "main", bar = true },
	{ key = "expose_armor", id = 8647, group = "main" },
	{ key = "ambush", id = 8676, group = "main", tree = "subtlety" },
	{ key = "garrote", id = 8632, group = "main", tree = "assassination" },
	{ key = "cheap_shot", id = 1833, group = "main", tree = "subtlety" },
	{ key = "hemorrhage", id = 16511, group = "main", tree = "subtlety" },
	{ key = "ghostly_strike", id = 14278, group = "main", tree = "subtlety", bar = true },
	{ key = "shiv", id = 1329283, group = "main" },

	-- Defensifs
	{ key = "evasion", id = 5277, group = "defensive", bar = true, major = true },
	{ key = "vanish", id = 1856, group = "defensive", bar = true, major = true },
	{ key = "sprint", id = 2983, group = "defensive", bar = true },
	{ key = "feint", id = 1966, group = "defensive" },
	{ key = "blind", id = 2094, group = "defensive", bar = true, major = true },
	{ key = "distract", id = 1725, group = "defensive" },
	{ key = "stealth", id = 1785, group = "defensive" },

	-- Offensifs
	{ key = "blade_flurry", id = 13877, group = "offensive", tree = "combat", bar = true, major = true },
	{ key = "adrenaline_rush", id = 13750, group = "offensive", tree = "combat", bar = true, major = true },
	{ key = "riposte", id = 14251, group = "offensive", tree = "combat" },
	{ key = "cold_blood", id = 14177, group = "offensive", tree = "assassination", bar = true, major = true },
	{ key = "preparation", id = 14185, group = "offensive", tree = "subtlety", bar = true, major = true },
	{ key = "premeditation", id = 14183, group = "offensive", tree = "subtlety", bar = true },
}

ns.Data.SpellGroups = { "main", "defensive", "offensive" }
