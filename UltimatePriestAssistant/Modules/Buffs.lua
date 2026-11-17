-- Ultimate Priest Assistant - Buffs
-- Surveille les ameliorations que le pretre entretient sur lui-meme.
--
-- Les auras ne sont lisibles que hors combat. En combat, le dernier etat connu
-- est conserve et marque comme incertain : l'addon n'affirme jamais qu'une
-- amelioration est presente ou absente sans pouvoir le verifier.

local _, ns = ...

local Buffs = ns:NewModule("Buffs")
ns.Buffs = Buffs

local L = ns.L

local list = {}        -- ameliorations surveillees et apprises
local spellBook = {}
local ticker
local uncertain = false

function Buffs:GetList()
	return list
end

-- Vrai tant que les auras sont illisibles (combat).
function Buffs:IsUncertain()
	return uncertain
end

local function Settings()
	return ns.Profiles:GetCurrent().buffs
end

local function IsTracked(definition)
	local override = Settings().tracked[definition.key]
	if override ~= nil then
		return override
	end
	return definition.enabled
end

function Buffs:SetTracked(key, tracked)
	Settings().tracked[key] = tracked
	self:Rebuild()
end

-- Decrit toutes les ameliorations apprises : liste de { key, name, tracked }.
function Buffs:Describe()
	ns.API.ScanSpellBook(spellBook)
	local described = {}
	for _, definition in ipairs(ns.Data.Buffs) do
		local name = ns.API.GetSpellName(definition.id)
		if name and spellBook[name] then
			described[#described + 1] = { key = definition.key, name = name, tracked = IsTracked(definition) }
		end
	end
	return described
end

local function ReadBuff(buff)
	local active, seconds = false, nil
	for _, name in ipairs(buff.names) do
		local found, remaining = ns.API.GetPlayerBuff(name)
		if found then
			active, seconds = true, remaining
			break
		end
	end
	local previous = buff.alert
	buff.active, buff.seconds = active, seconds
	if not active then
		buff.alert = "missing"
	elseif seconds and seconds < Settings().warnMinutes * 60 then
		buff.alert = "expiring"
	else
		buff.alert = nil
	end
	if buff.alert ~= previous and buff.alert and Settings().chatAlerts then
		ns:Printf(buff.alert == "missing" and L.ALERT_BUFF_MISSING or L.ALERT_BUFF_EXPIRING, buff.name)
	end
end

function Buffs:Update()
	local wasUncertain = uncertain
	uncertain = ns.Secrets.AreAurasSecret()
	-- En combat, UNIT_AURA arrive sans cesse et rien n'est lisible : on ne
	-- republie pas un etat qui n'a pas change.
	if uncertain and wasUncertain then
		return
	end
	if not uncertain then
		local anyTimed = false
		for _, buff in ipairs(list) do
			ReadBuff(buff)
			anyTimed = anyTimed or buff.seconds ~= nil
		end
		-- La duree restante ne declenche aucun evenement : rappel lent, et
		-- seulement tant qu'une amelioration a duree limitee est active.
		if anyTimed and not ticker then
			ticker = C_Timer.NewTicker(20, function()
				Buffs:Update()
			end)
		elseif not anyTimed and ticker then
			ticker:Cancel()
			ticker = nil
		end
	end
	ns.Events:Fire("UPA_BUFFS_UPDATE", list, uncertain)
end

function Buffs:Rebuild()
	ns.API.ScanSpellBook(spellBook)
	wipe(list)
	for _, definition in ipairs(ns.Data.Buffs) do
		local name = ns.API.GetSpellName(definition.id)
		local learned = name and spellBook[name]
		if learned and IsTracked(definition) then
			local names = { name }
			for _, otherID in ipairs(definition.others or {}) do
				local otherName = ns.API.GetSpellName(otherID)
				if otherName then
					names[#names + 1] = otherName
				end
			end
			list[#list + 1] = { key = definition.key, id = learned.id, name = name, icon = learned.icon,
				names = names, toggle = definition.toggle }
		end
	end
	ns.Events:Fire("UPA_BUFFS_CHANGED", list)
	self:Update()
end

function Buffs:OnEnable()
	local function Update()
		self:Update()
	end
	local function Rebuild()
		self:Rebuild()
	end
	ns.Events:RegisterUnit("UNIT_AURA", "player", self, Update)
	ns.Events:Register("PLAYER_REGEN_ENABLED", self, Update)
	ns.Events:Register("PLAYER_REGEN_DISABLED", self, Update)
	ns.Events:Register("PLAYER_ENTERING_WORLD", self, Rebuild)
	ns.Events:Register("LEARNED_SPELL_IN_SKILL_LINE", self, Rebuild)
	self:Rebuild()
end

function Buffs:OnProfileChanged()
	self:Rebuild()
end
