--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EntityProfiles = require(Shared:WaitForChild("EntityProfiles"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local MapLayout = require(Shared:WaitForChild("MapLayout"))

local EntityService = require(script:WaitForChild("EntityService"))
local PlayerStateService = require(script:WaitForChild("PlayerStateService"))
local RepairService = require(script:WaitForChild("RepairService"))
local RoundService = require(script:WaitForChild("RoundService"))

local ok, errs = MapLayout.validate()
if not ok then
	error("[Server] MapLayout validation failed: " .. table.concat(errs, "; "))
end

PlayerStateService.init()
RoundService.init()
EntityService.init()

RepairService.setNoiseCallback(function(worldPos: Vector3)
	EntityService.alertNoise(worldPos, GameConfig.Entity.RepairNoiseRadius)
end)

local activeEntity = EntityProfiles.getActiveProfile()
print(string.format(
	"[Server] M4 initialized | MapLayout: %d tiles | Contract: %d faults | Entity AI: %s (%s)",
	#MapLayout.Tiles,
	RoundService.getState().requiredCount,
	activeEntity.id,
	EntityService.getState()
))
