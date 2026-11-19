--!strict
--[[
	Client crawl controller:
	- Locks camera to First Person with crawl eye-height offset & bob.
	- Disables jumping and interpolates forward/strafe/reverse crawl speed.
	- Applies procedural R6 Motor6D prone crawl poses across all visible players.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local CrawlController = {}

local localPlayer = Players.LocalPlayer
local initialized = false
local bobPhase = 0

local restC0Cache = setmetatable({}, { __mode = "k" }) :: { [Motor6D]: CFrame }
local playerPhases = setmetatable({}, { __mode = "k" }) :: { [Player]: number }

local function getRestC0Rotation(motor: Motor6D): CFrame
	local cached = restC0Cache[motor]
	if cached then
		return cached
	end
	local rot = motor.C0.Rotation
	restC0Cache[motor] = rot
	return rot
end

local function applyPart0Transform(motor: Motor6D?, targetPart0CFrame: CFrame)
	if not motor then
		return
	end
	local restRot = getRestC0Rotation(motor)
	motor.Transform = restRot:Inverse() * targetPart0CFrame * restRot
end

local function enforceLocalHumanoid(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.HipHeight = GameConfig.Crawl.HipHeight
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
end

local function updateLocalMovementAndCamera(dt: number)
	local character = localPlayer.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not rootPart or humanoid.Health <= 0 then
		return
	end

	local camera = workspace.CurrentCamera
	local lookDir = if camera then camera.CFrame.LookVector else rootPart.CFrame.LookVector
	local flatLook = Vector3.new(lookDir.X, 0, lookDir.Z)
	if flatLook.Magnitude > 0.001 then
		flatLook = flatLook.Unit
	else
		flatLook = Vector3.new(0, 0, -1)
	end

	local moveDir = humanoid.MoveDirection
	local flatMove = Vector3.new(moveDir.X, 0, moveDir.Z)
	local targetSpeed = GameConfig.Crawl.ForwardWalkSpeed

	if flatMove.Magnitude > 0.05 then
		local forwardDot = flatMove.Unit:Dot(flatLook)
		if forwardDot < -0.35 then
			targetSpeed = GameConfig.Crawl.ReverseWalkSpeed
		elseif math.abs(forwardDot) <= 0.45 then
			targetSpeed = GameConfig.Crawl.StrafeWalkSpeed
		end
	end

	local speedAlpha = 1 - math.exp(-GameConfig.Crawl.SpeedLerpRate * dt)
	humanoid.WalkSpeed = humanoid.WalkSpeed + (targetSpeed - humanoid.WalkSpeed) * speedAlpha

	local vel = rootPart.AssemblyLinearVelocity
	local horizSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude
	local baseOffset = GameConfig.Crawl.BaseCameraOffset

	local targetOffset: Vector3
	if horizSpeed > 0.25 then
		local speedRatio = math.clamp(horizSpeed / GameConfig.Crawl.ForwardWalkSpeed, 0.2, 1.3)
		bobPhase += dt * GameConfig.Crawl.BobFrequency * speedRatio
		local bobX = math.cos(bobPhase) * GameConfig.Crawl.BobHorizontalAmp
		local bobY = math.abs(math.sin(bobPhase)) * GameConfig.Crawl.BobVerticalAmp
		targetOffset = baseOffset + Vector3.new(bobX, bobY, 0)
	else
		bobPhase += dt * 1.6
		local breathY = math.sin(bobPhase) * 0.015
		targetOffset = baseOffset + Vector3.new(0, breathY, 0)
	end

	local camAlpha = 1 - math.exp(-14 * dt)
	humanoid.CameraOffset = humanoid.CameraOffset:Lerp(targetOffset, camAlpha)
end

local function updateCharacterCrawlPose(player: Player, dt: number)
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local torso = character:FindFirstChild("Torso") :: BasePart?
	if not humanoid or not rootPart or not torso or humanoid.Health <= 0 then
		return
	end

	local rootJoint = rootPart:FindFirstChild("RootJoint") :: Motor6D?
	local neck = torso:FindFirstChild("Neck") :: Motor6D?
	local leftShoulder = torso:FindFirstChild("Left Shoulder") :: Motor6D?
	local rightShoulder = torso:FindFirstChild("Right Shoulder") :: Motor6D?
	local leftHip = torso:FindFirstChild("Left Hip") :: Motor6D?
	local rightHip = torso:FindFirstChild("Right Hip") :: Motor6D?

	local vel = rootPart.AssemblyLinearVelocity
	local horizVel = Vector3.new(vel.X, 0, vel.Z)
	local horizSpeed = horizVel.Magnitude

	local phase = playerPhases[player] or 0
	local isMoving = horizSpeed > 0.25
	if isMoving then
		local dirSign = if horizVel:Dot(rootPart.CFrame.LookVector) >= -0.1 then 1 else -1
		local strideScale = math.clamp(horizSpeed / GameConfig.Crawl.ForwardWalkSpeed, 0.2, 1.4)
		phase += dt * 6.5 * strideScale * dirSign
	end
	playerPhases[player] = phase

	local armSwing = if isMoving then math.sin(phase) * 28 else 0
	local legSwing = if isMoving then math.sin(phase) * 22 else 0
	local rollSway = if isMoving then math.sin(phase) * 6 else math.sin(os.clock() * 1.4) * 1.2

	-- Lay Torso prone (-82 deg pitch) and tuck backward slightly so Head clears duct walls.
	applyPart0Transform(
		rootJoint,
		CFrame.new(0, -0.35, 0.55) * CFrame.Angles(-math.rad(82), 0, math.rad(rollSway))
	)
	applyPart0Transform(neck, CFrame.Angles(math.rad(72), 0, 0))
	applyPart0Transform(leftShoulder, CFrame.Angles(math.rad(152 + armSwing), 0, math.rad(-10)))
	applyPart0Transform(rightShoulder, CFrame.Angles(math.rad(152 - armSwing), 0, math.rad(10)))
	applyPart0Transform(leftHip, CFrame.Angles(math.rad(-14 - legSwing), 0, math.rad(-7)))
	applyPart0Transform(rightHip, CFrame.Angles(math.rad(-14 + legSwing), 0, math.rad(7)))
end

function CrawlController.init()
	if initialized then
		return
	end
	initialized = true

	localPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
	localPlayer.CameraMinZoomDistance = 0.5
	localPlayer.CameraMaxZoomDistance = 0.5

	localPlayer.CharacterAdded:Connect(enforceLocalHumanoid)
	if localPlayer.Character then
		task.spawn(enforceLocalHumanoid, localPlayer.Character)
	end

	RunService.RenderStepped:Connect(function(dt: number)
		updateLocalMovementAndCamera(dt)
	end)

	if GameConfig.Crawl.CustomCrawlAnimationId == "" then
		RunService.Stepped:Connect(function(_time: number, dt: number)
			for _, player in ipairs(Players:GetPlayers()) do
				updateCharacterCrawlPose(player, dt)
			end
		end)
	end
end

return CrawlController
