--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EntityProfiles = require(Shared:WaitForChild("EntityProfiles"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local MapLayout = require(Shared:WaitForChild("MapLayout"))
local NetContracts = require(Shared:WaitForChild("NetContracts"))

-- Ensure every canonical RemoteEvent exists immediately in both Lobby and Match modes.
for _, remoteName in pairs(NetContracts.Remotes) do
	NetContracts.getRemoteEvent(remoteName, true)
end

local EntityService = require(script:WaitForChild("EntityService"))
local LobbyService = require(script:WaitForChild("LobbyService"))
local PlayerStateService = require(script:WaitForChild("PlayerStateService"))
local RepairService = require(script:WaitForChild("RepairService"))
local RoundService = require(script:WaitForChild("RoundService"))

local ok, errs = MapLayout.validate()
if not ok then
	error("[Server] MapLayout validation failed: " .. table.concat(errs, "; "))
end

local matchServicesStarted = false

local function startMatchServices()
	if matchServicesStarted then
		RoundService.startNewRound()
		return
	end
	matchServicesStarted = true

	RoundService.init()
	EntityService.init()

	RepairService.setNoiseCallback(function(worldPos: Vector3)
		EntityService.alertNoise(worldPos, GameConfig.Entity.RepairNoiseRadius)
	end)
	EntityService.setEliminatedCallback(function(_player: Player)
		RoundService.checkSquadWipe()
	end)

	local activeEntity = EntityProfiles.getActiveProfile()
	print(string.format(
		"[Server] Match services initialized | MapLayout: %d tiles | Contract: %d faults | Entity AI: %s (%s)",
		#MapLayout.Tiles,
		RoundService.getState().requiredCount,
		activeEntity.id,
		EntityService.getState()
	))
end

PlayerStateService.init()
LobbyService.init(startMatchServices)

local mode = LobbyService.getServerMode()
if mode == "Match" then
	startMatchServices()
else
	print(string.format("[Server] Dispatch Lobby initialized | MapLayout: %d tiles | Waiting for parties", #MapLayout.Tiles))
end
