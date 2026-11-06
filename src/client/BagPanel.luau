--!strict
--[[
	BagPanel — le sac (Y) : voir ce qu'on porte, et manger ou se soigner ; et
	le journal : la quete en cours et tout ce que Mara a dit (Josh : relire si
	l'on n'etait pas attentif). L1 / R1 passent d'un onglet a l'autre.

	A la manette (lecons d'Arena) : a l'ouverture, le premier objet est
	SELECTIONNE ; A utilise l'objet choisi ; B ou Y ferment. Dans le journal, le
	cadre est selectionne et le stick droit le fait defiler. Le jeu ne se met
	pas en pause : on ouvre son sac a l'abri.
	Boutons : Config.controls.contexts.bag.
]]

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Survivor = ReplicatedStorage:WaitForChild("Survivor")
local Config = require(Survivor:WaitForChild("Config"))
local Remotes = Survivor:WaitForChild("Remotes")

local Typography = require(script.Parent:WaitForChild("Typography"))

local BagPanel = {}

local player = Players.LocalPlayer
local bagRemote = Remotes:WaitForChild("Bag") :: RemoteEvent
local radioRemote = Remotes:WaitForChild("Radio") :: RemoteEvent
local hud = Remotes:WaitForChild("Hud") :: RemoteEvent

local INK = Color3.fromRGB(236, 230, 218)
local DIM = Color3.fromRGB(140, 134, 124)
local PANEL = Color3.fromRGB(20, 19, 18)
local ROW = Color3.fromRGB(40, 38, 35)
local FONT = Enum.Font.GothamMedium

local function effectText(itemId: string): (string, boolean)
	local item = Config.items[itemId] :: any
	if item == nil then
		return "", false
	end
	if item.food then
		return string.format("Manger : faim +%d", item.food), true
	end
	if item.heal then
		return string.format("Utiliser : santé +%d", item.heal), true
	end
	if item.hint then
		return item.hint, false
	end
	return "À déposer au coffre de la Planque", false
end

function BagPanel.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SurvivorSac"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	-- Centre a gauche, en hauteur relative : a 420 px fixes, il sortait par
	-- le haut d'un petit ecran (vu en jeu le 5 novembre 2026).
	frame.AnchorPoint = Vector2.new(0, 0.5)
	frame.Position = UDim2.new(0, 24, 0.5, 0)
	frame.Size = UDim2.fromScale(0.6, 0.78)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(380, 460)
	limit.Parent = frame
	frame.BackgroundColor3 = PANEL
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundTransparency = 1
	title.Font = FONT
	title.TextSize = 22
	title.TextColor3 = INK
	title.Text = "Sac"
	title.Parent = frame

	local list = Instance.new("Frame")
	list.Name = "Liste"
	list.Position = UDim2.fromOffset(12, 44)
	list.Size = UDim2.new(1, -24, 1, -80)
	list.BackgroundTransparency = 1
	list.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local journalView = Instance.new("ScrollingFrame")
	journalView.Name = "Journal"
	journalView.Position = UDim2.fromOffset(12, 44)
	journalView.Size = UDim2.new(1, -24, 1, -80)
	journalView.BackgroundTransparency = 1
	journalView.BorderSizePixel = 0
	journalView.ScrollBarThickness = 6
	journalView.ScrollingDirection = Enum.ScrollingDirection.Y
	journalView.CanvasSize = UDim2.new()
	journalView.AutomaticCanvasSize = Enum.AutomaticSize.Y
	-- Selectionnable : a la manette, le stick droit le fait defiler.
	journalView.Selectable = true
	journalView.Visible = false
	journalView.Parent = frame
	local journalLayout = Instance.new("UIListLayout")
	journalLayout.Padding = UDim.new(0, 8)
	journalLayout.SortOrder = Enum.SortOrder.LayoutOrder
	journalLayout.Parent = journalView

	local hint = Instance.new("TextLabel")
	hint.AnchorPoint = Vector2.new(0, 1)
	hint.Position = UDim2.new(0, 0, 1, -6)
	hint.Size = UDim2.new(1, 0, 0, 22)
	hint.BackgroundTransparency = 1
	hint.Font = FONT
	hint.TextSize = 15
	hint.TextColor3 = DIM
	hint.Text = "A : manger / utiliser   ·   B ou Y : fermer"
	hint.Parent = frame

	local empty = Instance.new("TextLabel")
	empty.Name = "Vide"
	empty.Size = UDim2.new(1, 0, 0, 40)
	empty.Position = UDim2.fromOffset(0, 60)
	empty.BackgroundTransparency = 1
	empty.Font = FONT
	empty.TextSize = 17
	empty.TextColor3 = DIM
	empty.Text = "Le sac est vide. Fouille les maisons (X maintenu)."
	empty.TextWrapped = true
	empty.Parent = frame

	local items: { string } = {}
	local buttons: { [TextButton]: number } = {}
	local tab = "bag"
	type Entry = { title: string, lines: { string } }
	local journal: { Entry } = {}
	local objective = ""

	local function journalLabel(order: number, text: string, color: Color3, size: number)
		local label = Instance.new("TextLabel")
		label.LayoutOrder = order
		label.Size = UDim2.new(1, -10, 0, 0)
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.BackgroundTransparency = 1
		-- Le journal se lit comme des pages tapees a la machine.
		label.Font = Typography.STORY
		label.TextSize = size
		label.TextColor3 = color
		label.TextWrapped = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text = text
		label.Parent = journalView
	end

	-- Le journal se reecrit en entier : il est court, et l'ordre change (le
	-- plus recent en haut).
	local function renderJournal()
		for _, child in journalView:GetChildren() do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		local order = 0
		local function nextOrder(): number
			order += 1
			return order
		end
		journalLabel(nextOrder(), "En cours", DIM, 14)
		journalLabel(
			nextOrder(),
			if objective == "" then "Rien pour l'instant." else objective,
			INK,
			17
		)
		if #journal == 0 then
			journalLabel(nextOrder(), "La radio de la Planque ne dit encore rien.", DIM, 15)
		end
		for i = #journal, 1, -1 do
			local entry = journal[i]
			journalLabel(nextOrder(), entry.title, DIM, 14)
			journalLabel(nextOrder(), table.concat(entry.lines, "\n\n"), INK, 16)
		end
	end

	local function render()
		-- Des noms stables (Objet1, Objet2...) : Roblox deplace la selection
		-- tout seul quand le bouton selectionne disparait.
		for i = 1, Config.bag.slots do
			local name = "Objet" .. i
			local b = list:FindFirstChild(name) :: TextButton?
			local itemId = items[i]
			if itemId == nil then
				if b then
					b.Visible = false
				end
				continue
			end
			if b == nil then
				local created = Instance.new("TextButton")
				created.Name = name
				created.LayoutOrder = i
				-- Une ligne par place du sac, quelle que soit la hauteur.
				created.Size = UDim2.new(1, 0, 1 / Config.bag.slots, -4)
				created.BackgroundColor3 = ROW
				created.BorderSizePixel = 0
				created.TextXAlignment = Enum.TextXAlignment.Left
				created.Font = FONT
				created.TextSize = 16
				created.TextColor3 = INK
				created.Parent = list
				local stroke = Instance.new("UIStroke")
				stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				stroke.Color = INK
				stroke.Transparency = 1
				stroke.Parent = created
				created.SelectionGained:Connect(function()
					stroke.Transparency = 0
				end)
				created.SelectionLost:Connect(function()
					stroke.Transparency = 1
				end)
				created.Activated:Connect(function()
					local index = buttons[created]
					if index and items[index] then
						bagRemote:FireServer({ use = index })
					end
				end)
				b = created
			end
			local button = b :: TextButton
			buttons[button] = i
			button.Visible = true
			local item = Config.items[itemId]
			local effect, usable = effectText(itemId)
			button.Text = "  " .. (if item then item.name else itemId) .. "   ·   " .. effect
			button.TextColor3 = if usable then INK else DIM
		end
		if tab ~= "bag" then
			return
		end
		title.Text = string.format("Sac %d / %d   ·   R1 : journal", #items, Config.bag.slots)
		empty.Visible = #items == 0
		-- Si l'objet selectionne vient d'etre mange, on retombe sur le premier.
		if gui.Enabled then
			local selected = GuiService.SelectedObject
			if selected == nil or not selected:IsDescendantOf(gui) or not selected.Visible then
				GuiService.SelectedObject = list:FindFirstChild("Objet1") :: GuiObject?
			end
		end
	end

	hud.OnClientEvent:Connect(function(data: any)
		if typeof(data.items) == "table" then
			items = data.items
			render()
		end
	end)
	radioRemote.OnClientEvent:Connect(function(data: any)
		if typeof(data) ~= "table" then
			return
		end
		if typeof(data.journal) == "table" then
			journal = data.journal
		end
		if typeof(data.objective) == "string" then
			objective = data.objective
		end
		if tab == "journal" then
			renderJournal()
		end
	end)

	local function setTab(name: string)
		tab = name
		local onBag = name == "bag"
		list.Visible = onBag
		journalView.Visible = not onBag
		if onBag then
			hint.Text = "A : manger / utiliser   ·   B ou Y : fermer"
			render()
			GuiService.SelectedObject = list:FindFirstChild("Objet1") :: GuiObject?
		else
			empty.Visible = false
			title.Text = "Journal   ·   L1 : sac"
			hint.Text = "Stick droit : défiler   ·   B ou Y : fermer"
			renderJournal()
			journalView.CanvasPosition = Vector2.zero
			GuiService.SelectedObject = journalView
		end
	end

	local function close()
		gui.Enabled = false
		GuiService.SelectedObject = nil
		ContextActionService:UnbindAction("SurvivorFermerSac")
		ContextActionService:UnbindAction("SurvivorOngletSac")
	end

	local function open()
		if
			player:GetAttribute("Hidden")
			or player:GetAttribute("Taken")
			or player:GetAttribute("Bound")
		then
			return
		end
		gui.Enabled = true
		setTab("bag")
		local keys = Config.controls.contexts.bag
		local function key(name: string): Enum.KeyCode
			return (Enum.KeyCode :: any)[name]
		end
		ContextActionService:BindActionAtPriority(
			"SurvivorFermerSac",
			function(_, state)
				if state == Enum.UserInputState.Begin then
					close()
				end
				return Enum.ContextActionResult.Sink
			end,
			false,
			Enum.ContextActionPriority.High.Value,
			key(keys.close.gamepad),
			key(keys.close.keyboard)
		)
		-- L1 / R1 : il n'y a que deux onglets, chacun mene a l'autre.
		ContextActionService:BindActionAtPriority(
			"SurvivorOngletSac",
			function(_, state, input)
				if state == Enum.UserInputState.Begin then
					local back = input.KeyCode == key(keys.previousTab.gamepad)
						or input.KeyCode == key(keys.previousTab.keyboard)
					setTab(if back then "bag" else "journal")
				end
				return Enum.ContextActionResult.Sink
			end,
			false,
			Enum.ContextActionPriority.High.Value,
			key(keys.previousTab.gamepad),
			key(keys.previousTab.keyboard),
			key(keys.nextTab.gamepad),
			key(keys.nextTab.keyboard)
		)
	end

	-- Y (et I au clavier) ouvre et ferme le sac : Config.controls.
	local binding = Config.controls.contexts.bag.toggle
	ContextActionService:BindAction("SurvivorSac", function(_, state)
		if state == Enum.UserInputState.Begin then
			if gui.Enabled then
				close()
			else
				open()
			end
		end
		return Enum.ContextActionResult.Sink
	end, false, (Enum.KeyCode :: any)[binding.gamepad], (Enum.KeyCode :: any)[binding.keyboard])
end

return BagPanel
