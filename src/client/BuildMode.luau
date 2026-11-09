--!strict
--[[
	BuildMode — la construction libre, a la manette (decide avec Josh le 9
	novembre 2026).

	Fleche gauche, pres de la Planque : on entre en mode construction. On
	vise le sol : un fantome de la piece, vert si on peut la poser, rouge
	sinon (trop loin, place prise, reserve insuffisante). R2 pose, L1 / R1
	tournent, haut / bas changent de piece, B ou fleche gauche sortent.

	Le client ne fait que montrer et demander : le serveur verifie tout
	(FreeBuildService) et peut refuser.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Survivor = ReplicatedStorage:WaitForChild("Survivor")
local Config = require(Survivor:WaitForChild("Config"))
local FreeBuild = require(Survivor:WaitForChild("FreeBuild"))
local Planque = require(Survivor:WaitForChild("Planque"))
local Remotes = Survivor:WaitForChild("Remotes")

local Typography = require(script.Parent:WaitForChild("Typography"))

local BuildMode = {}

local player = Players.LocalPlayer
local construct = Remotes:WaitForChild("Construct") :: RemoteEvent

local active = false
local pieceIndex = 1
local turns = 0
local stock: { [string]: number } = {}
local ghost: Part? = nil
local aim: Vector3? = nil
local panel: TextLabel? = nil

local GREEN = Color3.fromRGB(110, 220, 120)
local RED = Color3.fromRGB(230, 80, 70)

local function spawnPosition(): Vector3?
	local root = workspace:FindFirstChild(Config.world.folder)
	local planque = root and root:FindFirstChild(Config.world.planque)
	local spawn = planque and planque:FindFirstChild(Config.world.spawn)
	return if spawn and spawn:IsA("BasePart") then spawn.Position else nil
end

local function pieces(): { any }
	return Config.freeBuild.pieces :: { any }
end

-- Les cases deja prises : celles des constructions posees.
local function occupied(): { [string]: boolean }
	local out: { [string]: boolean } = {}
	local root = workspace:FindFirstChild(Config.world.folder)
	local built = root and root:FindFirstChild("Constructions")
	if built then
		for _, model in built:GetChildren() do
			local keys = model:GetAttribute("Cles")
			if typeof(keys) == "string" then
				for key in string.gmatch(keys, "[^,]+") do
					out[key] = true
				end
			end
		end
	end
	return out
end

local function costText(cost: { [string]: number }): string
	local parts: { string } = {}
	for itemId, amount in cost do
		local have = stock[itemId] or 0
		table.insert(parts, string.format("%s %d/%d", Config.items[itemId].name, have, amount))
	end
	table.sort(parts)
	return table.concat(parts, " · ")
end

local function refreshPanel()
	local label = panel
	if label == nil then
		return
	end
	local piece = pieces()[pieceIndex]
	label.Text = string.format(
		"%s   —   %s\nR2 poser · L1/R1 tourner · ↑↓ pièce · B sortir",
		piece.name,
		costText(piece.cost)
	)
end

local function makeGhost()
	if ghost then
		ghost:Destroy()
	end
	local piece = pieces()[pieceIndex]
	local g = Instance.new("Part")
	g.Name = "FantomeConstruction"
	g.Anchored = true
	g.CanCollide = false
	g.CanQuery = false
	g.CanTouch = false
	g.CastShadow = false
	-- Un fantome plein et pale : en champ de force, il ne se voyait presque
	-- pas (vu le 9 novembre 2026).
	g.Material = Enum.Material.SmoothPlastic
	g.Size = Vector3.new(piece.size[1], piece.size[2], piece.size[3])
	g.Parent = workspace
	ghost = g
	refreshPanel()
end

local function update()
	local g = ghost
	local character = player.Character
	local spawn = spawnPosition()
	if g == nil or character == nil or spawn == nil then
		return
	end
	local b = Config.freeBuild
	local camera = workspace.CurrentCamera
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, g }
	local hit =
		workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * (b.reach + 10), params)
	if hit == nil then
		g.Transparency = 1
		aim = nil
		return
	end
	local piece = pieces()[pieceIndex]
	local i, j = FreeBuild.cellAt(hit.Position.X, hit.Position.Z, b.grid)
	local keys, cx, cz = FreeBuild.footprint(piece, turns, i, j, b.grid)
	local lift = piece.size[2] / 2 + (piece.height or 0)
	g.CFrame = CFrame.new(cx, hit.Position.Y + lift, cz) * CFrame.Angles(0, math.rad(90 * turns), 0)
	g.Transparency = 0.45
	local from = character:GetPivot().Position
	local ok = FreeBuild.inYard(cx, cz, spawn.X, spawn.Z, b.radius)
		and Vector3.new(cx - from.X, 0, cz - from.Z).Magnitude <= b.reach
		and FreeBuild.fits(occupied(), keys)
		and Planque.canAfford(stock, piece.cost)
	g.Color = if ok then GREEN else RED
	aim = if ok then hit.Position else nil
