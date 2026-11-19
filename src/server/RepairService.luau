--!strict
--[[
	Server-authoritative RepairNode manager:
	- Activates randomized faults each contract.
	- Supports interruptible ProximityPrompt holds with saved RepairProgress (0..1).
	- Drives node StatusStrips, fault lights, and spark ParticleEmitters.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local MapLayout = require(Shared:WaitForChild("MapLayout"))
local NetContracts = require(Shared:WaitForChild("NetContracts"))

export type NodeRepairedCallback = (nodeId: string, sector: string) -> ()
export type RepairNoiseCallback = (worldPos: Vector3) -> ()

local RepairService = {}

type ActiveHold = {
	player: Player,
	startTime: number,
	startProgress: number,
	lastNoiseTime: number,
}

local COLOR_STANDBY = Color3.fromRGB(65, 72, 80)
local COLOR_FAULT = Color3.fromRGB(255, 110, 45)
local COLOR_REPAIRED = Color3.fromRGB(64, 210, 115)

local nodesById: { [string]: Model } = {}
local activeHolds: { [Model]: ActiveHold } = {}
local onNodeRepairedCallback: NodeRepairedCallback? = nil
local onRepairNoiseCallback: RepairNoiseCallback? = nil
local onRepairBeganCallback: ((player: Player) -> ())? = nil
local initialized = false

local function getPrompt(nodeModel: Model): ProximityPrompt?
	local body = nodeModel.PrimaryPart
	if not body then
		return nil
	end
	return body:FindFirstChild("RepairPrompt") :: ProximityPrompt?
end

local function getSparks(nodeModel: Model): ParticleEmitter?
	local body = nodeModel.PrimaryPart
	if not body then
		return nil
	end
	return body:FindFirstChild("SparkEmitter") :: ParticleEmitter?
end

local function getFaultLight(nodeModel: Model): PointLight?
	local body = nodeModel.PrimaryPart
	if not body then
		return nil
	end
	return body:FindFirstChild("FaultLight") :: PointLight?
end

local function updateNodeVisuals(nodeModel: Model)
	local isActive = nodeModel:GetAttribute("IsActiveFault") == true
	local isRepaired = nodeModel:GetAttribute("IsRepaired") == true
	local progress = (nodeModel:GetAttribute("RepairProgress") :: number?) or 0
	local nodeId = (nodeModel:GetAttribute("NodeId") :: string?) or "?"

	local strip = nodeModel:FindFirstChild("StatusStrip") :: BasePart?
	local prompt = getPrompt(nodeModel)
	local sparks = getSparks(nodeModel)
	local light = getFaultLight(nodeModel)

	if isRepaired then
		if strip then
			strip.Color = COLOR_REPAIRED
			strip.Material = Enum.Material.Neon
		end
		if prompt then
			prompt.Enabled = false
		end
		if sparks then
			sparks.Enabled = false
		end
		if light then
			light.Enabled = true
			light.Color = COLOR_REPAIRED
			light.Brightness = 0.35
		end
	elseif isActive then
		if strip then
			strip.Color = COLOR_FAULT
			strip.Material = Enum.Material.Neon
		end
		if prompt then
			prompt.Enabled = true
			prompt.HoldDuration = math.max(0.25, (1 - progress) * GameConfig.Repair.RepairDurationSeconds)
			prompt.ActionText = if progress > 0.01 then "Resume Repair" else "Repair Fault"
			prompt.ObjectText = string.format("Fault %s (%d%%)", nodeId, math.floor(progress * 100))
		end
		if sparks then
			sparks.Enabled = activeHolds[nodeModel] ~= nil
		end
		if light then
			light.Enabled = true
			light.Color = COLOR_FAULT
			light.Brightness = 0.7
		end
	else
		local sector = (nodeModel:GetAttribute("Sector") :: string?) or "A"
		local secDef = MapLayout.Sectors[sector :: any]
		if strip then
			strip.Color = if secDef then secDef.color else COLOR_STANDBY
			strip.Material = Enum.Material.SmoothPlastic
		end
		if prompt then
			prompt.Enabled = false
		end
		if sparks then
			sparks.Enabled = false
		end
		if light then
			light.Enabled = false
		end
	end
end

function RepairService.setNodeProgress(nodeModel: Model, progress: number)
	if nodeModel:GetAttribute("IsActiveFault") ~= true or nodeModel:GetAttribute("IsRepaired") == true then
		return
	end
	local clamped = math.clamp(progress, 0, 0.99)
	nodeModel:SetAttribute("RepairProgress", clamped)
	updateNodeVisuals(nodeModel)
end

function RepairService.completeNode(nodeModel: Model)
	if nodeModel:GetAttribute("IsActiveFault") ~= true or nodeModel:GetAttribute("IsRepaired") == true then
		return
	end

	activeHolds[nodeModel] = nil
	nodeModel:SetAttribute("RepairProgress", 1.0)
	nodeModel:SetAttribute("IsRepaired", true)
	nodeModel:SetAttribute("IsActiveFault", false)
	updateNodeVisuals(nodeModel)

	if onNodeRepairedCallback then
		local nodeId = (nodeModel:GetAttribute("NodeId") :: string?) or "?"
		local sector = (nodeModel:GetAttribute("Sector") :: string?) or "A"
		onNodeRepairedCallback(nodeId, sector)
	end
end

local function isPlayerAliveNear(player: Player, body: BasePart): boolean
	local character = player.Character
	if not character then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root or humanoid.Health <= 0 then
		return false
	end
	return (root.Position - body.Position).Magnitude <= (GameConfig.Repair.PromptMaxDistance + 5)
end

local function setupNode(nodeModel: Model)
	local nodeId = nodeModel:GetAttribute("NodeId")
	if typeof(nodeId) ~= "string" then
		return
	end
	nodesById[nodeId] = nodeModel

	local body = nodeModel.PrimaryPart or nodeModel:FindFirstChild("JunctionBox") :: BasePart?
	if not body then
		return
	end
	nodeModel.PrimaryPart = body

	local prompt = body:FindFirstChild("RepairPrompt") :: ProximityPrompt?
	if not prompt then
		local newPrompt = Instance.new("ProximityPrompt")
		newPrompt.Name = "RepairPrompt"
		newPrompt.ActionText = "Repair Fault"
		newPrompt.ObjectText = "Fault " .. nodeId
		newPrompt.HoldDuration = GameConfig.Repair.RepairDurationSeconds
		newPrompt.MaxActivationDistance = GameConfig.Repair.PromptMaxDistance
		newPrompt.RequiresLineOfSight = false
		newPrompt.Enabled = false
		newPrompt.Parent = body
		prompt = newPrompt
	end

	if not body:FindFirstChild("SparkEmitter") then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "SparkEmitter"
		emitter.Enabled = false
		emitter.Rate = 24
		emitter.Lifetime = NumberRange.new(0.15, 0.35)
		emitter.Speed = NumberRange.new(3, 7)
		emitter.SpreadAngle = Vector2.new(65, 65)
		emitter.Size = NumberSequence.new(0.08, 0)
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 95, 30))
		emitter.LightEmission = 1
		emitter.Parent = body
	end

	if not body:FindFirstChild("FaultLight") then
		local light = Instance.new("PointLight")
		light.Name = "FaultLight"
		light.Enabled = false
		light.Range = 10
		light.Shadows = true
		light.Parent = body
	end

	if prompt then
		prompt.PromptButtonHoldBegan:Connect(function(player: Player)
			if nodeModel:GetAttribute("IsActiveFault") ~= true or nodeModel:GetAttribute("IsRepaired") == true then
				return
			end
			if activeHolds[nodeModel] ~= nil then
				return
			end
			if not isPlayerAliveNear(player, body) then
				return
			end

			local currentProgress = (nodeModel:GetAttribute("RepairProgress") :: number?) or 0
			activeHolds[nodeModel] = {
				player = player,
				startTime = os.clock(),
				startProgress = currentProgress,
				lastNoiseTime = 0,
			}
			updateNodeVisuals(nodeModel)

			-- Give the player 0.8s to commit to repairing before potentially triggering a corner-peek
			task.delay(0.8, function()
				local hold = activeHolds[nodeModel]
				if hold and hold.player == player and onRepairBeganCallback then
					onRepairBeganCallback(player)
				end
			end)
		end)

		prompt.PromptButtonHoldEnded:Connect(function(player: Player)
			local hold = activeHolds[nodeModel]
			if not hold or hold.player ~= player then
				return
			end
			activeHolds[nodeModel] = nil

			if nodeModel:GetAttribute("IsRepaired") == true then
				return
			end

			local elapsed = os.clock() - hold.startTime
			local saved = math.clamp(
				hold.startProgress + elapsed / GameConfig.Repair.RepairDurationSeconds,
				0,
				0.95
			)
			nodeModel:SetAttribute("RepairProgress", saved)
			updateNodeVisuals(nodeModel)
		end)

		prompt.Triggered:Connect(function(player: Player)
			if not isPlayerAliveNear(player, body) then
				return
			end
			RepairService.completeNode(nodeModel)
		end)
	end

	updateNodeVisuals(nodeModel)
