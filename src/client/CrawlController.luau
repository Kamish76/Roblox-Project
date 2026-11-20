--!strict
--[[
	Client crawl & Safe Room stance controller:
	- Locks camera to First Person with stance-aware eye-height offset, bob & fast-crawl FOV surge.
	- Disables jumping; switches WalkSpeed between Safe Room standing, directional crawl, and LeftShift fast-crawl.
	- Manages stamina drain/regen/exhaustion lockout for fast-crawling.
	- Applies procedural R6 Motor6D standing/walking or prone crawl/scramble poses across all visible players.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local NetContracts = require(Shared:WaitForChild("NetContracts"))

local CrawlController = {}

local localPlayer = Players.LocalPlayer
local initialized = false
local bobPhase = 0

local staminaRatio = 1.0
local exhausted = false
local lastFastCrawlTime = 0
local isFastCrawlingNow = false

local restC0Cache = setmetatable({}, { __mode = "k" }) :: { [Motor6D]: CFrame }
local playerPhases = setmetatable({}, { __mode = "k" }) :: { [Player]: number }

function CrawlController.isFastCrawling(): boolean
	return isFastCrawlingNow
end

function CrawlController.getStaminaRatio(): number
	return staminaRatio
end

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

local function isPlayerCrawling(player: Player): boolean
	return player:GetAttribute(NetContracts.Attributes.IsCrawling) == true
end

local function applyStancePhysics(humanoid: Humanoid, crawling: boolean)
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)

	if crawling then
		humanoid.HipHeight = GameConfig.Crawl.HipHeight
	else
		humanoid.HipHeight = GameConfig.SafeRoom.StandingHipHeight
	end
end

local function enforceLocalHumanoid(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	applyStancePhysics(humanoid, isPlayerCrawling(localPlayer))
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

	local crawling = isPlayerCrawling(localPlayer)
	local expectedHip = if crawling then GameConfig.Crawl.HipHeight else GameConfig.SafeRoom.StandingHipHeight
	if math.abs(humanoid.HipHeight - expectedHip) > 0.01 then
		applyStancePhysics(humanoid, crawling)
	end

	local now = os.clock()
	local moveDir = humanoid.MoveDirection
	local flatMove = Vector3.new(moveDir.X, 0, moveDir.Z)
	local isTryingToMove = flatMove.Magnitude > 0.05
	local wantsFastCrawl = crawling
		and isTryingToMove
		and UserInputService:IsKeyDown(GameConfig.Crawl.FastCrawlKey)
		and not UserInputService:GetFocusedTextBox()

	if not crawling then
		isFastCrawlingNow = false
		exhausted = false
		staminaRatio = math.min(1.0, staminaRatio + GameConfig.Crawl.StaminaRegenRate * 2.0 * dt)
	elseif wantsFastCrawl and not exhausted and staminaRatio > 0 then
		isFastCrawlingNow = true
		lastFastCrawlTime = now
		staminaRatio = math.max(0, staminaRatio - GameConfig.Crawl.StaminaDrainRate * dt)
		if staminaRatio <= 0.001 then
			staminaRatio = 0
			exhausted = true
			isFastCrawlingNow = false
		end
	else
		isFastCrawlingNow = false
		if now - lastFastCrawlTime >= GameConfig.Crawl.StaminaRegenDelay then
			staminaRatio = math.min(1.0, staminaRatio + GameConfig.Crawl.StaminaRegenRate * dt)
			if exhausted and staminaRatio >= GameConfig.Crawl.StaminaResumeThreshold then
				exhausted = false
			end
		end
	end

	local prevFast = localPlayer:GetAttribute(NetContracts.Attributes.IsFastCrawling) == true
	if prevFast ~= isFastCrawlingNow then
		localPlayer:SetAttribute(NetContracts.Attributes.IsFastCrawling, isFastCrawlingNow)
	end
	local prevStamina = (localPlayer:GetAttribute(NetContracts.Attributes.StaminaRatio) :: number?) or 1
	if math.abs(prevStamina - staminaRatio) >= 0.01 or (staminaRatio == 1 and prevStamina ~= 1) then
		localPlayer:SetAttribute(NetContracts.Attributes.StaminaRatio, staminaRatio)
	end

	local camera = workspace.CurrentCamera
	local targetSpeed = GameConfig.SafeRoom.WalkSpeed
	if crawling then
		local lookDir = if camera then camera.CFrame.LookVector else rootPart.CFrame.LookVector
		local flatLook = Vector3.new(lookDir.X, 0, lookDir.Z)
		if flatLook.Magnitude > 0.001 then
			flatLook = flatLook.Unit
		else
			flatLook = Vector3.new(0, 0, -1)
		end

		local fwdSpeed = if isFastCrawlingNow
			then GameConfig.Crawl.FastForwardWalkSpeed
			else GameConfig.Crawl.ForwardWalkSpeed
		local strafeSpeed = if isFastCrawlingNow
			then GameConfig.Crawl.FastStrafeWalkSpeed
			else GameConfig.Crawl.StrafeWalkSpeed
		local revSpeed = if isFastCrawlingNow
			then GameConfig.Crawl.FastReverseWalkSpeed
			else GameConfig.Crawl.ReverseWalkSpeed

		targetSpeed = fwdSpeed
		if isTryingToMove then
			local forwardDot = flatMove.Unit:Dot(flatLook)
			if forwardDot < -0.35 then
				targetSpeed = revSpeed
			elseif math.abs(forwardDot) <= 0.45 then
				targetSpeed = strafeSpeed
			end
		end
	end

	local speedAlpha = 1 - math.exp(-GameConfig.Crawl.SpeedLerpRate * dt)
	humanoid.WalkSpeed = humanoid.WalkSpeed + (targetSpeed - humanoid.WalkSpeed) * speedAlpha

	-- Subtle FOV surge when scrambling so fast-crawling feels urgent
	if camera then
		local targetFov = if isFastCrawlingNow
			then GameConfig.Crawl.BaseFov + GameConfig.Crawl.FastFovBoost
			else GameConfig.Crawl.BaseFov
		local fovAlpha = 1 - math.exp(-8 * dt)
		camera.FieldOfView = camera.FieldOfView + (targetFov - camera.FieldOfView) * fovAlpha
	end

	local vel = rootPart.AssemblyLinearVelocity
	local horizSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude
	local baseOffset = if crawling then GameConfig.Crawl.BaseCameraOffset else GameConfig.SafeRoom.BaseCameraOffset

	local targetOffset: Vector3
	if crawling then
		if horizSpeed > 0.25 then
			local speedRatio = math.clamp(horizSpeed / GameConfig.Crawl.ForwardWalkSpeed, 0.2, 1.8)
			local bobBoost = if isFastCrawlingNow then GameConfig.Crawl.FastBobMultiplier else 1.0
			bobPhase += dt * GameConfig.Crawl.BobFrequency * speedRatio
			local bobX = math.cos(bobPhase) * GameConfig.Crawl.BobHorizontalAmp * bobBoost
			local bobY = math.abs(math.sin(bobPhase)) * GameConfig.Crawl.BobVerticalAmp * bobBoost
			targetOffset = baseOffset + Vector3.new(bobX, bobY, 0)
		else
			bobPhase += dt * 1.6
			local breathY = math.sin(bobPhase) * 0.015
			targetOffset = baseOffset + Vector3.new(0, breathY, 0)
		end
	else
		if horizSpeed > 0.35 then
			local speedRatio = math.clamp(horizSpeed / GameConfig.SafeRoom.WalkSpeed, 0.2, 1.2)
			bobPhase += dt * 7.5 * speedRatio
			local bobY = math.abs(math.sin(bobPhase)) * 0.05
			targetOffset = baseOffset + Vector3.new(0, bobY, 0)
		else
			targetOffset = baseOffset
		end
	end

	local camAlpha = 1 - math.exp(-14 * dt)
	humanoid.CameraOffset = humanoid.CameraOffset:Lerp(targetOffset, camAlpha)
end

local function updateCharacterPose(player: Player, dt: number)
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
	local crawling = isPlayerCrawling(player)

	local phase = playerPhases[player] or 0
	local isMoving = horizSpeed > 0.25

	if crawling then
		if isMoving then
			local dirSign = if horizVel:Dot(rootPart.CFrame.LookVector) >= -0.1 then 1 else -1
			local strideScale = math.clamp(horizSpeed / GameConfig.Crawl.ForwardWalkSpeed, 0.2, 1.9)
			phase += dt * 6.5 * strideScale * dirSign
		end
		playerPhases[player] = phase

		local scrambleAmp = if horizSpeed > GameConfig.Crawl.ForwardWalkSpeed + 1.0 then 1.25 else 1.0
		local armSwing = if isMoving then math.sin(phase) * 28 * scrambleAmp else 0
		local legSwing = if isMoving then math.sin(phase) * 22 * scrambleAmp else 0
		local rollSway = if isMoving then math.sin(phase) * 6 * scrambleAmp else math.sin(os.clock() * 1.4) * 1.2

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
	else
		if isMoving then
			local dirSign = if horizVel:Dot(rootPart.CFrame.LookVector) >= -0.1 then 1 else -1
			local strideScale = math.clamp(horizSpeed / GameConfig.SafeRoom.WalkSpeed, 0.2, 1.3)
			phase += dt * 8.0 * strideScale * dirSign
		end
		playerPhases[player] = phase

		local stride = if isMoving then math.sin(phase) * 26 else 0
		applyPart0Transform(rootJoint, CFrame.identity)
		applyPart0Transform(neck, CFrame.identity)
		applyPart0Transform(leftShoulder, CFrame.Angles(math.rad(stride), 0, math.rad(-4)))
		applyPart0Transform(rightShoulder, CFrame.Angles(math.rad(-stride), 0, math.rad(4)))
		applyPart0Transform(leftHip, CFrame.Angles(math.rad(-stride), 0, 0))
		applyPart0Transform(rightHip, CFrame.Angles(math.rad(stride), 0, 0))
	end
end

local function syncCameraMode()
	local isLobby = ReplicatedStorage:GetAttribute(NetContracts.Attributes.ServerMode) == "Lobby"
	if isLobby then
		localPlayer.CameraMode = Enum.CameraMode.Classic
		localPlayer.CameraMinZoomDistance = 4
		localPlayer.CameraMaxZoomDistance = 10
	else
		localPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
		localPlayer.CameraMinZoomDistance = 0.5
		localPlayer.CameraMaxZoomDistance = 0.5
	end
end

function CrawlController.init()
	if initialized then
		return
	end
	initialized = true

	syncCameraMode()
	ReplicatedStorage:GetAttributeChangedSignal(NetContracts.Attributes.ServerMode):Connect(syncCameraMode)

	localPlayer.CharacterAdded:Connect(enforceLocalHumanoid)
	if localPlayer.Character then
		task.spawn(enforceLocalHumanoid, localPlayer.Character)
	end

	localPlayer:GetAttributeChangedSignal(NetContracts.Attributes.IsCrawling):Connect(function()
		local char = localPlayer.Character
		local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
		if hum then
			applyStancePhysics(hum, isPlayerCrawling(localPlayer))
		end
	end)

	RunService.RenderStepped:Connect(function(dt: number)
		updateLocalMovementAndCamera(dt)
	end)

	if GameConfig.Crawl.CustomCrawlAnimationId == "" then
		RunService.Stepped:Connect(function(_time: number, dt: number)
			for _, player in ipairs(Players:GetPlayers()) do
				updateCharacterPose(player, dt)
			end
		end)
	end
end

return CrawlController
