-- Ultimate Rogue Assistant - PoisonManager
-- Etat des poisons des deux armes, preferences par profil et alertes.
-- Ce module n'applique jamais rien : l'application reste un clic du joueur
-- sur un bouton securise (UI/PoisonPanel).

local _, ns = ...

local PoisonManager = ns:NewModule("PoisonManager")
ns.PoisonManager = PoisonManager

local L = ns.L

-- hands[1] = main droite, hands[2] = main gauche
local hands = { {}, {} }
local pending = {}       -- main -> { itemID, time, enchantID, seconds } apres un clic
local ticker
local bagPoisons = {}

function PoisonManager:GetHands()
	return hands
end

local function Settings()
	return ns.Profiles:GetCurrent().poisons
end

function PoisonManager:GetPreferred(hand)
	return Settings().preferred[hand]
end

-- Enregistre le poison souhaite pour une main dans le profil actif.
function PoisonManager:SetPreferred(hand, itemID)
	Settings().preferred[hand] = itemID
	self:Update()
	ns.Events:Fire("URA_POISON_PREFERENCE_CHANGED", hand, itemID)
end

function PoisonManager:GetBagPoisons()
	return ns.API.ScanBagPoisons(bagPoisons, ns.Data.PoisonKeywords)
end

local function Announce(hand, state)
	if not Settings().chatAlerts or not state.alert then
		return
	end
	local label = hand == 1 and L.MAIN_HAND or L.OFF_HAND
	if state.alert == "missing" then
		ns:Printf(L.ALERT_MISSING, label)
	elseif state.alert == "expiring" then
		ns:Printf(L.ALERT_EXPIRING, label)
	elseif state.alert == "mismatch" then
		ns:Printf(L.ALERT_MISMATCH, label)
	end
end

local function ReadHand(hand)
	local state = hands[hand]
	local known = ns.db.enchantItems
	local previousAlert = state.alert

	state.weaponIcon, state.hasWeapon = ns.API.GetWeapon(hand)

	local enchant = state.hasWeapon and ns.API.GetWeaponPoison(hand, known) or nil
	state.active = enchant ~= nil
	state.enchantID, state.icon, state.seconds, state.charges, state.itemID, state.name = nil, nil, nil, nil, nil, nil
	if enchant then
		state.enchantID = enchant.enchantID
		state.icon = enchant.enchantIconID
		-- Ces valeurs sont lisibles sur Forever ; si elles devenaient secretes,
		-- la duree et les alertes d'expiration seraient simplement omises.
		if not ns.Secrets.IsSecret(enchant.timeLeft) then
			state.seconds = enchant.timeLeft / 1000
		end
		if not ns.Secrets.IsSecret(enchant.charges) then
			state.charges = enchant.charges
		end
		state.itemID = known[enchant.enchantID]
		state.name = state.itemID and ns.API.GetItemName(state.itemID)
	end

	local preferred = Settings().preferred[hand]
	state.preferred = preferred
	state.preferredIcon = preferred and ns.API.GetItemIcon(preferred)
	state.preferredCount = preferred and ns.API.GetItemCount(preferred) or 0

	-- Alerte, de la plus grave a la moins grave.
	local alert
	if state.hasWeapon and not state.active then
		alert = "missing"
	elseif state.active and state.seconds and state.seconds < Settings().warnMinutes * 60 then
		alert = "expiring"
	elseif state.active and preferred then
		-- Correspondance apprise si elle existe, sinon comparaison des icones.
		if state.itemID then
			if state.itemID ~= preferred then
				alert = "mismatch"
			end
		elseif state.preferredIcon and state.icon ~= state.preferredIcon then
			alert = "mismatch"
		end
	end
	state.alert = alert
	if alert ~= previousAlert then
		Announce(hand, state)
	end
end

-- Apprend quel objet a pose quel enchantement, apres un clic du joueur.
local function LearnFromPending(hand)
	local wait = pending[hand]
	local state = hands[hand]
	if not wait or not state.active or not state.enchantID then
		return
	end
	if GetTime() - wait.time > 20 then
		pending[hand] = nil
		return
	end
	local refreshed = state.seconds and wait.seconds and state.seconds > wait.seconds + 1
	if state.enchantID ~= wait.enchantID or refreshed then
		ns.db.enchantItems[state.enchantID] = wait.itemID
		pending[hand] = nil
		ReadHand(hand)
	end
end

function PoisonManager:Update()
	local anyActive = false
	for hand = 1, 2 do
		ReadHand(hand)
		LearnFromPending(hand)
		anyActive = anyActive or hands[hand].active
	end
	-- La duree restante ne declenche aucun evenement : un rappel lent suffit,
	-- et seulement tant qu'un poison est actif.
	if anyActive and not ticker then
		ticker = C_Timer.NewTicker(15, function()
			PoisonManager:Update()
		end)
	elseif not anyActive and ticker then
		ticker:Cancel()
		ticker = nil
	end
	ns.Events:Fire("URA_POISONS_UPDATE", hands)
end

-- Appele par le panneau quand le joueur clique pour appliquer un poison.
function PoisonManager:NotifyApplyClick(hand)
	local itemID = Settings().preferred[hand]
	local wait = pending[hand]
	if not itemID or (wait and GetTime() - wait.time < 1) then
		return
	end
	local state = hands[hand]
	pending[hand] = { itemID = itemID, time = GetTime(), enchantID = state.enchantID, seconds = state.seconds }
end

function PoisonManager:OnEnable()
	local function Update()
		self:Update()
	end
	ns.Events:Register("WEAPON_ENCHANT_CHANGED", self, Update)
	ns.Events:Register("BAG_UPDATE_DELAYED", self, Update)
	ns.Events:Register("PLAYER_ENTERING_WORLD", self, Update)
	ns.Events:Register("PLAYER_EQUIPMENT_CHANGED", self, function(_, _, slot)
		if slot == ns.API.GetInventorySlot(1) or slot == ns.API.GetInventorySlot(2) then
			local hand = slot == ns.API.GetInventorySlot(1) and 1 or 2
			local wasMissing = hands[hand].alert == "missing"
			self:Update()
			-- Si l'alerte n'a pas change, Update n'a rien annonce : on signale l'arme.
			if Settings().chatAlerts then
				if wasMissing and hands[hand].alert == "missing" then
					ns:Printf(L.ALERT_WEAPON_CHANGED, hand == 1 and L.MAIN_HAND or L.OFF_HAND)
				end
			end
		end
	end)
	self:Update()
end

function PoisonManager:OnProfileChanged()
	self:Update()
end
