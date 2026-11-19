--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EntityProfiles = require(Shared:WaitForChild("EntityProfiles"))
local MapLayout = require(Shared:WaitForChild("MapLayout"))
local PlayerStateService = require(script:WaitForChild("PlayerStateService"))

local ok, errs = MapLayout.validate()
if not ok then
	error("[Server] MapLayout validation failed: " .. table.concat(errs, "; "))
end

PlayerStateService.init()

local activeEntity = EntityProfiles.getActiveProfile()
print(string.format(
	"[Server] M2 initialized | MapLayout valid: %d tiles, %d repair nodes, 4 sectors | Flagship Entity: %s",
	#MapLayout.Tiles,
	#MapLayout.getRepairSlots(),
	activeEntity.id
))
