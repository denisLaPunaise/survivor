--!strict
--[[
	SoundView — ce qu'on entend, de son propre point de vue.

	- L'ambiance : le vent le jour, un drone sourd la nuit, un coeur lent dans
	  le Ventre ; on passe de l'une a l'autre en fondu.
	- L'Oeil : un coup sourd et un grondement quand le ciel rougit, ses
	  paupieres, son regard qui bourdonne de plus en plus fort quand il
	  approche, un murmure quand il te voit, son cri quand on lui fait mal.
	- L'aspiration, pour celui qu'on aspire.

	Les sons poses dans le monde (toits, epaves, aspiration vue des autres)
	sont joues par le serveur (Sfx). Tous les sons sont precharges au
	demarrage : un son qui ne charge pas est nomme dans la console, plutot que
	de manquer en silence.
]]

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Survivor = ReplicatedStorage:WaitForChild("Survivor")
local Config = require(Survivor:WaitForChild("Config"))
local Remotes = Survivor:WaitForChild("Remotes")

local SoundView = {}

local sounds: { [string]: Sound } = {}
local volumes: { [string]: number } = {}

-- Un son d'un coup, chez soi seulement.
function SoundView.play(name: string)
	local sound = sounds[name]
	if sound then
		sound.TimePosition = 0
		sound:Play()
	end
end

local function fadeTo(name: string, volume: number)
	local sound = sounds[name]
	if sound == nil then
		return
	end
	if volume > 0 and not sound.IsPlaying then
		sound.Volume = 0
		sound:Play()
	end
	local tween =
		TweenService:Create(sound, TweenInfo.new(Config.sounds.fadeSeconds), { Volume = volume })
	tween:Play()
	if volume == 0 then
		tween.Completed:Once(function()
			if sound.Volume == 0 then
				sound:Stop()
			end
		end)
	end
end

function SoundView.start()
	local player = Players.LocalPlayer
	local all: { Instance } = {}
	for name, entry in Config.sounds.library :: any do
		local sound = Instance.new("Sound")
		sound.Name = "Survivor_" .. name
		sound.SoundId = "rbxassetid://" .. entry.id
		sound.Volume = entry.volume
		sound.Looped = entry.looped == true
		sound.PlaybackSpeed = entry.speed or 1
		sound.Parent = SoundService
		sounds[name] = sound
		volumes[name] = entry.volume
		table.insert(all, sound)
	end
	task.spawn(function()
		ContentProvider:PreloadAsync(all)
		for name, sound in sounds do
			if not sound.IsLoaded then
				warn(
					"[Survivor] Son qui ne se charge pas : " .. name .. " (" .. sound.SoundId .. ")"
				)
			end
		end
	end)

	-- L'AMBIANCE : une seule a la fois.
	local night = false
	local function ambience()
		local taken = player:GetAttribute("Taken") == true
		local wanted = if taken then "coeur" elseif night then "nuit" else "vent"
		for _, name in { "vent", "nuit", "coeur" } do
			fadeTo(name, if name == wanted then volumes[name] else 0)
		end
	end
	ambience()

	-- L'OEIL.
	local eyeState = Remotes:WaitForChild("EyeState") :: RemoteEvent
	eyeState.OnClientEvent:Connect(function(data: any)
		if data.phase == "warning" then
			SoundView.play("signal")
			SoundView.play("ouverture")
			fadeTo("menace", volumes.menace)
		elseif data.phase == "sweep" then
			fadeTo("menace", 0)
			local regard = sounds.regard
			if regard and not regard.IsPlaying then
				regard.Volume = 0
				regard:Play()
			end
		elseif data.phase == "blink" then
			SoundView.play("cri")
		elseif data.phase == "idle" then
			fadeTo("menace", 0)
			fadeTo("regard", 0)
			local closing = sounds.ouverture
			if closing then
				-- Les paupieres se referment : le meme son, plus lent.
				closing.PlaybackSpeed = 0.7
				SoundView.play("ouverture")
				task.delay(3, function()
					closing.PlaybackSpeed = 1
				end)
			end
		elseif data.phase == "night" then
			night = true
			fadeTo("regard", 0)
			ambience()
		elseif data.phase == "dawn" then
			night = false
			ambience()
		end
	end)

	-- Son regard bourdonne d'autant plus fort que le bout du faisceau est
	-- pres de soi.
	RunService.RenderStepped:Connect(function()
		local regard = sounds.regard
		if regard == nil or not regard.IsPlaying then
			return
		end
		local beam = workspace:FindFirstChild("Regard")
		if beam == nil or not beam:IsA("BasePart") then
			return
		end
		local tip = beam.Position + beam.CFrame.RightVector * (beam.Size.X / 2)
		local here = workspace.CurrentCamera.CFrame.Position
		local flat = Vector3.new(tip.X - here.X, 0, tip.Z - here.Z).Magnitude
		local near = math.clamp(1 - flat / Config.sounds.gazeHeardStuds, 0, 1)
		regard.Volume = volumes.regard * near * near
	end)

	-- Il te voit : un murmure, une fois par regard (pas a chaque image).
	local seen = false
	player:GetAttributeChangedSignal("Exposure"):Connect(function()
		local level = player:GetAttribute("Exposure")
		local now = typeof(level) == "number" and level > 0.02
		if now and not seen then
			SoundView.play("murmure")
		end
		seen = now
	end)

	-- Aspire : le souffle, et le coeur du Ventre a la place du vent.
	player:GetAttributeChangedSignal("Taken"):Connect(function()
		if player:GetAttribute("Taken") == true then
			SoundView.play("aspiration")
		end
		ambience()
	end)
end

return SoundView
