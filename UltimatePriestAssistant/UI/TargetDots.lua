-- Ultimate Priest Assistant - TargetDots
-- Affiche les afflictions que le joueur a posees sur sa cible (Mot de l'ombre :
-- Douleur, Peste devorante...), avec leur duree.
--
-- En combat, un addon ne peut pas lire les auras. Ce fichier s'appuie donc sur
-- le "conteneur d'auras" fourni par le client (CustomAuraContainerTemplate) :
-- c'est le client qui choisit les auras et remplit les icones ; l'addon ne
-- fait que decrire leur apparence, une fois, a la creation de chaque icone.
--
-- EXPERIMENTAL : cette integration a ete ecrite d'apres le code d'interface du
-- client 1.60.1.70888 et n'a jamais ete executee en jeu. Elle est isolee : en
-- cas d'echec, le groupe reste vide et le reste de l'addon fonctionne.

local _, ns = ...

local TargetDots = ns:NewModule("TargetDots")
ns.TargetDots = TargetDots

local Style = ns.Style
local SIZE, GAP, MAX = 30, 4, 8

TargetDots.status = "non initialise"

-- Appelee par le client pour chaque icone, a sa creation.
local function InitializeButton(button)
	button:SetSize(SIZE, SIZE)

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	button:SetIcon(icon)

	local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
	cooldown:SetAllPoints()
	cooldown:SetReverse(true)
	cooldown:SetDrawEdge(false)
	cooldown:SetHideCountdownNumbers(false)
	button:SetDurationCooldown(cooldown)

	local border = Style.AddBorder(button, 1, 1, "OVERLAY")
	border:SetColor(0, 0, 0, 1)
end

local function Build()
	local group = ns.UI.groups.dots
	local container = CreateFrame("AuraContainer", "UPATargetDots", group, "CustomAuraContainerTemplate")
	container:SetPoint("LEFT", group, "LEFT", 0, 0)
	container:SetUnit("target")
	-- Afflictions nuisibles posees par le joueur lui-meme.
	container:AddAuraGroup("dots", "HARMFUL|PLAYER", {
		maxFrameCount = MAX,
		initializeFrame = InitializeButton,
		layout = { elementSpacing = GAP, elementWidth = SIZE, elementHeight = SIZE },
	})
end

function TargetDots:OnEnable()
	-- Comme pour tout cadre gere par le client, on evite de le creer en combat.
	local function TryBuild()
		if self.built or ns.API.InCombat() then
			return
		end
		self.built = true
		local ok, err = pcall(Build)
		if ok then
			self.status = "actif"
		else
			self.status = "indisponible : " .. tostring(err)
			ns:Print(ns.L.DOTS_UNAVAILABLE)
		end
	end
	ns.Events:Register("PLAYER_REGEN_ENABLED", self, TryBuild)
	TryBuild()
end
