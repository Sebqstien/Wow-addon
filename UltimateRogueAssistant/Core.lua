-- Ultimate Rogue Assistant - Core
-- Espace de noms partage, registre de modules et cycle de vie.
-- Ce fichier est charge en premier : il ne depend d'aucun autre.

local ADDON_NAME, ns = ...

ns.name = ADDON_NAME
ns.version = "1.0.0"
ns.modules = {}       -- liste ordonnee des modules enregistres
ns.moduleByName = {}
ns.UI = {}
ns.enabled = false    -- vrai une fois l'addon initialise pour un voleur

local PREFIX = "|cff33ff99URA|r "

function ns:Print(...)
	print(PREFIX .. string.join(" ", tostringall(...)))
end

function ns:Printf(fmt, ...)
	print(PREFIX .. string.format(fmt, ...))
end

-- Enregistre un module. Un module peut definir :
--   OnInitialize()  : base de donnees prete (ADDON_LOADED)
--   OnEnable()      : personnage en jeu (PLAYER_LOGIN), voleur uniquement
--   OnProfileChanged() : profil actif change ou reinitialise
function ns:NewModule(name)
	assert(not self.moduleByName[name], "module deja enregistre : " .. name)
	local module = { name = name }
	self.modules[#self.modules + 1] = module
	self.moduleByName[name] = module
	return module
end

function ns:GetModule(name)
	return self.moduleByName[name]
end

-- Appelle une methode sur tous les modules. Une erreur dans un module est
-- signalee par le gestionnaire d'erreurs du jeu sans bloquer les suivants.
function ns:CallModules(method, ...)
	for _, module in ipairs(self.modules) do
		local fn = module[method]
		if fn then
			xpcall(fn, geterrorhandler(), module, ...)
		end
	end
end

function ns:OnAddonLoaded()
	self.Config:InitializeDatabase()
	self:CallModules("OnInitialize")
end

function ns:OnPlayerLogin()
	local _, classFile = UnitClass("player")
	if classFile ~= "ROGUE" then
		-- L'addon reste inerte pour les autres classes : aucun cadre, aucun evenement.
		self.Events:UnregisterAll()
		return
	end
	self.enabled = true
	self:CallModules("OnEnable")
	self:Printf(self.L.LOADED, self.version)
end
