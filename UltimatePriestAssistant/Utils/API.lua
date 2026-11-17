-- Ultimate Priest Assistant - API
-- Seul fichier autorise a appeler les API du jeu pour le compte des modules.
-- Chaque fonction ci-dessous a ete verifiee sur le client 1.60.1.70888, soit
-- dans sa documentation, soit en jeu par l'addon de diagnostic.
--
-- Les valeurs marquees "opaque" peuvent etre secretes : elles se transmettent
-- a un widget mais ne se comparent pas et ne se calculent pas.

local _, ns = ...

local API = {}
ns.API = API

local MANA = Enum.PowerType.Mana
local PLAYER_BANK = Enum.SpellBookSpellBank.Player
local SPELL_ITEM = Enum.SpellBookItemType.Spell

------------------------------------------------------------------------
-- General
------------------------------------------------------------------------

function API.InCombat()
	return InCombatLockdown()
end

function API.GetCharacterKey()
	local name = UnitName("player") or "?"
	local realm = GetRealmName() or "?"
	return name .. " - " .. realm
end

function API.GetBuild()
	local version, build, _, interface = GetBuildInfo()
	return version, build, interface
end

function API.HasTarget()
	return UnitExists("target")
end

------------------------------------------------------------------------
-- Ressources
------------------------------------------------------------------------

-- Mana courant (peut etre opaque) et maximum.
function API.GetMana()
	return UnitPower("player", MANA), UnitPowerMax("player", MANA)
end

-- Couleur du mana evaluee par le client a travers une courbe de couleur.
-- Renvoie un objet couleur dont les composantes peuvent etre opaques.
function API.GetManaColor(curve)
	return UnitPowerPercent("player", MANA, false, curve)
end

------------------------------------------------------------------------
-- Auras du joueur
------------------------------------------------------------------------

-- Amelioration active sur le joueur, cherchee par nom. Renvoie : presente,
-- secondes restantes (nil si permanente ou illisible). A n'appeler que lorsque
-- les auras sont lisibles (voir Secrets.AreAurasSecret).
function API.GetPlayerBuff(spellName)
	local aura = C_UnitAuras.GetAuraDataBySpellName("player", spellName, "HELPFUL")
	if not aura then
		return false
	end
	local expiration = aura.expirationTime
	if type(expiration) == "number" and expiration > 0 then
		return true, expiration - GetTime()
	end
	return true
end

------------------------------------------------------------------------
-- Sorts
------------------------------------------------------------------------

function API.GetSpellName(spellID)
	return C_Spell.GetSpellName(spellID)
end

-- Liste les sorts actifs du grimoire dans `out` : nom -> { id, name, icon }.
function API.ScanSpellBook(out)
	wipe(out)
	for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
		local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo(line)
		if lineInfo then
			local first = lineInfo.itemIndexOffset + 1
			for index = first, lineInfo.itemIndexOffset + lineInfo.numSpellBookItems do
				local item = C_SpellBook.GetSpellBookItemInfo(index, PLAYER_BANK)
				if item and item.itemType == SPELL_ITEM and not item.isPassive and not item.isOffSpec
					and item.spellID and item.name then
					out[item.name] = { id = item.spellID, name = item.name, icon = item.iconID }
				end
			end
		end
	end
	return out
end

-- Drapeaux de recharge, documentes "jamais secrets" et verifies en combat.
-- Renvoie : en recharge reelle (hors GCD), recharge suspendue.
function API.GetCooldownFlags(spellID)
	local info = C_Spell.GetSpellCooldown(spellID)
	if not info then
		return false, false
	end
	return info.isActive == true and info.isOnGCD ~= true, info.isEnabled == false
end

-- Objet de duree de la recharge : a transmettre tel quel a un widget.
function API.GetCooldownDuration(spellID)
	return C_Spell.GetSpellCooldownDuration(spellID)
end

-- Charges : courantes (opaque), maximum (lisible). Rien si le sort n'en a pas.
function API.GetSpellCharges(spellID)
	local info = C_Spell.GetSpellCharges(spellID)
	if info then
		return info.currentCharges, info.maxCharges
	end
end

-- Utilisabilite selon le client : utilisable, ressource insuffisante.
function API.IsSpellUsable(spellID)
	local usable, noPower = C_Spell.IsSpellUsable(spellID)
	return usable == true, noPower == true
end

------------------------------------------------------------------------
-- Objets natifs (courbes, formats de duree)
------------------------------------------------------------------------

-- Courbe de couleur a paliers. `points` : liste de { seuil (0-1), couleur }.
-- Le client l'evalue lui-meme sur une valeur secrete.
function API.CreateStepColorCurve(points)
	local curve = C_CurveUtil.CreateColorCurve()
	curve:SetType(Enum.LuaCurveType.Step)
	for _, point in ipairs(points) do
		curve:AddPoint(point[1], point[2])
	end
	return curve
end

-- Format court des durees ("1m 41s"). La configuration abregee est optionnelle :
-- en cas de refus, le format par defaut du client est conserve.
function API.CreateDurationFormatter()
	local formatter = C_StringUtil.CreateSecondsFormatter()
	pcall(function()
		formatter:SetDefaultAbbreviation(Enum.SecondsFormatterAbbreviation.OneLetter)
		formatter:SetStripIntervalWhitespace(Enum.SecondsFormatterIntervalWhitespace.Strip)
	end)
	return formatter
end

-- Lie un texte a un objet de duree : le client tient le compteur a jour.
function API.CreateDurationText(fontString, formatter)
	local binding = C_DurationUtil.CreateDurationTextBinding()
	binding:SetFormatter(formatter)
	binding:SetFontString(fontString)
	return binding
end

------------------------------------------------------------------------
-- Talents
------------------------------------------------------------------------

-- Groupes de l'arbre de talents actif : liste de { order, name, points }.
-- Renvoie nil tant que le client n'a pas charge les talents. Un groupe sans
-- point depense est absent de la reponse du client : il compte pour zero.
function API.GetTalentGroups()
	local configID = C_ClassTalents.GetActiveConfigID()
	local config = configID and C_Traits.GetConfigInfo(configID)
	local treeID = config and config.treeIDs and config.treeIDs[1]
	if not treeID then
		return nil
	end
	local display = C_Traits.GetGroupDisplayInfoByTreeID(treeID)
	if not display or #display == 0 then
		return nil
	end
	local groupIDs = {}
	for index, info in ipairs(display) do
		groupIDs[index] = info.groupID
	end
	local spent = {}
	for _, currency in ipairs(C_Traits.GetGroupCurrencyInfo(configID, groupIDs) or {}) do
		local first = currency.currencyInfos and currency.currencyInfos[1]
		spent[currency.traitNodeGroupID] = first and first.spent or 0
	end
	local groups = {}
	for index, info in ipairs(display) do
		groups[index] = { order = info.orderIndex, name = info.displayName, points = spent[info.groupID] or 0 }
	end
	return groups
end
