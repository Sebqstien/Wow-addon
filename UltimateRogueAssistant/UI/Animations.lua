-- Ultimate Rogue Assistant - Animations
-- Animations courtes, toutes desactivables par le profil.

local _, ns = ...

local Animations = {}
ns.Animations = Animations

local function Enabled()
	return ns.Profiles:GetCurrent().animations
end

-- Grossissement bref puis retour a la taille normale.
function Animations.CreatePulse(region, scale, duration)
	local group = region:CreateAnimationGroup()
	local grow = group:CreateAnimation("Scale")
	grow:SetOrder(1)
	grow:SetDuration(duration * 0.35)
	grow:SetScaleFrom(1, 1)
	grow:SetScaleTo(scale, scale)
	local shrink = group:CreateAnimation("Scale")
	shrink:SetOrder(2)
	shrink:SetDuration(duration * 0.65)
	shrink:SetScaleFrom(scale, scale)
	shrink:SetScaleTo(1, 1)
	return group
end

-- Eclat : la texture apparait puis s'efface.
function Animations.CreateFlash(texture, duration)
	texture:SetAlpha(0)
	local group = texture:CreateAnimationGroup()
	local fade = group:CreateAnimation("Alpha")
	fade:SetDuration(duration)
	fade:SetFromAlpha(1)
	fade:SetToAlpha(0)
	return group
end

function Animations.Play(group)
	if Enabled() then
		group:Stop()
		group:Play()
	end
end
