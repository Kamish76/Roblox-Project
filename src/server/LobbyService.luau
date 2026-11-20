--!strict
--[[
	Server-authoritative Party Lobby & Reserved-Server Matchmaking service (ADR-010).
	- Single-Place Reserved Server pattern:
		* Public / VIP servers boot in ServerMode = "Lobby".
		* Reserved servers (PrivateServerId ~= "" and PrivateServerOwnerId == 0) boot in ServerMode = "Match".
		* Roblox Studio defaults to GameConfig.Lobby.StudioStartMode ("Lobby") with an in-place Match fallback.
	- Supports Create/Join/Code-Join/Leave/Kick/Ready/Settings/Launch (1-4 players, Public | Friends | Private).
	- Supports Return to Lobby from Match servers (TeleportAsync to public place, or in-place reset in Studio).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local NetContracts = require(Shared:WaitForChild("NetContracts"))

local PlayerStateService = require(script.Parent:WaitForChild("PlayerStateService"))

export type ServerMode = "Lobby" | "Match"
export type LobbyPrivacy = "Public" | "Friends" | "Private"
export type LobbyStatus = "Waiting" | "Launching"

export type LobbyMember = {
	userId: number,
	name: string,
	displayName: string,
	isReady: boolean,
}

type LobbyRecord = {
	id: string,
	code: string,
	hostUserId: number,
	hostName: string,
	maxPlayers: number,
	privacy: LobbyPrivacy,
	status: LobbyStatus,
	countdown: number,
	launchToken: number,
	members: { LobbyMember },
}

local LobbyService = {}

local CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
local VALID_PRIVACY: { [string]: boolean } = {
	Public = true,
	Friends = true,
	Private = true,
}

local serverMode: ServerMode = "Lobby"
local initialized = false
local nextLobbySeq = 0

local lobbies: { [string]: LobbyRecord } = {}
local playerLobbyMap: { [number]: string } = {}
local actionTimestamps: { [Player]: number } = {}
local returnTimestamps: { [Player]: number } = {}

local lobbyActionRemote: RemoteEvent
local lobbySyncRemote: RemoteEvent
local returnLobbyRemote: RemoteEvent
local returnLobbyPrompt: ProximityPrompt? = nil

local onStudioLaunchCallback: (() -> ())? = nil

function LobbyService.detectInitialMode(): ServerMode
	if RunService:IsStudio() then
		return if GameConfig.Lobby.StudioStartMode == "Match" then "Match" else "Lobby"
	end
	-- Reserved servers created via TeleportService:ReserveServer have PrivateServerId ~= "" and PrivateServerOwnerId == 0.
	if game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0 then
		return "Match"
	end
	return "Lobby"
end

function LobbyService.getServerMode(): ServerMode
	return serverMode
end

local function setServerMode(newMode: ServerMode)
	serverMode = newMode
	ReplicatedStorage:SetAttribute(NetContracts.Attributes.ServerMode, newMode)
	if returnLobbyPrompt then
		returnLobbyPrompt.Enabled = (newMode == "Match")
	end
end

local function generateJoinCode(): string
	local len = GameConfig.Lobby.CodeLength
	local alphaLen = #CODE_ALPHABET
	for _attempt = 1, 24 do
		local chars = table.create(len)
		for i = 1, len do
			local idx = math.random(1, alphaLen)
			chars[i] = string.sub(CODE_ALPHABET, idx, idx)
		end
		local candidate = table.concat(chars)
		local collision = false
		for _, lobby in pairs(lobbies) do
			if lobby.code == candidate then
				collision = true
				break
			end
		end
		if not collision then
			return candidate
		end
	end
	return string.format("L%03d", math.random(100, 999))
end

local function findMemberIndex(lobby: LobbyRecord, userId: number): number?
	for i, member in ipairs(lobby.members) do
		if member.userId == userId then
			return i
		end
	end
	return nil
end

local function buildPayloadForPlayer(player: Player, toast: string?, toastIsError: boolean?)
	local myLobbyId = playerLobbyMap[player.UserId]
	local publicList = {}

	for _, lobby in pairs(lobbies) do
		local isMember = (myLobbyId == lobby.id)
		local membersCopy = table.create(#lobby.members)
		for i, m in ipairs(lobby.members) do
			membersCopy[i] = {
				userId = m.userId,
				name = m.name,
				displayName = m.displayName,
				isReady = m.isReady,
			}
		end

		table.insert(publicList, {
			id = lobby.id,
			code = if isMember then lobby.code else nil,
			hostUserId = lobby.hostUserId,
			hostName = lobby.hostName,
			maxPlayers = lobby.maxPlayers,
			privacy = lobby.privacy,
			status = lobby.status,
			countdown = lobby.countdown,
			memberCount = #lobby.members,
			members = membersCopy,
		})
	end

	table.sort(publicList, function(a, b)
		if a.id == myLobbyId and b.id ~= myLobbyId then
			return true
		end
		if b.id == myLobbyId and a.id ~= myLobbyId then
			return false
		end
		return a.id < b.id
	end)

	return {
		serverMode = serverMode,
		isStudio = RunService:IsStudio(),
		myLobbyId = myLobbyId,
		lobbies = publicList,
		toast = toast,
		toastIsError = toastIsError == true,
	}
end

local function syncPlayer(player: Player, toast: string?, toastIsError: boolean?)
	if not player.Parent then
		return
	end
	lobbySyncRemote:FireClient(player, buildPayloadForPlayer(player, toast, toastIsError))
end

local function broadcastAll(toastByUserId: { [number]: { text: string, isError: boolean } }?)
	for _, player in ipairs(Players:GetPlayers()) do
		local msg = if toastByUserId then toastByUserId[player.UserId] else nil
		syncPlayer(player, if msg then msg.text else nil, if msg then msg.isError else false)
	end
end

local function removePlayerFromLobby(userId: number, reasonToast: string?): boolean
	local lobbyId = playerLobbyMap[userId]
	if not lobbyId then
		return false
	end
	playerLobbyMap[userId] = nil

	local lobby = lobbies[lobbyId]
	if not lobby then
		return false
	end

	local idx = findMemberIndex(lobby, userId)
	if idx then
		table.remove(lobby.members, idx)
	end

	-- Cancel any active launch countdown if squad composition changes.
	if lobby.status == "Launching" then
		lobby.status = "Waiting"
		lobby.countdown = 0
		lobby.launchToken += 1
	end

	if #lobby.members == 0 then
		lobbies[lobbyId] = nil
	elseif lobby.hostUserId == userId then
		local newHost = lobby.members[1]
		lobby.hostUserId = newHost.userId
		lobby.hostName = newHost.displayName
		newHost.isReady = true
	end

	if reasonToast then
		local p = Players:GetPlayerByUserId(userId)
		if p then
			syncPlayer(p, reasonToast, true)
		end
	end

	return true
end

local function canJoinLobby(player: Player, lobby: LobbyRecord, suppliedCode: string?): (boolean, string?)
	if lobby.status ~= "Waiting" then
		return false, "Lobby is already launching."
	end
	if #lobby.members >= lobby.maxPlayers then
		return false, "Lobby is full."
	end

	local normalizedCode = if typeof(suppliedCode) == "string" then string.upper(string.gsub(suppliedCode, "%s+", "")) else ""
	local codeMatches = (normalizedCode ~= "" and normalizedCode == lobby.code)

	if lobby.privacy == "Public" then
		return true, nil
	elseif lobby.privacy == "Private" then
		if codeMatches then
			return true, nil
		end
		return false, "Private lobby requires the 4-character Join Code."
	elseif lobby.privacy == "Friends" then
		if codeMatches or player.UserId == lobby.hostUserId then
			return true, nil
		end
		local okFriend, isFriend = pcall(function()
			return player:IsFriendsWith(lobby.hostUserId)
		end)
		if okFriend and isFriend then
			return true, nil
		end
		return false, "Friends-Only lobby. Be friends with the host or enter the Join Code."
	end

	return false, "Cannot join this lobby."
end

local function handleCreate(player: Player, payload: { [string]: any })
	if serverMode ~= "Lobby" then
		return
	end

	removePlayerFromLobby(player.UserId, nil)

	local requestedMax = if typeof(payload.maxPlayers) == "number" then math.floor(payload.maxPlayers) else GameConfig.Lobby.MaxPartySize
	local maxPlayers = math.clamp(requestedMax, GameConfig.Lobby.MinPartySize, GameConfig.Lobby.MaxPartySize)

	local requestedPrivacy = if typeof(payload.privacy) == "string" and VALID_PRIVACY[payload.privacy] then payload.privacy else "Public"

	nextLobbySeq += 1
	local id = string.format("LOBBY_%d", nextLobbySeq)
	local code = generateJoinCode()

	local record: LobbyRecord = {
		id = id,
		code = code,
		hostUserId = player.UserId,
		hostName = player.DisplayName,
		maxPlayers = maxPlayers,
		privacy = requestedPrivacy :: LobbyPrivacy,
		status = "Waiting",
		countdown = 0,
		launchToken = 0,
		members = {
			{
				userId = player.UserId,
				name = player.Name,
				displayName = player.DisplayName,
				isReady = true,
			},
		},
	}

	lobbies[id] = record
	playerLobbyMap[player.UserId] = id
	broadcastAll({
		[player.UserId] = { text = string.format("Lobby created! Share code: %s", code), isError = false },
	})
end

local function handleJoin(player: Player, payload: { [string]: any })
	if serverMode ~= "Lobby" then
		return
	end

	local targetLobby: LobbyRecord? = nil
	local suppliedCode = if typeof(payload.code) == "string" then string.upper(string.gsub(payload.code, "%s+", "")) else nil

	if typeof(payload.lobbyId) == "string" then
		targetLobby = lobbies[payload.lobbyId]
	elseif suppliedCode and suppliedCode ~= "" then
		for _, lobby in pairs(lobbies) do
			if lobby.code == suppliedCode then
				targetLobby = lobby
				break
			end
		end
	end

	if not targetLobby then
		syncPlayer(player, "Lobby not found. Check the code and try again.", true)
		return
	end

	if playerLobbyMap[player.UserId] == targetLobby.id then
		syncPlayer(player, nil, false)
		return
	end

	local allowed, reason = canJoinLobby(player, targetLobby, suppliedCode)
	if not allowed then
		syncPlayer(player, reason or "Unable to join lobby.", true)
		return
	end

	removePlayerFromLobby(player.UserId, nil)

	table.insert(targetLobby.members, {
		userId = player.UserId,
		name = player.Name,
		displayName = player.DisplayName,
		isReady = false,
	})
	playerLobbyMap[player.UserId] = targetLobby.id
	broadcastAll({
		[player.UserId] = { text = string.format("Joined %s's lobby!", targetLobby.hostName), isError = false },
	})
end

local function handleLeave(player: Player)
	if serverMode ~= "Lobby" then
		return
	end
	if removePlayerFromLobby(player.UserId, nil) then
		broadcastAll({
			[player.UserId] = { text = "Left the lobby.", isError = false },
		})
	end
end

local function handleToggleReady(player: Player)
	if serverMode ~= "Lobby" then
		return
	end
	local lobbyId = playerLobbyMap[player.UserId]
	local lobby = if lobbyId then lobbies[lobbyId] else nil
	if not lobby or lobby.status ~= "Waiting" then
		return
	end
	if lobby.hostUserId == player.UserId then
		return
	end

	local idx = findMemberIndex(lobby, player.UserId)
	if not idx then
		return
	end
	lobby.members[idx].isReady = not lobby.members[idx].isReady
	broadcastAll(nil)
end

local function handleUpdateSettings(player: Player, payload: { [string]: any })
	if serverMode ~= "Lobby" then
		return
	end
	local lobbyId = playerLobbyMap[player.UserId]
	local lobby = if lobbyId then lobbies[lobbyId] else nil
	if not lobby or lobby.hostUserId ~= player.UserId or lobby.status ~= "Waiting" then
		return
	end

	if typeof(payload.maxPlayers) == "number" then
		local clamped = math.clamp(math.floor(payload.maxPlayers), math.max(GameConfig.Lobby.MinPartySize, #lobby.members), GameConfig.Lobby.MaxPartySize)
		lobby.maxPlayers = clamped
	end
	if typeof(payload.privacy) == "string" and VALID_PRIVACY[payload.privacy] then
		lobby.privacy = payload.privacy :: LobbyPrivacy
	end
	broadcastAll(nil)
end

local function handleKick(player: Player, payload: { [string]: any })
	if serverMode ~= "Lobby" then
		return
	end
	local lobbyId = playerLobbyMap[player.UserId]
	local lobby = if lobbyId then lobbies[lobbyId] else nil
	if not lobby or lobby.hostUserId ~= player.UserId or lobby.status ~= "Waiting" then
		return
	end

	local targetUserId = payload.targetUserId
	if typeof(targetUserId) ~= "number" or targetUserId == player.UserId then
		return
	end
	if not findMemberIndex(lobby, targetUserId) then
		return
	end

	removePlayerFromLobby(targetUserId, "You were removed from the lobby by the host.")
	broadcastAll(nil)
end

local function executeLaunch(lobby: LobbyRecord)
	local memberPlayers: { Player } = {}
	for _, member in ipairs(lobby.members) do
		local p = Players:GetPlayerByUserId(member.userId)
		if p and p.Parent then
			table.insert(memberPlayers, p)
		end
	end

	if #memberPlayers == 0 then
		lobbies[lobby.id] = nil
		broadcastAll(nil)
		return
	end

	-- Studio fallback: TeleportService cannot teleport inside Studio, so transition in-place to Match mode.
	if RunService:IsStudio() then
		for _, member in ipairs(lobby.members) do
			playerLobbyMap[member.userId] = nil
		end
		lobbies[lobby.id] = nil
		setServerMode("Match")
		if onStudioLaunchCallback then
			onStudioLaunchCallback()
		end
		broadcastAll(nil)
		print(string.format("[LobbyService] Studio fallback launched Match in-place for %d player(s).", #memberPlayers))
		return
	end

	-- Live Roblox: Reserve an isolated private match server for this party.
	local okReserve, accessCodeOrErr = pcall(function()
		return TeleportService:ReserveServer(game.PlaceId)
	end)

	if not okReserve or typeof(accessCodeOrErr) ~= "string" then
		warn("[LobbyService] ReserveServer failed:", accessCodeOrErr)
		lobby.status = "Waiting"
		lobby.countdown = 0
		local toasts: { [number]: { text: string, isError: boolean } } = {}
		for _, p in ipairs(memberPlayers) do
			toasts[p.UserId] = { text = "Failed to reserve match server. Please retry.", isError = true }
		end
		broadcastAll(toasts)
		return
	end

	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = accessCodeOrErr
	options:SetTeleportData({
		mode = "Match",
		hostUserId = lobby.hostUserId,
		expectedPlayers = #memberPlayers,
	})

	local okTp, tpErr = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, memberPlayers, options)
	end)

	if not okTp then
		warn("[LobbyService] TeleportAsync failed:", tpErr)
		lobby.status = "Waiting"
		lobby.countdown = 0
		local toasts: { [number]: { text: string, isError: boolean } } = {}
		for _, p in ipairs(memberPlayers) do
			toasts[p.UserId] = { text = "Teleport failed. Please retry in a moment.", isError = true }
		end
		broadcastAll(toasts)
		return
	end

	-- Clear lobby once teleport is dispatched.
	for _, member in ipairs(lobby.members) do
		playerLobbyMap[member.userId] = nil
	end
	lobbies[lobby.id] = nil
	broadcastAll(nil)
end

local function handleLaunch(player: Player)
	if serverMode ~= "Lobby" then
		return
	end
	local lobbyId = playerLobbyMap[player.UserId]
	local lobby = if lobbyId then lobbies[lobbyId] else nil
	if not lobby or lobby.hostUserId ~= player.UserId or lobby.status ~= "Waiting" then
		return
	end

	for _, member in ipairs(lobby.members) do
		if member.userId ~= lobby.hostUserId and not member.isReady then
			syncPlayer(player, "All party members must be Ready before launching.", true)
			return
		end
	end

	lobby.status = "Launching"
	lobby.launchToken += 1
	local myToken = lobby.launchToken
	local countdownSecs = GameConfig.Lobby.LaunchCountdownSeconds

	task.spawn(function()
		for remaining = countdownSecs, 1, -1 do
			if lobbies[lobby.id] ~= lobby or lobby.launchToken ~= myToken or lobby.status ~= "Launching" then
				return
			end
			lobby.countdown = remaining
			broadcastAll(nil)
			task.wait(1)
		end

		if lobbies[lobby.id] ~= lobby or lobby.launchToken ~= myToken or lobby.status ~= "Launching" then
			return
		end
		lobby.countdown = 0
		broadcastAll(nil)
		executeLaunch(lobby)
	end)
end

function LobbyService.returnPlayerToLobby(player: Player)
	if serverMode ~= "Match" then
		return
	end
	if player:GetAttribute(NetContracts.Attributes.InSafeRoom) ~= true then
		syncPlayer(player, "Return to the Safe Room before leaving to the Lobby.", true)
		return
	end

	local now = os.clock()
	if now - (returnTimestamps[player] or 0) < 2.0 then
		return
	end
	returnTimestamps[player] = now

	if RunService:IsStudio() then
		setServerMode("Lobby")
		for _, p in ipairs(Players:GetPlayers()) do
			p:SetAttribute(NetContracts.Attributes.IsEliminated, false)
			PlayerStateService.transitionToSafeRoom(p)
		end
		broadcastAll({
			[player.UserId] = { text = "Returned to Dispatch Lobby (Studio Mode).", isError = false },
		})
		return
	end

	local ok, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, { player })
	end)
	if not ok then
		warn("[LobbyService] ReturnToLobby TeleportAsync failed:", err)
		syncPlayer(player, "Could not return to Lobby right now. Try again.", true)
	end
end

local function wireSafeRoomLobbyPrompt()
	local ventMap = workspace:WaitForChild("VentMap", 10)
	if not ventMap then
		return
	end
	local safeRoom = ventMap:FindFirstChild("SafeRoom")
	if not safeRoom then
		return
	end

	local anchor = safeRoom:FindFirstChild("LobbyExitAnchor") :: BasePart?
	if not anchor then
		local safeSpawn = safeRoom:FindFirstChild("SafeSpawn", true) :: BasePart?
		local basePos = if safeSpawn then safeSpawn.Position else GameConfig.SafeRoom.ReturnCFrame.Position
		local part = Instance.new("Part")
		part.Name = "LobbyExitAnchor"
		part.Size = Vector3.new(1.5, 1.5, 1.5)
		part.Transparency = 1
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Position = basePos + Vector3.new(0, 2.5, 4.5)
		part.Parent = safeRoom
		anchor = part
	end

	if anchor then
		local prompt = anchor:FindFirstChild("ReturnToLobbyPrompt") :: ProximityPrompt?
		if not prompt then
			local p = Instance.new("ProximityPrompt")
			p.Name = "ReturnToLobbyPrompt"
			p.ActionText = "Return to Dispatch Lobby"
			p.ObjectText = "Safe Room Exit"
			p.KeyboardKeyCode = Enum.KeyCode.E
			p.HoldDuration = 0.8
			p.MaxActivationDistance = 7.5
			p.RequiresLineOfSight = false
			p.Parent = anchor
			prompt = p
		end
		returnLobbyPrompt = prompt
		if prompt then
			prompt.Enabled = (serverMode == "Match")
			prompt.Triggered:Connect(function(player: Player)
				LobbyService.returnPlayerToLobby(player)
			end)
		end
	end
end

function LobbyService.init(studioLaunchCallback: (() -> ())?)
	if initialized then
		return
	end
	initialized = true
	onStudioLaunchCallback = studioLaunchCallback

	setServerMode(LobbyService.detectInitialMode())

	lobbyActionRemote = NetContracts.getRemoteEvent(NetContracts.Remotes.LobbyAction, true)
	lobbySyncRemote = NetContracts.getRemoteEvent(NetContracts.Remotes.LobbyStateSync, true)
	returnLobbyRemote = NetContracts.getRemoteEvent(NetContracts.Remotes.ReturnToLobby, true)

	lobbyActionRemote.OnServerEvent:Connect(function(player: Player, payload: unknown)
		if typeof(payload) ~= "table" then
			return
		end
		local now = os.clock()
		if now - (actionTimestamps[player] or 0) < GameConfig.Lobby.ActionCooldown then
			return
		end
		actionTimestamps[player] = now

		local data = payload :: { [string]: any }
		local action = data.action
		if action == "create" then
			handleCreate(player, data)
		elseif action == "join" then
			handleJoin(player, data)
		elseif action == "leave" then
			handleLeave(player)
		elseif action == "toggleReady" then
			handleToggleReady(player)
		elseif action == "updateSettings" then
			handleUpdateSettings(player, data)
		elseif action == "kick" then
			handleKick(player, data)
		elseif action == "launch" then
			handleLaunch(player)
		elseif action == "requestSync" then
			syncPlayer(player, nil, false)
		end
	end)

	returnLobbyRemote.OnServerEvent:Connect(function(player: Player)
		LobbyService.returnPlayerToLobby(player)
	end)

	Players.PlayerAdded:Connect(function(player: Player)
		actionTimestamps[player] = 0
		returnTimestamps[player] = 0
		task.defer(function()
			syncPlayer(player, nil, false)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		actionTimestamps[player] = nil
		returnTimestamps[player] = nil
		if removePlayerFromLobby(player.UserId, nil) then
			broadcastAll(nil)
		end
	end)

	TeleportService.TeleportInitFailed:Connect(function(player: Player, result: Enum.TeleportResult, errMsg: string)
		warn(string.format("[LobbyService] TeleportInitFailed for %s (%s): %s", player.Name, tostring(result), errMsg))
		syncPlayer(player, "Teleport failed: " .. tostring(result.Name), true)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		actionTimestamps[player] = 0
		returnTimestamps[player] = 0
		task.defer(function()
			syncPlayer(player, nil, false)
		end)
	end

	task.spawn(wireSafeRoomLobbyPrompt)
end

return LobbyService
