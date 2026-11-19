--!strict
--[[
	Server-authoritative player crawl physics, CollisionGroup registration,
	and Headlamp state replication for 1-4 co-op players.
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

local toggleTimestamps: { [Player]: number } = {}
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

	ensureCollisionGroup(crawlers)
	ensureCollisionGroup(ventWalls)

	-- Co-op players can share tight ducts without body-block griefing.
	PhysicsService:CollisionGroupSetCollidable(crawlers, crawlers, false)
	PhysicsService:CollisionGroupSetCollidable(crawlers, ventWalls, true)
	PhysicsService:CollisionGroupSetCollidable(crawlers, "Default", true)
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

local function onCharacterAdded(player: Player, character: Model)
	clearCharacterConnections(player)

	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local rootPart = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not humanoid or not rootPart then
		return
	end

	humanoid.WalkSpeed = GameConfig.Crawl.ForwardWalkSpeed
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.HipHeight = GameConfig.Crawl.HipHeight

	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)

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

	-- Enclosed 4.2-stud duct ceilings can cause Roblox SpawnLocation to push spawns onto the roof;
	-- snap the character inside TestSpawn when present.
	local testBox = workspace:FindFirstChild("M1_TestVentBox")
	local ventSpawn = if testBox then testBox:FindFirstChild("TestSpawn", true) else nil
	if ventSpawn and ventSpawn:IsA("BasePart") then
		task.defer(function()
			if character.Parent and rootPart.Parent and rootPart.Position.Y > ventSpawn.Position.Y + 3.0 then
				character:PivotTo(CFrame.new(ventSpawn.Position.X, ventSpawn.Position.Y + 1.35, ventSpawn.Position.Z))
			end
		end)
	end
end

local function onPlayerAdded(player: Player)
	player:SetAttribute(NetContracts.Attributes.HeadlampOn, true)
	toggleTimestamps[player] = 0

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)

	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	toggleTimestamps[player] = nil
	clearCharacterConnections(player)
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
end

return PlayerStateService
