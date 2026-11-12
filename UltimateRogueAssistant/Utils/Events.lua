-- Ultimate Rogue Assistant - Events
-- Point d'entree unique des evenements du jeu et bus de messages interne.
-- Les modules ne creent jamais leur propre cadre d'ecoute.

local ADDON_NAME, ns = ...

local Events = {}
ns.Events = Events

local frame = CreateFrame("Frame")
local unitFrames = {}     -- unite -> cadre dedie (RegisterUnitEvent filtre cote client)
local handlers = {}       -- evenement ou message -> liste { owner, fn, owner, fn, ... }
local errorHandler = geterrorhandler

local function Dispatch(event, ...)
	local list = handlers[event]
	if not list then
		return
	end
	-- Parcours par index : un gestionnaire peut s'inscrire pendant la diffusion.
	for i = 1, #list, 2 do
		local owner, fn = list[i], list[i + 1]
		if fn then
			xpcall(fn, errorHandler(), owner, event, ...)
		end
	end
end

local function OnEvent(_, event, ...)
	Dispatch(event, ...)
end

frame:SetScript("OnEvent", OnEvent)

local function AddHandler(event, owner, fn)
	local list = handlers[event]
	if not list then
		list = {}
		handlers[event] = list
	end
	for i = 1, #list, 2 do
		if list[i] == owner then
			list[i + 1] = fn
			return
		end
	end
	list[#list + 1] = owner
	list[#list + 1] = fn
end

-- Ecoute un evenement du jeu. `fn(owner, event, ...)`.
function Events:Register(event, owner, fn)
	AddHandler(event, owner, fn)
	frame:RegisterEvent(event)
end

-- Ecoute un evenement d'unite, filtre par le client pour l'unite donnee.
function Events:RegisterUnit(event, unit, owner, fn)
	AddHandler(event, owner, fn)
	local unitFrame = unitFrames[unit]
	if not unitFrame then
		unitFrame = CreateFrame("Frame")
		unitFrame:SetScript("OnEvent", OnEvent)
		unitFrames[unit] = unitFrame
	end
	unitFrame:RegisterUnitEvent(event, unit)
end

function Events:Unregister(event, owner)
	local list = handlers[event]
	if not list then
		return
	end
	for i = #list - 1, 1, -2 do
		if list[i] == owner then
			table.remove(list, i + 1)
			table.remove(list, i)
		end
	end
	if #list == 0 then
		handlers[event] = nil
		frame:UnregisterEvent(event)
		for _, unitFrame in pairs(unitFrames) do
			unitFrame:UnregisterEvent(event)
		end
	end
end

function Events:UnregisterAll()
	frame:UnregisterAllEvents()
	for _, unitFrame in pairs(unitFrames) do
		unitFrame:UnregisterAllEvents()
	end
	wipe(handlers)
end

-- Bus interne : messages prefixes "URA_", sans passer par le client.
function Events:On(message, owner, fn)
	AddHandler(message, owner, fn)
end

function Events:Fire(message, ...)
	Dispatch(message, ...)
end

-- Demarrage : le coeur est appele quand la sauvegarde est chargee, puis en jeu.
Events:Register("ADDON_LOADED", Events, function(_, _, loadedName)
	if loadedName == ADDON_NAME then
		Events:Unregister("ADDON_LOADED", Events)
		ns:OnAddonLoaded()
	end
end)

Events:Register("PLAYER_LOGIN", Events, function()
	Events:Unregister("PLAYER_LOGIN", Events)
	ns:OnPlayerLogin()
end)
