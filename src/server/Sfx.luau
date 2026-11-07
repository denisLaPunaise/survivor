--!strict
--[[
	Sfx — les sons poses dans le monde, que tout le monde entend d'ou il est :
	un toit qui s'arrache, quelqu'un qu'on aspire, une epave qui s'ecrase.

	Les sons viennent de Config.sounds.library. Un son joue par le serveur est
	entendu par chaque client ; il se nettoie quand il a fini (`Ended` : sa
	duree vaut 0 tant qu'il n'est pas charge).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Survivor = ReplicatedStorage:WaitForChild("Survivor")
local Config = require(Survivor:WaitForChild("Config"))

local Sfx = {}

-- Joue le son `name` a cet endroit (une part, ou une position).
function Sfx.at(name: string, where: BasePart | Vector3)
	local entry = (Config.sounds.library :: any)[name]
	if entry == nil then
		warn("[Survivor] Son inconnu : " .. name)
		return
	end
	local holder: BasePart
	local temporary: Part? = nil
	if typeof(where) == "Vector3" then
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.Transparency = 1
		p.Size = Vector3.one
		p.Position = where
		p.Parent = workspace
		holder, temporary = p, p
	else
		holder = where
	end
	local sound = Instance.new("Sound")
	sound.Name = "Son_" .. name
	sound.SoundId = "rbxassetid://" .. entry.id
	sound.Volume = entry.volume
	sound.PlaybackSpeed = entry.speed or 1
	sound.RollOffMinDistance = Config.sounds.rollOffMin
	sound.RollOffMaxDistance = Config.sounds.rollOffMax
	sound.Parent = holder
	sound.Ended:Connect(function()
		sound:Destroy()
		if temporary then
			temporary:Destroy()
		end
	end)
	sound:Play()
end

return Sfx
