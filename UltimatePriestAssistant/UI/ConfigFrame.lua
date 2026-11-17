-- Ultimate Priest Assistant - ConfigFrame
-- Fenetre de reglages, ouverte par /upa. Elle ne contient aucune logique de
-- jeu : chaque controle lit et ecrit un reglage du profil, puis demande aux
-- modules de se reappliquer. Les controles sont construits sans modele
-- d'interface du jeu, pour ne dependre d'aucun gabarit propre a une version.

local _, ns = ...

local ConfigFrame = ns:NewModule("ConfigFrame")
ns.ConfigFrame = ConfigFrame

local Style = ns.Style
local L = ns.L

local WIDTH, HEIGHT, PAD = 440, 580, 16
local frame
local controls = {}      -- tous les controles disposant d'une methode Refresh
local panels = {}
local tabs = {}
local spellRows = {}
local spellChild

local function Profile()
	return ns.Profiles:GetCurrent()
end

-- Reapplique les reglages a tous les modules, puis rafraichit la fenetre.
local function Changed()
	ns:CallModules("OnProfileChanged")
end

local function Track(control)
	controls[#controls + 1] = control
	return control
end

------------------------------------------------------------------------
-- Controles
------------------------------------------------------------------------

local function CreateLabel(parent, text, size, r, g, b)
	local label = parent:CreateFontString(nil, "OVERLAY")
	Style.SetFont(label, size or 12, false)
	label:SetText(text)
	label:SetTextColor(r or 1, g or 1, b or 1)
	return label
end

local function CreateButton(parent, text, width, onClick)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(width, 22)
	Style.AddBackground(button)
	button.border = Style.AddBorder(button, 1)
	local highlight = button:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetAllPoints()
	highlight:SetColorTexture(1, 1, 1, 0.12)
	button.text = CreateLabel(button, text, 12)
	button.text:SetPoint("CENTER")
	button:SetScript("OnClick", onClick)
	return button
end

-- Case a cocher. `set` renvoie false si le changement est refuse (combat).
local function CreateCheck(parent, text, get, set)
	local check = CreateFrame("Button", nil, parent)
	check:SetSize(16, 16)
	Style.AddBackground(check)
	Style.AddBorder(check, 1)
	local mark = check:CreateTexture(nil, "ARTWORK")
	mark:SetPoint("TOPLEFT", 3, -3)
	mark:SetPoint("BOTTOMRIGHT", -3, 3)
	mark:SetColorTexture(0.94, 0.76, 0.18, 1)
	check.label = CreateLabel(check, text, 12)
	check.label:SetPoint("LEFT", check, "RIGHT", 8, 0)
	-- Le libelle est cliquable lui aussi.
	check:SetHitRectInsets(0, -220, 0, 0)
	check:SetScript("OnClick", function()
		if set(not get()) == false then
			ns:Print(L.COMBAT_BLOCKED)
		end
		ConfigFrame:Refresh()
	end)
	function check:Refresh()
		mark:SetShown(get() and true or false)
	end
	return Track(check)
end

-- Curseur horizontal avec son libelle et sa valeur.
local function CreateSlider(parent, text, minValue, maxValue, step, format, get, set)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(WIDTH - PAD * 2, 34)
	holder.label = CreateLabel(holder, text, 12)
	holder.label:SetPoint("TOPLEFT")
	holder.value = CreateLabel(holder, "", 12, 0.94, 0.76, 0.18)
	holder.value:SetPoint("TOPRIGHT")

	local slider = CreateFrame("Slider", nil, holder)
	slider:SetOrientation("HORIZONTAL")
	slider:SetPoint("BOTTOMLEFT")
	slider:SetPoint("BOTTOMRIGHT")
	slider:SetHeight(12)
	slider:SetMinMaxValues(minValue, maxValue)
	slider:SetValueStep(step)
	slider:SetObeyStepOnDrag(true)
	Style.AddBackground(slider)
	Style.AddBorder(slider, 1)
	local thumb = slider:CreateTexture(nil, "OVERLAY")
	thumb:SetSize(10, 16)
	thumb:SetColorTexture(0.94, 0.76, 0.18, 1)
	slider:SetThumbTexture(thumb)

	slider:SetScript("OnValueChanged", function(_, value, userInput)
		holder.value:SetFormattedText(format, value)
		if userInput then
			if set(value) == false then
				ns:Print(L.COMBAT_BLOCKED)
			end
		end
	end)
	function holder:Refresh()
		local value = get()
		slider:SetValue(value)
		holder.value:SetFormattedText(format, value)
	end
	return Track(holder)
end

-- Liste de choix : un bouton qui ouvre un menu. `options()` renvoie une liste
-- de { valeur, texte }.
local function CreateChoice(parent, text, options, get, set)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(WIDTH - PAD * 2, 22)
	holder.label = CreateLabel(holder, text, 12)
	holder.label:SetPoint("LEFT")
	local button
	button = CreateButton(holder, "", 190, function()
		MenuUtil.CreateContextMenu(button, function(_, root)
			for _, option in ipairs(options()) do
				root:CreateButton(option[2], function()
					if set(option[1]) == false then
						ns:Print(L.COMBAT_BLOCKED)
					end
					ConfigFrame:Refresh()
				end)
			end
		end)
	end)
	button:SetPoint("RIGHT")
	function holder:Refresh()
		local current = get()
		for _, option in ipairs(options()) do
			if option[1] == current then
				button.text:SetText(option[2])
			end
		end
	end
	return Track(holder)
end

-- Pastille de couleur ouvrant le selecteur de couleurs du jeu.
local function CreateSwatch(parent, text, colorName)
	local swatch = CreateFrame("Button", nil, parent)
	swatch:SetSize(16, 16)
	local fill = swatch:CreateTexture(nil, "ARTWORK")
	fill:SetAllPoints()
	Style.AddBorder(swatch, 1, 1)
	swatch.label = CreateLabel(swatch, text, 12)
	swatch.label:SetPoint("LEFT", swatch, "RIGHT", 8, 0)
	swatch:SetHitRectInsets(0, -160, 0, 0)

	local function Apply(r, g, b)
		local color = Profile().colors[colorName]
		color[1], color[2], color[3] = r, g, b
		Changed()
	end
	swatch:SetScript("OnClick", function()
		local color = Profile().colors[colorName]
		ColorPickerFrame:SetupColorPickerAndShow({
			r = color[1], g = color[2], b = color[3], hasOpacity = false,
			swatchFunc = function()
				Apply(ColorPickerFrame:GetColorRGB())
			end,
			cancelFunc = function(previous)
				if previous then
					Apply(previous.r, previous.g, previous.b)
				end
			end,
		})
	end)
	function swatch:Refresh()
		local color = Profile().colors[colorName]
		fill:SetColorTexture(color[1], color[2], color[3], 1)
	end
	return Track(swatch)
end

------------------------------------------------------------------------
-- Onglet General
------------------------------------------------------------------------

local function BuildGeneral(panel)
	local y = 0
	local function Place(control, height, indent)
		control:SetPoint("TOPLEFT", panel, "TOPLEFT", indent or 0, y)
		y = y - height
	end

	Place(CreateChoice(panel, L.CFG_PROFILE, function()
		local list = {}
		for _, name in ipairs(ns.Config.PROFILE_NAMES) do
			list[#list + 1] = { name, name }
		end
		return list
	end, function()
		return ns.Profiles:GetCurrentName()
	end, function(name)
		if ns.API.InCombat() then
			return false
		end
		ns.Profiles:SetCurrent(name)
	end), 28)

	local specChoice = CreateChoice(panel, L.CFG_SPEC, function()
		local list = { { "auto", L.CFG_SPEC_AUTO } }
		for _, key in ipairs(ns.Data.SpecKeys) do
			list[#list + 1] = { key, ns.Specialization:GetName(key) }
		end
		return list
	end, function()
		return ns.Specialization:GetMode()
	end, function(mode)
		ns.Specialization:SetMode(mode)
	end)
	Place(specChoice, 24)

	local detected = CreateFrame("Frame", nil, panel)
	detected:SetSize(WIDTH - PAD * 2, 14)
	detected.text = CreateLabel(detected, "", 11, 0.62, 0.64, 0.68)
	detected.text:SetPoint("RIGHT")
	function detected:Refresh()
		local state = ns.Specialization:GetState()
		local name = state.detected and ns.Specialization:GetName(state.detected) or L.SPEC_NONE
		self.text:SetFormattedText(L.CFG_DETECTED, name)
	end
	Place(Track(detected), 22)

	Place(CreateCheck(panel, L.CFG_LOCK, function()
		return ns.Movers:IsLocked()
	end, function(value)
		ns.Movers:SetLocked(value)
	end), 24)
	Place(CreateCheck(panel, L.CFG_ANIMATIONS, function()
		return Profile().animations
	end, function(value)
		Profile().animations = value
	end), 24)
	Place(CreateCheck(panel, L.CFG_CHAT_ALERTS, function()
		return Profile().buffs.chatAlerts
	end, function(value)
		Profile().buffs.chatAlerts = value
	end), 30)

	Place(CreateSlider(panel, L.CFG_MANA_LOW, 5, 90, 5, "%d", function()
		return Profile().mana.low
	end, function(value)
		Profile().mana.low = value
		-- Le seuil moyen reste au-dessus du seuil faible.
		if Profile().mana.mid <= value then
			Profile().mana.mid = value + 5
		end
		Changed()
	end), 42)
	Place(CreateSlider(panel, L.CFG_MANA_MID, 10, 95, 5, "%d", function()
		return Profile().mana.mid
	end, function(value)
		Profile().mana.mid = value
		if Profile().mana.low >= value then
			Profile().mana.low = value - 5
		end
		Changed()
	end), 42)
	Place(CreateSlider(panel, L.CFG_IDLE_ALPHA, 0.1, 1, 0.05, "%.2f", function()
		return Profile().idleAlpha
	end, function(value)
		Profile().idleAlpha = value
		Changed()
	end), 42)
	Place(CreateSlider(panel, L.CFG_WARN_MINUTES, 1, 30, 1, "%d", function()
		return Profile().buffs.warnMinutes
	end, function(value)
		Profile().buffs.warnMinutes = value
		Changed()
	end), 46)

	local title = CreateLabel(panel, L.CFG_COLORS, 12, 0.62, 0.64, 0.68)
	title:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
	y = y - 22
	local swatches = {
		{ "mana", L.CFG_COLOR_MANA }, { "manaMid", L.CFG_COLOR_MANA_MID },
		{ "manaLow", L.CFG_COLOR_MANA_LOW },
	}
	for index, entry in ipairs(swatches) do
		local swatch = CreateSwatch(panel, entry[2], entry[1])
		local column = (index - 1) % 2
		swatch:SetPoint("TOPLEFT", panel, "TOPLEFT", column * 205, y)
		if column == 1 or index == #swatches then
			y = y - 24
		end
	end

	local reset = CreateButton(panel, L.CFG_RESET, 190, function()
		StaticPopup_Show("UPA_RESET_PROFILE", ns.Profiles:GetCurrentName())
	end)
	reset:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
end

------------------------------------------------------------------------
-- Onglet Groupes
------------------------------------------------------------------------

local function BuildGroups(panel)
	local y = 0
	for _, key in ipairs(ns.Movers:GetOrder()) do
		local function Settings()
			return Profile().groups[key]
		end
		local title = CreateLabel(panel, ns.Movers:GetLabel(key), 13, 0.94, 0.76, 0.18)
		title:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)

		local show = CreateCheck(panel, L.CFG_SHOW, function()
			return Settings().shown
		end, function(value)
			return ns.Movers:SetShown(key, value)
		end)
		show:SetPoint("TOPLEFT", panel, "TOPLEFT", 190, y)
		show:SetHitRectInsets(0, -80, 0, 0)

		local size = CreateSlider(panel, L.CFG_SIZE, ns.Config.SCALE_MIN, ns.Config.SCALE_MAX, 0.05, "%.2f", function()
			return Settings().scale
		end, function(value)
			return ns.Movers:SetScale(key, value)
		end)
		size:SetWidth(190)
		size:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y - 22)

		local opacity = CreateSlider(panel, L.CFG_OPACITY, ns.Config.ALPHA_MIN, ns.Config.ALPHA_MAX, 0.05, "%.2f", function()
			return Settings().alpha
		end, function(value)
			return ns.Movers:SetAlpha(key, value)
		end)
		opacity:SetWidth(190)
		opacity:SetPoint("TOPLEFT", panel, "TOPLEFT", 214, y - 22)

		y = y - 66
	end
end

------------------------------------------------------------------------
-- Onglet Techniques
------------------------------------------------------------------------

local ROW_HEIGHT = 22

local function GroupLabel(group)
	return group == "main" and L.GROUP_MAIN or group == "defensive" and L.GROUP_DEFENSIVE or L.GROUP_OFFENSIVE
end

local function CreateSpellRow(index)
	local row = CreateFrame("Frame", nil, spellChild)
	row:SetSize(WIDTH - PAD * 2 - 26, ROW_HEIGHT)
	row:SetPoint("TOPLEFT", spellChild, "TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)

	row.check = CreateFrame("Button", nil, row)
	row.check:SetSize(14, 14)
	row.check:SetPoint("LEFT")
	Style.AddBackground(row.check)
	Style.AddBorder(row.check, 1)
	row.mark = row.check:CreateTexture(nil, "ARTWORK")
	row.mark:SetPoint("TOPLEFT", 3, -3)
	row.mark:SetPoint("BOTTOMRIGHT", -3, 3)
	row.mark:SetColorTexture(0.94, 0.76, 0.18, 1)
	row.check:SetHitRectInsets(0, -180, 0, 0)
	row.check:SetScript("OnClick", function()
		ns.Cooldowns:SetTracked(row.key, not row.tracked)
	end)

	row.name = CreateLabel(row, "", 12)
	row.name:SetPoint("LEFT", row.check, "RIGHT", 8, 0)
	row.group = CreateLabel(row, "", 11, 0.62, 0.64, 0.68)
	row.group:SetPoint("RIGHT", row, "RIGHT", -56, 0)

	row.later = CreateButton(row, ">", 22, function()
		ns.Cooldowns:Move(row.key, 1)
	end)
	row.later:SetPoint("RIGHT")
	row.earlier = CreateButton(row, "<", 22, function()
		ns.Cooldowns:Move(row.key, -1)
	end)
	row.earlier:SetPoint("RIGHT", row.later, "LEFT", -4, 0)
	return row
end

-- Liste : techniques suivies dans leur ordre d'affichage, puis les autres.
local function RefreshSpells()
	if not spellChild then
		return
	end
	local described = {}
	for _, entry in ipairs(ns.Cooldowns:Describe()) do
		described[entry.key] = entry
	end
	local list = {}
	for _, spell in ipairs(ns.Cooldowns:GetTracked()) do
		if described[spell.key] then
			list[#list + 1] = described[spell.key]
			described[spell.key] = nil
		end
	end
	for _, entry in ipairs(ns.Cooldowns:Describe()) do
		if described[entry.key] then
			list[#list + 1] = entry
		end
	end

	for index, entry in ipairs(list) do
		local row = spellRows[index]
		if not row then
			row = CreateSpellRow(index)
			spellRows[index] = row
		end
		row.key, row.tracked = entry.key, entry.tracked
		row.name:SetText(entry.name)
		row.group:SetText(GroupLabel(entry.group))
		row.mark:SetShown(entry.tracked)
		row.earlier:SetShown(entry.tracked)
		row.later:SetShown(entry.tracked)
		row:Show()
	end
	for index = #list + 1, #spellRows do
		spellRows[index]:Hide()
	end
	spellChild:SetHeight(math.max(#list * ROW_HEIGHT, 1))
end

local function BuildSpells(panel)
	local hint = CreateLabel(panel, L.CFG_SPELLS_HINT, 11, 0.62, 0.64, 0.68)
	hint:SetPoint("TOPLEFT")
	hint:SetWidth(WIDTH - PAD * 2)
	hint:SetJustifyH("LEFT")

	local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 0, -34)
	scroll:SetPoint("BOTTOMRIGHT", -24, 0)
	spellChild = CreateFrame("Frame", nil, scroll)
	spellChild:SetSize(WIDTH - PAD * 2 - 26, 1)
	scroll:SetScrollChild(spellChild)
end

------------------------------------------------------------------------
-- Onglet Ameliorations
------------------------------------------------------------------------

local buffRows = {}
local buffPanel

local function RefreshBuffs()
	if not buffPanel then
		return
	end
	local described = ns.Buffs:Describe()
	for index, entry in ipairs(described) do
		local row = buffRows[index]
		if not row then
			row = CreateFrame("Button", nil, buffPanel)
			row:SetSize(14, 14)
			row:SetPoint("TOPLEFT", buffPanel, "TOPLEFT", 0, -34 - (index - 1) * 24)
			Style.AddBackground(row)
			Style.AddBorder(row, 1)
			row.mark = row:CreateTexture(nil, "ARTWORK")
			row.mark:SetPoint("TOPLEFT", 3, -3)
			row.mark:SetPoint("BOTTOMRIGHT", -3, 3)
			row.mark:SetColorTexture(0.94, 0.76, 0.18, 1)
			row.label = CreateLabel(row, "", 12)
			row.label:SetPoint("LEFT", row, "RIGHT", 8, 0)
			row:SetHitRectInsets(0, -220, 0, 0)
			row:SetScript("OnClick", function()
				ns.Buffs:SetTracked(row.key, not row.tracked)
				ConfigFrame:Refresh()
			end)
			buffRows[index] = row
		end
		row.key, row.tracked = entry.key, entry.tracked
		row.label:SetText(entry.name)
		row.mark:SetShown(entry.tracked)
		row:Show()
	end
	for index = #described + 1, #buffRows do
		buffRows[index]:Hide()
	end
end

local function BuildBuffs(panel)
	buffPanel = panel
	local hint = CreateLabel(panel, L.CFG_BUFFS_HINT, 11, 0.62, 0.64, 0.68)
	hint:SetPoint("TOPLEFT")
	hint:SetWidth(WIDTH - PAD * 2)
	hint:SetJustifyH("LEFT")
end

------------------------------------------------------------------------
-- Fenetre
------------------------------------------------------------------------

local function SelectTab(index)
	for i, panel in ipairs(panels) do
		panel:SetShown(i == index)
		local color = i == index and 1 or 0.11
		tabs[i].border:SetColor(color == 1 and 0.94 or 1, color == 1 and 0.76 or 1, color == 1 and 0.18 or 1, color == 1 and 1 or 0.11)
	end
end

local function Build()
	frame = CreateFrame("Frame", "UPAConfigFrame", UIParent)
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:Hide()
	local background = frame:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetColorTexture(0.04, 0.05, 0.06, 0.95)
	Style.AddBorder(frame, 1)

	local title = CreateLabel(frame, L.CFG_TITLE, 15, 0.94, 0.76, 0.18)
	title:SetPoint("TOPLEFT", PAD, -12)
	local version = CreateLabel(frame, ns.version, 11, 0.62, 0.64, 0.68)
	version:SetPoint("LEFT", title, "RIGHT", 8, -1)
	local close = CreateButton(frame, "X", 22, function()
		frame:Hide()
	end)
	close:SetPoint("TOPRIGHT", -10, -8)

	local builders = {
		{ L.CFG_TAB_GENERAL, BuildGeneral }, { L.CFG_TAB_GROUPS, BuildGroups }, { L.CFG_TAB_SPELLS, BuildSpells },
		{ L.CFG_TAB_BUFFS, BuildBuffs },
	}
	for index, entry in ipairs(builders) do
		local tab = CreateButton(frame, entry[1], 96, function()
			SelectTab(index)
		end)
		tab:SetPoint("TOPLEFT", PAD + (index - 1) * 104, -40)
		tabs[index] = tab

		local panel = CreateFrame("Frame", nil, frame)
		panel:SetPoint("TOPLEFT", PAD, -76)
		panel:SetPoint("BOTTOMRIGHT", -PAD, PAD)
		panels[index] = panel
		entry[2](panel)
	end
	SelectTab(1)

	-- Echap ferme la fenetre.
	tinsert(UISpecialFrames, "UPAConfigFrame")
	frame:SetScript("OnShow", function()
		ConfigFrame:Refresh()
	end)
end

function ConfigFrame:Refresh()
	if not frame or not frame:IsShown() then
		return
	end
	for _, control in ipairs(controls) do
		control:Refresh()
	end
	RefreshSpells()
	RefreshBuffs()
end

function ConfigFrame:Toggle()
	if not frame then
		Build()
	end
	frame:SetShown(not frame:IsShown())
end

function ConfigFrame:OnEnable()
	local function Refresh()
		self:Refresh()
	end
	ns.Events:On("UPA_SPELLS_CHANGED", self, Refresh)
	ns.Events:On("UPA_SPEC_CHANGED", self, Refresh)
	ns.Events:On("UPA_LOCK_CHANGED", self, Refresh)
	ns.Events:On("UPA_BUFFS_CHANGED", self, Refresh)
end

function ConfigFrame:OnProfileChanged()
	self:Refresh()
end
