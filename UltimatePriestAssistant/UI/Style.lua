-- Ultimate Priest Assistant - Style
-- Couleurs, polices et petites briques visuelles communes.

local _, ns = ...

local Style = {}
ns.Style = Style

Style.TEXTURE = "Interface\\Buttons\\WHITE8X8"

Style.colors = {
	panel = { 0.03, 0.04, 0.05, 0.74 },
	line = { 1, 1, 1, 0.11 },
	ready = { 1, 0.91, 0.66 },
	noPower = { 0.35, 0.64, 0.90 },
	dark = { 0, 0, 0 },
	cooldownBar = { 0.35, 0.64, 0.90 },
}

-- Police de l'interface du jeu, lue sur un objet de police standard.
local FONT = GameFontNormal:GetFont()

-- Couleur reglable du profil actif : { r, g, b }.
function Style.ProfileColor(name)
	return ns.Profiles:GetCurrent().colors[name]
end

function Style.SetFont(fontString, size, outline)
	fontString:SetFont(FONT, size, outline == false and "" or "OUTLINE")
	fontString:SetShadowOffset(0, 0)
end

-- Fond sombre semi-transparent.
function Style.AddBackground(frame)
	local background = frame:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetColorTexture(unpack(Style.colors.panel))
	return background
end

-- Contour d'epaisseur `size`, a l'exterieur (`offset` > 0) ou sur le bord.
-- Renvoie un objet avec SetColor(r, g, b, a).
function Style.AddBorder(frame, size, offset, layer)
	offset = offset or 0
	local edges = {}
	local function Edge()
		local edge = frame:CreateTexture(nil, layer or "BORDER")
		edges[#edges + 1] = edge
		return edge
	end
	local top, bottom, left, right = Edge(), Edge(), Edge(), Edge()
	top:SetPoint("TOPLEFT", -offset, offset)
	top:SetPoint("TOPRIGHT", offset, offset)
	top:SetHeight(size)
	bottom:SetPoint("BOTTOMLEFT", -offset, -offset)
	bottom:SetPoint("BOTTOMRIGHT", offset, -offset)
	bottom:SetHeight(size)
	left:SetPoint("TOPLEFT", -offset, offset)
	left:SetPoint("BOTTOMLEFT", -offset, -offset)
	left:SetWidth(size)
	right:SetPoint("TOPRIGHT", offset, offset)
	right:SetPoint("BOTTOMRIGHT", offset, -offset)
	right:SetWidth(size)

	local border = {}
	function border:SetColor(r, g, b, a)
		for _, edge in ipairs(edges) do
			edge:SetColorTexture(r, g, b, a or 1)
		end
	end
	border:SetColor(unpack(Style.colors.line))
	return border
end

function Style.CreateBar(parent, width, height)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetSize(width, height)
	bar:SetStatusBarTexture(Style.TEXTURE)
	Style.AddBackground(bar)
	Style.AddBorder(bar, 1)
	return bar
end
