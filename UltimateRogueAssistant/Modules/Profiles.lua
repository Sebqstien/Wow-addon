-- Ultimate Rogue Assistant - Profiles
-- Profil actif par personnage, changement et reinitialisation.

local _, ns = ...

local Profiles = ns:NewModule("Profiles")
ns.Profiles = Profiles

local function CharacterEntry()
	local key = ns.API.GetCharacterKey()
	local entry = ns.db.chars[key]
	if type(entry) ~= "table" then
		entry = {}
		ns.db.chars[key] = entry
	end
	if not ns.Config:IsProfileName(tostring(entry.profile)) then
		entry.profile = ns.Config.DEFAULT_PROFILE
	end
	return entry
end

function Profiles:GetCurrentName()
	return CharacterEntry().profile
end

-- Table du profil actif. Les modules la relisent a chaque usage et ne la
-- gardent pas en cache : elle change avec le profil.
function Profiles:GetCurrent()
	return ns.db.profiles[self:GetCurrentName()]
end

function Profiles:SetCurrent(name)
	local known = ns.Config:IsProfileName(name)
	if not known then
		return false
	end
	CharacterEntry().profile = known
	ns:CallModules("OnProfileChanged")
	ns.Events:Fire("URA_PROFILE_CHANGED", known)
	return true, known
end

function Profiles:ResetCurrent()
	local name = self:GetCurrentName()
	ns.db.profiles[name] = ns.Helpers.DeepCopy(ns.Config.PROFILE_DEFAULTS)
	ns:CallModules("OnProfileChanged")
	ns.Events:Fire("URA_PROFILE_CHANGED", name)
	return name
end

function Profiles:ListNames()
	return table.concat(ns.Config.PROFILE_NAMES, ", ")
end
