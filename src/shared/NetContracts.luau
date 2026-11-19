--!strict
--[[
	Canonical network remote, attribute, and CollisionGroup contracts.
	Any additions or edits here must be synced to docs/ARCHITECTURE.md.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NetContracts = {
	RemotesFolderName = "Remotes",

	Remotes = {
		HeadlampToggled = "HeadlampToggled",
	},

	Attributes = {
		HeadlampOn = "HeadlampOn",
	},

	CollisionGroups = {
		Crawlers = "Crawlers",
		VentWalls = "VentWalls",
	},
}

function NetContracts.getOrCreateRemotesFolder(isServer: boolean): Folder
	if isServer then
		local existing = ReplicatedStorage:FindFirstChild(NetContracts.RemotesFolderName)
		if existing and existing:IsA("Folder") then
			return existing
		end
		local folder = Instance.new("Folder")
		folder.Name = NetContracts.RemotesFolderName
		folder.Parent = ReplicatedStorage
		return folder
	end

	return ReplicatedStorage:WaitForChild(NetContracts.RemotesFolderName) :: Folder
end

function NetContracts.getRemoteEvent(remoteName: string, isServer: boolean): RemoteEvent
	local folder = NetContracts.getOrCreateRemotesFolder(isServer)
	if isServer then
		local existing = folder:FindFirstChild(remoteName)
		if existing and existing:IsA("RemoteEvent") then
			return existing
		end
		local remote = Instance.new("RemoteEvent")
		remote.Name = remoteName
		remote.Parent = folder
		return remote
	end

	return folder:WaitForChild(remoteName) :: RemoteEvent
end

return NetContracts
