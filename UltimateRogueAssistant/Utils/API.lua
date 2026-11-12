-- Ultimate Rogue Assistant - API
-- Seul fichier autorise a appeler les API du jeu pour le compte des modules.
-- Chaque fonction ci-dessous a ete verifiee sur le client 1.60.1.70888, soit
-- dans sa documentation, soit en jeu par l'addon de diagnostic.
--
-- Les valeurs marquees "opaque" peuvent etre secretes : elles se transmettent
-- a un widget mais ne se comparent pas et ne se calculent pas.

local _, ns = ...

local API = {}
ns.API = API

local ENERGY = Enum.PowerType.Energy
local COMBO = Enum.PowerType.ComboPoints
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

-- Energie courante (opaque) et maximum (lisible).
function API.GetEnergy()
	return UnitPower("player", ENERGY), UnitPowerMax("player", ENERGY)
end

-- Couleur de l'energie evaluee par le client a travers une courbe de couleur.
-- Renvoie un objet couleur dont les composantes sont opaques.
function API.GetEnergyColor(curve)
	return UnitPowerPercent("player", ENERGY, false, curve)
end

-- Points de combo sur la cible (jamais secrets sur Forever) et maximum.
function API.GetComboPoints()
	return GetComboPoints("player", "target"), UnitPowerMax("player", COMBO)
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
-- Armes, enchantements temporaires et objets
------------------------------------------------------------------------

local INV_SLOT = { 16, 17 }          -- main droite, main gauche
local WEAPON_SLOT = { Enum.WeaponSlot.MainHand, Enum.WeaponSlot.OffHand }
local IMBUE = Enum.ItemEnchantType and Enum.ItemEnchantType.Imbue
local WEAPON_EQUIP_LOC = { INVTYPE_WEAPON = true, INVTYPE_WEAPONOFFHAND = true, INVTYPE_WEAPONMAINHAND = true, INVTYPE_2HWEAPON = true }

function API.GetInventorySlot(hand)
	return INV_SLOT[hand]
end

-- Icone de l'arme tenue dans la main donnee, et vrai si c'est bien une arme
-- (un bouclier ou un objet tenu en main gauche ne recoit pas de poison).
function API.GetWeapon(hand)
	local itemID = GetInventoryItemID("player", INV_SLOT[hand])
	if not itemID then
		return nil, false
	end
	local _, _, _, equipLoc, icon = C_Item.GetItemInfoInstant(itemID)
	return icon, WEAPON_EQUIP_LOC[equipLoc] == true
end

-- Poison actif sur une arme. Le client renvoie une liste d'enchantements : on
-- retient l'imbue, sinon un enchantement deja reconnu comme poison (`known`).
function API.GetWeaponPoison(hand, known)
	local fallback
	for _, enchant in pairs(C_Item.GetWeaponEnchantInfo(WEAPON_SLOT[hand])) do
		if enchant.hasEnchant then
			if enchant.enchantType == IMBUE then
				return enchant
			elseif known[enchant.enchantID] then
				fallback = enchant
			end
		end
	end
	return fallback
end

function API.GetItemName(itemID)
	return C_Item.GetItemNameByID(itemID)
end

function API.GetItemIcon(itemID)
	return C_Item.GetItemIconByID(itemID)
end

function API.GetItemCount(itemID)
	return C_Item.GetItemCount(itemID) or 0
end

-- Recense dans `out` les poisons des sacs : liste de { id, name, icon, count }.
function API.ScanBagPoisons(out, keywords)
	wipe(out)
	local seen = {}
	for bag = 0, NUM_BAG_SLOTS or 4 do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local itemID = C_Container.GetContainerItemID(bag, slot)
			if itemID and not seen[itemID] then
				seen[itemID] = true
				local spellName = C_Item.GetItemSpell(itemID)
				local name = spellName and C_Item.GetItemNameByID(itemID)
				if name then
					local haystack = string.lower(name .. " " .. spellName)
					for _, keyword in ipairs(keywords) do
						if string.find(haystack, keyword, 1, true) then
							out[#out + 1] = { id = itemID, name = name, icon = C_Item.GetItemIconByID(itemID),
								count = C_Item.GetItemCount(itemID) or 0 }
							break
						end
					end
				end
			end
		end
	end
	table.sort(out, function(a, b)
		return a.name < b.name
	end)
	return out
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
