--!strict
--[[
	BuildPanel — le panneau de l'etabli : ce qu'on peut construire a la
	Planque, ce que ca coute, ce qui manque.

	A LA MANETTE D'ABORD (lecons d'Arena) : a l'ouverture, un bouton est
	SELECTIONNE, sinon la croix et le stick ne naviguent pas et le panneau est
	un mur. B ferme. Les boutons gardent des noms stables : le panneau se
	reconstruit a chaque reponse du serveur, et Roblox deplacerait la selection
	tout seul si le bouton selectionne disparaissait.
]]

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Survivor = ReplicatedStorage:WaitForChild("Survivor")
local Config = require(Survivor:WaitForChild("Config"))
local Remotes = Survivor:WaitForChild("Remotes")

local BuildPanel = {}

local player = Players.LocalPlayer
local remote = Remotes:WaitForChild("Planque") :: RemoteEvent

local INK = Color3.fromRGB(236, 230, 218)
local DIM = Color3.fromRGB(140, 134, 124)
local PANEL = Color3.fromRGB(20, 19, 18)
local ROW = Color3.fromRGB(40, 38, 35)
local FONT = Enum.Font.GothamMedium

local function costText(cost: { [string]: number }): string
	local parts: { string } = {}
	local ids: { string } = {}
	for itemId in cost do
		table.insert(ids, itemId)
	end
	table.sort(ids)
	for _, itemId in ids do
		local item = Config.items[itemId]
		table.insert(
			parts,
			string.format("%d %s", cost[itemId], if item then item.name else itemId)
		)
	end
	return table.concat(parts, ", ")
end

function BuildPanel.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SurvivorEtabli"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "Panneau"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(560, 470)
	frame.BackgroundColor3 = PANEL
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 44)
	title.BackgroundTransparency = 1
	title.Font = FONT
	title.TextSize = 24
	title.TextColor3 = INK
	title.Text = "Établi — construire avec la réserve"
	title.Parent = frame

	local list = Instance.new("Frame")
	list.Name = "Liste"
	list.Position = UDim2.fromOffset(16, 50)
	list.Size = UDim2.new(1, -32, 1, -90)
	list.BackgroundTransparency = 1
	list.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local hint = Instance.new("TextLabel")
	hint.AnchorPoint = Vector2.new(0, 1)
	hint.Position = UDim2.new(0, 0, 1, -8)
	hint.Size = UDim2.new(1, 0, 0, 24)
	hint.BackgroundTransparency = 1
	hint.Font = FONT
	hint.TextSize = 16
	hint.TextColor3 = DIM
	hint.Text = "A : construire   ·   B : fermer"
	hint.Parent = frame

	-- L'action de chaque bouton : une Instance ne porte pas de champ a nous.
	local actions: { [TextButton]: () -> () } = {}

	local function close()
		gui.Enabled = false
		GuiService.SelectedObject = nil
		ContextActionService:UnbindAction("SurvivorFermerEtabli")
	end

	local function row(
		order: number,
		name: string,
		heading: string,
		detail: string,
		enabled: boolean,
		onPress: () -> ()
	)
		local button = list:FindFirstChild(name) :: TextButton?
		if button == nil then
			local b = Instance.new("TextButton")
			b.Name = name
			b.Size = UDim2.new(1, 0, 0, 62)
			b.BackgroundColor3 = ROW
			b.BorderSizePixel = 0
			b.AutoButtonColor = true
			b.Text = ""
			b.Parent = list
			local stroke = Instance.new("UIStroke")
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Color = INK
			stroke.Transparency = 1
			stroke.Parent = b
			b.SelectionGained:Connect(function()
				stroke.Transparency = 0
			end)
			b.SelectionLost:Connect(function()
				stroke.Transparency = 1
			end)
			for _, key in { "Titre", "Detail" } do
				local l = Instance.new("TextLabel")
				l.Name = key
				l.BackgroundTransparency = 1
				l.Font = FONT
				l.TextXAlignment = Enum.TextXAlignment.Left
				l.Position = UDim2.fromOffset(12, if key == "Titre" then 6 else 32)
				l.Size = UDim2.new(1, -24, 0, 24)
				l.TextSize = if key == "Titre" then 19 else 15
				l.Parent = b
			end
			button = b
		end
		local b = button :: TextButton
		b.LayoutOrder = order
		local titleLabel = b:FindFirstChild("Titre") :: TextLabel
		local detailLabel = b:FindFirstChild("Detail") :: TextLabel
		titleLabel.Text = heading
		titleLabel.TextColor3 = if enabled then INK else DIM
		detailLabel.Text = detail
		detailLabel.TextColor3 = DIM
		b:SetAttribute("Actif", enabled)
		-- Un seul branchement par bouton ; l'action du moment est en attribut.
		if b:GetAttribute("Branche") ~= true then
			b:SetAttribute("Branche", true)
			b.Activated:Connect(function()
				local action = actions[b]
				if b:GetAttribute("Actif") and action then
					action()
				end
			end)
		end
		actions[b] = onPress
	end

	local function render(panel: any)
		for i, entry in panel.builds do
			local state = if entry.built
				then "Construit"
				elseif entry.affordable then "Possible"
				else "Il manque des objets"
			row(
				i,
				"Construire_" .. entry.id,
				string.format("%s — %s", entry.name, state),
				if entry.built
					then entry.description
					else costText(entry.cost) .. " · " .. entry.description,
				not entry.built and entry.affordable,
				function()
					remote:FireServer({ build = entry.id })
				end
			)
		end
		local repair = list:FindFirstChild("Reparer")
		if panel.repair then
			row(
				100,
				"Reparer",
				string.format(
					"Réparer la barricade (%d / %d)",
					panel.repair.health,
					panel.repair.max
				),
				costText(panel.repair.cost),
				panel.repair.affordable,
				function()
					remote:FireServer({ repair = true })
				end
			)
		elseif repair then
			repair:Destroy()
		end
	end

	remote.OnClientEvent:Connect(function(data: any)
		if data.panel then
			render(data.panel)
		end
		if data.open then
			gui.Enabled = true
			-- La main a la manette : le premier bouton est selectionne.
			local first = list:FindFirstChild("Construire_" .. Config.planque.builds[1].id)
			if
				GuiService.SelectedObject == nil
				or not GuiService.SelectedObject:IsDescendantOf(gui)
			then
				GuiService.SelectedObject = first :: GuiObject?
			end
			ContextActionService:BindActionAtPriority(
				"SurvivorFermerEtabli",
				function(_, state)
					if state == Enum.UserInputState.Begin then
						close()
					end
					return Enum.ContextActionResult.Sink
				end,
				false,
				Enum.ContextActionPriority.High.Value,
				Enum.KeyCode.ButtonB,
				Enum.KeyCode.Backspace
			)
		end
	end)
	-- S'eloigner de l'etabli ferme le panneau : un panneau ouvert qui ne sert
	-- plus a rien bloque la manette.
	task.spawn(function()
		while true do
			task.wait(0.5)
			if gui.Enabled then
				local character = player.Character
				local bench = workspace:FindFirstChild(Config.world.folder)
				bench = bench and bench:FindFirstChild(Config.world.planque)
				bench = bench and bench:FindFirstChild(Config.world.workbench, true)
				if
					character == nil
					or bench == nil
					or not bench:IsA("BasePart")
					or (character:GetPivot().Position - bench.Position).Magnitude
						> Config.planque.useDistance + 4
				then
					close()
				end
			end
		end
	end)
end

return BuildPanel