end

function RepairService.activateFaults(selectedNodeIds: { string })
	table.clear(activeHolds)

	local activeLookup: { [string]: boolean } = {}
	for _, id in ipairs(selectedNodeIds) do
		activeLookup[id] = true
	end

	for nodeId, nodeModel in pairs(nodesById) do
		local isSelected = activeLookup[nodeId] == true
		nodeModel:SetAttribute("IsActiveFault", isSelected)
		nodeModel:SetAttribute("IsRepaired", false)
		nodeModel:SetAttribute("RepairProgress", 0)
		updateNodeVisuals(nodeModel)
	end
end

function RepairService.getNodeById(nodeId: string): Model?
	return nodesById[nodeId]
end

function RepairService.getActiveFaultSectors(): { [string]: boolean }
	local sectors: { [string]: boolean } = {}
	for _, nodeModel in pairs(nodesById) do
		if nodeModel:GetAttribute("IsActiveFault") == true and nodeModel:GetAttribute("IsRepaired") ~= true then
			local sector = nodeModel:GetAttribute("Sector")
			if typeof(sector) == "string" then
				sectors[sector] = true
			end
		end
	end
	return sectors
end

function RepairService.getRepairedCount(): number
	local count = 0
	for _, nodeModel in pairs(nodesById) do
		if nodeModel:GetAttribute("IsRepaired") == true then
			count += 1
		end
	end
	return count
