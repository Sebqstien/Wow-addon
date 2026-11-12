-- Ultimate Rogue Assistant - Data/Talents
-- Forever n'a pas de specialisation au sens moderne : le voleur a un arbre
-- unique divise en trois groupes. La "specialisation" est le groupe qui a recu
-- le plus de points, ou celle que le joueur choisit a la main.

local _, ns = ...

ns.Data = ns.Data or {}

-- Ordre des groupes dans l'arbre, releve en jeu (orderIndex 0, 1, 2).
ns.Data.SpecByOrder = { [0] = "assassination", [1] = "combat", [2] = "subtlety" }
ns.Data.SpecKeys = { "assassination", "combat", "subtlety" }

-- Prereglages : techniques suivies par defaut et leur ordre d'affichage, pour
-- chaque specialisation. "none" sert quand aucune n'est detectee ni choisie.
-- Une technique non apprise est ignoree, quel que soit le prereglage.
ns.Data.Presets = {
	none = {
		"sinister_strike", "eviscerate", "slice_and_dice", "kidney_shot", "kick", "gouge",
		"evasion", "vanish", "sprint", "feint", "blind",
		"blade_flurry", "adrenaline_rush", "riposte", "cold_blood", "preparation", "premeditation",
	},
	-- Assassinat : saignements et coups de grace d'abord, puis controles.
	assassination = {
		"backstab", "sinister_strike", "eviscerate", "rupture", "garrote", "slice_and_dice", "kidney_shot", "kick",
		"evasion", "vanish", "sprint", "blind", "feint",
		"cold_blood", "blade_flurry", "adrenaline_rush", "preparation",
	},
	-- Combat : attaque pernicieuse et temps forts offensifs.
	combat = {
		"sinister_strike", "eviscerate", "slice_and_dice", "kidney_shot", "kick", "gouge",
		"sprint", "evasion", "vanish", "feint", "blind",
		"blade_flurry", "adrenaline_rush", "riposte", "cold_blood",
	},
	-- Finesse : ouvertures en camouflage, controles et reinitialisations.
	subtlety = {
		"backstab", "ambush", "cheap_shot", "hemorrhage", "eviscerate", "kidney_shot", "kick", "gouge", "ghostly_strike",
		"stealth", "vanish", "evasion", "sprint", "blind",
		"preparation", "premeditation", "cold_blood",
	},
}
