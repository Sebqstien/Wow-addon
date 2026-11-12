-- Ultimate Rogue Assistant - Commands
-- Commande /ura. Charge en dernier : tous les modules sont deja declares.

local _, ns = ...

local L = ns.L

StaticPopupDialogs["URA_RESET_PROFILE"] = {
	text = L.RESET_CONFIRM,
	button1 = L.YES,
	button2 = L.NO,
	OnAccept = function()
		if ns.API.InCombat() then
			ns:Print(L.COMBAT_BLOCKED)
			return
		end
		ns:Printf(L.RESET_DONE, ns.Profiles:ResetCurrent())
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

local function PrintHelp()
	ns:Print(L.HELP_HEADER)
	print("  " .. L.HELP_CONFIG)
	print("  " .. L.HELP_UNLOCK)
	print("  " .. L.HELP_LOCK)
	print("  " .. string.format(L.HELP_PROFILE, ns.Profiles:ListNames()))
	print("  " .. L.HELP_SPEC)
	print("  " .. L.HELP_SPELLS)
	print("  " .. L.HELP_SCALE)
	print("  " .. L.HELP_ALPHA)
	print("  " .. L.HELP_RESET)
	print("  " .. L.HELP_DEBUG)
end

local function PrintDebug()
	local version, build, interface = ns.API.GetBuild()
	ns:Printf("addon %s, client %s (%s), interface %s", ns.version, tostring(version), tostring(build), tostring(interface))
	ns:Printf("profil %s, verrouille : %s, schema %s", ns.Profiles:GetCurrentName(), tostring(ns.db.locked), tostring(ns.db.schema))
	ns:Printf("restrictions : %s, combat : %s, energie secrete : %s, combo secret : %s",
		tostring(ns.Secrets.HasRestrictions()), tostring(ns.Secrets.IsCombatRestrictionActive()),
		tostring(ns.Secrets.IsEnergySecret()), tostring(ns.Secrets.IsComboSecret()))
	for key, settings in pairs(ns.Profiles:GetCurrent().groups) do
		if ns.Movers:HasGroup(key) then
		ns:Printf("groupe %s : x=%s y=%s taille=%s opacite=%s", key, tostring(settings.x), tostring(settings.y),
			tostring(settings.scale), tostring(settings.alpha))
		end
	end
	if UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then
		UpdateAddOnMemoryUsage()
		ns:Printf("memoire : %.0f Ko", GetAddOnMemoryUsage(ns.name))
	end
	local names = {}
	for _, spell in ipairs(ns.Cooldowns:GetTracked()) do
		names[#names + 1] = string.format("%s (%d, %s)", spell.name, spell.id, tostring(spell.status))
	end
	local spec = ns.Specialization:GetState()
	ns:Printf("specialisation : active=%s detectee=%s mode=%s", tostring(spec.active), tostring(spec.detected), ns.Specialization:GetMode())
	ns:Printf("techniques suivies : %d", #names)
	for _, line in ipairs(names) do
		print("  " .. line)
	end
end

-- /ura scale <groupe> <valeur> et /ura alpha <groupe> <valeur>
local function SetGroupValue(rest, label, minValue, maxValue, setter)
	local key, value = string.match(rest, "^(%S+)%s+(%S+)$")
	value = tonumber(value)
	key = key and string.lower(key)
	if not key or not ns.Movers:HasGroup(key) then
		ns:Printf(L.UNKNOWN_GROUP, tostring(key or ""), ns.Movers:ListGroups())
		return
	end
	if not value or value < minValue or value > maxValue then
		ns:Printf(L.BAD_VALUE, tostring(minValue), tostring(maxValue))
		return
	end
	if setter(ns.Movers, key, value) then
		ns:Printf(L.VALUE_SET, key, label, tostring(value))
	else
		ns:Print(L.COMBAT_BLOCKED)
	end
end

-- Retrouve une technique apprise par sa cle ou son nom (exact, sinon partiel unique).
local function FindSpell(text)
	local wanted = string.lower(text)
	local partial, partialCount = nil, 0
	for _, entry in ipairs(ns.Cooldowns:Describe()) do
		local name = string.lower(entry.name)
		if entry.key == wanted or name == wanted then
			return entry
		elseif string.find(name, wanted, 1, true) then
			partial, partialCount = entry, partialCount + 1
		end
	end
	if partialCount == 1 then
		return partial
	end
	return nil
end

local GROUP_ALIASES = {
	main = "main", principaux = "main", principal = "main",
	defensive = "defensive", defensifs = "defensive", defensif = "defensive",
	offensive = "offensive", offensifs = "offensive", offensif = "offensive",
}

local function GroupLabel(group)
	return group == "main" and L.GROUP_MAIN or group == "defensive" and L.GROUP_DEFENSIVE or L.GROUP_OFFENSIVE
end

local function PrintSpec()
	local state = ns.Specialization:GetState()
	local mode = ns.Specialization:GetMode()
	local active = state.active and ns.Specialization:GetName(state.active) or L.SPEC_NONE
	ns:Printf(L.SPEC_STATUS, active, mode == "auto" and L.SPEC_AUTO or L.SPEC_MANUAL)
	for _, key in ipairs(ns.Data.SpecKeys) do
		print(string.format("  %s : %d", ns.Specialization:GetName(key), state.points[key] or 0))
	end
	print("  " .. L.HELP_SPEC)
end

local function SetSpec(text)
	local wanted = string.lower(text)
	if wanted == "auto" then
		ns.Specialization:SetMode("auto")
		PrintSpec()
		return
	end
	for _, key in ipairs(ns.Data.SpecKeys) do
		if wanted == key or wanted == string.lower(ns.Specialization:GetName(key))
			or wanted == string.lower(L["SPEC_" .. string.upper(key)]) then
			ns.Specialization:SetMode(key)
			PrintSpec()
			return
		end
	end
	ns:Printf(L.SPEC_UNKNOWN, text)
end

local function PrintSpells()
	ns:Print(L.SPELLS_HEADER)
	for _, entry in ipairs(ns.Cooldowns:Describe()) do
		print(string.format("  %s %s |cff909090(%s)|r", entry.tracked and "|cff40d040[x]|r" or "|cff909090[ ]|r",
			entry.name, GroupLabel(entry.group)))
	end
	print("  " .. L.HELP_TRACK)
	print("  " .. L.HELP_ADD)
end

local function TrackSpell(text, isTracked)
	local entry = text ~= "" and FindSpell(text)
	if not entry then
		ns:Printf(L.SPELL_UNKNOWN, text)
		return
	end
	ns.Cooldowns:SetTracked(entry.key, isTracked)
	ns:Printf(isTracked and L.SPELL_TRACKED or L.SPELL_UNTRACKED, entry.name)
end

local function AddSpell(rest)
	local groupText, name = string.match(rest, "^(%S+)%s+(.+)$")
	local group = groupText and GROUP_ALIASES[string.lower(groupText)]
	if not group then
		ns:Print(L.HELP_ADD)
		return
	end
	local key, spellName = ns.Cooldowns:AddCustom(name, group)
	if key then
		ns:Printf(L.SPELL_ADDED, spellName, GroupLabel(group))
	else
		ns:Printf(L.SPELL_UNKNOWN, name)
	end
end

local function RemoveSpell(text)
	local entry = text ~= "" and FindSpell(text)
	if entry and entry.custom and ns.Cooldowns:RemoveCustom(entry.key) then
		ns:Printf(L.SPELL_REMOVED, entry.name)
	else
		ns:Printf(L.SPELL_NOT_CUSTOM, text)
	end
end

local function HandleCommand(message)
	local command, rest = string.match(message or "", "^%s*(%S*)%s*(.-)%s*$")
	command = string.lower(command or "")

	if not ns.enabled then
		ns:Print(L.NOT_ROGUE)
	elseif command == "" or command == "config" then
		ns.ConfigFrame:Toggle()
	elseif command == "help" then
		PrintHelp()
	elseif command == "lock" then
		ns.Movers:SetLocked(true)
		ns:Print(L.LOCKED)
	elseif command == "unlock" then
		ns.Movers:SetLocked(false)
		ns:Print(ns.API.InCombat() and L.UNLOCK_AFTER_COMBAT or L.UNLOCKED)
	elseif command == "profile" then
		if rest == "" then
			ns:Printf(L.PROFILE_CURRENT, ns.Profiles:GetCurrentName(), ns.Profiles:ListNames())
		elseif ns.API.InCombat() then
			ns:Print(L.COMBAT_BLOCKED)
		else
			local ok, name = ns.Profiles:SetCurrent(rest)
			if ok then
				ns:Printf(L.PROFILE_CHANGED, name)
			else
				ns:Printf(L.PROFILE_UNKNOWN, rest, ns.Profiles:ListNames())
			end
		end
	elseif command == "scale" then
		SetGroupValue(rest, L.SCALE, ns.Config.SCALE_MIN, ns.Config.SCALE_MAX, ns.Movers.SetScale)
	elseif command == "alpha" then
		SetGroupValue(rest, L.ALPHA, ns.Config.ALPHA_MIN, ns.Config.ALPHA_MAX, ns.Movers.SetAlpha)
	elseif command == "spec" then
		if rest == "" then
			PrintSpec()
		else
			SetSpec(rest)
		end
	elseif command == "spells" then
		PrintSpells()
	elseif command == "track" then
		TrackSpell(rest, true)
	elseif command == "untrack" then
		TrackSpell(rest, false)
	elseif command == "add" then
		AddSpell(rest)
	elseif command == "remove" then
		RemoveSpell(rest)
	elseif command == "reset" then
		StaticPopup_Show("URA_RESET_PROFILE", ns.Profiles:GetCurrentName())
	elseif command == "debug" then
		PrintDebug()
	else
		ns:Printf(L.UNKNOWN_COMMAND, command)
		PrintHelp()
	end
end

SLASH_ULTIMATEROGUEASSISTANT1 = "/ura"
SlashCmdList["ULTIMATEROGUEASSISTANT"] = HandleCommand
