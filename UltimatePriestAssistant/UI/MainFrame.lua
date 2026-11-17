-- Ultimate Priest Assistant - MainFrame
-- Cree les groupes de l'interface et regle leur discretion hors combat.
-- Chaque groupe est un conteneur independant, deplacable et redimensionnable.

local _, ns = ...

local MainFrame = ns:NewModule("MainFrame")
ns.MainFrame = MainFrame

local L = ns.L

-- cle, nom global, largeur, hauteur, libelle
local GROUPS = {
	{ "resources", "UPAResources", 240, 18, L.GROUP_RESOURCES },
	{ "main", "UPAMainSpells", 260, 40, L.GROUP_MAIN },
	{ "defensive", "UPADefensive", 176, 32, L.GROUP_DEFENSIVE },
	{ "offensive", "UPAOffensive", 176, 32, L.GROUP_OFFENSIVE },
	{ "bars", "UPACooldownBars", 240, 73, L.GROUP_BARS },
	-- Groupe separe : il contient les boutons securises des ameliorations.
	{ "buffs", "UPABuffPanel", 180, 32, L.GROUP_BUFFS },
	-- Afflictions posees sur la cible, remplies par le client.
	{ "dots", "UPATargetDotsGroup", 268, 30, L.GROUP_DOTS },
}

local inCombat = false

-- Hors combat et sans cible, l'interface s'estompe.
local function UpdateDim()
	ns.Movers:SetDimmed(not inCombat and not ns.API.HasTarget())
end

function MainFrame:OnEnable()
	ns.UI.groups = {}
	for _, definition in ipairs(GROUPS) do
		local key, globalName, width, height, label = unpack(definition)
		local frame = CreateFrame("Frame", globalName, UIParent)
		frame:SetSize(width, height)
		frame:SetFrameStrata("MEDIUM")
		ns.UI.groups[key] = frame
		ns.Movers:Register(key, frame, label)
	end

	inCombat = UnitAffectingCombat("player") and true or false
	ns.Events:Register("PLAYER_REGEN_DISABLED", self, function()
		inCombat = true
		UpdateDim()
	end)
	ns.Events:Register("PLAYER_REGEN_ENABLED", self, function()
		inCombat = false
		UpdateDim()
	end)
	ns.Events:Register("PLAYER_TARGET_CHANGED", self, UpdateDim)
	UpdateDim()
end

function MainFrame:OnProfileChanged()
	UpdateDim()
end
