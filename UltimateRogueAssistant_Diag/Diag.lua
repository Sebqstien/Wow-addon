-- Ultimate Rogue Assistant - Diagnostic
-- Objectif unique : mesurer ce que le client autorise reellement.
-- Chaque operation sensible passe par pcall et son resultat est enregistre
-- separement selon que la valeur manipulee etait secrete ou non.
-- Aucun sort n'est lance. Le seul geste de jeu possible est le clic du joueur
-- sur les deux boutons de poison (boutons securises standard).

local ADDON_NAME = ...

local ENERGY = (Enum and Enum.PowerType and Enum.PowerType.Energy) or 3
local COMBO = (Enum and Enum.PowerType and Enum.PowerType.ComboPoints) or 4
local SLOT_MAINHAND, SLOT_OFFHAND = 16, 17
local MAX_CD_ROWS = 4

------------------------------------------------------------------------
-- Enregistrement des resultats
------------------------------------------------------------------------

local results = {}      -- cle -> { plain = {ok, err}, secret = {ok, err} }
local resultOrder = {}
local notes = {}        -- lignes libres (releves statiques)

local function IsSecret(v)
	if type(issecretvalue) ~= "function" then
		return false
	end
	local ok, res = pcall(issecretvalue, v)
	return ok and res == true
end

local function AnySecret(...)
	for i = 1, select("#", ...) do
		if IsSecret((select(i, ...))) then
			return true
		end
	end
	return false
end

