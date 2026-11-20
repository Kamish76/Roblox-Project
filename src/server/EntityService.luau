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

export type AIState = "Patrol" | "Stalk" | "Scramble" | "Lurk" | "Retreat" | "Chase"

local EntityService = {}

local activeProfile = EntityProfiles.getActiveProfile()
local entityModel: Model
local entityCore: Part
local entityHead: Part
local isSkinnedRig = false
local skinnedRoot: BasePart? = nil
local rigBones: { [string]: Bone } = {}

local mapOffset = Vector3.zero
local currentTileKey = GameConfig.Entity.SpawnTileKey
local aiState: AIState = "Patrol"
local pathQueue: { string } = {}
local pathIndex = 1
local targetPlayer: Player? = nil
local lurkTimer = 0
local unnoticedPeekTimer = 0
local spottedPeekTimer = 0
local lurkCorridorLostTimer = 0
local lastPeekTileKey = ""
local chaseLostTimer = 0
local retreatCooldownTimer = 0

local lastDetectionTime = 0
local lastPanicTime = 0
local activeVentPlayerCount = 0
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

	table.clear(rigBones)
	isSkinnedRig = false
	skinnedRoot = nil

	local function makeAnchorPart(name: string, size: Vector3, parent: Instance): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Transparency = 1
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.CollisionGroup = NetContracts.CollisionGroups.Entity
		p.Parent = parent
		return p
	end

	-- Prefer the custom Blender-sculpted Skinned Mesh Rig (ReplicatedStorage.JointCracker_Template)
	local template = ReplicatedStorage:FindFirstChild("JointCracker_Template")
	if template and template:IsA("Model") then
		local model = template:Clone()
		model.Name = activeProfile.id
		model:SetAttribute("EntityId", activeProfile.id)
		model:SetAttribute("EntityState", aiState)
		model:SetAttribute("MoveSpeed", 0)
		model:SetAttribute("LurkSideSign", 1)
		model:SetAttribute("LurkTargetPos", Vector3.zero)
		model:SetAttribute("TargetRootCF", CFrame.identity)

		local root = model:FindFirstChild("RootPart")
		if root and root:IsA("BasePart") then
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then
					d.CanCollide = false
					d.CanQuery = false
					d.CanTouch = false
					d.CollisionGroup = NetContracts.CollisionGroups.Entity
					if d == root then
						d.Anchored = true
						d.Transparency = 1
						d.CastShadow = false
					else
						d.Anchored = false
					end
				elseif d:IsA("Bone") then
					rigBones[d.Name] = d
				end
			end

			local core = makeAnchorPart("Core", Vector3.new(1.2, 0.85, 2.0), model)
			local head = makeAnchorPart("Head", Vector3.new(0.85, 0.85, 0.9), model)

			local eyeGlow = Instance.new("PointLight")
			eyeGlow.Name = "EyeGlow"
			eyeGlow.Color = Color3.fromRGB(255, 215, 75)
			eyeGlow.Brightness = 0.42
			eyeGlow.Range = 6.5
			eyeGlow.Shadows = false
			eyeGlow.Parent = head

			model.PrimaryPart = core
			model.Parent = parentMap

			isSkinnedRig = true
			skinnedRoot = root
			entityCore = core
			entityHead = head
			return model
		else
			model:Destroy()
		end
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
	if isSkinnedRig and skinnedRoot then
		-- Replicate target pose via attribute so Client EntityAnimator smoothly interpolates
		-- RootPart.CFrame at 60-144 FPS (avoiding Roblox's choppy 20 Hz Anchored CFrame replication!).
		local targetRootCF = baseCF * CFrame.new(0, -1.35, 0)
		entityModel:SetAttribute("TargetRootCF", targetRootCF)
		entityModel:SetAttribute("MoveSpeed", speed)
		entityCore.CFrame = baseCF
		entityHead.CFrame = baseCF * CFrame.new(0, 0.90, -2.60)
		return
	end

	local bob = if speed > 0.1 then math.sin(t * 10) * 0.06 else math.sin(t * 2.2) * 0.025
	local coreCF = baseCF * CFrame.new(0, bob, 0)

	local twitch = if speed > 0.1 then math.sin(t * 12) * 0.28 else 0
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

local function hasLineOfSightFrom(origin: Vector3, playerHead: BasePart): boolean
	local dir = playerHead.Position - origin
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local ventMap = workspace:FindFirstChild("VentMap")
	local ventTiles = if ventMap then ventMap:FindFirstChild("VentTiles") else nil
	params.FilterDescendantsInstances = if ventTiles then { ventTiles } else {}
	local result = workspace:Raycast(origin, dir, params)
	return result == nil
end

local function hasLineOfSight(playerHead: BasePart): boolean
	return hasLineOfSightFrom(entityHead.Position, playerHead)
end

type VentPlayerInfo = {
	player: Player,
	root: BasePart,
	head: BasePart,
	dist: number,
	headlampOn: boolean,
}

local function getVentPlayers(): { VentPlayerInfo }
	local list: { VentPlayerInfo } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute(NetContracts.Attributes.InSafeRoom) == false
			and player:GetAttribute(NetContracts.Attributes.IsEliminated) ~= true
		then
			local char = player.Character
			local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
			local root = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
			local head = if char then char:FindFirstChild("Head") :: BasePart? else nil
			if hum and root and head and hum.Health > 0 then
				table.insert(list, {
					player = player,
					root = root,
					head = head,
					dist = (entityCore.Position - root.Position).Magnitude,
					headlampOn = player:GetAttribute(NetContracts.Attributes.HeadlampOn) == true,
				})
			end
		end
	end
	return list
end

local function isCornerTile(tile: any): boolean
	return tile ~= nil and (tile.tileType == "Corner" or tile.tileType == "TJunction" or tile.tileType == "Cross")
end

-- Check if two tile keys share an unobstructed straight row (gz) or column (gx) sightline
local function isSameCorridorAxis(tileKeyA: string, tileKeyB: string): boolean
	local a = MapLayout.getTileByKey(tileKeyA)
	local b = MapLayout.getTileByKey(tileKeyB)
	if not a or not b then
		return false
	end
	return a.gx == b.gx or a.gz == b.gz
end

-- Walk straight down all 4 cardinal corridors from the player's tile (exact row gz / col gx)
-- to find corners/junctions that look directly down the player's vent shaft!
local function pickCorridorPeekCorner(playerTileKey: string, excludeTileKey: string?): string
	local startTile = MapLayout.getTileByKey(playerTileKey)
	local sightlineCorners: { string } = {}

	if startTile then
		local dirs = {
			{ dx = 1, dz = 0 },
			{ dx = -1, dz = 0 },
			{ dx = 0, dz = 1 },
			{ dx = 0, dz = -1 },
		}
		for _, d in ipairs(dirs) do
			local prevKey = playerTileKey
			local gx, gz = startTile.gx, startTile.gz
			for step = 1, 6 do
				gx += d.dx
				gz += d.dz
				local nextKey = MapLayout.key(gx, gz)
				-- Ensure the corridor is actually connected (no wall between prevKey and nextKey)
				local connected = false
				for _, nKey in ipairs(MapLayout.getNeighbors(prevKey)) do
					if nKey == nextKey then
						connected = true
						break
					end
				end
				if not connected then
					break
				end

				local tile = MapLayout.getTileByKey(nextKey)
				if tile and nextKey ~= MapLayout.DROP_TILE_KEY and nextKey ~= excludeTileKey and isCornerTile(tile) then
					table.insert(sightlineCorners, nextKey)
				end
				prevKey = nextKey
			end
		end
	end

	-- Prefer the closest straight-corridor peek corner to the entity's current position
	if #sightlineCorners > 0 then
		local bestKey = sightlineCorners[1]
		local bestDist = math.huge
		local myPos = entityCore.Position
		for _, k in ipairs(sightlineCorners) do
			local d = (EntityService.tileKeyToWorld(k) - myPos).Magnitude
			if d < bestDist then
				bestDist = d
				bestKey = k
			end
		end
		return bestKey
	end

	-- Fallback: BFS 1-2 tiles around player for any corner/junction
	local queue: { { key: string, depth: number } } = { { key = playerTileKey, depth = 0 } }
	local visited: { [string]: boolean } = { [playerTileKey] = true }
	local fallback: { string } = {}
	local idx = 1
	while idx <= #queue do
		local item = queue[idx]
		idx += 1
		if item.depth >= 1 and item.depth <= 2 and item.key ~= MapLayout.DROP_TILE_KEY and item.key ~= excludeTileKey then
			local tile = MapLayout.getTileByKey(item.key)
			if isCornerTile(tile) then
				table.insert(fallback, item.key)
			end
		end
		if item.depth < 2 then
			for _, neighborKey in ipairs(MapLayout.getNeighbors(item.key)) do
				if not visited[neighborKey] then
					visited[neighborKey] = true
					table.insert(queue, { key = neighborKey, depth = item.depth + 1 })
				end
			end
		end
	end
	if #fallback > 0 then
		return fallback[math.random(1, #fallback)]
	end
	return playerTileKey
end

-- Find the closest corner/junction tile to scramble into when caught in open LOS
local function pickClosestCornerForScramble(): string
	local curTile = MapLayout.getTileByKey(currentTileKey)
	if isCornerTile(curTile) and currentTileKey ~= MapLayout.DROP_TILE_KEY then
		return currentTileKey
	end

	local queue: { { key: string, depth: number } } = { { key = currentTileKey, depth = 0 } }
	local visited: { [string]: boolean } = { [currentTileKey] = true }
	local idx = 1
	while idx <= #queue do
		local item = queue[idx]
		idx += 1
		if item.depth >= 1 and item.key ~= MapLayout.DROP_TILE_KEY then
			local tile = MapLayout.getTileByKey(item.key)
			if isCornerTile(tile) then
				return item.key
			end
		end
		if item.depth < 4 then
			for _, neighborKey in ipairs(MapLayout.getNeighbors(item.key)) do
				if not visited[neighborKey] then
					visited[neighborKey] = true
					table.insert(queue, { key = neighborKey, depth = item.depth + 1 })
				end
			end
		end
	end
	return currentTileKey
end

local function pickRetreatTile(ventPlayers: { VentPlayerInfo }): string
	-- Prefer a nearby blind corner (2-4 BFS tiles away, out of LOS of all players) so it stays pressuring
	local queue: { { key: string, depth: number } } = { { key = currentTileKey, depth = 0 } }
	local visited: { [string]: boolean } = { [currentTileKey] = true }
	local blindCorners: { string } = {}
	local idx = 1

	while idx <= #queue do
		local item = queue[idx]
		idx += 1
		if item.depth >= 2 and item.depth <= 4 and item.key ~= MapLayout.DROP_TILE_KEY then
			local tile = MapLayout.getTileByKey(item.key)
			if tile and (tile.tileType == "Corner" or tile.tileType == "TJunction" or tile.tileType == "Cross") then
				local wp = EntityService.tileKeyToWorld(item.key)
				local visibleToAny = false
				local tooClose = false
				for _, vp in ipairs(ventPlayers) do
					if (wp - vp.root.Position).Magnitude < GameConfig.Entity.CloseStareRange then
						tooClose = true
						break
					end
					if hasLineOfSightFrom(wp + Vector3.new(0, 0.25, 0), vp.head) then
						visibleToAny = true
						break
					end
				end
				if not visibleToAny and not tooClose then
					table.insert(blindCorners, item.key)
				end
			end
		end
		if item.depth < 4 then
			for _, neighborKey in ipairs(MapLayout.getNeighbors(item.key)) do
				if not visited[neighborKey] then
					visited[neighborKey] = true
					table.insert(queue, { key = neighborKey, depth = item.depth + 1 })
				end
			end
		end
	end

	if #blindCorners > 0 then
		return blindCorners[math.random(1, #blindCorners)]
	end

	-- Fallback: furthest tile from all players
	local bestKey = GameConfig.Entity.SpawnTileKey
	local bestMinDist = -1
	for _, tile in ipairs(MapLayout.Tiles) do
		local k = MapLayout.key(tile.gx, tile.gz)
		if k ~= currentTileKey and k ~= MapLayout.DROP_TILE_KEY then
			local wp = EntityService.tileKeyToWorld(k)
			local minDist = math.huge
			for _, vp in ipairs(ventPlayers) do
				local d = (wp - vp.root.Position).Magnitude
				if d < minDist then
					minDist = d
				end
			end
			if minDist > bestMinDist then
				bestMinDist = minDist
				bestKey = k
			end
		end
	end
	return bestKey
end

local function isPlayerLookingAtEntity(vp: VentPlayerInfo): boolean
	local visionRange = if vp.headlampOn then activeProfile.lightAggroRange else 20
	if vp.dist > visionRange or not hasLineOfSight(vp.head) then
		return false
	end
	local toEntity = entityHead.Position - vp.head.Position
	if toEntity.Magnitude < 0.01 then
		return true
	end
	local dotThreshold = if aiState == "Lurk"
		then GameConfig.Entity.PeekSpotDotThreshold
		else GameConfig.Entity.StareDotThreshold
	return vp.head.CFrame.LookVector:Dot(toEntity.Unit) >= dotThreshold
end

local function positionLurkPeekRig(basePos: Vector3, playerPos: Vector3, t: number)
	-- Find corridor opening toward player and a perpendicular side corridor to tuck the body behind
	local neighbors = MapLayout.getNeighbors(currentTileKey)
	local openDir = Vector3.new(playerPos.X - basePos.X, 0, playerPos.Z - basePos.Z)
	if openDir.Magnitude > 0.01 then
		openDir = openDir.Unit
	else
		openDir = Vector3.new(0, 0, -1)
	end

	local bestOpenDir = openDir
	local bestOpenDist = math.huge
	for _, nKey in ipairs(neighbors) do
		local np = EntityService.tileKeyToWorld(nKey)
		local d = (np - playerPos).Magnitude
		if d < bestOpenDist then
			bestOpenDist = d
			local dir = Vector3.new(np.X - basePos.X, 0, np.Z - basePos.Z)
			if dir.Magnitude > 0.01 then
				bestOpenDir = dir.Unit
			end
		end
	end

	local hideSideDir: Vector3? = nil
	for _, nKey in ipairs(neighbors) do
		local np = EntityService.tileKeyToWorld(nKey)
		local dir = Vector3.new(np.X - basePos.X, 0, np.Z - basePos.Z)
		if dir.Magnitude > 0.01 then
			dir = dir.Unit
			if math.abs(dir:Dot(bestOpenDir)) < 0.3 then
				hideSideDir = dir
				break
			end
		end
	end

	local sideVec = if hideSideDir then hideSideDir else Vector3.new(-bestOpenDir.Z, 0, bestOpenDir.X)
	local sideSign = if bestOpenDir:Cross(sideVec).Y >= 0 then 1 else -1

	-- Tuck torso + legs into the hiding side corridor; lean ONLY tilted head + yellow eyes + 1 gripping arm out
	local subtleBreath = math.sin(t * 2.4) * 0.03
	local corePos = basePos + sideVec * 2.0 - bestOpenDir * 0.45 + Vector3.new(0, subtleBreath, 0)
	local peekHeadPos = basePos + sideVec * 0.55 + bestOpenDir * 0.90 + Vector3.new(0, 0.28 + subtleBreath, 0)

	local lookTarget = Vector3.new(playerPos.X, peekHeadPos.Y, playerPos.Z)
	local headBaseCF = if (lookTarget - peekHeadPos).Magnitude > 0.05
		then CFrame.lookAt(peekHeadPos, lookTarget)
		else CFrame.new(peekHeadPos)
	local headTilt = math.rad(28 * sideSign) + math.sin(t * 2.7) * 0.06
	local headCF = headBaseCF * CFrame.Angles(0, 0, headTilt)

	local coreLookTarget = Vector3.new(peekHeadPos.X, corePos.Y, peekHeadPos.Z)
	local coreCF = if (coreLookTarget - corePos).Magnitude > 0.05
		then CFrame.lookAt(corePos, coreLookTarget)
		else CFrame.new(corePos)

	if isSkinnedRig and skinnedRoot then
		-- TRUE CORNER-PEEK: Hide entire torso/elbows/legs deep behind the perpendicular wall (sideVec * 3.85),
		-- oriented outward toward the corner edge so ONLY the extended neck & tilted head peek past the 2.3-stud wall!
		local peekBodyPos = basePos + sideVec * 3.85 - bestOpenDir * 0.55
		local outOfCornerDir = (-sideVec * 0.92 + bestOpenDir * 0.39).Unit
		local bodyCF = CFrame.lookAt(peekBodyPos, peekBodyPos + outOfCornerDir)

		-- Exact monster-relative peek side: +1 = player is to monster's RIGHT (PeekRight), -1 = monster's LEFT (PeekLeft)
		local peekSideSign = if bodyCF.RightVector:Dot(bestOpenDir) >= 0 then 1 else -1

		entityModel:SetAttribute("TargetRootCF", bodyCF * CFrame.new(0, -1.35, 0))
		entityModel:SetAttribute("MoveSpeed", 0)
		entityModel:SetAttribute("LurkSideSign", peekSideSign)
		entityModel:SetAttribute("LurkTargetPos", playerPos)

		entityCore.CFrame = bodyCF
		-- Place LOS/stare anchor right where the peeking head emerges past the corner edge
		local truePeekHeadPos = basePos + sideVec * 1.45 + bestOpenDir * 0.45 + Vector3.new(0, 0.55, 0)
		entityHead.CFrame = CFrame.lookAt(truePeekHeadPos, Vector3.new(playerPos.X, truePeekHeadPos.Y, playerPos.Z))
		return
	end

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

	-- One arm reaches to grip the corner edge just below the peeking head; other limbs stay tucked back
	local gripCF = headBaseCF * CFrame.new(0.25 * sideSign, -0.42, -0.20) * CFrame.Angles(math.rad(35), 0, math.rad(-15 * sideSign))
	if sideSign > 0 then
		if armR then armR.CFrame = gripCF end
		if armL then armL.CFrame = coreCF * CFrame.new(-0.75, -0.25, 0.35) end
	else
		if armL then armL.CFrame = gripCF end
		if armR then armR.CFrame = coreCF * CFrame.new(0.75, -0.25, 0.35) end
	end
	if legL then
		legL.CFrame = coreCF * CFrame.new(-0.55, -0.28, 1.05) * CFrame.Angles(math.rad(-10), math.rad(-12), 0)
	end
	if legR then
		legR.CFrame = coreCF * CFrame.new(0.55, -0.28, 1.05) * CFrame.Angles(math.rad(-10), math.rad(12), 0)
	end
end

local function enterLurk(player: Player?)
	setState("Lurk")
	targetPlayer = player or targetPlayer
	lurkTimer = GameConfig.Entity.LurkMaxDuration
	unnoticedPeekTimer = 0
	spottedPeekTimer = 0
	lurkCorridorLostTimer = 0
	pathQueue = {}
	pathIndex = 1
end

local function enterScrambleToCorner(player: Player)
	targetPlayer = player
	unnoticedPeekTimer = 0
	spottedPeekTimer = 0
	local cornerKey = pickClosestCornerForScramble()
	if cornerKey == currentTileKey then
		enterLurk(player)
		return
	end
	setState("Scramble")
	setDestination(cornerKey)
end

local function enterRetreat(ventPlayers: { VentPlayerInfo })
	lastPeekTileKey = currentTileKey
	setState("Retreat")
	targetPlayer = nil
	unnoticedPeekTimer = 0
	spottedPeekTimer = 0
	lurkCorridorLostTimer = 0
	local cdScale = if #ventPlayers >= 2 then GameConfig.Entity.MultiplayerRetreatCooldownScale else 1.0
	retreatCooldownTimer = GameConfig.Entity.RetreatCooldown * cdScale
	setDestination(pickRetreatTile(ventPlayers))
end

local function enterChase(player: Player)
	setState("Chase")
	targetPlayer = player
	unnoticedPeekTimer = 0
	spottedPeekTimer = 0
	lurkCorridorLostTimer = 0
	chaseLostTimer = 0
end

function EntityService.alertNoise(worldPos: Vector3, radius: number, sourcePlayer: Player?, isHighPriority: boolean?)
	if aiState == "Chase" or aiState == "Retreat" or aiState == "Scramble" then
		return
	end
	local dist = (entityCore.Position - worldPos).Magnitude
	if dist <= radius * activeProfile.noiseSensitivity then
		-- Loud FastCrawl scrambling at close/mid range snaps the entity straight into Chase
		if isHighPriority and sourcePlayer and dist <= GameConfig.Entity.FastCrawlChaseRadius then
			enterChase(sourcePlayer)
			setDestination(EntityService.worldToTileKey(worldPos))
			return
		end

		local goalKey = EntityService.worldToTileKey(worldPos)
		if (aiState == "Patrol" or (isHighPriority and aiState == "Lurk")) and (retreatCooldownTimer <= 0 or isHighPriority) then
			setState("Stalk")
			targetPlayer = sourcePlayer or targetPlayer
			unnoticedPeekTimer = 0
			spottedPeekTimer = 0
		end
		setDestination(if isHighPriority then goalKey else pickCorridorPeekCorner(goalKey, lastPeekTileKey))
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

local function updateDetectionAndElimination(dt: number)
	if retreatCooldownTimer > 0 then
		retreatCooldownTimer = math.max(0, retreatCooldownTimer - dt)
	end

	local ventPlayers = getVentPlayers()
	activeVentPlayerCount = #ventPlayers

	-- 1. Elimination check in all states
	for _, vp in ipairs(ventPlayers) do
		if vp.dist <= GameConfig.Entity.KillRadius then
			vp.player:SetAttribute(NetContracts.Attributes.IsEliminated, true)
			eliminatedRemote:FireClient(vp.player, { entityId = activeProfile.id })
			local hum = vp.player.Character and vp.player.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.Health = 0
			end
			targetPlayer = nil
			unnoticedPeekTimer = 0
			spottedPeekTimer = 0
			lurkCorridorLostTimer = 0
			setState("Patrol")
			setDestination(pickPatrolDestination())
			if onPlayerEliminatedCallback then
				onPlayerEliminatedCallback(vp.player)
			end
			return
		end
	end

	-- 2. Retreat and Scramble are non-interruptible until they reach their corner tile
	if aiState == "Retreat" or aiState == "Scramble" then
		return
	end

	-- 3. Chase logic: pursue nearest visible player, drop to Patrol if sight lost
	if aiState == "Chase" then
		local bestTarget: VentPlayerInfo? = nil
		local bestDist = math.huge
		for _, vp in ipairs(ventPlayers) do
			local visionRange = if vp.headlampOn then activeProfile.lightAggroRange else activeProfile.passiveVisionRange
			if vp.dist <= visionRange and hasLineOfSight(vp.head) and vp.dist < bestDist then
				bestDist = vp.dist
				bestTarget = vp
			end
		end

		if bestTarget then
			targetPlayer = bestTarget.player
			chaseLostTimer = 0
			local playerTile = EntityService.worldToTileKey(bestTarget.root.Position)
			if pathQueue[#pathQueue] ~= playerTile then
				setDestination(playerTile)
			end
		else
			chaseLostTimer += dt
			if chaseLostTimer >= GameConfig.Entity.ChaseLostSightTimeout then
				targetPlayer = nil
				setState("Patrol")
				setDestination(pickPatrolDestination())
			end
		end
		return
	end

	-- 4. Sense nearby vent players & detect LOS / spotted status
	local closestVP: VentPlayerInfo? = nil
	local closestDist = math.huge
	local spottedBy: VentPlayerInfo? = nil
	local spottedDist = math.huge
	local targetVP: VentPlayerInfo? = nil

	for _, vp in ipairs(ventPlayers) do
		if vp.player == targetPlayer then
			targetVP = vp
		end
		if vp.dist < closestDist then
			closestDist = vp.dist
			closestVP = vp
		end
		if (aiState == "Stalk" or aiState == "Lurk") and vp.dist <= GameConfig.Entity.AmbushRadius then
			enterChase(vp.player)
			return
		end
		if isPlayerLookingAtEntity(vp) and vp.dist < spottedDist then
			spottedDist = vp.dist
			spottedBy = vp
		end
	end

	-- 5. LURK (Persistent Corridor Corner-Peek + Unnoticed-Peek Ambush!)
	if aiState == "Lurk" then
		local focusVP = targetVP or closestVP
		if not focusVP then
			setState("Patrol")
			targetPlayer = nil
			setDestination(pickPatrolDestination())
			return
		end
		targetPlayer = focusVP.player

		-- Player spotted the peeking head in time -> tense 0.5s stare-down, then whip back & reposition!
		if spottedBy then
			unnoticedPeekTimer = 0
			spottedPeekTimer += dt
			if spottedPeekTimer >= GameConfig.Entity.SpottedPeekFlinchDuration then
				enterRetreat(ventPlayers)
				return
			end
		else
			spottedPeekTimer = math.max(0, spottedPeekTimer - dt * 2.0)

			-- Check if the target player is still in our corridor row/column or direct LOS
			local playerTileKey = EntityService.worldToTileKey(focusVP.root.Position)
			local inCorridor = isSameCorridorAxis(currentTileKey, playerTileKey)
				or hasLineOfSight(focusVP.head)

			if inCorridor then
				lurkCorridorLostTimer = 0
				-- UNNOTICED PEEK ESCALATION: if player ignores the peeking corner for ~5s -> ATTACK!
				unnoticedPeekTimer += dt
				if unnoticedPeekTimer >= GameConfig.Entity.UnnoticedPeekAttackDuration then
					enterChase(focusVP.player)
					setDestination(playerTileKey)
					return
				end
			else
				-- Player left our vent row/column -> re-stalk a new corner on their new row/column!
				unnoticedPeekTimer = math.max(0, unnoticedPeekTimer - dt)
				lurkCorridorLostTimer += dt
				if lurkCorridorLostTimer >= GameConfig.Entity.LurkCorridorLostTimeout then
					setState("Stalk")
					setDestination(pickCorridorPeekCorner(playerTileKey, currentTileKey))
					return
				end
			end
		end

		lurkTimer -= dt
		if lurkTimer <= 0 then
			local playerTileKey = EntityService.worldToTileKey(focusVP.root.Position)
			setState("Stalk")
			setDestination(pickCorridorPeekCorner(playerTileKey, currentTileKey))
		end
		return
	end

	-- 6. STALK (Row/Column Sightline Corner Hunter)
	if aiState == "Stalk" then
		-- Caught in open LOS while stalking -> bolt straight to the CLOSEST corner and peek back!
		if spottedBy then
			if spottedBy.dist <= GameConfig.Entity.AmbushRadius then
				enterChase(spottedBy.player)
			else
				enterScrambleToCorner(spottedBy.player)
			end
			return
		end

		local focusVP = targetVP or closestVP
		if focusVP then
			targetPlayer = focusVP.player
			-- If player moved off the row/column we're heading toward, smoothly re-aim for a corner on their new row/col
			local playerTileKey = EntityService.worldToTileKey(focusVP.root.Position)
			local destKey = pathQueue[#pathQueue]
			if not destKey or not isSameCorridorAxis(destKey, playerTileKey) then
				setDestination(pickCorridorPeekCorner(playerTileKey, lastPeekTileKey))
			end
		else
			setState("Patrol")
			targetPlayer = nil
			setDestination(pickPatrolDestination())
		end
		return
	end

	-- 7. PATROL (Prioritizes entering Stalk/Lurk when players are in the vents; scrambles to closest corner if spotted!)
	if aiState == "Patrol" then
		if spottedBy then
			if spottedBy.dist <= GameConfig.Entity.AmbushRadius then
				enterChase(spottedBy.player)
			else
				-- Caught in open LOS -> scramble at high speed to closest corner & immediately peek back!
				enterScrambleToCorner(spottedBy.player)
			end
			return
		elseif closestVP then
			local acquireRange = GameConfig.Entity.StalkAcquireRange
				+ (if #ventPlayers >= 2 then GameConfig.Entity.MultiplayerAcquireRangeBonus else 0)
			if closestDist <= acquireRange and retreatCooldownTimer <= 0 then
				setState("Stalk")
				targetPlayer = closestVP.player
				unnoticedPeekTimer = 0
				spottedPeekTimer = 0
				local playerTile = EntityService.worldToTileKey(closestVP.root.Position)
				setDestination(pickCorridorPeekCorner(playerTile, lastPeekTileKey))
			end
		end
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
	-- Corner-peek Lurk pose: tuck torso behind inner corner wall, lean tilted head & gripping hand out
	if aiState == "Lurk" then
		local basePos = EntityService.tileKeyToWorld(currentTileKey)
		local targetRoot = if targetPlayer and targetPlayer.Character
			then targetPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			else nil
		if targetRoot then
			positionLurkPeekRig(basePos, targetRoot.Position, os.clock())
		else
			positionRig(CFrame.new(basePos), os.clock(), 0)
		end
		return
	end

	local targetTile = pathQueue[pathIndex]
	if not targetTile then
		if aiState == "Patrol" then
			setDestination(pickPatrolDestination())
			targetTile = pathQueue[pathIndex]
		elseif aiState == "Retreat" then
			-- Immediately resume stalking a fresh row/col corner if players are in the vents!
			local vps = getVentPlayers()
			if #vps > 0 then
				setState("Stalk")
				targetPlayer = vps[1].player
				local pTile = EntityService.worldToTileKey(vps[1].root.Position)
				setDestination(pickCorridorPeekCorner(pTile, lastPeekTileKey))
			else
				setState("Patrol")
				setDestination(pickPatrolDestination())
			end
			targetTile = pathQueue[pathIndex]
		elseif aiState == "Stalk" or aiState == "Scramble" then
			enterLurk(targetPlayer)
			return
		end
	end

	local stalkSpeed = GameConfig.Entity.StalkSpeed
		+ (if activeVentPlayerCount >= 2 then GameConfig.Entity.MultiplayerStalkSpeedBonus else 0)
	local moveSpeed = if aiState == "Retreat"
		then GameConfig.Entity.RetreatSpeed
		elseif aiState == "Scramble"
		then GameConfig.Entity.ScrambleSpeed
		elseif aiState == "Chase"
		then activeProfile.chaseCadence * 5.2 -- ~9.62 studs/s (faster than 8.4 fast-crawl on straightaways)
		elseif aiState == "Stalk"
		then stalkSpeed
		else activeProfile.patrolCadence * MapLayout.CELL_SIZE * GameConfig.Entity.PatrolSpeedMultiplier

	local currentPos = entityCore.Position
	if targetTile then
		local wp = EntityService.tileKeyToWorld(targetTile)
		local delta = Vector3.new(wp.X - currentPos.X, 0, wp.Z - currentPos.Z)
		local dist = delta.Magnitude

		-- Advance immediately to next tile without a 1-frame speed=0 hiccup!
		if dist <= 0.45 then
			currentTileKey = targetTile
			pathIndex += 1
			if pathIndex > #pathQueue then
				if aiState == "Patrol" then
					setDestination(pickPatrolDestination())
				elseif aiState == "Stalk" or aiState == "Scramble" then
					enterLurk(targetPlayer)
					return
				elseif aiState == "Retreat" then
					local vps = getVentPlayers()
					if #vps > 0 then
						setState("Stalk")
						targetPlayer = vps[1].player
						local pTile = EntityService.worldToTileKey(vps[1].root.Position)
						setDestination(pickCorridorPeekCorner(pTile, lastPeekTileKey))
					else
						setState("Patrol")
						setDestination(pickPatrolDestination())
					end
				end
			end
			targetTile = pathQueue[pathIndex]
			if targetTile then
				wp = EntityService.tileKeyToWorld(targetTile)
				delta = Vector3.new(wp.X - currentPos.X, 0, wp.Z - currentPos.Z)
				dist = delta.Magnitude
			end
		end

		if targetTile and dist > 0.01 then
			local stepDist = math.min(dist, moveSpeed * dt)
			local nextPos = currentPos + delta.Unit * stepDist
			local desiredLook = CFrame.lookAt(nextPos, nextPos + delta.Unit)
			-- Smoothly turn around corners instead of snapping 90 deg in 1 frame
			local turnAlpha = 1 - math.exp(-10 * dt)
			local smoothRot = entityCore.CFrame.Rotation:Lerp(desiredLook.Rotation, turnAlpha)
			positionRig(CFrame.new(nextPos) * smoothRot, os.clock(), moveSpeed)
		else
			positionRig(entityCore.CFrame, os.clock(), 0)
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
		local noiseType = (payload :: any).noiseType
		local isFast = noiseType == "FastCrawl"
		local minInterval = if isFast then 0.45 else 0.8
		local now = os.clock()
		if now - (lastNoiseTimes[player] or 0) < minInterval then
			return
		end
		lastNoiseTimes[player] = now

		local char = player.Character
		local root = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		if root then
			local radius = if isFast
				then GameConfig.Entity.FastCrawlNoiseRadius
				else GameConfig.Entity.CrawlNoiseRadius
			EntityService.alertNoise(root.Position, radius, player, isFast)
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
			local detectDt = now - lastDetectionTime
			lastDetectionTime = now
			updateDetectionAndElimination(math.min(detectDt, 0.5))
		end

		if now - lastPanicTime >= 0.25 then
			local panicDt = now - lastPanicTime
			lastPanicTime = now
			updatePanicLoop(math.min(panicDt, 0.5))
		end
	end)
end

return EntityService
