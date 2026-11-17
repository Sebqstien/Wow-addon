-- Ultimate Priest Assistant - Cooldowns
-- Liste des techniques suivies et de leur etat. Tout est pilote par les
-- evenements du client ; aucune boucle de mise a jour.
--
-- Techniques suivies = prereglage de la specialisation active, corrige par les
-- choix du joueur (profil actif), plus ses techniques ajoutees a la main.

local _, ns = ...

local Cooldowns = ns:NewModule("Cooldowns")
ns.Cooldowns = Cooldowns

local tracked = {}      -- techniques suivies, dans l'ordre d'affichage
local spellBook = {}    -- nom -> sort du grimoire
local rebuildQueued = false

function Cooldowns:GetTracked()
	return tracked
end

local function SpecKey()
	return ns.Specialization:GetActive() or "none"
end

-- Choix du joueur pour la specialisation active : cle -> true/false.
function Cooldowns:GetOverrides()
	return ns.Profiles:GetCurrent().spellsBySpec[SpecKey()]
end

-- Parcourt toutes les definitions : base, puis techniques ajoutees a la main.
local function ForEachDefinition(callback)
	for _, definition in ipairs(ns.Data.Spells) do
		callback(definition)
	end
	for _, definition in ipairs(ns.Profiles:GetCurrent().customSpells) do
		callback(definition)
	end
end

-- Decrit toutes les techniques connues de l'addon et apprises par le joueur :
-- liste de { key, name, group, tracked, custom }.
function Cooldowns:Describe()
	ns.API.ScanSpellBook(spellBook)
	local overrides = self:GetOverrides()
	local inPreset = {}
	for _, key in ipairs(ns.Data.Presets[SpecKey()]) do
		inPreset[key] = true
	end
	local list = {}
	ForEachDefinition(function(definition)
		local name = ns.API.GetSpellName(definition.id)
		if name and spellBook[name] then
			local override = overrides[definition.key]
			local isTracked = override
			if override == nil then
				isTracked = inPreset[definition.key] or definition.custom or false
			end
			list[#list + 1] = { key = definition.key, name = name, group = definition.group,
				tracked = isTracked, custom = definition.custom }
		end
	end)
	return list
end

local function RefreshCooldown(spell)
	local active, onHold = ns.API.GetCooldownFlags(spell.id)
	spell.active = active
	spell.onHold = onHold
end

local function RefreshUsable(spell)
	spell.usable, spell.noPower = ns.API.IsSpellUsable(spell.id)
end

local function Publish(spell, force)
	local changed, becameReady = ns.SpellAvailability:Evaluate(spell)
	-- Tant qu'une recharge court, on republie : sa duree a pu etre modifiee.
	if changed or force or spell.active then
		ns.Events:Fire("UPA_SPELL_UPDATE", spell, becameReady)
	end
end

