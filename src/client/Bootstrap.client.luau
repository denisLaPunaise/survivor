--!strict
--[[
	Bootstrap — point d'entree client, et le seul.

	Le client affiche et envoie des intentions ; il ne decide de rien. Chaque
	module d'interface et d'entree se demarre depuis ici.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Survivor = ReplicatedStorage:WaitForChild("Survivor")
local Config = require(Survivor:WaitForChild("Config"))

local Controls = require(script.Parent:WaitForChild("Controls"))
local Hud = require(script.Parent:WaitForChild("Hud"))

print(
	string.format(
		"[Survivor] Client démarré pour %s — réglages version %d",
		Players.LocalPlayer.Name,
		Config.version
	)
)

Hud.start()
Controls.start()
