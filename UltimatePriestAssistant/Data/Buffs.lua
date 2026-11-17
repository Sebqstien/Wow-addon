-- Ultimate Priest Assistant - Data/Buffs
-- Ameliorations que le pretre entretient sur lui-meme.
--
-- Champs :
--   key      identifiant interne stable
--   id       identifiant de sort (un rang quelconque) : sert a lancer le sort
--   others   autres sorts qui posent une amelioration equivalente (version de groupe)
--   toggle   forme a bascule : un clic alors qu'elle est active la retirerait,
--            le bouton est donc desarme tant qu'elle est active
--   enabled  surveillee par defaut
--
-- Identifiants issus de la numerotation Classic, non verifies sur Forever.

local _, ns = ...

ns.Data = ns.Data or {}

ns.Data.Buffs = {
	{ key = "inner_fire", id = 588, enabled = true },
	{ key = "fortitude", id = 1243, others = { 21562 }, enabled = true },
	{ key = "divine_spirit", id = 14752, others = { 27681 }, enabled = true },
	{ key = "shadow_protection", id = 976, others = { 27683 }, enabled = false },
	{ key = "shadowform", id = 15473, toggle = true, enabled = true },
}
