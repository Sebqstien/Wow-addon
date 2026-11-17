-- Ultimate Priest Assistant - Data/Spells
-- Base extensible des sorts suivis.
--
-- `id` peut etre l'identifiant de n'importe quel rang : le sort est retrouve
-- dans le grimoire par son nom, puis suivi avec l'identifiant du rang
-- reellement appris. Une entree dont l'identifiant est inconnu du client, ou
-- dont le sort n'est pas appris, est simplement ignoree.
--
-- Champs :
--   key      identifiant interne stable (sauvegarde, personnalisation)
--   id       identifiant de sort (un rang quelconque)
--   group    groupe d'affichage : "main", "defensive", "offensive"
--   tree     arbre de talents associe (information)
--   bar      affiche une barre de recharge
--   major    sort important : effet de disponibilite plus marque
--
-- Les sorts suivis par defaut et leur ordre sont definis par specialisation
-- dans Data/Talents.lua.
--
-- ATTENTION : ces identifiants viennent de la numerotation Classic. Aucun n'a
-- ete verifie sur le client Forever avec un pretre. Un identifiant errone a
-- pour seul effet que le sort n'apparait pas ; "/upa add" permet alors de
-- l'ajouter par son nom.

local _, ns = ...

ns.Data = ns.Data or {}

ns.Data.Spells = {
	-- Sorts principaux : degats
	{ key = "mind_blast", id = 8092, group = "main", tree = "shadow", bar = true, major = true },
	{ key = "shadow_word_pain", id = 589, group = "main", tree = "shadow" },
	{ key = "mind_flay", id = 15407, group = "main", tree = "shadow" },
	{ key = "devouring_plague", id = 2944, group = "main", tree = "shadow", bar = true },
	{ key = "vampiric_embrace", id = 15286, group = "main", tree = "shadow" },
	{ key = "silence", id = 15487, group = "main", tree = "shadow", bar = true, major = true },
	{ key = "psychic_scream", id = 8122, group = "main", bar = true, major = true },
	{ key = "smite", id = 585, group = "main", tree = "holy" },
	{ key = "holy_fire", id = 14914, group = "main", tree = "holy" },
	{ key = "mana_burn", id = 8129, group = "main", tree = "discipline" },
	{ key = "holy_nova", id = 15237, group = "main", tree = "holy" },
	{ key = "starshards", id = 10797, group = "main" },
	{ key = "mind_control", id = 605, group = "main" },
	{ key = "shackle_undead", id = 9484, group = "main" },

	-- Sorts principaux : soins
	{ key = "flash_heal", id = 2061, group = "main", tree = "holy" },
	{ key = "greater_heal", id = 2060, group = "main", tree = "holy" },
	{ key = "heal", id = 2054, group = "main", tree = "holy" },
	{ key = "renew", id = 139, group = "main", tree = "holy" },
	{ key = "prayer_of_healing", id = 596, group = "main", tree = "holy" },

	-- Defensifs
	{ key = "power_word_shield", id = 17, group = "defensive", tree = "discipline", bar = true, major = true },
	{ key = "fade", id = 586, group = "defensive", bar = true },
	{ key = "desperate_prayer", id = 13908, group = "defensive", bar = true, major = true },
	{ key = "fear_ward", id = 6346, group = "defensive", bar = true, major = true },
	{ key = "dispel_magic", id = 527, group = "defensive" },
	{ key = "abolish_disease", id = 552, group = "defensive" },
	{ key = "cure_disease", id = 528, group = "defensive" },
	{ key = "elunes_grace", id = 2651, group = "defensive", bar = true },
	{ key = "feedback", id = 13896, group = "defensive", bar = true },

	-- Offensifs et temps forts
	{ key = "inner_focus", id = 14751, group = "offensive", tree = "discipline", bar = true, major = true },
	{ key = "power_infusion", id = 10060, group = "offensive", tree = "discipline", bar = true, major = true },
	{ key = "lightwell", id = 724, group = "offensive", tree = "holy", bar = true },
}

ns.Data.SpellGroups = { "main", "defensive", "offensive" }