end

local function leave()
	if not active then
		return
	end
	active = false
	RunService:UnbindFromRenderStep("SurvivorConstruction")
	for _, name in
		{
			"SurvivorPoser",
			"SurvivorTournerG",
			"SurvivorTournerD",
			"SurvivorPiecePrec",
			"SurvivorPieceSuiv",
			"SurvivorSortirConstruction",
		}
	do
		ContextActionService:UnbindAction(name)
	end
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
	local label = panel
	if label then
		label.Visible = false
	end
end

local function bindHigh(name: string, binding: any, onPress: () -> ())
	local inputs: { any } = { (Enum.KeyCode :: any)[binding.gamepad] }
	if binding.keyboard == "MouseButton1" then
		table.insert(inputs, Enum.UserInputType.MouseButton1)
	else
		table.insert(inputs, (Enum.KeyCode :: any)[binding.keyboard])
	end
	-- Au-dessus des actions a pied : R2 ne frappe plus, B ne s'accroupit
	-- plus, tant qu'on construit.
	ContextActionService:BindActionAtPriority(name, function(_, state)
		if state == Enum.UserInputState.Begin then
			onPress()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, table.unpack(inputs))
end

local function enter()
	local spawn = spawnPosition()
	local character = player.Character
	if spawn == nil or character == nil then
		return
	end
	if (character:GetPivot().Position - spawn).Magnitude > Config.freeBuild.radius then
		return
	end
	active = true
	makeGhost()
	local label = panel
	if label then
		label.Visible = true
	end
	local c = Config.controls.contexts.building
	bindHigh("SurvivorPoser", c.place, function()
		local at = aim
		if at then
			construct:FireServer({
				piece = pieces()[pieceIndex].id,
				x = at.X,
				z = at.Z,
				turns = turns,
			})
		end
	end)
	bindHigh("SurvivorTournerG", c.rotateLeft, function()
		turns = (turns + 3) % 4
	end)
	bindHigh("SurvivorTournerD", c.rotateRight, function()
		turns = (turns + 1) % 4
	end)
	bindHigh("SurvivorPiecePrec", c.previousPiece, function()
		pieceIndex = (pieceIndex - 2) % #pieces() + 1
		makeGhost()
	end)
	bindHigh("SurvivorPieceSuiv", c.nextPiece, function()
		pieceIndex = pieceIndex % #pieces() + 1
		makeGhost()
	end)
	bindHigh("SurvivorSortirConstruction", c.leave, leave)
	RunService:BindToRenderStep(
		"SurvivorConstruction",
		Enum.RenderPriority.Camera.Value + 1,
		function()
			-- Sorti de la cour, cache, a terre ou aspire : on quitte le mode.
			local spawnNow = spawnPosition()
			local ch = player.Character
			if
				spawnNow == nil
				or ch == nil
				or (ch:GetPivot().Position - spawnNow).Magnitude > Config.freeBuild.radius + 10
				or player:GetAttribute("Hidden")
				or player:GetAttribute("Downed")
				or player:GetAttribute("Taken")
			then
				leave()
				return
			end
			update()
		end
	)
end

function BuildMode.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SurvivorConstruction"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, -110)
	label.Size = UDim2.new(0.7, 0, 0, 56)
	label.BackgroundColor3 = Color3.fromRGB(14, 13, 12)
	label.BackgroundTransparency = 0.35
	label.BorderSizePixel = 0
	label.Font = Typography.UI
	label.TextSize = 18
	label.TextColor3 = Typography.INK
	label.TextWrapped = true
	label.Visible = false
	label.Parent = gui
	panel = label

	-- La reserve, telle que le serveur l'envoie avec le reste du HUD.
	local hud = Remotes:WaitForChild("Hud") :: RemoteEvent
	hud.OnClientEvent:Connect(function(data: any)
		if typeof(data) == "table" and typeof(data.stock) == "table" then
			stock = data.stock
			if active then
				refreshPanel()
			end
		end
	end)

	-- La meme touche entre et sort (fleche gauche, l'action `build` a pied).
	local toggle = Config.controls.contexts.onFoot.build
	ContextActionService:BindAction("SurvivorConstruire", function(_, state)
		if state == Enum.UserInputState.Begin then
			if active then
				leave()
			else
				enter()
			end
		end
		return Enum.ContextActionResult.Pass
	end, false, (Enum.KeyCode :: any)[toggle.gamepad], (Enum.KeyCode :: any)[toggle.keyboard])
end

return BuildMode
