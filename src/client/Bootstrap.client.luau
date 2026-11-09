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

local BagPanel = require(script.Parent:WaitForChild("BagPanel"))
local BuildPanel = require(script.Parent:WaitForChild("BuildPanel"))
local ChapterView = require(script.Parent:WaitForChild("ChapterView"))
local Controls = require(script.Parent:WaitForChild("Controls"))
local Hud = require(script.Parent:WaitForChild("Hud"))
local RadioView = require(script.Parent:WaitForChild("RadioView"))
local SkyView = require(script.Parent:WaitForChild("SkyView"))
local SoundView = require(script.Parent:WaitForChild("SoundView"))
local VentreView = require(script.Parent:WaitForChild("VentreView"))

print(
	string.format(
		"[Survivor] Client démarré pour %s — réglages version %d",
		Players.LocalPlayer.Name,
		Config.version
	)
)

SoundView.start()
Hud.start()
Controls.start()
SkyView.start()
BuildPanel.start()
BagPanel.start()
RadioView.start()
VentreView.start()
ChapterView.start()
