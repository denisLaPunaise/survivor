--!strict
--[[
	Controls — courir, s'accroupir, glisser, sortir de cachette.

	Les boutons viennent de `Config.controls` et de nulle part ailleurs. La
	manette decide : chaque action se branche sur son bouton ET sa touche par
	ContextActionService, qui rend les deux equivalents.

	La vitesse se calcule ici (le personnage appartient a son client dans
	Roblox) a partir de l'attribut `SpeedFactor` que le serveur pose selon le
	poids du sac.

	La glissade passe par un LinearVelocity, limite de force coupee :
	l'Humanoid mange les coups de vitesse horizontaux (lecon d'Arena).
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Survivor = ReplicatedStorage:WaitForChild("Survivor")
local Config = require(Survivor:WaitForChild("Config"))
local Remotes = Survivor:WaitForChild("Remotes")

local Controls = {}

local player = Players.LocalPlayer
local leaveHiding = Remotes:WaitForChild("LeaveHiding") :: RemoteEvent

local sprinting = false
local crouching = false
local slidingUntil = 0
local lastSlide = -math.huge

local function inputsFor(binding: { gamepad: string, keyboard: string }): { any }
	local out: { any } = { (Enum.KeyCode :: any)[binding.gamepad] }
	local keyboard = binding.keyboard
	if keyboard == "MouseButton1" or keyboard == "MouseButton2" then
		table.insert(out, (Enum.UserInputType :: any)[keyboard])
	else
		table.insert(out, (Enum.KeyCode :: any)[keyboard])
	end
	return out
end

local function humanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function refresh()
	local h = humanoid()
	if h == nil then
		return
	end
	local m = Config.movement
	local factor = player:GetAttribute("SpeedFactor")
	local scale = if typeof(factor) == "number" then factor else 1
	local base = if crouching then m.crouchSpeed elseif sprinting then m.sprintSpeed else m.walkSpeed
	h.WalkSpeed = base * scale
	h.CameraOffset = Vector3.new(0, if crouching then m.crouchCameraOffset else 0, 0)
end

local function slide()
	local m = Config.movement
	local now = os.clock()
	local h = humanoid()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if h == nil or root == nil or not root:IsA("BasePart") then
		return
	end
	if now - lastSlide < m.slideCooldownSeconds or h.MoveDirection.Magnitude < 0.1 then
		return
	end
	lastSlide = now
	slidingUntil = now + m.slideSeconds
	crouching = true
	refresh()

	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local push = Instance.new("LinearVelocity")
	push.Attachment0 = attachment
	push.ForceLimitsEnabled = false
	push.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	push.PrimaryTangentAxis = Vector3.xAxis
	push.SecondaryTangentAxis = Vector3.zAxis
	local direction = h.MoveDirection.Unit * m.slideSpeed
	push.PlaneVelocity = Vector2.new(direction.X, direction.Z)
	push.RelativeTo = Enum.ActuatorRelativeTo.World
	push.Parent = root
	task.delay(m.slideSeconds, function()
		push:Destroy()
		attachment:Destroy()
	end)
end

local function bind(
	name: string,
	binding: { gamepad: string, keyboard: string },
	handler: (Enum.UserInputState, boolean) -> ()
)
	ContextActionService:BindAction(
		name,
		function(_, state: Enum.UserInputState, input: InputObject)
			local fromGamepad = string.find(input.UserInputType.Name, "Gamepad") ~= nil
			handler(state, fromGamepad)
			return Enum.ContextActionResult.Sink
		end,
		false,
		table.unpack(inputsFor(binding))
	)
end

local function bindOnFoot()
	local onFoot = Config.controls.contexts.onFoot
	bind("SurvivorSprint", onFoot.sprint, function(state, fromGamepad)
		-- A la manette, L3 se maintient mal en bougeant le stick : un appui
		-- bascule la course. Au clavier, on la maintient.
		if fromGamepad then
			if state == Enum.UserInputState.Begin then
				sprinting = not sprinting
			end
		else
			sprinting = state == Enum.UserInputState.Begin
		end
		if sprinting then
			crouching = false
		end
		refresh()
	end)
	bind("SurvivorCrouch", onFoot.crouchOrSlide, function(state)
		if state ~= Enum.UserInputState.Begin then
			return
		end
		if sprinting and not crouching then
			sprinting = false
			slide()
			return
		end
		crouching = not crouching
		refresh()
	end)
end

local function unbindOnFoot()
	ContextActionService:UnbindAction("SurvivorSprint")
	ContextActionService:UnbindAction("SurvivorCrouch")
end

local function onHiddenChanged()
	if player:GetAttribute("Hidden") then
		unbindOnFoot()
		bind("SurvivorLeave", Config.controls.contexts.hidden.leave, function(state)
			if state == Enum.UserInputState.Begin then
				leaveHiding:FireServer()
			end
		end)
	else
		ContextActionService:UnbindAction("SurvivorLeave")
		bindOnFoot()
	end
end

function Controls.start()
	player:GetAttributeChangedSignal("SpeedFactor"):Connect(refresh)
	player:GetAttributeChangedSignal("Hidden"):Connect(onHiddenChanged)
	player.CharacterAdded:Connect(function()
		sprinting = false
		crouching = false
		task.defer(refresh)
	end)
	bindOnFoot()
	refresh()

	-- Fin de glissade : on reste accroupi, comme apres une vraie glissade.
	game:GetService("RunService").Heartbeat:Connect(function()
		if slidingUntil > 0 and os.clock() >= slidingUntil then
			slidingUntil = 0
			refresh()
		end
	end)
end

return Controls
