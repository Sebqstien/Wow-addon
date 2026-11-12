-- Ultimate Rogue Assistant - Config
-- Valeurs par defaut, schema de la sauvegarde et migrations.
--
-- URA_DB = {
--   schema   = numero de version du schema,
--   locked   = verrouillage des groupes (commun a tous les profils),
--   chars    = { ["Nom - Royaume"] = { profile = "PvE" } },
--   profiles = { PvE = {...}, PvP = {...}, Leveling = {...}, Custom = {...} },
-- }

local _, ns = ...

local Config = {}
ns.Config = Config

Config.SCHEMA = 1
Config.PROFILE_NAMES = { "PvE", "PvP", "Leveling", "Custom" }
Config.DEFAULT_PROFILE = "PvE"

Config.SCALE_MIN, Config.SCALE_MAX = 0.5, 2.5
Config.ALPHA_MIN, Config.ALPHA_MAX = 0.1, 1

-- Position d'un groupe : decalage de son centre par rapport au centre de
-- l'ecran, en unites de UIParent. Independant de la resolution.
Config.PROFILE_DEFAULTS = {
	groups = {
		resources = { x = 0, y = -160, scale = 1, alpha = 1, shown = true },
		main = { x = 0, y = -208, scale = 1, alpha = 1, shown = true },
		defensive = { x = -250, y = -204, scale = 1, alpha = 1, shown = true },
		offensive = { x = 250, y = -204, scale = 1, alpha = 1, shown = true },
		bars = { x = 0, y = -276, scale = 1, alpha = 1, shown = true },
		poisons = { x = 420, y = -160, scale = 1, alpha = 1, shown = true },
	},
	-- Seuils de couleur de l'energie, en pourcentage du maximum.
	energy = { low = 30, mid = 60 },
	-- Opacite appliquee hors combat et sans cible (1 = toujours pleinement visible).
	idleAlpha = 0.45,
	animations = true,
	showBars = true,
	-- Choix du joueur par specialisation : cle de technique -> true/false.
	-- Une cle absente suit le prereglage de la specialisation.
	spellsBySpec = { none = {}, assassination = {}, combat = {}, subtlety = {} },
	-- Techniques ajoutees a la main : liste de { key, id, group, bar, custom }.
	customSpells = {},
	-- Ordre d'affichage choisi par le joueur, par specialisation : liste de cles.
	orderBySpec = { none = {}, assassination = {}, combat = {}, subtlety = {} },
	-- Couleurs reglables : { rouge, vert, bleu }.
	colors = {
		energy = { 0.94, 0.76, 0.18 },
		energyMid = { 0.88, 0.54, 0.16 },
		energyLow = { 0.82, 0.26, 0.18 },
		combo = { 0.85, 0.27, 0.18 },
		finisher = { 1, 0.70, 0.24 },
	},
	poisons = {
		-- Poison souhaite par arme (identifiant d'objet) : [1] main droite, [2] main gauche.
		preferred = {},
		-- Alerte d'expiration quand il reste moins de ce nombre de minutes.
		warnMinutes = 5,
		chatAlerts = true,
	},
}

Config.DB_DEFAULTS = {
	schema = Config.SCHEMA,
	locked = true,
	chars = {},
	profiles = {},
	-- Correspondances apprises : enchantement d'arme -> objet poison.
	enchantItems = {},
}

function Config:InitializeDatabase()
	if type(URA_DB) ~= "table" then
		URA_DB = {}
	end
	local db = URA_DB
	self:Migrate(db)
	ns.Helpers.ApplyDefaults(db, self.DB_DEFAULTS)
	for _, name in ipairs(self.PROFILE_NAMES) do
		if type(db.profiles[name]) ~= "table" then
			db.profiles[name] = {}
		end
		ns.Helpers.ApplyDefaults(db.profiles[name], self.PROFILE_DEFAULTS)
	end
	ns.db = db
end

-- Fait evoluer une sauvegarde ancienne vers le schema courant.
function Config:Migrate(db)
	local schema = tonumber(db.schema) or self.SCHEMA
	-- Les migrations futures s'ajoutent ici : if schema < 2 then ... end
	if schema > self.SCHEMA then
		-- Sauvegarde ecrite par une version plus recente : on la garde telle quelle.
		return
	end
	db.schema = self.SCHEMA
end

function Config:IsProfileName(name)
	for _, known in ipairs(self.PROFILE_NAMES) do
		if string.lower(known) == string.lower(name) then
			return known
		end
	end
	return nil
end
