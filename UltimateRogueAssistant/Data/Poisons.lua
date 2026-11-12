-- Ultimate Rogue Assistant - Data/Poisons
-- Reconnaissance des poisons dans les sacs.
--
-- Un objet utilisable est considere comme un poison si son nom, ou le nom de
-- son effet, contient l'un des mots ci-dessous. Ce critere a ete valide en jeu
-- (client frFR). L'addon apprend ensuite lui-meme la correspondance entre un
-- enchantement d'arme et l'objet qui l'a pose, a chaque application reussie.

local _, ns = ...

ns.Data = ns.Data or {}

ns.Data.PoisonKeywords = {
	"poison",   -- frFR, enUS
	"gift",     -- deDE
	"veneno",   -- esES, esMX, ptBR
	"veleno",   -- itIT
	"яд",       -- ruRU
}