end

function RepairService.setNoiseCallback(callback: RepairNoiseCallback?)
	onRepairNoiseCallback = callback
end

function RepairService.setRepairBeganCallback(callback: ((player: Player) -> ())?)
	onRepairBeganCallback = callback
end

function RepairService.init(onRepaired: NodeRepairedCallback?)
	if initialized then
		return
	end
	initialized = true
	onNodeRepairedCallback = onRepaired

	for _, inst in ipairs(CollectionService:GetTagged(NetContracts.Tags.RepairNode)) do
		if inst:IsA("Model") then
			setupNode(inst)
		end
	end

	CollectionService:GetInstanceAddedSignal(NetContracts.Tags.RepairNode):Connect(function(inst)
		if inst:IsA("Model") then
			setupNode(inst)
		end
	end)

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for nodeModel, hold in pairs(activeHolds) do
			local body = nodeModel.PrimaryPart
			if not hold.player.Parent or not body or not isPlayerAliveNear(hold.player, body) then
				activeHolds[nodeModel] = nil
				updateNodeVisuals(nodeModel)
			else
				local elapsed = now - hold.startTime
				local liveProgress = math.clamp(
					hold.startProgress + elapsed / GameConfig.Repair.RepairDurationSeconds,
					0,
					0.99
				)
				nodeModel:SetAttribute("RepairProgress", liveProgress)
				if onRepairNoiseCallback and now - hold.lastNoiseTime >= 1.4 then
					hold.lastNoiseTime = now
					onRepairNoiseCallback(body.Position)
				end
			end
		end
	end)
end

return RepairService
