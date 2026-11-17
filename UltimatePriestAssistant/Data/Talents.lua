-- Ultimate Priest Assistant - Data/Talents
-- Forever n'a pas de specialisation au sens moderne : l'arbre de talents est
-- unique et divise en trois groupes. La "specialisation" est le groupe qui a
-- recu le plus de points, ou celle que le joueur choisit a la main.

local _, ns = ...

ns.Data = ns.Data or {}

-- Ordre des groupes dans l'arbre. Il suit l'ordre Classic (Discipline, Sacre,
-- Ombre) et n'a PAS ete verifie en jeu sur un pretre. S'il etait faux, la
-- detection automatique designerait le mauvais prereglage : "/upa spec"
-- affiche les points par arbre et permet de choisir a la main.
ns.Data.SpecByOrder = { [0] = "discipline", [1] = "holy", [2] = "shadow" }
ns.Data.SpecKeys = { "discipline", "holy", "shadow" }

-- Prereglages : sorts suivis par defaut et leur ordre d'affichage, pour chaque
-- specialisation. "none" sert quand aucune n'est detectee ni choisie.
-- Un sort non appris est ignore, quel que soit le prereglage.
ns.Data.Presets = {
	none = {
		"mind_blast", "shadow_word_pain", "smite", "flash_heal", "renew", "psychic_scream",
		"power_word_shield", "fade", "desperate_prayer", "fear_ward", "dispel_magic",
		"inner_focus", "power_infusion",
	},
	-- Discipline : degats directs, brulure de mana et soins rapides.
	discipline = {
		"smite", "mind_blast", "shadow_word_pain", "mana_burn", "flash_heal", "renew", "psychic_scream",
		"power_word_shield", "fade", "desperate_prayer", "fear_ward", "dispel_magic",
		"inner_focus", "power_infusion",
	},
	-- Sacre : soins d'abord.
	holy = {
		"flash_heal", "greater_heal", "renew", "prayer_of_healing", "holy_nova", "holy_fire", "psychic_scream",
		"power_word_shield", "fade", "desperate_prayer", "fear_ward", "dispel_magic", "abolish_disease",
		"inner_focus", "lightwell",
	},
	-- Ombre : degats d'ombre et controles.
	shadow = {
		"mind_blast", "shadow_word_pain", "mind_flay", "devouring_plague", "vampiric_embrace", "silence", "psychic_scream",
		"power_word_shield", "fade", "desperate_prayer", "fear_ward", "dispel_magic", "elunes_grace", "feedback",
		"inner_focus", "power_infusion",
	},
}
