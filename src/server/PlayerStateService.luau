--!strict
--[[
	Server-authoritative player stance (Safe Room standing vs Vent crawling),
	CollisionGroup registration, DropShaft hatch prompts, and Headlamp replication.
]]

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local NetContracts = require(Shared:WaitForChild("NetContracts"))

local PlayerStateService = {}

local LIMB_NAMES = {
	["Left Leg"] = true,
	["Right Leg"] = true,
	["Left Arm"] = true,
	["Right Arm"] = true,
}

local STANCE_COOLDOWN = 0.6

local toggleTimestamps: { [Player]: number } = {}
local stanceTimestamps: { [Player]: number } = {}
local charConnections: { [Player]: { RBXScriptConnection } } = {}
local initialized = false

local function ensureCollisionGroup(groupName: string)
	if not PhysicsService:IsCollisionGroupRegistered(groupName) then
		PhysicsService:RegisterCollisionGroup(groupName)
	end
end

local function setupCollisionGroups()
	local crawlers = NetContracts.CollisionGroups.Crawlers
	local ventWalls = NetContracts.CollisionGroups.VentWalls
	local entityGroup = NetContracts.CollisionGroups.Entity

	ensureCollisionGroup(crawlers)
	ensureCollisionGroup(ventWalls)
	ensureCollisionGroup(entityGroup)

	-- Co-op players can share tight ducts without body-block griefing.
	PhysicsService:CollisionGroupSetCollidable(crawlers, crawlers, false)
	PhysicsService:CollisionGroupSetCollidable(crawlers, ventWalls, true)
	PhysicsService:CollisionGroupSetCollidable(crawlers, "Default", true)

	PhysicsService:CollisionGroupSetCollidable(entityGroup, ventWalls, true)
	PhysicsService:CollisionGroupSetCollidable(entityGroup, crawlers, false)
	PhysicsService:CollisionGroupSetCollidable(entityGroup, entityGroup, false)
end

local function configureCharacterPart(part: BasePart)
	part.CollisionGroup = NetContracts.CollisionGroups.Crawlers
	if LIMB_NAMES[part.Name] then
		part.CanCollide = false
	end
end

local function clearCharacterConnections(player: Player)
	local conns = charConnections[player]
	if conns then
		for _, conn in ipairs(conns) do
			conn:Disconnect()
		end
		charConnections[player] = nil
	end
end

function PlayerStateService.setStance(player: Player, inSafeRoom: boolean, targetCFrame: CFrame?)
	local isCrawling = not inSafeRoom
	player:SetAttribute(NetContracts.Attributes.InSafeRoom, inSafeRoom)
	player:SetAttribute(NetContracts.Attributes.IsCrawling, isCrawling)

	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid then
		return
	end

	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)

	if isCrawling then
		humanoid.HipHeight = GameConfig.Crawl.HipHeight
		humanoid.WalkSpeed = GameConfig.Crawl.ForwardWalkSpeed
	else
		humanoid.HipHeight = GameConfig.SafeRoom.StandingHipHeight
		humanoid.WalkSpeed = GameConfig.SafeRoom.WalkSpeed
	end

	if targetCFrame and rootPart and rootPart.Parent then
		rootPart.AssemblyLinearVelocity = Vector3.zero
		rootPart.AssemblyAngularVelocity = Vector3.zero
		character:PivotTo(targetCFrame)
	end
end

local function getVentEntryCFrame(): CFrame
	local ventMap = workspace:FindFirstChild("VentMap")
	local tiles = if ventMap then ventMap:FindFirstChild("VentTiles") else nil
	local dropTile = if tiles then tiles:FindFirstChild("Tile_0_0") else nil
	local floor = if dropTile then dropTile:FindFirstChild("Floor") else nil
	if floor and floor:IsA("BasePart") then
		return CFrame.new(floor.Position.X, floor.Position.Y + floor.Size.Y / 2 + 1.4, floor.Position.Z)
	end
	return GameConfig.Crawl.DropEntryCFrame
end

local function getSafeRoomReturnCFrame(): CFrame
	local ventMap = workspace:FindFirstChild("VentMap")
	local safeRoom = if ventMap then ventMap:FindFirstChild("SafeRoom") else nil
	local safeSpawn = if safeRoom then safeRoom:FindFirstChild("SafeSpawn", true) else nil
	if safeSpawn and safeSpawn:IsA("BasePart") then
		return CFrame.new(safeSpawn.Position.X, safeSpawn.Position.Y + 2.9, safeSpawn.Position.Z)
	end
	return GameConfig.SafeRoom.ReturnCFrame