-- Reconstruit la liste a partir du grimoire, des prereglages et du profil.
function Cooldowns:Rebuild()
	rebuildQueued = false
	ns.API.ScanSpellBook(spellBook)
	wipe(tracked)

	local overrides = self:GetOverrides()
	local definitions, added = {}, {}
	ForEachDefinition(function(definition)
		definitions[definition.key] = definition
	end)

	local function Add(definition, byDefault)
		if added[definition.key] then
			return
		end
		added[definition.key] = true
		local enabled = overrides[definition.key]
		if enabled == nil then
			enabled = byDefault
		end
		local name = enabled and ns.API.GetSpellName(definition.id)
		local learned = name and spellBook[name]
		if learned then
			local spell = {
				key = definition.key, group = definition.group, bar = definition.bar,
				major = definition.major, id = learned.id, name = learned.name, icon = learned.icon,
			}
			RefreshCooldown(spell)
			RefreshUsable(spell)
			ns.SpellAvailability:Evaluate(spell)
			tracked[#tracked + 1] = spell
		end
	end

	-- D'abord le prereglage, dans son ordre ; puis les ajouts du joueur.
	for _, key in ipairs(ns.Data.Presets[SpecKey()]) do
		if definitions[key] then
			Add(definitions[key], true)
		end
	end
	ForEachDefinition(function(definition)
		Add(definition, definition.custom == true)
	end)

	-- Ordre choisi par le joueur : les cles listees passent devant, dans cet
	-- ordre ; les autres gardent leur place relative a la suite.
	local rank = {}
	for index, key in ipairs(ns.Profiles:GetCurrent().orderBySpec[SpecKey()]) do
		rank[key] = index
	end
	for index, spell in ipairs(tracked) do
		spell.sort = rank[spell.key] or (1000 + index)
	end
	table.sort(tracked, function(a, b)
		return a.sort < b.sort
	end)

	ns.Events:Fire("UPA_SPELLS_CHANGED", tracked)
	for _, spell in ipairs(tracked) do
		ns.Events:Fire("UPA_SPELL_UPDATE", spell, false)
	end
end

-- Deplace une technique suivie d'un cran dans son groupe (-1 : avant, 1 : apres).
function Cooldowns:Move(key, direction)
	local from
	for index, spell in ipairs(tracked) do
		if spell.key == key then
			from = index
		end
	end
	if not from then
		return false
	end
	local to = from + direction
	while tracked[to] and tracked[to].group ~= tracked[from].group do
		to = to + direction
	end
	if not tracked[to] then
		return false
	end
	tracked[from], tracked[to] = tracked[to], tracked[from]
	local saved = {}
	for index, spell in ipairs(tracked) do
		saved[index] = spell.key
	end
	ns.Profiles:GetCurrent().orderBySpec[SpecKey()] = saved
	self:Rebuild()
	return true
end

-- SPELLS_CHANGED arrive par rafales : une seule reconstruction est planifiee.
local function QueueRebuild()
	if not rebuildQueued then
		rebuildQueued = true
		C_Timer.After(0.3, function()
			Cooldowns:Rebuild()
		end)
	end
end

-- Suit ou cesse de suivre une technique pour la specialisation active.
function Cooldowns:SetTracked(key, isTracked)
	self:GetOverrides()[key] = isTracked
	self:Rebuild()
end

-- Ajoute une technique du grimoire absente de la base. Renvoie sa cle, ou nil
-- si le nom ne correspond a aucun sort appris.
function Cooldowns:AddCustom(spellName, group)
	ns.API.ScanSpellBook(spellBook)
	local wanted = string.lower(spellName)
	local found
	for name, spell in pairs(spellBook) do
		if string.lower(name) == wanted then
			found = spell
		end
	end
	if not found then
		return nil
	end
	local key = "custom_" .. found.id
	local custom = ns.Profiles:GetCurrent().customSpells
	for _, definition in ipairs(custom) do
		if definition.key == key then
			definition.group = group
			self:SetTracked(key, true)
			return key, found.name
		end
	end
	custom[#custom + 1] = { key = key, id = found.id, group = group, bar = true, custom = true }
	self:SetTracked(key, true)
	return key, found.name
end

function Cooldowns:RemoveCustom(key)
	local custom = ns.Profiles:GetCurrent().customSpells
	for index, definition in ipairs(custom) do
		if definition.key == key then
			table.remove(custom, index)
			self:Rebuild()
			return true
		end
	end
	return false
end

function Cooldowns:OnEnable()
	ns.Events:Register("SPELL_UPDATE_COOLDOWN", self, function()
		for _, spell in ipairs(tracked) do
			RefreshCooldown(spell)
			Publish(spell)
		end
	end)
	ns.Events:Register("SPELL_UPDATE_USABLE", self, function()
		for _, spell in ipairs(tracked) do
			RefreshUsable(spell)
			Publish(spell)
		end
	end)
	ns.Events:Register("SPELL_UPDATE_CHARGES", self, function()
		for _, spell in ipairs(tracked) do
			Publish(spell, true)
		end
	end)
	ns.Events:Register("SPELLS_CHANGED", self, QueueRebuild)
	ns.Events:Register("PLAYER_ENTERING_WORLD", self, QueueRebuild)
	ns.Events:On("UPA_SPEC_CHANGED", self, function()
		self:Rebuild()
	end)
	self:Rebuild()
end

function Cooldowns:OnProfileChanged()
	self:Rebuild()
end
