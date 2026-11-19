--!strict
--[[
	Server-authoritative contract lifecycle, SectorLED annunciator,
	Work Order Terminal, and Partial/Full Sign-Off XP rewards (ADR-005).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local MapLayout = require(Shared:WaitForChild("MapLayout"))
local NetContracts = require(Shared:WaitForChild("NetContracts"))

local PlayerStateService = require(script.Parent:WaitForChild("PlayerStateService"))
local RepairService = require(script.Parent:WaitForChild("RepairService"))

export type RoundPhase = "Active" | "Summary"

local RoundService = {}

local phase: RoundPhase = "Active"
local roundId = 0
local requiredCount = GameConfig.Repair.ActiveFaultCount
local totalXP = 0
local lastOutcome: string? = nil

local roundSyncRemote: RemoteEvent
local signOffRemote: RemoteEvent
local terminalLabel: TextLabel? = nil
local signOffPrompt: ProximityPrompt? = nil
local initialized = false

local function updateSectorLEDs(activeSectors: { [string]: boolean })
	for _, led in ipairs(CollectionService:GetTagged(NetContracts.Tags.SectorLED)) do
		if led:IsA("BasePart") then
			local sector = led:GetAttribute("Sector")
			local secDef = if typeof(sector) == "string" then MapLayout.Sectors[sector :: any] else nil
			local hasFault = typeof(sector) == "string" and activeSectors[sector] == true

			if hasFault then
				led.Material = Enum.Material.Neon
				led.Color = if secDef then secDef.color else Color3.fromRGB(255, 80, 50)
			else
				led.Material = Enum.Material.SmoothPlastic
				led.Color = Color3.fromRGB(32, 38, 44)
			end
		end
	end
end

local function formatSectorList(activeSectors: { [string]: boolean }): string
	local list: { string } = {}
	for _, sec in ipairs({ "A", "B", "C", "D" }) do
		if activeSectors[sec] then
			table.insert(list, sec)
		end
	end
	if #list == 0 then
		return "NONE (ALL CLEAR)"
	end
	return table.concat(list, ", ")
end

local function updateWorkOrderTerminal(activeSectors: { [string]: boolean }, repairedCount: number)
	if not terminalLabel then
		return
	end

	if phase == "Active" then
		terminalLabel.Text = string.format(
			"WORK ORDER: ACTIVE\nREPAIRED: %d / %d\nFAULT SECTORS: %s\nTOTAL XP: %d\n\n[E] LOCK & SIGN OFF",
			repairedCount,
			requiredCount,
			formatSectorList(activeSectors),
			totalXP
		)
		terminalLabel.TextColor3 = if repairedCount >= requiredCount
			then Color3.fromRGB(115, 240, 155)
			else Color3.fromRGB(215, 232, 255)
	else
		terminalLabel.Text = string.format(
			"WORK ORDER SIGNED OFF\n%s\nTOTAL XP: %d\nRESETTING CONTRACT...",
			lastOutcome or "",
			totalXP
		)
		terminalLabel.TextColor3 = Color3.fromRGB(255, 215, 110)
	end

	if signOffPrompt then
		signOffPrompt.Enabled = (phase == "Active")
	end
end

local function buildStatePayload()
	local activeSectors = RepairService.getActiveFaultSectors()
	local repairedCount = RepairService.getRepairedCount()
	return {
		phase = phase,
		activeSectors = activeSectors,
		repairedCount = repairedCount,
		requiredCount = requiredCount,
		totalXP = totalXP,
		lastOutcome = lastOutcome,
	}
end

local function broadcastState()
	local payload = buildStatePayload()
	updateSectorLEDs(payload.activeSectors)
	updateWorkOrderTerminal(payload.activeSectors, payload.repairedCount)
	roundSyncRemote:FireAllClients(payload)
end

local function pickBalancedFaultIds(count: number): { string }
	local slots = MapLayout.getRepairSlots()
	local bySector: { [string]: { string } } = { A = {}, B = {}, C = {}, D = {} }
	for _, slot in ipairs(slots) do
		local bucket = bySector[slot.sector]
		if bucket then
			table.insert(bucket, slot.nodeId)
		end
	end

	local selected: { string } = {}
	local used: { [string]: boolean } = {}
	local sectors = { "A", "B", "C", "D" }

	-- Shuffle sectors, pick 1 from each up to count so faults span the facility
	for i = #sectors, 2, -1 do
		local j = math.random(1, i)
		sectors[i], sectors[j] = sectors[j], sectors[i]
	end

	for _, sec in ipairs(sectors) do
		if #selected >= count then
			break
		end
		local bucket = bySector[sec]
		if bucket and #bucket > 0 then
			local pick = bucket[math.random(1, #bucket)]
			table.insert(selected, pick)
			used[pick] = true
		end
	end

	-- Fill remaining from unused slots
	local remaining: { string } = {}
	for _, slot in ipairs(slots) do
		if not used[slot.nodeId] then
			table.insert(remaining, slot.nodeId)
		end
	end
	for i = #remaining, 2, -1 do
		local j = math.random(1, i)
		remaining[i], remaining[j] = remaining[j], remaining[i]
	end

	for _, id in ipairs(remaining) do
		if #selected >= count then
			break
		end
		table.insert(selected, id)
	end

	return selected
end

function RoundService.startNewRound()
	roundId += 1
	phase = "Active"
	lastOutcome = nil

	local selected = pickBalancedFaultIds(requiredCount)
	RepairService.activateFaults(selected)

	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute(NetContracts.Attributes.InSafeRoom) ~= true then
			PlayerStateService.transitionToSafeRoom(player)
		end
	end

	broadcastState()
end

function RoundService.trySignOff(player: Player): boolean
	if phase ~= "Active" then
		return false
	end
	if player:GetAttribute(NetContracts.Attributes.InSafeRoom) ~= true then
		return false
	end

	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid or humanoid.Health <= 0 then
		return false
	end

	local repaired = RepairService.getRepairedCount()
	local awardedXP = 0
	local label = ""

	if repaired <= 0 then
		label = "ZERO-PROGRESS ABORT (+0 XP)"
	elseif repaired < requiredCount then
		awardedXP = repaired * GameConfig.WorkOrder.BaseXPPerRepair
		label = string.format("PARTIAL SIGN-OFF: %d/%d FIXED (+%d XP)", repaired, requiredCount, awardedXP)
	else
		awardedXP = repaired * GameConfig.WorkOrder.BaseXPPerRepair + GameConfig.WorkOrder.FullClearBonusXP
		label = string.format("FULL SIGN-OFF: %d/%d FIXED (+%d XP)", repaired, requiredCount, awardedXP)
	end

	totalXP += awardedXP
	phase = "Summary"
	lastOutcome = label
	broadcastState()

	local thisRound = roundId
	task.delay(GameConfig.WorkOrder.RoundResetDelay, function()
		if roundId == thisRound and phase == "Summary" then
			RoundService.startNewRound()
		end
	end)

	return true
end

function RoundService.getState()
	return buildStatePayload()
end

local function wireSafeRoomTerminal()
	local ventMap = workspace:WaitForChild("VentMap", 10)
	if not ventMap then
		return
	end
	local safeRoom = ventMap:FindFirstChild("SafeRoom")
	if not safeRoom then
		return
	end

	local monitor = safeRoom:FindFirstChild("WorkOrderMonitor")
	if monitor and monitor:IsA("BasePart") then
		local gui = monitor:FindFirstChildOfClass("SurfaceGui")
		local lbl = if gui then gui:FindFirstChildOfClass("TextLabel") else nil
		if lbl then
			terminalLabel = lbl
		end

		local prompt = monitor:FindFirstChild("SignOffPrompt") :: ProximityPrompt?
		if not prompt then
			local newPrompt = Instance.new("ProximityPrompt")
			newPrompt.Name = "SignOffPrompt"
			newPrompt.ActionText = "Lock & Sign Off Work Order"
			newPrompt.ObjectText = "Work Order Terminal"
			newPrompt.HoldDuration = 0.8
			newPrompt.MaxActivationDistance = 7
			newPrompt.RequiresLineOfSight = false
			newPrompt.Parent = monitor
			prompt = newPrompt
		end
		signOffPrompt = prompt
		if prompt then
			prompt.Triggered:Connect(function(player: Player)
				RoundService.trySignOff(player)
			end)
		end
	end
end

function RoundService.init()
	if initialized then
		return
	end
	initialized = true

	roundSyncRemote = NetContracts.getRemoteEvent(NetContracts.Remotes.RoundStateSync, true)
	signOffRemote = NetContracts.getRemoteEvent(NetContracts.Remotes.WorkOrderSignOff, true)

	signOffRemote.OnServerEvent:Connect(function(player: Player)
		RoundService.trySignOff(player)
	end)

	RepairService.init(function(_nodeId: string, _sector: string)
		broadcastState()
	end)

	wireSafeRoomTerminal()

	Players.PlayerAdded:Connect(function(player: Player)
		task.defer(function()
			if player.Parent then
				roundSyncRemote:FireClient(player, buildStatePayload())
			end
		end)
	end)

	RoundService.startNewRound()
end

return RoundService
