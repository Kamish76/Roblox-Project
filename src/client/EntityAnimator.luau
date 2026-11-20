--!strict
--[[
	Client-side 60 FPS Procedural Skinned-Mesh Animator for The Joint-Cracker:
	- Bone.Transform does not replicate from Server to Client in Roblox, so all 23 bones
	  are animated locally on RenderStepped from lightweight replicated attributes:
	    EntityState ("Patrol" | "Stalk" | "Lurk" | "Retreat" | "Chase")
	    MoveSpeed (number, studs/sec)
	    LurkSideSign (-1 | 1)
	    LurkTargetPos (Vector3)
	- Uses axis-independent monster-space rotation (cached from each bone's rest WorldCFrame
	  relative to RootPart) so pitch/yaw/roll are 100% immune to Blender bone-roll quirks.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EntityProfiles = require(Shared:WaitForChild("EntityProfiles"))

local EntityAnimator = {}

local AXIS_RIGHT = Vector3.new(1, 0, 0) -- +X: +rot pitches nose UP, -rot pitches nose DOWN / opens jaw
local AXIS_UP = Vector3.new(0, 1, 0) -- +Y: +rot yaws LEFT, -rot yaws RIGHT
local AXIS_BACK = Vector3.new(0, 0, 1) -- +Z: +rot rolls top-of-head LEFT, -rot rolls top-of-head RIGHT

local activeProfile = EntityProfiles.getActiveProfile()
local initialized = false

local trackedModel: Model? = nil
local rootPart: BasePart? = nil
local bones: { [string]: Bone } = {}
local restRotInRoot: { [string]: CFrame } = {}
local currentTransforms: { [string]: CFrame } = {}
local targetTransforms: { [string]: CFrame } = {}

local stridePhase = 0
local lurkElapsed = 0
local lastState = "Patrol"

-- Periodic "Joint-Crack" sudden head-snap state
local nextCrackTime = 0
local crackTargetRoll = 0
local crackCurrentRoll = 0

local function rotAround(boneName: string, monsterAxis: Vector3, angleRad: number): CFrame
	local restRot = restRotInRoot[boneName]
	if not restRot or math.abs(angleRad) < 1e-5 then
		return CFrame.identity
	end
	local localAxis = restRot:VectorToObjectSpace(monsterAxis)
	if localAxis.Magnitude < 1e-5 then
		return CFrame.identity
	end
	return CFrame.fromAxisAngle(localAxis.Unit, angleRad)
end

-- Compose pitch (X), yaw (Y), roll (Z) in monster space cleanly onto a bone
local function composeBone(boneName: string, pitchRad: number, yawRad: number, rollRad: number, offsetMonster: Vector3?): CFrame
	local rot = rotAround(boneName, AXIS_UP, yawRad)
		* rotAround(boneName, AXIS_RIGHT, pitchRad)
		* rotAround(boneName, AXIS_BACK, rollRad)

	if offsetMonster and offsetMonster.Magnitude > 1e-5 then
		local restRot = restRotInRoot[boneName]
		if restRot then
			local localOffset = restRot:VectorToObjectSpace(offsetMonster)
			return CFrame.new(localOffset) * rot
		end
	end
	return rot
end

local function bindEntityModel(model: Model)
	if trackedModel == model then
		return
	end

	table.clear(bones)
	table.clear(restRotInRoot)
	table.clear(currentTransforms)
	table.clear(targetTransforms)
	trackedModel = nil
	rootPart = nil

	local root = model:FindFirstChild("RootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	-- Reset any transforms to identity before sampling rest-pose orientation
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Bone") then
			d.Transform = CFrame.identity
			bones[d.Name] = d
		end
	end

	if not bones["Pelvis"] or not bones["Head"] then
		return
	end

	-- Cache each bone's rest-pose rotation relative to RootPart
	local rootCF = root.CFrame
	for name, b in pairs(bones) do
		restRotInRoot[name] = rootCF:ToObjectSpace(b.WorldCFrame).Rotation
		currentTransforms[name] = CFrame.identity
		targetTransforms[name] = CFrame.identity
	end

	trackedModel = model
	rootPart = root
	stridePhase = 0
	lurkElapsed = 0
	nextCrackTime = os.clock() + 2.5
end

local function findAndBindEntity()
	local ventMap = workspace:FindFirstChild("VentMap")
	if not ventMap then
		return
	end
	local entity = ventMap:FindFirstChild(activeProfile.id)
	if entity and entity:IsA("Model") then
		bindEntityModel(entity)
	end
end

local function setTarget(name: string, pitchDeg: number, yawDeg: number, rollDeg: number, offsetMonster: Vector3?)
	if bones[name] then
		targetTransforms[name] = composeBone(
			name,
			math.rad(pitchDeg),
			math.rad(yawDeg),
			math.rad(rollDeg),
			offsetMonster
		)
	end
end

-- Diagonal spider/quadruped crawl limb pose helper
local function applyCrawlLimbs(phase: number, amp: number, speedScale: number, crouched: boolean)
	-- Diagonal pairs: (Arm.L + Leg.R) vs (Arm.R + Leg.L)
	local pL = phase
	local pR = phase + math.pi

	local sL, cL = math.sin(pL), math.cos(pL)
	local sR, cR = math.sin(pR), math.cos(pR)

	-- Lift only during forward swing (positive cos half-cycle)
	local liftL = math.max(0, cL) * amp
	local liftR = math.max(0, cR) * amp

	local crouchElbow = if crouched then 12 else 0
	local reach = (24 + speedScale * 10) * amp
	local liftDeg = (18 + speedScale * 8)

	-- Front Arms (Left = -X in Roblox? Note: in our Blender->FBX rig, L is +X side, R is -X side)
	setTarget("Clavicle.L", 0, -sL * 8 * amp, liftL * 6)
	setTarget("UpperArm.L", sL * reach * 0.45, -sL * reach, (liftL * liftDeg) + crouchElbow)
	setTarget("Forearm.L", sL * reach * 0.75 + liftL * 16, 0, -liftL * 10)
	setTarget("Hand.L", -liftL * 28, 0, 0)

	setTarget("Clavicle.R", 0, sR * 8 * amp, -liftR * 6)
	setTarget("UpperArm.R", sR * reach * 0.45, sR * reach, -(liftR * liftDeg) - crouchElbow)
	setTarget("Forearm.R", sR * reach * 0.75 + liftR * 16, 0, liftR * 10)
	setTarget("Hand.R", -liftR * 28, 0, 0)

	-- Back Legs (diagonal opposite: Leg.L pairs with Arm.R, Leg.R pairs with Arm.L)
	local legReach = (22 + speedScale * 9) * amp
	setTarget("Thigh.L", sR * legReach * 0.5, -sR * legReach * 0.85, liftR * 16)
	setTarget("Shin.L", -sR * legReach * 0.7 - liftR * 18, 0, 0)
	setTarget("Foot.L", liftR * 24, 0, 0)

	setTarget("Thigh.R", sL * legReach * 0.5, sL * legReach * 0.85, -liftL * 16)
	setTarget("Shin.R", -sL * legReach * 0.7 - liftL * 18, 0, 0)
	setTarget("Foot.R", liftL * 24, 0, 0)
end

local function updateAnimation(dt: number)
	if not trackedModel or not trackedModel.Parent or not rootPart then
		findAndBindEntity()
		return
	end

	local now = os.clock()
	local state = (trackedModel:GetAttribute("EntityState") :: string?) or "Patrol"
	local moveSpeed = (trackedModel:GetAttribute("MoveSpeed") :: number?) or 0
	local lurkSide = (trackedModel:GetAttribute("LurkSideSign") :: number?) or 1
	local lurkTarget = trackedModel:GetAttribute("LurkTargetPos") :: Vector3?

	if state ~= lastState then
		if state == "Lurk" then
			lurkElapsed = 0
		end
		lastState = state
	end

	-- Periodic sudden "Joint-Crack" neck snap (signature monster tell!)
	if now >= nextCrackTime then
		nextCrackTime = now + 2.2 + math.random() * 2.4
		if math.abs(crackTargetRoll) > 5 then
			crackTargetRoll = 0
		else
			crackTargetRoll = (if math.random() > 0.5 then 1 else -1) * (18 + math.random() * 14)
		end
	end
	-- Fast snap toward crackTargetRoll (feels like a dry bone pop!)
	local crackAlpha = 1 - math.exp(-26 * dt)
	crackCurrentRoll += (crackTargetRoll - crackCurrentRoll) * crackAlpha

	-- Clear defaults to identity each frame
	for name in pairs(bones) do
		targetTransforms[name] = CFrame.identity
	end

	local blendRate = 11.0

	if state == "Lurk" then
		-- =====================================================================
		-- LURK CORNER-PEEK MONEY SHOT:
		-- Body tucked behind corner; spine/neck twist around the edge,
		-- head snaps ~62 deg sideways staring at player, jaw slowly unhinges!
		-- =====================================================================
		lurkElapsed += dt
		blendRate = 7.5
		local breath = math.sin(now * 2.4)
		local shiver = math.sin(now * 17.0) * 1.4

		-- Compute subtle extra yaw/pitch toward player's actual head position
		local aimYawDeg = 0
		local aimPitchDeg = 0
		if lurkTarget and lurkTarget.Magnitude > 0.1 then
			local localTarget = rootPart.CFrame:PointToObjectSpace(lurkTarget)
			aimYawDeg = math.clamp(math.deg(math.atan2(-localTarget.X, -localTarget.Z)), -35, 35)
			aimPitchDeg = math.clamp(math.deg(math.atan2(localTarget.Y - 2.1, math.max(1, -localTarget.Z))), -20, 20)
		end

		local s = lurkSide
		-- Pelvis drops low & tucks back
		setTarget("Pelvis", -6, -8 * s, 0, Vector3.new(0, -0.18 + breath * 0.03, 0.12))
		setTarget("Spine1", -4, 10 * s, 6 * s)
		setTarget("Spine2", -6, 16 * s, 10 * s)
		setTarget("Chest",  -5 + breath * 2, 18 * s, 12 * s)

		-- Cracked sideways neck leaning around the corner
		setTarget("Neck1",  6 + aimPitchDeg * 0.3, 18 * s + aimYawDeg * 0.35, 22 * s)
		setTarget("Neck2",  4 + aimPitchDeg * 0.3, 14 * s + aimYawDeg * 0.35, 24 * s)
		setTarget("Head",   -6 + aimPitchDeg * 0.4, aimYawDeg * 0.3, (20 * s) + breath * 3 + shiver)

		-- Jaw slowly unhinges wider the longer it lurks (12 -> 32 deg!)
		local jawOpen = math.min(32, 12 + lurkElapsed * 4.5) + math.sin(now * 3.8) * 2.5
		setTarget("Jaw", -jawOpen, 0, shiver * 0.5)

		-- Corner-side arm reaches forward & up to grip the duct edge; other limbs stay tucked
		if s > 0 then
			setTarget("Clavicle.R", 0, -14, 0)
			setTarget("UpperArm.R", 18, 28, -24)
			setTarget("Forearm.R",  34, 0, 12)
			setTarget("Hand.R",     -20, 0, 0)
			setTarget("UpperArm.L", -14, -18, 12)
			setTarget("Forearm.L",  -16, 0, 0)
		else
			setTarget("Clavicle.L", 0, 14, 0)
			setTarget("UpperArm.L", 18, -28, 24)
			setTarget("Forearm.L",  34, 0, -12)
			setTarget("Hand.L",     -20, 0, 0)
			setTarget("UpperArm.R", -14, 18, -12)
			setTarget("Forearm.R",  -16, 0, 0)
		end

		setTarget("Thigh.L", -12, 10, 6)
		setTarget("Shin.L",  14, 0, 0)
		setTarget("Thigh.R", -12, -10, -6)
		setTarget("Shin.R",  14, 0, 0)

	elseif state == "Chase" then
		-- =====================================================================
		-- CHASE: Violent high-speed nightmare scuttle + screaming unhinged jaw!
		-- =====================================================================
		blendRate = 18.0
		local speedNorm = math.clamp(moveSpeed / 8.0, 0.7, 1.8)
		stridePhase += dt * (11.5 * speedNorm)
		local s = math.sin(stridePhase)
		local c = math.cos(stridePhase)
		local jitter = math.sin(now * 29.0) * 3.5

		setTarget("Pelvis", 4 * c, 6 * s, 5 * s, Vector3.new(0, -0.10 + math.abs(s) * 0.14, 0))
		setTarget("Spine1", 6 * s, -8 * s, -4 * s)
		setTarget("Spine2", 8 * c, 10 * s, 5 * s)
		setTarget("Chest",  -6 * s, -8 * s, -4 * s)

		-- Head locked aggressively forward, jittering violently, jaw WIDE open
		setTarget("Neck1",  -8, 4 * s, jitter * 0.5)
		setTarget("Neck2",  -6, -4 * s, -jitter * 0.5)
		setTarget("Head",   10, jitter * 0.6, math.sin(now * 9.0) * 10 + jitter)
		setTarget("Jaw",    -(30 + math.sin(now * 18.0) * 6), 0, jitter * 0.4)

		applyCrawlLimbs(stridePhase, 1.15, 1.3, true)

	elseif state == "Retreat" then
		-- =====================================================================
		-- RETREAT: Startled recoil flinch + rapid pullback scuttle
		-- =====================================================================
		blendRate = 15.0
		local speedNorm = math.clamp(moveSpeed / 7.0, 0.5, 1.5)
		stridePhase += dt * (9.5 * speedNorm)
		local s = math.sin(stridePhase)

		setTarget("Pelvis", -8, 6 * s, 4 * s, Vector3.new(0, -0.16, 0))
		setTarget("Spine1", -5, -7 * s, 0)
		setTarget("Spine2", -6, 7 * s, 0)
		setTarget("Chest",  -8, -5 * s, 0)
		setTarget("Neck1",  12, 0, -14)
		setTarget("Neck2",  8, 0, -10)
		setTarget("Head",   -12, 0, 18)
		setTarget("Jaw",    -14, 0, 0)

		applyCrawlLimbs(stridePhase, 0.95, 1.0, true)

	else
		-- =====================================================================
		-- PATROL & STALK: Heavy deliberate spider-crawl + joint-crack head snaps!
		-- =====================================================================
		local isStalk = (state == "Stalk")
		local moving = moveSpeed > 0.25
		local speedNorm = math.clamp(moveSpeed / 5.5, 0.0, 1.4)
		if moving then
			stridePhase += dt * (if isStalk then 6.2 * speedNorm else 5.2 * speedNorm)
		end

		local amp = if moving then math.clamp(speedNorm, 0.35, 1.0) else 0.0
		local s = math.sin(stridePhase) * amp
		local c = math.cos(stridePhase) * amp
		local breath = math.sin(now * 2.2)

		local crouchDrop = if isStalk then -0.18 else -0.05
		local strideLift = math.abs(s) * 0.08
		setTarget("Pelvis", 2 * c, 5 * s, 3 * s, Vector3.new(0, crouchDrop + strideLift + breath * 0.02, 0))
		setTarget("Spine1", 3 * s, -7 * s, -3 * s)
		setTarget("Spine2", 4 * c + breath * 2, 8 * s, 4 * s)
		setTarget("Chest",  (if isStalk then -8 else -3 * s), -6 * s, -3 * s)

		-- Uncanny periodic joint-crack sideways head snaps!
		local neckPitch = if isStalk then -8 else -2
		setTarget("Neck1", neckPitch, 4 * s, crackCurrentRoll * 0.35)
		setTarget("Neck2", neckPitch * 0.5, -3 * s, crackCurrentRoll * 0.45)
		setTarget("Head",  (if isStalk then 10 else 4) + breath * 2, 0, crackCurrentRoll * 0.65)

		-- Subtle jaw clicking in Patrol, slightly open hungry gape in Stalk
		local jawAngle = if isStalk
			then 12 + math.sin(now * 3.6) * 4
			else 4 + math.max(0, math.sin(now * 4.5)) * 5
		setTarget("Jaw", -jawAngle, 0, 0)

		applyCrawlLimbs(stridePhase, amp, speedNorm * 0.7, isStalk)
	end

	-- Smooth exponential slerp on every bone (zero popping between states!)
	local alpha = 1 - math.exp(-blendRate * dt)
	for name, b in pairs(bones) do
		local cur = currentTransforms[name] or CFrame.identity
		local tgt = targetTransforms[name] or CFrame.identity
		local nextCF = cur:Lerp(tgt, alpha)
		currentTransforms[name] = nextCF
		b.Transform = nextCF
	end
end

function EntityAnimator.init()
	if initialized then
		return
	end
	initialized = true

	findAndBindEntity()

	local ventMap = workspace:FindFirstChild("VentMap")
	if ventMap then
		ventMap.ChildAdded:Connect(function(child)
			if child.Name == activeProfile.id and child:IsA("Model") then
				task.defer(function()
					bindEntityModel(child)
				end)
			end
		end)
	end

	RunService.RenderStepped:Connect(updateAnimation)
end

return EntityAnimator
