--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EntityProfiles = require(Shared:WaitForChild("EntityProfiles"))
local PlayerStateService = require(script:WaitForChild("PlayerStateService"))

PlayerStateService.init()

local activeEntity = EntityProfiles.getActiveProfile()
print(string.format("[Server] M1 initialized | Flagship Entity: %s", activeEntity.id))
