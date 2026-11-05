--!strict
--[[
	WorldService — verifie que la ville construite dans Studio respecte le
	contrat de nommage (`Config.world`), et la donne aux autres services.

	Si quelque chose manque, il le dit EN CLAIR, chemin par chemin, et le jeu ne
	demarre pas : une ville incomplete qui tourne quand meme fabrique des bugs
	introuvables (un Balayage sans limites, une cachette sans interieur).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Survivor = ReplicatedStorage:WaitForChild("Survivor")
local Config = require(Survivor:WaitForChild("Config"))

local WorldService = {}

export type World = {
	root: Instance,
	planque: Instance,
	spawn: BasePart,
	chest: BasePart,
	bounds: BasePart,
	solidSpots: Instance,
	anchors: Instance,
	containers: Instance,
	prefabs: Instance,
}

local world: World? = nil

local function child(
	parent: Instance?,
	name: string,
	problems: { string },
	where: string
): Instance?
	if parent == nil then
		return nil
	end
	local found = parent:FindFirstChild(name)
	if found == nil then
		table.insert(problems, string.format("%s.%s manquant", where, name))
	end
	return found
end

local function asPart(instance: Instance?, problems: { string }, label: string): BasePart?
	if instance == nil then
		return nil
	end
	if instance:IsA("BasePart") then
		return instance
	end
	table.insert(problems, label .. " doit être une Part")
	return nil
end

-- Chaque cachette doit avoir un interieur et une sortie, sinon on ne sait ni
-- ou placer le joueur ni ou le rendre.
local function checkSpot(spot: Instance, problems: { string }, label: string)
	local w = Config.world
	if not spot:FindFirstChild(w.spotInside, true) then
		table.insert(
			problems,
			string.format("%s %s : pas de part %s", label, spot.Name, w.spotInside)
		)
	end
	if not spot:FindFirstChild(w.spotExit, true) then
		table.insert(
			problems,
			string.format("%s %s : pas de part %s", label, spot.Name, w.spotExit)
		)
	end
end

function WorldService.load(): World?
	local w = Config.world
	local problems: { string } = {}

	local root = child(workspace, w.folder, problems, "Workspace")
	local planque = child(root, w.planque, problems, w.folder)
	local spawn = asPart(child(planque, w.spawn, problems, w.planque), problems, w.spawn)
	local chest = asPart(child(planque, w.chest, problems, w.planque), problems, w.chest)
	local bounds = asPart(child(root, w.bounds, problems, w.folder), problems, w.bounds)
	local solidSpots = child(root, w.solidSpots, problems, w.folder)
	local anchors = child(root, w.anchors, problems, w.folder)
	local containers = child(root, w.containers, problems, w.folder)
	local prefabs = child(ServerStorage, w.prefabs, problems, "ServerStorage")

	if solidSpots then
		for _, spot in solidSpots:GetChildren() do
			checkSpot(spot, problems, "Cachette solide")
		end
	end
	if prefabs then
		for _, prefab in prefabs:GetChildren() do
			checkSpot(prefab, problems, "Modèle de cachette")
		end
	end
	if anchors and prefabs then
		local names: { [string]: boolean } = {}
		for _, anchor in anchors:GetChildren() do
			if names[anchor.Name] then
				table.insert(problems, "Emplacement en double : " .. anchor.Name)
			end
			names[anchor.Name] = true
			local prefabName = anchor:GetAttribute("Prefab")
			if typeof(prefabName) ~= "string" or prefabs:FindFirstChild(prefabName) == nil then
				table.insert(
					problems,
					string.format("Emplacement %s : attribut Prefab absent ou inconnu", anchor.Name)
				)
			end
		end
	end
	if containers then
		for _, container in containers:GetChildren() do
			local tableId = container:GetAttribute("Table")
			if typeof(tableId) ~= "string" or Config.loot.tables[tableId] == nil then
				table.insert(
					problems,
					string.format("Fouille %s : attribut Table absent ou inconnu", container.Name)
				)
			end
		end
	end

	if #problems > 0 then
		warn("[Survivor] La ville ne respecte pas le contrat, le jeu ne démarre pas :")
		for _, problem in problems do
			warn("[Survivor]   - " .. problem)
		end
		return nil
	end

	world = {
		root = root :: Instance,
		planque = planque :: Instance,
		spawn = spawn :: BasePart,
		chest = chest :: BasePart,
		bounds = bounds :: BasePart,
		solidSpots = solidSpots :: Instance,
		anchors = anchors :: Instance,
		containers = containers :: Instance,
		prefabs = prefabs :: Instance,
	}
	return world
end

function WorldService.get(): World
	assert(world, "WorldService.load doit réussir avant tout le reste")
	return world
end

return WorldService
