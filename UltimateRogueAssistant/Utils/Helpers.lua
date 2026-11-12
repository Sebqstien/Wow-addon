-- Ultimate Rogue Assistant - Helpers
-- Fonctions utilitaires sans dependance au jeu.

local _, ns = ...

local Helpers = {}
ns.Helpers = Helpers

function Helpers.Clamp(value, minValue, maxValue)
	if value < minValue then
		return minValue
	elseif value > maxValue then
		return maxValue
	end
	return value
end

function Helpers.Round(value, decimals)
	local factor = 10 ^ (decimals or 0)
	return math.floor(value * factor + 0.5) / factor
end

function Helpers.DeepCopy(source)
	if type(source) ~= "table" then
		return source
	end
	local copy = {}
	for key, value in pairs(source) do
		copy[key] = Helpers.DeepCopy(value)
	end
	return copy
end

-- Complete `target` avec les cles de `defaults` qui lui manquent, sans ecraser
-- les valeurs existantes. Une valeur dont le type ne correspond plus a celui
-- des valeurs par defaut est remplacee : cela protege d'une sauvegarde abimee.
function Helpers.ApplyDefaults(target, defaults)
	for key, default in pairs(defaults) do
		local current = target[key]
		if type(default) == "table" then
			if type(current) ~= "table" then
				current = {}
				target[key] = current
			end
			Helpers.ApplyDefaults(current, default)
		elseif current == nil or type(current) ~= type(default) then
			target[key] = default
		end
	end
	return target
end
