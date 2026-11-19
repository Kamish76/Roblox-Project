--!strict
--[[
	Server-authoritative Tile-Graph Entity AI (ADR-003, ADR-004, ADR-006) & Panic loop:
	- Drives The Joint-Cracker across MapLayout BFS paths (offset-safe to Studio VentMap).
	- Two-layer detection: raycast LOS (passive dark vs HeadlampOn beam) + noise alerts.
	- Tracks per-player Stale Air / PanicRatio and triggers gasps in dark stillness.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EntityProfiles = require(Shared:WaitForChild("EntityProfiles"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local MapLayout = require(Shared:WaitForChild("MapLayout"))
local NetContracts = require(Shared:WaitForChild("NetContracts"))

export type AIState = "Patrol" | "Investigate" | "Chase"

local EntityService = {}

local activeProfile = EntityProfiles.getActiveProfile()
local entityModel: Model
local entityCore: Part
local entityHead: Part

local mapOffset = Vector3.zero
local currentTileKey = GameConfig.Entity.SpawnTileKey
local aiState: AIState = "Patrol"
local pathQueue: { string } = {}
local pathIndex = 1
local targetPlayer: Player? = nil
local investigateTimer = 0

local lastDetectionTime = 0
local lastPanicTime = 0
local lastGaspTimes: { [Player]: number } = {}
local lastNoiseTimes: { [Player]: number } = {}
local initialized = false

local noiseRemote: RemoteEvent
local panicSyncRemote: RemoteEvent
local eliminatedRemote: RemoteEvent
local onPlayerEliminatedCallback: ((player: Player) -> ())? = nil

local function computeMapOffset()
	local ventMap = workspace:FindFirstChild("VentMap")
	local tiles = if ventMap then ventMap:FindFirstChild("VentTiles") else nil
	local dropTile = if tiles then tiles:FindFirstChild("Tile_0_0") else nil
	local floor = if dropTile then dropTile:FindFirstChild("Floor") else nil
	if floor and floor:IsA("BasePart") then
		local canonicalFloorY = MapLayout.FLOOR_Y - GameConfig.VentKit.WallThickness / 2
		mapOffset = floor.Position - Vector3.new(0, canonicalFloorY, 0)
	else
		mapOffset = Vector3.zero
	end
end

function EntityService.tileKeyToWorld(tileKey: string): Vector3
	local tile = MapLayout.getTileByKey(tileKey)
	if not tile then
		return mapOffset + Vector3.new(0, MapLayout.FLOOR_Y + 1.35, 0)
	end
	local canonical = MapLayout.tileToWorld(tile.gx, tile.gz)
	return canonical + mapOffset + Vector3.new(0, 1.35, 0)
end

function EntityService.worldToTileKey(worldPos: Vector3): string
	local localPos = worldPos - mapOffset
	local gx, gz = MapLayout.worldToTile(localPos)
	local k = MapLayout.key(gx, gz)
	if MapLayout.getTileByKey(k) then
		return k
	end
	return currentTileKey
end

local function createEntityRig(parentMap: Instance): Model
	local existing = parentMap:FindFirstChild(activeProfile.id)
	if existing and existing:IsA("Model") then
		existing:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = activeProfile.id
	model:SetAttribute("EntityId", activeProfile.id)
	model:SetAttribute("EntityState", aiState)

	local function part(name: string, size: Vector3, color: Color3, mat: Enum.Material): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = mat
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CollisionGroup = NetContracts.CollisionGroups.Entity
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end

	local paleSkin = Color3.fromRGB(162, 158, 152)
	local darkJoint = Color3.fromRGB(72, 68, 66)

	local core = part("Core", Vector3.new(1.2, 0.85, 2.0), paleSkin, Enum.Material.SmoothPlastic)
	local head = part("Head", Vector3.new(0.85, 0.85, 0.9), paleSkin, Enum.Material.SmoothPlastic)
	part("EyeL", Vector3.new(0.12, 0.08, 0.08), Color3.fromRGB(255, 225, 95), Enum.Material.Neon)
	part("EyeR", Vector3.new(0.12, 0.08, 0.08), Color3.fromRGB(255, 225, 95), Enum.Material.Neon)

	part("ArmL", Vector3.new(0.28, 0.28, 1.8), darkJoint, Enum.Material.SmoothPlastic)
	part("ArmR", Vector3.new(0.28, 0.28, 1.8), darkJoint, Enum.Material.SmoothPlastic)
	part("LegL", Vector3.new(0.30, 0.30, 1.8), darkJoint, Enum.Material.SmoothPlastic)
	part("LegR", Vector3.new(0.30, 0.30, 1.8), darkJoint, Enum.Material.SmoothPlastic)

	local eyeGlow = Instance.new("PointLight")
	eyeGlow.Name = "EyeGlow"
	eyeGlow.Color = Color3.fromRGB(255, 215, 90)
	eyeGlow.Brightness = 0.28
	eyeGlow.Range = 5.5
	eyeGlow.Shadows = false
	eyeGlow.Parent = head

	model.PrimaryPart = core
	model.Parent = parentMap

	entityCore = core
	entityHead = head
	return model
end

local function positionRig(baseCF: CFrame, t: number, speed: number)
	local bob = if speed > 0.1 then math.sin(t * 10) * 0.08 else math.sin(t * 2.2) * 0.03
	local twitch = if speed > 0.1 then math.sin(t * 12) * 0.28 else 0
	local coreCF = baseCF * CFrame.new(0, bob, 0)
	local headCF = coreCF * CFrame.new(0, 0.22, -1.25) * CFrame.Angles(0, 0, math.sin(t * 3.1) * 0.18)

	entityCore.CFrame = coreCF
	entityHead.CFrame = headCF

	local eyeL = entityModel:FindFirstChild("EyeL") :: BasePart?
	local eyeR = entityModel:FindFirstChild("EyeR") :: BasePart?
	if eyeL then
		eyeL.CFrame = headCF * CFrame.new(-0.20, 0.08, -0.44)
	end
	if eyeR then
		eyeR.CFrame = headCF * CFrame.new(0.20, 0.08, -0.44)
	end

	local armL = entityModel:FindFirstChild("ArmL") :: BasePart?
	local armR = entityModel:FindFirstChild("ArmR") :: BasePart?
	local legL = entityModel:FindFirstChild("LegL") :: BasePart?
	local legR = entityModel:FindFirstChild("LegR") :: BasePart?
	if armL then
		armL.CFrame = coreCF * CFrame.new(-0.78, -0.25, -0.65 + twitch) * CFrame.Angles(math.rad(15), math.rad(12), 0)
	end
	if armR then
		armR.CFrame = coreCF * CFrame.new(0.78, -0.25, -0.65 - twitch) * CFrame.Angles(math.rad(15), math.rad(-12), 0)
	end
	if legL then
		legL.CFrame = coreCF * CFrame.new(-0.68, -0.28, 0.85 - twitch) * CFrame.Angles(math.rad(-12), math.rad(-14), 0)
	end
	if legR then
		legR.CFrame = coreCF * CFrame.new(0.68, -0.28, 0.85 + twitch) * CFrame.Angles(math.rad(-12), math.rad(14), 0)
	end
end

local function setState(newState: AIState)
	if aiState ~= newState then
		aiState = newState
		if entityModel then
			entityModel:SetAttribute("EntityState", aiState)
		end
	end
end

local function setDestination(goalTileKey: string)
	local newPath = MapLayout.findPath(currentTileKey, goalTileKey)
	if #newPath >= 2 then
		pathQueue = newPath
		pathIndex = 2
	elseif #newPath == 1 then
		pathQueue = newPath
		pathIndex = 1
	end
end

local function pickPatrolDestination(): string
	local candidates = MapLayout.Tiles
	for _ = 1, 8 do
		local pick = candidates[math.random(1, #candidates)]
		local k = MapLayout.key(pick.gx, pick.gz)
		if k ~= currentTileKey and k ~= MapLayout.DROP_TILE_KEY then
			return k
		end
	end
	return GameConfig.Entity.SpawnTileKey
end

local function hasLineOfSight(playerHead: BasePart): boolean
	local origin = entityHead.Position
	local dir = playerHead.Position - origin
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local ventMap = workspace:FindFirstChild("VentMap")
	local ventTiles = if ventMap then ventMap:FindFirstChild("VentTiles") else nil
	params.FilterDescendantsInstances = if ventTiles then { ventTiles } else {}
	local result = workspace:Raycast(origin, dir, params)
	return result == nil
end

function EntityService.alertNoise(worldPos: Vector3, radius: number)
	if aiState == "Chase" then
		return
	end
	local dist = (entityCore.Position - worldPos).Magnitude
	if dist <= radius * activeProfile.noiseSensitivity then
		local goalKey = EntityService.worldToTileKey(worldPos)
		setState("Investigate")
		investigateTimer = GameConfig.Entity.InvestigateDuration
		setDestination(goalKey)
	end
end

function EntityService.teleportToTile(tileKey: string)
	if not MapLayout.getTileByKey(tileKey) then
		return
	end
	currentTileKey = tileKey
	pathQueue = { tileKey }
	pathIndex = 1
	local worldPos = EntityService.tileKeyToWorld(tileKey)
	positionRig(CFrame.new(worldPos), os.clock(), 0)
end

function EntityService.getState(): AIState
	return aiState
end

function EntityService.getModel(): Model
	return entityModel
end

function EntityService.setEliminatedCallback(callback: ((player: Player) -> ())?)
	onPlayerEliminatedCallback = callback
end

local function updateDetectionAndElimination()
	local bestTarget: Player? = nil
	local bestDist = math.huge

	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute(NetContracts.Attributes.InSafeRoom) == false
			and player:GetAttribute(NetContracts.Attributes.IsEliminated) ~= true
		then
			local char = player.Character
			local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
			local root = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
			local head = if char then char:FindFirstChild("Head") :: BasePart? else nil

			if hum and root and head and hum.Health > 0 then
				local dist = (entityCore.Position - root.Position).Magnitude
				if dist <= GameConfig.Entity.KillRadius then
					player:SetAttribute(NetContracts.Attributes.IsEliminated, true)
					eliminatedRemote:FireClient(player, { entityId = activeProfile.id })
					hum.Health = 0
					targetPlayer = nil
					setState("Patrol")
					setDestination(pickPatrolDestination())
					if onPlayerEliminatedCallback then
						onPlayerEliminatedCallback(player)
					end
					return
				end

				local headlampOn = player:GetAttribute(NetContracts.Attributes.HeadlampOn) == true
				local visionRange = if headlampOn
					then activeProfile.lightAggroRange
					else activeProfile.passiveVisionRange

				if dist <= visionRange and hasLineOfSight(head) and dist < bestDist then
					bestDist = dist
					bestTarget = player
				end
			end
		end
	end

	if bestTarget then
		targetPlayer = bestTarget
		setState("Chase")
		investigateTimer = GameConfig.Entity.InvestigateDuration
		local char = bestTarget.Character
		local root = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		if root then
			local playerTile = EntityService.worldToTileKey(root.Position)
			if pathQueue[#pathQueue] ~= playerTile then
				setDestination(playerTile)
			end
		end
	elseif aiState == "Chase" then
		-- Lost visual; finish investigating last known tile
		targetPlayer = nil
		setState("Investigate")
		investigateTimer = GameConfig.Entity.InvestigateDuration * 0.7
	end
end

local function updatePanicLoop(dt: number)
	local now = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		local inSafeRoom = player:GetAttribute(NetContracts.Attributes.InSafeRoom) == true
		local headlampOn = player:GetAttribute(NetContracts.Attributes.HeadlampOn) == true
		local char = player.Character
		local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
		local root = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil

		local currentPanic = (player:GetAttribute(NetContracts.Attributes.PanicRatio) :: number?) or 0
		local nextPanic = currentPanic

		if not hum or hum.Health <= 0 or inSafeRoom then
			nextPanic = math.max(0, currentPanic - GameConfig.Panic.DecayRateSafeRoom * dt)
		elseif headlampOn then
			nextPanic = math.max(0, currentPanic - GameConfig.Panic.DecayRateLightOn * dt)
		else
			local horizSpeed = if root
				then Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
				else 0
			local buildRate = if horizSpeed < 0.4
				then GameConfig.Panic.BuildRateDarkStill
				else GameConfig.Panic.BuildRateDarkMoving
			nextPanic = math.min(1, currentPanic + buildRate * dt)

			if nextPanic >= GameConfig.Panic.GaspThreshold and root then
				local lastGasp = lastGaspTimes[player] or 0
				if now - lastGasp >= GameConfig.Panic.GaspInterval then
					lastGaspTimes[player] = now
					EntityService.alertNoise(root.Position, GameConfig.Entity.GaspNoiseRadius)
				end
			end
		end

		if math.abs(nextPanic - currentPanic) >= 0.005 or (nextPanic == 0 and currentPanic ~= 0) then
			player:SetAttribute(NetContracts.Attributes.PanicRatio, nextPanic)
			panicSyncRemote:FireClient(player, { panicRatio = nextPanic })
		end
	end
end

local function stepMovement(dt: number)
	if aiState == "Investigate" then
		investigateTimer -= dt
		if investigateTimer <= 0 then
			setState("Patrol")
		end
	end

	local targetTile = pathQueue[pathIndex]
	if not targetTile then
		if aiState == "Patrol" then
			setDestination(pickPatrolDestination())
			targetTile = pathQueue[pathIndex]
		elseif aiState == "Investigate" and investigateTimer <= 0 then
			setState("Patrol")
			setDestination(pickPatrolDestination())
			targetTile = pathQueue[pathIndex]
		end
	end

	local moveSpeed = if aiState == "Chase"
		then activeProfile.chaseCadence * 5.0 -- ~9.25 studs/s (faster than 5.5 crawl)
		else activeProfile.patrolCadence * MapLayout.CELL_SIZE * GameConfig.Entity.PatrolSpeedMultiplier

	local currentPos = entityCore.Position
	if targetTile then
		local wp = EntityService.tileKeyToWorld(targetTile)
		local delta = Vector3.new(wp.X - currentPos.X, 0, wp.Z - currentPos.Z)
		local dist = delta.Magnitude

		if dist <= 0.35 then
			currentTileKey = targetTile
			pathIndex += 1
			if pathIndex > #pathQueue then
				if aiState == "Patrol" then
					setDestination(pickPatrolDestination())
				elseif aiState == "Investigate" then
					-- Pause briefly at noise tile until investigateTimer expires
					pathQueue = {}
					pathIndex = 1
				end
			end
			positionRig(entityCore.CFrame, os.clock(), 0)
		else
			local stepDist = math.min(dist, moveSpeed * dt)
			local nextPos = currentPos + delta.Unit * stepDist
			local lookCF = CFrame.lookAt(nextPos, nextPos + delta.Unit)
			positionRig(lookCF, os.clock(), moveSpeed)
		end
	else
		positionRig(entityCore.CFrame, os.clock(), 0)
	end
end

function EntityService.init()
	if initialized then
		return
	end
	initialized = true

	noiseRemote = NetContracts.getRemoteEvent(NetContracts.Remotes.NoiseEmitted, true)
	panicSyncRemote = NetContracts.getRemoteEvent(NetContracts.Remotes.PanicStateSync, true)
	eliminatedRemote = NetContracts.getRemoteEvent(NetContracts.Remotes.PlayerEliminated, true)

	local ventMap = workspace:WaitForChild("VentMap", 10)
	assert(ventMap, "[EntityService] Workspace.VentMap missing")
	computeMapOffset()

	entityModel = createEntityRig(ventMap)
	EntityService.teleportToTile(GameConfig.Entity.SpawnTileKey)
	setDestination(pickPatrolDestination())

	noiseRemote.OnServerEvent:Connect(function(player: Player, payload: unknown)
		if typeof(payload) ~= "table" then
			return
		end
		if player:GetAttribute(NetContracts.Attributes.InSafeRoom) ~= false then
			return
		end
		local now = os.clock()
		if now - (lastNoiseTimes[player] or 0) < 0.8 then
			return
		end
		lastNoiseTimes[player] = now

		local char = player.Character
		local root = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		if root then
			EntityService.alertNoise(root.Position, GameConfig.Entity.CrawlNoiseRadius)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastGaspTimes[player] = nil
		lastNoiseTimes[player] = nil
		if targetPlayer == player then
			targetPlayer = nil
			setState("Patrol")
		end
	end)

	RunService.Heartbeat:Connect(function(dt: number)
		local now = os.clock()
		stepMovement(dt)

		if now - lastDetectionTime >= 0.15 then
			lastDetectionTime = now
			updateDetectionAndElimination()
		end

		if now - lastPanicTime >= 0.25 then
			local panicDt = now - lastPanicTime
			lastPanicTime = now
			updatePanicLoop(math.min(panicDt, 0.5))
		end
	end)
end

return EntityService