end

function PlayerStateService.transitionToVents(player: Player)
	if player:GetAttribute(NetContracts.Attributes.IsEliminated) == true then
		return
	end
	PlayerStateService.setStance(player, false, getVentEntryCFrame())
end

function PlayerStateService.transitionToSafeRoom(player: Player)
	PlayerStateService.setStance(player, true, getSafeRoomReturnCFrame())
end

local function onCharacterAdded(player: Player, character: Model)
	clearCharacterConnections(player)

	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local rootPart = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not humanoid or not rootPart then
		return
	end

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			configureCharacterPart(descendant)
		end
	end

	local descConn = character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			configureCharacterPart(descendant)
		end
	end)
	charConnections[player] = { descConn }

	-- Default spawn inside Safe Room standing stance
	PlayerStateService.setStance(player, true, nil)

	-- Defensive spawn clamp: if SafeRoom exists and Roblox placed character outside/on roof, snap cleanly to SafeSpawn
	local ventMap = workspace:FindFirstChild("VentMap")
	local safeRoom = if ventMap then ventMap:FindFirstChild("SafeRoom") else nil
	local safeSpawn = if safeRoom then safeRoom:FindFirstChild("SafeSpawn", true) else nil
	if safeSpawn and safeSpawn:IsA("BasePart") then
		task.defer(function()
			if character.Parent and rootPart.Parent then
				local y = rootPart.Position.Y
				local baseFloorY = safeSpawn.Position.Y - 0.1
				if y > baseFloorY + GameConfig.SafeRoom.CeilingHeight + 0.5 or y < baseFloorY - 0.5 then
					PlayerStateService.setStance(player, true, getSafeRoomReturnCFrame())
				end
			end
		end)
	end
end

local function onPlayerAdded(player: Player)
	player:SetAttribute(NetContracts.Attributes.HeadlampOn, true)
	player:SetAttribute(NetContracts.Attributes.InSafeRoom, true)
	player:SetAttribute(NetContracts.Attributes.IsCrawling, false)
	player:SetAttribute(NetContracts.Attributes.PanicRatio, 0)
	player:SetAttribute(NetContracts.Attributes.IsEliminated, false)
	toggleTimestamps[player] = 0
	stanceTimestamps[player] = 0

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)

	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	toggleTimestamps[player] = nil
	stanceTimestamps[player] = nil
	clearCharacterConnections(player)
end

local function wireDropShaftPrompts()
	local ventMap = workspace:WaitForChild("VentMap", 15)
	if not ventMap then
		return
	end

	local function bindPrompt(prompt: ProximityPrompt, toVents: boolean)
		prompt.Triggered:Connect(function(player: Player)
			local now = os.clock()
			if now - (stanceTimestamps[player] or 0) < STANCE_COOLDOWN then
				return
			end
			stanceTimestamps[player] = now

			if toVents then
				PlayerStateService.transitionToVents(player)
			else
				PlayerStateService.transitionToSafeRoom(player)
			end
		end)
	end

	local function checkInstance(inst: Instance)
		if inst:IsA("ProximityPrompt") then
			if inst.Name == "DropToVents" then
				bindPrompt(inst, true)
			elseif inst.Name == "ClimbToSafeRoom" then
				bindPrompt(inst, false)
			end
		end
	end

	for _, desc in ipairs(ventMap:GetDescendants()) do
		checkInstance(desc)
	end
	ventMap.DescendantAdded:Connect(checkInstance)
end

function PlayerStateService.init()
	if initialized then
		return
	end
	initialized = true

	setupCollisionGroups()

	local headlampRemote = NetContracts.getRemoteEvent(NetContracts.Remotes.HeadlampToggled, true)
	headlampRemote.OnServerEvent:Connect(function(player: Player, requestedState: unknown)
		if typeof(requestedState) ~= "boolean" then
			return
		end

		local now = os.clock()
		local lastToggle = toggleTimestamps[player] or 0
		if now - lastToggle < GameConfig.Headlamp.ToggleCooldown then
			return
		end

		toggleTimestamps[player] = now
		player:SetAttribute(NetContracts.Attributes.HeadlampOn, requestedState)
		headlampRemote:FireAllClients(player, requestedState)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	task.spawn(wireDropShaftPrompts)
end

return PlayerStateService