local function Record(key, wasSecret, ok, err)
	local entry = results[key]
	if not entry then
		entry = {}
		results[key] = entry
		resultOrder[#resultOrder + 1] = key
	end
	local slot = wasSecret and "secret" or "plain"
	local cell = entry[slot]
	if not cell then
		cell = { count = 0 }
		entry[slot] = cell
	end
	cell.ok = ok
	cell.count = cell.count + 1
	if InCombatLockdown() then
		cell.combatCount = (cell.combatCount or 0) + 1
	end
	if not ok then
		cell.err = tostring(err)
	end
end

-- Execute fn(...) sous pcall et enregistre le resultat sous `key`.
local function Try(key, wasSecret, fn, ...)
	if type(fn) ~= "function" then
		Record(key, wasSecret, false, "fonction absente")
		return false
	end
	local ok, err = pcall(fn, ...)
	Record(key, wasSecret, ok, err)
	return ok, err
end

local function Note(fmt, ...)
	local ok, line = pcall(string.format, fmt, ...)
	notes[#notes + 1] = ok and line or (tostring(fmt) .. " [format impossible]")
end

-- Convertit une valeur en texte sans jamais provoquer d'erreur.
local function Safe(v)
	if IsSecret(v) then
		return "<SECRET>"
	end
	local ok, s = pcall(tostring, v)
	return ok and s or "<illisible>"
end

local function Resolve(path)
	local node = _G
	for part in string.gmatch(path, "[^%.]+") do
		if type(node) ~= "table" then
			return nil
		end
		node = node[part]
	end
	return node
end

local function Call(path, ...)
	local fn = Resolve(path)
	if type(fn) ~= "function" then
		return false, "absent"
	end
	return pcall(fn, ...)
end

------------------------------------------------------------------------
-- Releve statique
------------------------------------------------------------------------

local API_LIST = {
	"issecretvalue", "C_Secrets.HasSecretRestrictions", "C_Secrets.ShouldCooldownsBeSecret",
	"C_Secrets.ShouldAurasBeSecret", "C_Secrets.GetPowerTypeSecrecy", "C_Secrets.ShouldUnitPowerBeSecret",
	"C_Secrets.ShouldSpellCooldownBeSecret", "C_RestrictedActions.IsAddOnRestrictionActive",
	"C_Spell.GetSpellCooldown", "C_Spell.GetSpellCharges", "C_Spell.GetSpellCooldownDuration",
	"C_Spell.GetSpellChargeDuration", "C_Spell.IsSpellUsable", "C_Spell.GetSpellInfo",
	"C_SpellBook.GetNumSpellBookSkillLines", "C_SpellBook.GetSpellBookSkillLineInfo",
	"C_SpellBook.GetSpellBookItemInfo", "C_SpellBook.IsSpellInSpellBook",
	"UnitPower", "UnitPowerMax", "UnitPowerPercent", "GetComboPoints",
	"C_Item.GetWeaponEnchantInfo", "C_PaperDollInfo.GetTemporaryEnchantmentInfo", "GetWeaponEnchantInfo",
	"C_ClassTalents.GetActiveConfigID", "C_Traits.GetConfigInfo", "C_Traits.GetGroupDisplayInfoByTreeID",
	"C_Traits.GetGroupCurrencyInfo", "C_SpecializationInfo.GetActiveSpecGroup",
	"C_SpecializationInfo.GetSpecialization", "GetNumSpecGroups",
	"C_DurationUtil.CreateDuration", "C_DurationUtil.CreateDurationTextBinding",
	"C_CurveUtil.CreateColorCurve", "C_StringUtil.CreateSecondsFormatter",
	"C_UnitAuras.GetPlayerAuraBySpellID", "C_UnitAuras.GetAuraDuration",
	"IsStealthed", "CombatLogGetCurrentEventInfo",
}

local function ScanStatic()
	wipe(notes)

	local version, build, date, toc = GetBuildInfo()
	Note("Client : version %s, build %s, date %s, interface %s", Safe(version), Safe(build), Safe(date), Safe(toc))
	Note("WOW_PROJECT_ID = %s (WOW_PROJECT_CAMELOT = %s)", Safe(WOW_PROJECT_ID), Safe(WOW_PROJECT_CAMELOT))
	local _, classFile = UnitClass("player")
	Note("Classe : %s, niveau %s, langue %s", Safe(classFile), Safe(UnitLevel("player")), Safe(GetLocale()))
	if classFile ~= "ROGUE" then
		Note("ATTENTION : ce personnage n'est pas un voleur, les tests d'energie et de combo sont sans objet.")
	end

	Note("--- Presence des API ---")
	local missing = {}
	for _, path in ipairs(API_LIST) do
		if type(Resolve(path)) ~= "function" then
			missing[#missing + 1] = path
		end
	end
	Note("API testees : %d, absentes : %d", #API_LIST, #missing)
	for _, path in ipairs(missing) do
		Note("  ABSENTE : %s", path)
	end

	Note("--- Restrictions (etat a l'instant du releve, en combat : %s) ---", Safe(InCombatLockdown()))
	local ok, v = Call("C_Secrets.HasSecretRestrictions")
	Note("HasSecretRestrictions = %s", ok and Safe(v) or "appel impossible")
	ok, v = Call("C_Secrets.ShouldCooldownsBeSecret")
	Note("ShouldCooldownsBeSecret = %s", ok and Safe(v) or "appel impossible")
	ok, v = Call("C_Secrets.ShouldAurasBeSecret")
	Note("ShouldAurasBeSecret = %s", ok and Safe(v) or "appel impossible")
	ok, v = Call("C_Secrets.GetPowerTypeSecrecy", ENERGY)
	Note("Secret de l'energie (0 jamais, 1 toujours, 2 selon contexte) = %s", ok and Safe(v) or "appel impossible")
	ok, v = Call("C_Secrets.GetPowerTypeSecrecy", COMBO)
	Note("Secret des points de combo = %s", ok and Safe(v) or "appel impossible")
	ok, v = Call("C_Secrets.ShouldUnitPowerBeSecret", "player", ENERGY)
	Note("ShouldUnitPowerBeSecret(player, energie) = %s", ok and Safe(v) or "appel impossible")
	ok, v = Call("C_Secrets.ShouldUnitPowerBeSecret", "player", COMBO)
	Note("ShouldUnitPowerBeSecret(player, combo) = %s", ok and Safe(v) or "appel impossible")
	if Enum and Enum.AddOnRestrictionType then
		for name, value in pairs(Enum.AddOnRestrictionType) do
			ok, v = Call("C_RestrictedActions.IsAddOnRestrictionActive", value)
			Note("Restriction %s active = %s", Safe(name), ok and Safe(v) or "appel impossible")
		end
	end

	Note("--- Talents ---")
	local okCfg, configID = Call("C_ClassTalents.GetActiveConfigID")
	Note("Config de talents active = %s", okCfg and Safe(configID) or "appel impossible")
	ok, v = Call("C_SpecializationInfo.GetActiveSpecGroup")
	Note("Groupe de specialisation actif (double spe) = %s", ok and Safe(v) or "appel impossible")
	ok, v = Call("GetNumSpecGroups")
	Note("Nombre de groupes de specialisation = %s", ok and Safe(v) or "appel impossible")
	ok, v = Call("C_SpecializationInfo.GetSpecialization")
	Note("GetSpecialization (systeme moderne) = %s", ok and Safe(v) or "appel impossible")
	if okCfg and configID then
		local okInfo, info = Call("C_Traits.GetConfigInfo", configID)
		local treeID = okInfo and type(info) == "table" and info.treeIDs and info.treeIDs[1]
		Note("Arbre de talents (treeID) = %s", Safe(treeID))
		if treeID then
			local okGroups, groups = Call("C_Traits.GetGroupDisplayInfoByTreeID", treeID)
			if okGroups and type(groups) == "table" then
				local ids = {}
				for i, g in ipairs(groups) do
					ids[i] = g.groupID
				end
				local okCur, currencies = Call("C_Traits.GetGroupCurrencyInfo", configID, ids)
				for _, g in ipairs(groups) do
					local spent = "0 (groupe absent de la reponse)"
					if okCur and type(currencies) == "table" then
						for _, c in ipairs(currencies) do
							if c.traitNodeGroupID == g.groupID and c.currencyInfos and c.currencyInfos[1] then
								spent = Safe(c.currencyInfos[1].spent)
							end
						end
					end
					Note("  Groupe %s (ordre %s) \"%s\" : %s points", Safe(g.groupID), Safe(g.orderIndex), Safe(g.displayName), spent)
				end
			else
				Note("  Groupes de l'arbre illisibles")
			end
		end
	end

	Note("--- Enchantements d'arme ---")
	for slot = 0, 1 do
		local label = slot == 0 and "Main droite" or "Main gauche"
		local okE, list = Call("C_Item.GetWeaponEnchantInfo", slot)
		if okE and type(list) == "table" then
			local n = 0
			for _, e in pairs(list) do
				n = n + 1
				Note("  %s #%d : hasEnchant=%s type=%s timeLeft(ms)=%s charges=%s enchantID=%s icone=%s",
					label, n, Safe(e.hasEnchant), Safe(e.enchantType), Safe(e.timeLeft), Safe(e.charges),
					Safe(e.enchantID), Safe(e.enchantIconID))
			end
			if n == 0 then
				Note("  %s : liste vide", label)
			end
		else
			Note("  %s : C_Item.GetWeaponEnchantInfo indisponible (%s)", label, Safe(list))
		end
		local invSlot = slot == 0 and SLOT_MAINHAND or SLOT_OFFHAND
		local okT, t = Call("C_PaperDollInfo.GetTemporaryEnchantmentInfo", invSlot)
		if okT and type(t) == "table" then
			Note("  %s (PaperDoll) : enchantID=%s reste(ms)=%s charges=%s expire=%s", label,
				Safe(t.enchantID), Safe(t.remainingTimeMs), Safe(t.chargesRemaining), Safe(t.hasExpirationTime))
		else
			Note("  %s (PaperDoll) : aucun enchantement temporaire ou API absente", label)
		end
		Note("  %s : objet equipe = %s", label, Safe(GetInventoryItemLink("player", invSlot)))
	end
end

------------------------------------------------------------------------
-- Grimoire : liste des sorts actifs (sert aux tests de cooldown)
------------------------------------------------------------------------

local knownSpells = {}   -- liste de { id = number, name = string, icon = number }

local function ScanSpellBook()
	wipe(knownSpells)
	local okN, numLines = Call("C_SpellBook.GetNumSpellBookSkillLines")
	if not okN or type(numLines) ~= "number" then
		return
	end
	local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
	local spellType = (Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell) or 1
	local seen = {}
	for line = 1, numLines do
		local okL, lineInfo = Call("C_SpellBook.GetSpellBookSkillLineInfo", line)
		if okL and type(lineInfo) == "table" then
			for index = lineInfo.itemIndexOffset + 1, lineInfo.itemIndexOffset + lineInfo.numSpellBookItems do
				local okI, item = Call("C_SpellBook.GetSpellBookItemInfo", index, bank)
				if okI and type(item) == "table" and item.itemType == spellType and not item.isPassive
					and not item.isOffSpec and item.spellID and not seen[item.spellID] then
					seen[item.spellID] = true
					knownSpells[#knownSpells + 1] = { id = item.spellID, name = item.name, icon = item.iconID }
				end
			end
		end
	end
end

------------------------------------------------------------------------
-- Panneau de test en direct (aucun cadre securise ici)
------------------------------------------------------------------------

local panel, energyBar, energyText, energyPct, comboText
local comboPips = {}
local cdRows = {}
local colorCurve

local function MakeBackdrop(frame, alpha)
	local bg = frame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, alpha or 0.6)
	return bg
end

local function MakeBar(parent, width, height)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetSize(width, height)
	bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
	bar:SetStatusBarColor(1, 0.85, 0.1)
	MakeBackdrop(bar, 0.7)
	return bar
end

local function BuildPanel()
	panel = CreateFrame("Frame", "URADiagPanel", UIParent)
	panel:SetSize(300, 250)
	panel:SetPoint("CENTER", UIParent, "CENTER", -360, 0)
	panel:SetMovable(true)
	panel:EnableMouse(true)
	panel:RegisterForDrag("LeftButton")
	panel:SetScript("OnDragStart", panel.StartMoving)
	panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
	panel:SetClampedToScreen(true)
	MakeBackdrop(panel, 0.6)

	local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOP", 0, -6)
	title:SetText("URA Diagnostic  -  /uradiag")

	-- Energie : la valeur va directement de l'API au widget.
	energyBar = MakeBar(panel, 280, 18)
	energyBar:SetPoint("TOP", 0, -28)
	energyText = energyBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	energyText:SetPoint("CENTER")
	energyPct = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	energyPct:SetPoint("TOPLEFT", energyBar, "BOTTOMLEFT", 0, -2)

	-- Combo : une mini-barre par point, bornee a [i-1, i].
	-- Le client remplit la barre i quand la valeur atteint i, sans lecture Lua.
	for i = 1, 5 do
		local pip = MakeBar(panel, 40, 14)
		pip:SetPoint("TOPLEFT", energyBar, "BOTTOMLEFT", (i - 1) * 46, -20)
		pip:SetStatusBarColor(0.9, 0.2, 0.2)
		pip:SetMinMaxValues(i - 1, i)
		pip:SetValue(0)
		comboPips[i] = pip
	end
	comboText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	comboText:SetPoint("LEFT", comboPips[5], "RIGHT", 8, 0)

	-- Cooldowns : icone + balayage natif + barre + texte.
	for i = 1, MAX_CD_ROWS do
		local row = CreateFrame("Frame", nil, panel)
		row:SetSize(280, 24)
		row:SetPoint("TOPLEFT", energyBar, "BOTTOMLEFT", 0, -46 - (i - 1) * 28)

		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(24, 24)
		row.icon:SetPoint("LEFT")

		row.cooldown = CreateFrame("Cooldown", nil, row, "CooldownFrameTemplate")
		row.cooldown:SetAllPoints(row.icon)

		row.bar = MakeBar(row, 180, 14)
		row.bar:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
		row.bar:SetStatusBarColor(0.3, 0.6, 1)

		row.name = row.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.name:SetPoint("LEFT", 3, 0)

		row.time = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.time:SetPoint("LEFT", row.bar, "RIGHT", 6, 0)

		row:Hide()
		cdRows[i] = row
	end

	panel.hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	panel.hint:SetPoint("BOTTOM", 0, 6)
	panel.hint:SetText("Utilisez vos techniques en combat, puis /uradiag report")
end

local function BuildColorCurve()
	local okC, curve = Call("C_CurveUtil.CreateColorCurve")
	if not okC or not curve then
		Record("energie.courbe de couleur (creation)", false, false, curve)
		return
	end
	local ok = pcall(function()
		if Enum.LuaCurveType and curve.SetType then
			curve:SetType(Enum.LuaCurveType.Step)
		end
		curve:AddPoint(0, CreateColor(0.9, 0.2, 0.2, 1))
		curve:AddPoint(0.3, CreateColor(0.95, 0.75, 0.1, 1))
		curve:AddPoint(0.6, CreateColor(0.2, 0.85, 0.3, 1))
	end)
	Record("energie.courbe de couleur (creation)", false, ok)
	if ok then
		colorCurve = curve
	end
end

local function UpdateEnergy()
	local value = UnitPower("player", ENERGY)
	local maxValue = UnitPowerMax("player", ENERGY)
	local secret = AnySecret(value, maxValue)

	Try("energie.barre SetMinMaxValues", IsSecret(maxValue), energyBar.SetMinMaxValues, energyBar, 0, maxValue)
	Try("energie.barre SetValue", IsSecret(value), energyBar.SetValue, energyBar, value)
	Try("energie.texte SetFormattedText(valeur/max)", secret, energyText.SetFormattedText, energyText, "%d / %d", value, maxValue)

	local scale = CurveConstants and CurveConstants.ScaleTo100
	local okP, pct = Call("UnitPowerPercent", "player", ENERGY, false, scale)
	if okP then
		Try("energie.texte pourcentage SetText", IsSecret(pct), energyPct.SetFormattedText, energyPct, scale and "%d %%" or "%.2f", pct)
		if not IsSecret(pct) then
			results.__pctSample = Safe(pct)
		end
	else
		Record("energie.UnitPowerPercent", false, false, pct)
	end

	if colorCurve then
		Try("energie.couleur par seuil (courbe)", secret, function()
			local color = UnitPowerPercent("player", ENERGY, false, colorCurve)
			energyBar:GetStatusBarTexture():SetVertexColor(color:GetRGB())
		end)
	end

	-- Temoin : ce que Lua ne doit PAS pouvoir faire sur une valeur secrete.
	Try("energie.lecture Lua (comparaison value > 50)", IsSecret(value), function()
		return value > 50
	end)
end

local function UpdateCombo()
	local points = GetComboPoints("player", "target")
	local secret = IsSecret(points)
	for i = 1, 5 do
		Try("combo.pastille individuelle SetValue", secret, comboPips[i].SetValue, comboPips[i], points)
	end
	Try("combo.chiffre SetText", secret, comboText.SetText, comboText, points)
	Try("combo.lecture Lua (comparaison points >= 5)", secret, function()
		return points >= 5
	end)

	local viaPower = UnitPower("player", COMBO)
	Record("combo.UnitPower(player, ComboPoints) appelable", IsSecret(viaPower), true)
end

local activeBySpell = {}   -- spellID -> index de ligne

local function ReleaseRow(spellID)
	local index = activeBySpell[spellID]
	if index then
		local binding = cdRows[index].binding
		if binding then
			pcall(binding.SetEnabled, binding, false)
		end
		cdRows[index]:Hide()
		cdRows[index].spellID = nil
		activeBySpell[spellID] = nil
	end
end

local function AcquireRow(spellID)
	if activeBySpell[spellID] then
		return cdRows[activeBySpell[spellID]], false
	end
	for i = 1, MAX_CD_ROWS do
		if not cdRows[i].spellID then
			cdRows[i].spellID = spellID
			activeBySpell[spellID] = i
			return cdRows[i], true
		end
	end
end

local function ApplyCooldownToRow(row, spell, info)
	row.icon:SetTexture(spell.icon)
	row.name:SetText(spell.name)
	row:Show()

	local okD, duration = Call("C_Spell.GetSpellCooldownDuration", spell.id)
	if not okD or not duration then
		Record("cooldown.GetSpellCooldownDuration renvoie un objet", false, false, duration)
		return
	end
	local secret = false
	if duration.HasSecretValues then
		local okS, s = pcall(duration.HasSecretValues, duration)
		secret = okS and s == true
	end
	secret = secret or AnySecret(info.startTime, info.duration)
	Record("cooldown.GetSpellCooldownDuration renvoie un objet", secret, true)

	-- 1. Affichage natif : balayage sur l'icone + chiffres natifs.
	Try("cooldown.natif SetCooldownFromDurationObject", secret, row.cooldown.SetCooldownFromDurationObject, row.cooldown, duration)
	Try("cooldown.natif chiffres (SetHideCountdownNumbers)", secret, row.cooldown.SetHideCountdownNumbers, row.cooldown, false)

	-- 2. Barre horizontale personnalisee animee par le client.
	local direction = Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime
	local interpolation = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate
	Try("cooldown.barre SetTimerDuration", secret, row.bar.SetTimerDuration, row.bar, duration, interpolation, direction)

	-- 3a. Compteur numerique entretenu par le client.
	Try("cooldown.texte DurationTextBinding", secret, function()
		if not row.binding then
			row.binding = C_DurationUtil.CreateDurationTextBinding()
			row.binding:SetFormatter(C_StringUtil.CreateSecondsFormatter())
			row.binding:SetFontString(row.time)
		end
		row.binding:SetDuration(duration)
		row.binding:SetEnabled(true)
	end)

	-- 3b. Compteur numerique : valeur ponctuelle transmise au texte.
	Try("cooldown.texte SetFormattedText(GetRemainingDuration)", secret, function()
		row.time:SetFormattedText("%.0f s", duration:GetRemainingDuration())
	end)

	-- Temoins : anciens chemins, attendus en echec si les valeurs sont secretes.
	Try("cooldown.ancien SetCooldown(start, duration)", secret, function()
		if not row.legacy then
			row.legacy = CreateFrame("Cooldown", nil, row, "CooldownFrameTemplate")
			row.legacy:SetSize(1, 1)
			row.legacy:SetPoint("RIGHT")
		end
		row.legacy:SetCooldown(info.startTime, info.duration)
	end)
	Try("cooldown.lecture Lua (calcul du temps restant)", secret, function()
		return info.startTime + info.duration - GetTime() > 3
	end)
end

local function UpdateCooldowns()
	for _, spell in ipairs(knownSpells) do
		local okI, info = Call("C_Spell.GetSpellCooldown", spell.id)
		if okI and type(info) == "table" then
			-- isActive et isOnGCD sont documentes "jamais secrets" : on le verifie.
			local okF, tracked = pcall(function()
				return info.isActive == true and info.isOnGCD ~= true
			end)
			Record("cooldown.drapeaux isActive/isOnGCD lisibles", AnySecret(info.startTime, info.duration), okF, tracked)

			if okF and tracked then
				local row, isNew = AcquireRow(spell.id)
				if row and isNew then
					ApplyCooldownToRow(row, spell, info)
				end
			elseif okF and activeBySpell[spell.id] then
				-- Transition "en recharge" -> "pret" : c'est l'alerte de disponibilite.
				Record("cooldown.detection du retour a l'etat pret", false, true)
				ReleaseRow(spell.id)
				local okU, usable, noPower = Call("C_Spell.IsSpellUsable", spell.id)
				Try("disponibilite.IsSpellUsable lisible", AnySecret(usable, noPower), function()
					return (usable == true) or (noPower == true)
				end)
				if not okU then
					Record("disponibilite.IsSpellUsable lisible", false, false, usable)
				end
			end
		end
	end
end

------------------------------------------------------------------------
-- Boutons securises de poison (groupe separe, modifiable hors combat)
------------------------------------------------------------------------

local poisonFrame
local poisonButtons = {}
local HAND_LABEL = { "main droite", "main gauche" }
local applyState = {}     -- index de bouton -> texte d'etat
local selectedPoison      -- defini plus bas : index de bouton -> choix
local pendingApply        -- { index, time, ids, maxTime }

-- Resume lisible des enchantements d'une arme (0 = main droite, 1 = main gauche).
local function EnchantSnapshot(weaponSlot)
	local ids, maxTime, count = "", 0, 0
	local ok = pcall(function()
		local list = C_Item.GetWeaponEnchantInfo(weaponSlot)
		for _, e in pairs(list) do
			if e.hasEnchant then
				count = count + 1
				ids = ids .. tostring(e.enchantID) .. ","
				if e.timeLeft and e.timeLeft > maxTime then
					maxTime = e.timeLeft
				end
			end
		end
	end)
	if not ok then
		return nil
	end
	return ids, maxTime, count
end

local function OnPoisonButtonClicked(index)
	if pendingApply and pendingApply.index == index and GetTime() - pendingApply.time < 1 then
		return -- second passage du meme clic (appui puis relachement)
	end
	if not selectedPoison[index] then
		applyState[index] = "clic recu, mais aucun poison n'etait choisi pour ce bouton"
		return
	end
	local ids, maxTime = EnchantSnapshot(index - 1)
	pendingApply = { index = index, time = GetTime(), ids = ids, maxTime = maxTime or 0 }
	applyState[index] = "clic recu, aucun changement d'enchantement detecte"
	Record("poison.clic recu sur le bouton " .. HAND_LABEL[index], false, true)
end

local function CheckPoisonApplied()
	if not pendingApply or GetTime() - pendingApply.time > 20 then
		return
	end
	local index = pendingApply.index
	local ids, maxTime = EnchantSnapshot(index - 1)
	if ids and (ids ~= pendingApply.ids or maxTime > pendingApply.maxTime + 1000) then
		applyState[index] = "CONFIRME : l'enchantement de l'arme a change apres le clic"
		Record("poison.application confirmee " .. HAND_LABEL[index], false, true)
		pendingApply = nil
	end
end

local QUESTION_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
selectedPoison = {}         -- index de bouton -> { kind = "item"|"spell", id = number }
local bagPoisons, bagOthers = {}, {}

-- Recense les objets utilisables des sacs. Un objet est classe "poison" si son
-- nom ou le nom de son effet contient "poison" ; les autres restent proposes
-- dans un sous-menu, au cas ou ce critere ne conviendrait pas a Forever.
local function ScanBags()
	wipe(bagPoisons)
	wipe(bagOthers)
	local seen = {}
	pcall(function()
		for bag = 0, (NUM_BAG_SLOTS or 4) do
			for slot = 1, C_Container.GetContainerNumSlots(bag) do
				local itemID = C_Container.GetContainerItemID(bag, slot)
				if itemID and not seen[itemID] then
					seen[itemID] = true
					local spellName, spellID = C_Item.GetItemSpell(itemID)
					if spellName then
						local name = C_Item.GetItemNameByID(itemID) or ("objet " .. itemID)
						local _, _, _, _, icon, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
						local entry = {
							id = itemID, name = name, icon = icon, classID = classID, subClassID = subClassID,
							spellName = spellName, spellID = spellID, count = C_Item.GetItemCount(itemID),
						}
						local haystack = string.lower(name .. " " .. spellName)
						if string.find(haystack, "poison", 1, true) then
							bagPoisons[#bagPoisons + 1] = entry
						else
							bagOthers[#bagOthers + 1] = entry
						end
					end
				end
			end
		end
	end)
	local byName = function(a, b)
		return a.name < b.name
	end
	table.sort(bagPoisons, byName)
	table.sort(bagOthers, byName)
end

local function UpdatePoisonDisplay()
	if not poisonFrame then
		return
	end
	for index, button in ipairs(poisonButtons) do
		local invSlot = index == 1 and SLOT_MAINHAND or SLOT_OFFHAND
		button.icon:SetTexture(GetInventoryItemTexture("player", invSlot) or QUESTION_ICON)

		local choice = selectedPoison[index]
		if choice and choice.kind == "item" then
			button.badge:SetTexture(C_Item.GetItemIconByID(choice.id) or QUESTION_ICON)
			button.count:SetText(C_Item.GetItemCount(choice.id) or 0)
			button.badge:Show()
		elseif choice then
			local info = C_Spell.GetSpellInfo(choice.id)
			button.badge:SetTexture(info and info.iconID or QUESTION_ICON)
			button.count:SetText("")
			button.badge:Show()
		else
			button.badge:Hide()
			button.count:SetText("")
		end

		-- Etat actuel de l'arme : icone de l'enchantement, duree et charges.
		local statusIcon, statusText = nil, "|cffff5555aucun poison|r"
		pcall(function()
			for _, e in pairs(C_Item.GetWeaponEnchantInfo(index - 1)) do
				if e.hasEnchant then
					statusIcon = e.enchantIconID
					statusText = string.format("%d min", math.ceil(e.timeLeft / 60000))
					if e.charges and e.charges > 0 then
						statusText = statusText .. string.format("  %d ch.", e.charges)
					end
				end
			end
		end)
		button.statusIcon:SetTexture(statusIcon)
		button.statusIcon:SetShown(statusIcon ~= nil)
		button.status:SetText(statusText)
	end
end

local function SelectPoison(index, kind, id)
	if InCombatLockdown() then
		print("|cffff5555URA Diag|r : choix impossible en combat (restriction des boutons securises).")
		return
	end
	local button = poisonButtons[index]
	-- "type1" : seul le clic gauche declenche l'action ; le clic droit ouvre le menu.
	button:SetAttribute("type1", kind)
	button:SetAttribute("item", kind == "item" and ("item:" .. id) or nil)
	button:SetAttribute("spell", kind == "spell" and id or nil)
	selectedPoison[index] = { kind = kind, id = id }
	URADiagDB.poisons = URADiagDB.poisons or {}
	URADiagDB.poisons[index] = { kind = kind, id = id }
	Record("poison.selection enregistree pour la " .. HAND_LABEL[index], false, true)
	UpdatePoisonDisplay()
end

local function MenuLabel(entry)
	return string.format("|T%s:16|t %s  |cffaaaaaax%d|r", tostring(entry.icon or QUESTION_ICON), entry.name, entry.count or 0)
end

local function OpenPoisonMenu(index)
	if InCombatLockdown() then
		print("|cffff5555URA Diag|r : le choix du poison se fait hors combat.")
		return
	end
	ScanBags()
	local ok, err = pcall(MenuUtil.CreateContextMenu, poisonButtons[index], function(_, root)
		root:CreateTitle("Poison pour la " .. HAND_LABEL[index])
		if #bagPoisons == 0 then
			root:CreateTitle("|cffff5555Aucun poison reconnu dans les sacs|r")
		end
		for _, entry in ipairs(bagPoisons) do
			root:CreateButton(MenuLabel(entry), function()
				SelectPoison(index, "item", entry.id)
			end)
		end
		if #bagOthers > 0 then
			local sub = root:CreateButton("Autres objets utilisables")
			for _, entry in ipairs(bagOthers) do
				sub:CreateButton(MenuLabel(entry), function()
					SelectPoison(index, "item", entry.id)
				end)
			end
		end
	end)
	Record("poison.menu de selection (MenuUtil)", false, ok, err)
end

local function BuildPoisonButtons()
	poisonFrame = CreateFrame("Frame", "URADiagPoisonFrame", UIParent)
	poisonFrame:SetSize(230, 96)
	poisonFrame:SetPoint("CENTER", UIParent, "CENTER", -360, -200)
	MakeBackdrop(poisonFrame, 0.75)
	local label = poisonFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("TOP", 0, -6)
	label:SetText("Poisons")
	local help = poisonFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	help:SetPoint("BOTTOM", 0, 5)
	help:SetText("Clic droit : choisir   Clic gauche : appliquer")

	local slots = { SLOT_MAINHAND, SLOT_OFFHAND }
	for i, invSlot in ipairs(slots) do
		local button = CreateFrame("Button", "URADiagPoisonButton" .. i, poisonFrame, "SecureActionButtonTemplate")
		button:SetSize(40, 40)
		button:SetPoint("TOPLEFT", 14 + (i - 1) * 108, -22)
		button:RegisterForClicks("AnyUp", "AnyDown")
		button:SetAttribute("target-slot", invSlot)

		button.icon = button:CreateTexture(nil, "ARTWORK")
		button.icon:SetAllPoints()
		button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

		-- Pastille : poison choisi pour cette arme, avec la quantite en sac.
		button.badge = button:CreateTexture(nil, "OVERLAY")
		button.badge:SetSize(18, 18)
		button.badge:SetPoint("BOTTOMRIGHT", 4, -4)
		button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
		button.count:SetPoint("TOPRIGHT", 2, 2)

		button.hand = poisonFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		button.hand:SetPoint("TOPLEFT", button, "TOPRIGHT", 6, 0)
		button.hand:SetText(i == 1 and "Main droite" or "Main gauche")
		button.statusIcon = poisonFrame:CreateTexture(nil, "ARTWORK")
		button.statusIcon:SetSize(14, 14)
		button.statusIcon:SetPoint("TOPLEFT", button.hand, "BOTTOMLEFT", 0, -3)
		button.status = poisonFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		button.status:SetPoint("TOPLEFT", button.hand, "BOTTOMLEFT", 0, -20)

		button:HookScript("PostClick", function(_, mouseButton, down)
			if mouseButton == "RightButton" then
				if not down then
					OpenPoisonMenu(i)
				end
			else
				OnPoisonButtonClicked(i)
			end
		end)
		poisonButtons[i] = button
	end
end

-- Commande de secours : regle les deux boutons sur le meme objet ou sort.
local function SetPoison(kind, id)
	SelectPoison(1, kind, id)
	SelectPoison(2, kind, id)
end

------------------------------------------------------------------------
-- Rapport
------------------------------------------------------------------------

local function CellText(cell)
	if not cell then
		return "non observe"
	end
	if cell.ok then
		return string.format("OK (%d fois, dont %d en combat)", cell.count, cell.combatCount or 0)
	end
	return "ECHEC : " .. (cell.err or "?")
end

-- Verdict d'un test : la colonne "secrete" prime, car c'est elle qui prouve le cas restrictif.
local function Verdict(key)
	local entry = results[key]
	if not entry then
		return "NON TESTE"
	end
	if entry.secret then
		if entry.secret.ok then
			return "CONFIRME avec valeurs secretes (" .. entry.secret.count .. " fois)"
		end
		return "ECHEC avec valeurs secretes : " .. (entry.secret.err or "?")
	end
	if entry.plain.ok then
		return "OK, mais jamais observe avec une valeur secrete (" .. entry.plain.count .. " fois)"
	end
	return "ECHEC : " .. (entry.plain.err or "?")
end

local function AnySecretSeen()
	for _, key in ipairs(resultOrder) do
		if results[key].secret then
			return true
		end
	end
	return false
end

local function AddVerdicts(lines)
	lines[#lines + 1] = "--- VERDICTS ---"
	lines[#lines + 1] = "Valeurs secretes rencontrees pendant les tests : " .. (AnySecretSeen() and "OUI" or "NON")
	lines[#lines + 1] = "1. Cooldowns par objet de duree"
	lines[#lines + 1] = "   balayage natif : " .. Verdict("cooldown.natif SetCooldownFromDurationObject")
	lines[#lines + 1] = "   chiffres natifs : " .. Verdict("cooldown.natif chiffres (SetHideCountdownNumbers)")
	lines[#lines + 1] = "   barre horizontale : " .. Verdict("cooldown.barre SetTimerDuration")
	lines[#lines + 1] = "   compteur lie : " .. Verdict("cooldown.texte DurationTextBinding")
	lines[#lines + 1] = "   retour a l'etat pret : " .. Verdict("cooldown.detection du retour a l'etat pret")
	lines[#lines + 1] = "2. Energie"
	lines[#lines + 1] = "   barre : " .. Verdict("energie.barre SetValue")
	lines[#lines + 1] = "   valeur numerique : " .. Verdict("energie.texte SetFormattedText(valeur/max)")
	lines[#lines + 1] = "   pourcentage : " .. Verdict("energie.texte pourcentage SetText")
	lines[#lines + 1] = "   couleur par seuil : " .. Verdict("energie.couleur par seuil (courbe)")
	lines[#lines + 1] = "3. Points de combo"
	lines[#lines + 1] = "   cinq pastilles : " .. Verdict("combo.pastille individuelle SetValue")
	lines[#lines + 1] = "   chiffre : " .. Verdict("combo.chiffre SetText")
	lines[#lines + 1] = "4. Detection des poisons"
	for index = 1, 2 do
		local ids, maxTime, count = EnchantSnapshot(index - 1)
		if ids == nil then
			lines[#lines + 1] = "   " .. HAND_LABEL[index] .. " : ECHEC de lecture"
		else
			lines[#lines + 1] = string.format("   %s : %d enchantement(s) actif(s), id [%s], reste %d s",
				HAND_LABEL[index], count, ids, math.floor(maxTime / 1000))
		end
	end
	lines[#lines + 1] = "   menu de selection : " .. Verdict("poison.menu de selection (MenuUtil)")
	lines[#lines + 1] = "5. Application par bouton securise"
	for index = 1, 2 do
		lines[#lines + 1] = "   " .. HAND_LABEL[index] .. " : " .. (applyState[index] or "NON TESTE")
	end
	lines[#lines + 1] = ""
end

local function BuildReport()
	ScanStatic()
	local lines = {}
	lines[#lines + 1] = "=== URA Diagnostic 1.1 ==="
	AddVerdicts(lines)
	for _, line in ipairs(notes) do
		lines[#lines + 1] = line
	end
	lines[#lines + 1] = string.format("Sorts actifs trouves dans le grimoire : %d", #knownSpells)
	lines[#lines + 1] = "Echantillon de UnitPowerPercent (valeur lisible) : " .. tostring(results.__pctSample or "non observe")
	lines[#lines + 1] = ""
	lines[#lines + 1] = "--- Tests en direct ---"
	lines[#lines + 1] = "Format : test | avec valeur lisible | avec valeur SECRETE"
	for _, key in ipairs(resultOrder) do
		local entry = results[key]
		lines[#lines + 1] = string.format("%s | %s | %s", key, CellText(entry.plain), CellText(entry.secret))
	end
	lines[#lines + 1] = ""
	lines[#lines + 1] = "--- Objets des sacs reconnus comme poisons (id ; nom ; quantite ; classe/sous-classe ; effet) ---"
	ScanBags()
	for _, e in ipairs(bagPoisons) do
		lines[#lines + 1] = string.format("%d ; %s ; x%s ; %s/%s ; %s (%s)", e.id, e.name, tostring(e.count),
			tostring(e.classID), tostring(e.subClassID), tostring(e.spellName), tostring(e.spellID))
	end
	lines[#lines + 1] = string.format("Autres objets utilisables dans les sacs : %d", #bagOthers)
	for index = 1, 2 do
		local c = selectedPoison[index]
		lines[#lines + 1] = string.format("Choix pour la %s : %s", HAND_LABEL[index], c and (c.kind .. " " .. c.id) or "aucun")
	end
	lines[#lines + 1] = ""
	lines[#lines + 1] = "--- Grimoire (id ; nom) ---"
	for _, spell in ipairs(knownSpells) do
		lines[#lines + 1] = string.format("%d ; %s", spell.id, tostring(spell.name))
	end
	local report = table.concat(lines, "\n")
	URADiagDB.report = report
	URADiagDB.reportTime = date("%Y-%m-%d %H:%M:%S")
	return report
end

local reportFrame

local function ShowReport()
	local report = BuildReport()
	if not reportFrame then
		reportFrame = CreateFrame("Frame", "URADiagReportFrame", UIParent)
		reportFrame:SetSize(720, 480)
		reportFrame:SetPoint("CENTER")
		reportFrame:SetFrameStrata("DIALOG")
		reportFrame:EnableMouse(true)
		MakeBackdrop(reportFrame, 0.9)

		local close = CreateFrame("Button", nil, reportFrame, "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT", 2, 2)

		local hint = reportFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		hint:SetPoint("TOPLEFT", 10, -8)
		hint:SetText("Ctrl+A puis Ctrl+C pour copier. Egalement enregistre dans SavedVariables (URADiagDB).")

		local scroll = CreateFrame("ScrollFrame", nil, reportFrame, "UIPanelScrollFrameTemplate")
		scroll:SetPoint("TOPLEFT", 10, -28)
		scroll:SetPoint("BOTTOMRIGHT", -30, 10)

		local edit = CreateFrame("EditBox", nil, scroll)
		edit:SetMultiLine(true)
		edit:SetAutoFocus(false)
		edit:SetFontObject(ChatFontNormal)
		edit:SetWidth(670)
		edit:SetScript("OnEscapePressed", function(self)
			self:ClearFocus()
		end)
		scroll:SetScrollChild(edit)
		reportFrame.edit = edit
	end
	reportFrame.edit:SetText(report)
	reportFrame.edit:SetCursorPosition(0)
	reportFrame:Show()
end

------------------------------------------------------------------------
-- Evenements et commandes
------------------------------------------------------------------------

local events = CreateFrame("Frame")
local started = false

local function Start()
	if started then
		return
	end
	started = true
	BuildPanel()
	BuildColorCurve()
	ScanSpellBook()
	if URADiagDB.poisons and not InCombatLockdown() then
		for index, choice in pairs(URADiagDB.poisons) do
			if poisonButtons[index] then
				SelectPoison(index, choice.kind, choice.id)
			end
		end
	end
	UpdatePoisonDisplay()
	C_Timer.NewTicker(5, UpdatePoisonDisplay)

	events:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
	events:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
	events:RegisterUnitEvent("UNIT_MAXPOWER", "player")
	events:RegisterEvent("PLAYER_TARGET_CHANGED")
	events:RegisterEvent("COMBO_TARGET_CHANGED")
	events:RegisterEvent("SPELL_UPDATE_COOLDOWN")
	events:RegisterEvent("SPELLS_CHANGED")
	events:RegisterEvent("WEAPON_ENCHANT_CHANGED")
	events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	events:RegisterEvent("BAG_UPDATE_DELAYED")
	events:RegisterEvent("PLAYER_REGEN_DISABLED")
	events:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
	events:RegisterEvent("ADDON_ACTION_BLOCKED")
	events:RegisterEvent("ADDON_ACTION_FORBIDDEN")

	UpdateEnergy()
	UpdateCombo()
	print("|cff33ff99URA Diag|r charge. Commandes : /uradiag report, /uradiag hide, /uradiag show. Poisons : clic droit sur une arme.")
end

events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")

events:SetScript("OnEvent", function(_, event, arg1, arg2)
	if event == "ADDON_LOADED" then
		if arg1 == ADDON_NAME then
			URADiagDB = URADiagDB or {}
			-- Les cadres securises sont crees des le chargement, donc toujours hors combat.
			BuildPoisonButtons()
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		URADiagDB = URADiagDB or {}
		Start()
	elseif not started then
		return
	elseif event == "UNIT_POWER_FREQUENT" or event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" then
		UpdateEnergy()
		UpdateCombo()
	elseif event == "PLAYER_TARGET_CHANGED" or event == "COMBO_TARGET_CHANGED" then
		Record("evenement." .. event .. " recu", false, true)
		UpdateCombo()
	elseif event == "SPELL_UPDATE_COOLDOWN" then
		UpdateCooldowns()
	elseif event == "SPELLS_CHANGED" then
		if not InCombatLockdown() then
			ScanSpellBook()
		end
	elseif event == "WEAPON_ENCHANT_CHANGED" then
		Record("evenement.WEAPON_ENCHANT_CHANGED recu", false, true)
		CheckPoisonApplied()
		UpdatePoisonDisplay()
	elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "BAG_UPDATE_DELAYED" then
		UpdatePoisonDisplay()
	elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
		if arg1 == ADDON_NAME then
			Record("ACTION REFUSEE par le client (" .. event .. ") : " .. Safe(arg2), false, false, "bloque")
		end
	elseif event == "PLAYER_REGEN_DISABLED" then
		-- Releve des restrictions au moment exact de l'entree en combat.
		local ok, v = Call("C_Secrets.ShouldCooldownsBeSecret")
		Record("combat.ShouldCooldownsBeSecret = " .. (ok and Safe(v) or "?"), false, true)
		ok, v = Call("C_Secrets.ShouldUnitPowerBeSecret", "player", ENERGY)
		Record("combat.energie secrete = " .. (ok and Safe(v) or "?"), false, true)
		ok, v = Call("C_Secrets.ShouldUnitPowerBeSecret", "player", COMBO)
		Record("combat.combo secret = " .. (ok and Safe(v) or "?"), false, true)
		ok, v = Call("C_Secrets.ShouldAurasBeSecret")
		Record("combat.ShouldAurasBeSecret = " .. (ok and Safe(v) or "?"), false, true)
	elseif event == "ADDON_RESTRICTION_STATE_CHANGED" then
		Record("evenement.ADDON_RESTRICTION_STATE_CHANGED type " .. Safe(arg1) .. " etat " .. Safe(arg2), false, true)
	end
end)

SLASH_URADIAG1 = "/uradiag"
SlashCmdList["URADIAG"] = function(message)
	local command, rest = string.match(message or "", "^(%S*)%s*(.-)$")
	command = string.lower(command or "")
	if command == "" or command == "report" then
		ShowReport()
	elseif command == "show" then
		panel:Show()
	elseif command == "hide" then
		panel:Hide()
	elseif command == "poison" then
		local id = tonumber(string.match(rest, "item:(%d+)")) or tonumber(rest)
		if id then
			SetPoison("item", id)
		else
			print("Usage : /uradiag poison 12345 (id d'objet). Le clic droit sur une arme est plus simple.")
		end
	elseif command == "poisonspell" then
		local id = tonumber(string.match(rest, "spell:(%d+)")) or tonumber(rest)
		if id then
			SetPoison("spell", id)
		else
			print("Usage : /uradiag poisonspell 12345")
		end
	else
		print("Commandes : /uradiag report | show | hide | poison [lien ou id] | poisonspell [id]")
	end
end
