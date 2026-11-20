--!strict
--[[
	Client Dispatch Lobby UI & Match Return-to-Lobby controller (ADR-010).
	- In ServerMode == "Lobby": renders dark industrial Lobby Browser / Active Party panel with
	  Create Lobby (1-4, Public | Friends | Private), Join by Click or 4-char Code, Ready Up,
	  Host Kick / Settings / Launch Contract, and one-click SocialService Invite Friends.
	- In ServerMode == "Match": hides Lobby UI and exposes [L] Return to Lobby while in the Safe Room.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local NetContracts = require(Shared:WaitForChild("NetContracts"))

type LobbyMemberInfo = {
	userId: number,
	name: string,
	displayName: string,
	isReady: boolean,
}

type LobbyInfo = {
	id: string,
	code: string?,
	hostUserId: number,
	hostName: string,
	maxPlayers: number,
	privacy: string,
	status: string,
	countdown: number,
	memberCount: number,
	members: { LobbyMemberInfo },
}

type LobbyStatePayload = {
	serverMode: string,
	isStudio: boolean,
	myLobbyId: string?,
	lobbies: { LobbyInfo },
	toast: string?,
	toastIsError: boolean?,
}

local LobbyUI = {}

local localPlayer = Players.LocalPlayer
local initialized = false

local lobbyActionRemote: RemoteEvent
local lobbySyncRemote: RemoteEvent
local returnLobbyRemote: RemoteEvent

local currentState: LobbyStatePayload? = nil
local isMinimized = false
local selectedMaxPlayers = GameConfig.Lobby.MaxPartySize
local selectedPrivacy = "Public"
local toastSeq = 0

-- UI References
local screenGui: ScreenGui
local mainPanel: Frame
local reopenButton: TextButton
local modeBadge: TextLabel
local browserView: Frame
local partyView: Frame
local lobbyListFrame: ScrollingFrame
local emptyListLabel: TextLabel
local codeInputBox: TextBox
local maxPlayerButtons: { [number]: TextButton } = {}
local privacyButtons: { [string]: TextButton } = {}

local partyTitleLabel: TextLabel
local partyCodeLabel: TextLabel
local partyMetaLabel: TextLabel
local hostSettingsBar: Frame
local hostPrivacyButtons: { [string]: TextButton } = {}
local hostMaxButtons: { [number]: TextButton } = {}
local memberListFrame: ScrollingFrame
local primaryActionButton: TextButton
local launchOverlay: Frame
local launchOverlayLabel: TextLabel
local toastLabel: TextLabel
local matchReturnHint: TextLabel

-- Palette (matches SafeRoomUI & WorkOrderMonitor)
local COL_BG = Color3.fromRGB(10, 13, 18)
local COL_PANEL = Color3.fromRGB(15, 20, 28)
local COL_ROW = Color3.fromRGB(20, 26, 36)
local COL_BORDER = Color3.fromRGB(42, 56, 74)
local COL_TEXT = Color3.fromRGB(220, 236, 255)
local COL_MUTED = Color3.fromRGB(132, 152, 176)
local COL_AMBER = Color3.fromRGB(245, 185, 85)
local COL_GREEN = Color3.fromRGB(72, 196, 122)
local COL_GREEN_BG = Color3.fromRGB(22, 64, 42)
local COL_RED = Color3.fromRGB(235, 98, 92)
local COL_RED_BG = Color3.fromRGB(72, 24, 26)
local COL_BLUE = Color3.fromRGB(96, 175, 245)
local COL_BLUE_BG = Color3.fromRGB(22, 48, 76)

local function addStroke(parent: Instance, color: Color3?, thickness: number?)
	local s = Instance.new("UIStroke")
	s.Color = color or COL_BORDER
	s.Thickness = thickness or 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

local function addCorner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 4)
	c.Parent = parent
end

local function showToast(msg: string, isError: boolean)
	toastSeq += 1
	local mySeq = toastSeq
	toastLabel.Text = msg
	toastLabel.TextColor3 = if isError then COL_RED else COL_GREEN
	toastLabel.BackgroundColor3 = if isError then Color3.fromRGB(42, 16, 18) else Color3.fromRGB(14, 38, 26)
	toastLabel.Visible = true
	task.delay(4.0, function()
		if toastSeq == mySeq and toastLabel then
			toastLabel.Visible = false
		end
	end)
end

local function promptInviteFriends()
	local okCan, canInvite = pcall(function()
		return SocialService:CanSendGameInviteAsync(localPlayer)
	end)
	if okCan and canInvite then
		pcall(function()
			SocialService:PromptGameInvite(localPlayer)
		end)
	else
		showToast("Invite modal unavailable here — share your Roblox server or Join Code!", false)
	end
end

local function fireAction(payload: { [string]: any })
	lobbyActionRemote:FireServer(payload)
end

local function refreshCreateToggles()
	for n, btn in pairs(maxPlayerButtons) do
		local active = (n == selectedMaxPlayers)
		btn.BackgroundColor3 = if active then COL_BLUE_BG else COL_ROW
		btn.TextColor3 = if active then COL_TEXT else COL_MUTED
	end
	for priv, btn in pairs(privacyButtons) do
		local active = (priv == selectedPrivacy)
		btn.BackgroundColor3 = if active then COL_BLUE_BG else COL_ROW
		btn.TextColor3 = if active then COL_TEXT else COL_MUTED
	end
end

local function updateMatchReturnHint()
	local mode = ReplicatedStorage:GetAttribute(NetContracts.Attributes.ServerMode)
	local inSafeRoom = localPlayer:GetAttribute(NetContracts.Attributes.InSafeRoom) == true
	matchReturnHint.Visible = (mode == "Match") and inSafeRoom
end

local function clearChildrenOfClass(parent: Instance, className: string)
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA(className) then
			child:Destroy()
		end
	end
end

local function renderBrowser(state: LobbyStatePayload)
	clearChildrenOfClass(lobbyListFrame, "Frame")

	local count = #state.lobbies
	emptyListLabel.Visible = (count == 0)

	for idx, lobby in ipairs(state.lobbies) do
		local row = Instance.new("Frame")
		row.Name = "LobbyRow_" .. lobby.id
		row.Size = UDim2.new(1, -6, 0, 56)
		row.BackgroundColor3 = COL_ROW
		row.BorderSizePixel = 0
		row.LayoutOrder = idx
		row.Parent = lobbyListFrame
		addCorner(row, 4)
		addStroke(row, COL_BORDER, 1)

		local hostLbl = Instance.new("TextLabel")
		hostLbl.Position = UDim2.fromOffset(10, 6)
		hostLbl.Size = UDim2.new(1, -110, 0, 22)
		hostLbl.BackgroundTransparency = 1
		hostLbl.Font = Enum.Font.Code
		hostLbl.TextSize = 15
		hostLbl.TextXAlignment = Enum.TextXAlignment.Left
		hostLbl.TextColor3 = COL_TEXT
		hostLbl.Text = string.format("%s's Squad", lobby.hostName)
		hostLbl.Parent = row

		local privColor = if lobby.privacy == "Public"
			then COL_GREEN
			elseif lobby.privacy == "Friends" then COL_BLUE
			else COL_AMBER

		local statusStr = if lobby.status == "Launching"
			then string.format("LAUNCHING (%ds)", lobby.countdown)
			else "WAITING"

		local metaLbl = Instance.new("TextLabel")
		metaLbl.Position = UDim2.fromOffset(10, 30)
		metaLbl.Size = UDim2.new(1, -110, 0, 18)
		metaLbl.BackgroundTransparency = 1
		metaLbl.Font = Enum.Font.Code
		metaLbl.TextSize = 12
		metaLbl.TextXAlignment = Enum.TextXAlignment.Left
		metaLbl.TextColor3 = privColor
		metaLbl.Text = string.format("[%s]  •  %d / %d PLAYERS  •  %s", string.upper(lobby.privacy), lobby.memberCount, lobby.maxPlayers, statusStr)
		metaLbl.Parent = row

		local isFull = lobby.memberCount >= lobby.maxPlayers
		local isLaunching = lobby.status == "Launching"
		local canClickJoin = (not isFull) and (not isLaunching)

		local joinBtn = Instance.new("TextButton")
		joinBtn.AnchorPoint = Vector2.new(1, 0.5)
		joinBtn.Position = UDim2.new(1, -10, 0.5, 0)
		joinBtn.Size = UDim2.fromOffset(82, 32)
		joinBtn.Font = Enum.Font.Code
		joinBtn.TextSize = 13
		joinBtn.BorderSizePixel = 0
		joinBtn.AutoButtonColor = canClickJoin
		if isLaunching then
			joinBtn.Text = "BUSY"
			joinBtn.BackgroundColor3 = COL_PANEL
			joinBtn.TextColor3 = COL_MUTED
		elseif isFull then
			joinBtn.Text = "FULL"
			joinBtn.BackgroundColor3 = COL_PANEL
			joinBtn.TextColor3 = COL_MUTED
		elseif lobby.privacy == "Private" then
			joinBtn.Text = "CODE"
			joinBtn.BackgroundColor3 = Color3.fromRGB(58, 44, 18)
			joinBtn.TextColor3 = COL_AMBER
		else
			joinBtn.Text = "JOIN"
			joinBtn.BackgroundColor3 = COL_GREEN_BG
			joinBtn.TextColor3 = COL_GREEN
		end
		joinBtn.Parent = row
		addCorner(joinBtn, 4)
		addStroke(joinBtn, if canClickJoin then COL_BORDER else Color3.fromRGB(30, 36, 46), 1)

		joinBtn.MouseButton1Click:Connect(function()
			if not canClickJoin then
				return
			end
			if lobby.privacy == "Private" then
				showToast("Enter the 4-character Join Code above to join this private lobby.", true)
				codeInputBox:CaptureFocus()
				return
			end
			fireAction({ action = "join", lobbyId = lobby.id })
		end)
	end
end

local function renderParty(lobby: LobbyInfo)
	local isHost = (lobby.hostUserId == localPlayer.UserId)
	local allReady = true
	local localReady = false
	for _, m in ipairs(lobby.members) do
		if m.userId == localPlayer.UserId then
			localReady = m.isReady
		end
		if m.userId ~= lobby.hostUserId and not m.isReady then
			allReady = false
		end
	end

	partyTitleLabel.Text = string.format("%s's SQUAD", string.upper(lobby.hostName))
	partyCodeLabel.Text = string.format("JOIN CODE: %s", lobby.code or "----")
	partyMetaLabel.Text = string.format(
		"PRIVACY: %s  |  SQUAD: %d / %d",
		string.upper(lobby.privacy),
		lobby.memberCount,
		lobby.maxPlayers
	)

	hostSettingsBar.Visible = isHost and lobby.status == "Waiting"
	if isHost then
		for priv, btn in pairs(hostPrivacyButtons) do
			local active = (priv == lobby.privacy)
			btn.BackgroundColor3 = if active then COL_BLUE_BG else COL_ROW
			btn.TextColor3 = if active then COL_TEXT else COL_MUTED
		end
		for n, btn in pairs(hostMaxButtons) do
			local active = (n == lobby.maxPlayers)
			local disabled = (n < lobby.memberCount)
			btn.BackgroundColor3 = if active then COL_BLUE_BG else COL_ROW
			btn.TextColor3 = if disabled then Color3.fromRGB(70, 80, 92) elseif active then COL_TEXT else COL_MUTED
		end
	end

	clearChildrenOfClass(memberListFrame, "Frame")

	for idx, m in ipairs(lobby.members) do
		local row = Instance.new("Frame")
		row.Name = "Member_" .. tostring(m.userId)
		row.Size = UDim2.new(1, -6, 0, 44)
		row.BackgroundColor3 = COL_ROW
		row.BorderSizePixel = 0
		row.LayoutOrder = idx
		row.Parent = memberListFrame
		addCorner(row, 4)
		addStroke(row, COL_BORDER, 1)

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Position = UDim2.fromOffset(12, 0)
		nameLbl.Size = UDim2.new(1, -210, 1, 0)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Font = Enum.Font.Code
		nameLbl.TextSize = 15
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.TextColor3 = if m.userId == localPlayer.UserId then COL_AMBER else COL_TEXT
		nameLbl.Text = string.format("%s (@%s)", m.displayName, m.name)
		nameLbl.Parent = row

		local badge = Instance.new("TextLabel")
		badge.AnchorPoint = Vector2.new(1, 0.5)
		badge.Position = UDim2.new(1, if isHost and m.userId ~= lobby.hostUserId then -78 else -12, 0.5, 0)
		badge.Size = UDim2.fromOffset(96, 24)
		badge.Font = Enum.Font.Code
		badge.TextSize = 12
		badge.BorderSizePixel = 0
		if m.userId == lobby.hostUserId then
			badge.Text = "HOST"
			badge.BackgroundColor3 = Color3.fromRGB(58, 44, 18)
			badge.TextColor3 = COL_AMBER
		elseif m.isReady then
			badge.Text = "READY"
			badge.BackgroundColor3 = COL_GREEN_BG
			badge.TextColor3 = COL_GREEN
		else
			badge.Text = "NOT READY"
			badge.BackgroundColor3 = COL_PANEL
			badge.TextColor3 = COL_MUTED
		end
		badge.Parent = row
		addCorner(badge, 3)

		if isHost and m.userId ~= lobby.hostUserId and lobby.status == "Waiting" then
			local kickBtn = Instance.new("TextButton")
			kickBtn.AnchorPoint = Vector2.new(1, 0.5)
			kickBtn.Position = UDim2.new(1, -10, 0.5, 0)
			kickBtn.Size = UDim2.fromOffset(58, 24)
			kickBtn.BackgroundColor3 = COL_RED_BG
			kickBtn.TextColor3 = COL_RED
			kickBtn.Font = Enum.Font.Code
			kickBtn.TextSize = 12
			kickBtn.Text = "KICK"
			kickBtn.BorderSizePixel = 0
			kickBtn.Parent = row
			addCorner(kickBtn, 3)
			kickBtn.MouseButton1Click:Connect(function()
				fireAction({ action = "kick", targetUserId = m.userId })
			end)
		end
	end

	-- Open slot placeholders
	for slot = lobby.memberCount + 1, lobby.maxPlayers do
		local emptyRow = Instance.new("Frame")
		emptyRow.Name = "OpenSlot_" .. tostring(slot)
		emptyRow.Size = UDim2.new(1, -6, 0, 38)
		emptyRow.BackgroundColor3 = Color3.fromRGB(13, 17, 23)
		emptyRow.BorderSizePixel = 0
		emptyRow.LayoutOrder = slot
		emptyRow.Parent = memberListFrame
		addCorner(emptyRow, 4)
		addStroke(emptyRow, Color3.fromRGB(28, 36, 48), 1)

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.fromScale(1, 1)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.Code
		lbl.TextSize = 13
		lbl.TextColor3 = Color3.fromRGB(82, 96, 114)
		lbl.Text = "— OPEN TECHNICIAN SLOT —"
		lbl.Parent = emptyRow
	end

	if lobby.status == "Launching" then
		launchOverlay.Visible = true
		launchOverlayLabel.Text = if lobby.countdown > 0
			then string.format("RESERVING PRIVATE SERVER... DEPLOYING IN %d", lobby.countdown)
			else "DEPLOYING SQUAD TO CONTRACT SECTOR..."
		primaryActionButton.Text = "DEPLOYING..."
		primaryActionButton.BackgroundColor3 = COL_PANEL
		primaryActionButton.TextColor3 = COL_AMBER
	else
		launchOverlay.Visible = false
		if isHost then
			if allReady then
				primaryActionButton.Text = "LAUNCH CONTRACT"
				primaryActionButton.BackgroundColor3 = COL_GREEN_BG
				primaryActionButton.TextColor3 = COL_GREEN
			else
				primaryActionButton.Text = "WAITING ON READY..."
				primaryActionButton.BackgroundColor3 = COL_PANEL
				primaryActionButton.TextColor3 = COL_MUTED
			end
		else
			if localReady then
				primaryActionButton.Text = "UNREADY"
				primaryActionButton.BackgroundColor3 = Color3.fromRGB(58, 44, 18)
				primaryActionButton.TextColor3 = COL_AMBER
			else
				primaryActionButton.Text = "READY UP"
				primaryActionButton.BackgroundColor3 = COL_GREEN_BG
				primaryActionButton.TextColor3 = COL_GREEN
			end
		end
	end
end

local function applyState(state: LobbyStatePayload)
	currentState = state

	if state.toast and state.toast ~= "" then
		showToast(state.toast, state.toastIsError == true)
	end

	local inLobbyMode = (state.serverMode == "Lobby")
	modeBadge.Text = if state.isStudio then "STUDIO PREVIEW" else "PUBLIC HUB"

	if not inLobbyMode then
		mainPanel.Visible = false
		reopenButton.Visible = false
		launchOverlay.Visible = false
		updateMatchReturnHint()
		return
	end

	matchReturnHint.Visible = false
	mainPanel.Visible = not isMinimized
	reopenButton.Visible = isMinimized

	local myLobby: LobbyInfo? = nil
	if state.myLobbyId then
		for _, lobby in ipairs(state.lobbies) do
			if lobby.id == state.myLobbyId then
				myLobby = lobby
				break
			end
		end
	end

	if myLobby then
		browserView.Visible = false
		partyView.Visible = true
		renderParty(myLobby)
	else
		browserView.Visible = true
		partyView.Visible = false
		launchOverlay.Visible = false
		renderBrowser(state)
	end
end

local function createGui()
	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local existing = playerGui:FindFirstChild("LobbyGui")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "LobbyGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	screenGui = gui

	-- Reopen pill when minimized in Lobby mode
	local reopen = Instance.new("TextButton")
	reopen.Name = "ReopenLobbyButton"
	reopen.AnchorPoint = Vector2.new(0.5, 0)
	reopen.Position = UDim2.new(0.5, 0, 0, 18)
	reopen.Size = UDim2.fromOffset(230, 34)
	reopen.BackgroundColor3 = COL_BG
	reopen.BackgroundTransparency = 0.1
	reopen.Font = Enum.Font.Code
	reopen.TextSize = 14
	reopen.TextColor3 = COL_AMBER
	reopen.Text = "[OPEN DISPATCH LOBBY]"
	reopen.BorderSizePixel = 0
	reopen.Visible = false
	reopen.Parent = gui
	addCorner(reopen, 4)
	addStroke(reopen, COL_AMBER, 1)
	reopenButton = reopen

	reopen.MouseButton1Click:Connect(function()
		isMinimized = false
		if currentState then
			applyState(currentState)
		end
	end)

	-- Match Mode Safe Room Return Hint
	local returnHint = Instance.new("TextLabel")
	returnHint.Name = "MatchReturnHint"
	returnHint.AnchorPoint = Vector2.new(1, 1)
	returnHint.Position = UDim2.new(1, -20, 1, -18)
	returnHint.Size = UDim2.fromOffset(250, 28)
	returnHint.BackgroundColor3 = COL_BG
	returnHint.BackgroundTransparency = 0.45
	returnHint.BorderSizePixel = 0
	returnHint.Font = Enum.Font.Code
	returnHint.TextSize = 13
	returnHint.TextColor3 = COL_AMBER
	returnHint.Text = "[L] RETURN TO DISPATCH LOBBY"
	returnHint.Visible = false
	returnHint.Parent = gui
	addCorner(returnHint, 3)
	matchReturnHint = returnHint

	-- Main Centered Panel
	local panel = Instance.new("Frame")
	panel.Name = "MainPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(760, 470)
	panel.BackgroundColor3 = COL_BG
	panel.BackgroundTransparency = 0.06
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui
	addCorner(panel, 6)
	addStroke(panel, COL_BORDER, 1.5)
	mainPanel = panel

	-- Responsive size clamp for smaller screens
	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MaxSize = Vector2.new(760, 470)
	sizeConstraint.MinSize = Vector2.new(540, 380)
	sizeConstraint.Parent = panel

	-- Header
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 48)
	header.BackgroundColor3 = COL_PANEL
	header.BorderSizePixel = 0
	header.Parent = panel
	addCorner(header, 6)

	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromOffset(16, 0)
	title.Size = UDim2.new(0, 320, 1, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.Code
	title.TextSize = 18
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = COL_TEXT
	title.Text = "VENTWORKS // DISPATCH LOBBY"
	title.Parent = header

	local badge = Instance.new("TextLabel")
	badge.Position = UDim2.fromOffset(330, 12)
	badge.Size = UDim2.fromOffset(122, 24)
	badge.BackgroundColor3 = Color3.fromRGB(28, 36, 48)
	badge.BorderSizePixel = 0
	badge.Font = Enum.Font.Code
	badge.TextSize = 12
	badge.TextColor3 = COL_AMBER
	badge.Text = "PUBLIC HUB"
	badge.Parent = header
	addCorner(badge, 3)
	modeBadge = badge

	local inviteTopBtn = Instance.new("TextButton")
	inviteTopBtn.AnchorPoint = Vector2.new(1, 0.5)
	inviteTopBtn.Position = UDim2.new(1, -112, 0.5, 0)
	inviteTopBtn.Size = UDim2.fromOffset(132, 30)
	inviteTopBtn.BackgroundColor3 = COL_BLUE_BG
	inviteTopBtn.TextColor3 = COL_BLUE
	inviteTopBtn.Font = Enum.Font.Code
	inviteTopBtn.TextSize = 12
	inviteTopBtn.Text = "+ INVITE FRIENDS"
	inviteTopBtn.BorderSizePixel = 0
	inviteTopBtn.Parent = header
	addCorner(inviteTopBtn, 4)
	addStroke(inviteTopBtn, COL_BLUE, 1)
	inviteTopBtn.MouseButton1Click:Connect(promptInviteFriends)

	local minBtn = Instance.new("TextButton")
	minBtn.AnchorPoint = Vector2.new(1, 0.5)
	minBtn.Position = UDim2.new(1, -12, 0.5, 0)
	minBtn.Size = UDim2.fromOffset(90, 30)
	minBtn.BackgroundColor3 = COL_ROW
	minBtn.TextColor3 = COL_MUTED
	minBtn.Font = Enum.Font.Code
	minBtn.TextSize = 12
	minBtn.Text = "MINIMIZE"
	minBtn.BorderSizePixel = 0
	minBtn.Parent = header
	addCorner(minBtn, 4)
	addStroke(minBtn, COL_BORDER, 1)
	minBtn.MouseButton1Click:Connect(function()
		isMinimized = true
		if currentState then
			applyState(currentState)
		end
	end)

	-- Content Body
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Position = UDim2.fromOffset(14, 58)
	body.Size = UDim2.new(1, -28, 1, -104)
	body.BackgroundTransparency = 1
	body.Parent = panel

	-- === BROWSER VIEW ===
	local browser = Instance.new("Frame")
	browser.Name = "BrowserView"
	browser.Size = UDim2.fromScale(1, 1)
	browser.BackgroundTransparency = 1
	browser.Parent = body
	browserView = browser

	-- Left Column: Active Lobbies
	local leftCol = Instance.new("Frame")
	leftCol.Name = "LeftColumn"
	leftCol.Size = UDim2.new(0.58, -8, 1, 0)
	leftCol.BackgroundColor3 = COL_PANEL
	leftCol.BorderSizePixel = 0
	leftCol.Parent = browser
	addCorner(leftCol, 5)
	addStroke(leftCol, COL_BORDER, 1)

	local leftHeader = Instance.new("TextLabel")
	leftHeader.Position = UDim2.fromOffset(12, 8)
	leftHeader.Size = UDim2.new(1, -24, 0, 22)
	leftHeader.BackgroundTransparency = 1
	leftHeader.Font = Enum.Font.Code
	leftHeader.TextSize = 14
	leftHeader.TextXAlignment = Enum.TextXAlignment.Left
	leftHeader.TextColor3 = COL_AMBER
	leftHeader.Text = "ACTIVE SQUAD LOBBIES"
	leftHeader.Parent = leftCol

	-- Join by Code Bar
	local codeBar = Instance.new("Frame")
	codeBar.Position = UDim2.fromOffset(12, 34)
	codeBar.Size = UDim2.new(1, -24, 0, 32)
	codeBar.BackgroundTransparency = 1
	codeBar.Parent = leftCol

	local codeBox = Instance.new("TextBox")
	codeBox.Size = UDim2.new(1, -106, 1, 0)
	codeBox.BackgroundColor3 = COL_BG
	codeBox.BorderSizePixel = 0
	codeBox.Font = Enum.Font.Code
	codeBox.TextSize = 14
	codeBox.TextColor3 = COL_TEXT
	codeBox.PlaceholderText = "ENTER 4-CHAR CODE..."
	codeBox.PlaceholderColor3 = COL_MUTED
	codeBox.Text = ""
	codeBox.ClearTextOnFocus = false
	codeBox.Parent = codeBar
	addCorner(codeBox, 4)
	addStroke(codeBox, COL_BORDER, 1)
	codeInputBox = codeBox

	local joinCodeBtn = Instance.new("TextButton")
	joinCodeBtn.AnchorPoint = Vector2.new(1, 0)
	joinCodeBtn.Position = UDim2.fromScale(1, 0)
	joinCodeBtn.Size = UDim2.fromOffset(98, 32)
	joinCodeBtn.BackgroundColor3 = COL_BLUE_BG
	joinCodeBtn.TextColor3 = COL_BLUE
	joinCodeBtn.Font = Enum.Font.Code
	joinCodeBtn.TextSize = 13
	joinCodeBtn.Text = "JOIN CODE"
	joinCodeBtn.BorderSizePixel = 0
	joinCodeBtn.Parent = codeBar
	addCorner(joinCodeBtn, 4)
	addStroke(joinCodeBtn, COL_BLUE, 1)
	joinCodeBtn.MouseButton1Click:Connect(function()
		local code = string.upper(string.gsub(codeBox.Text, "%s+", ""))
		if code == "" then
			showToast("Type a 4-character lobby code first.", true)
			return
		end
		fireAction({ action = "join", code = code })
	end)

	local listScroll = Instance.new("ScrollingFrame")
	listScroll.Name = "LobbyList"
	listScroll.Position = UDim2.fromOffset(12, 74)
	listScroll.Size = UDim2.new(1, -24, 1, -84)
	listScroll.BackgroundTransparency = 1
	listScroll.BorderSizePixel = 0
	listScroll.ScrollBarThickness = 5
	listScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	listScroll.Parent = leftCol
	lobbyListFrame = listScroll

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = listScroll

	local emptyLbl = Instance.new("TextLabel")
	emptyLbl.Size = UDim2.fromScale(1, 0.7)
	emptyLbl.BackgroundTransparency = 1
	emptyLbl.Font = Enum.Font.Code
	emptyLbl.TextSize = 14
	emptyLbl.TextColor3 = COL_MUTED
	emptyLbl.TextWrapped = true
	emptyLbl.Text = "No active squad lobbies yet.\nCreate one on the right to start!"
	emptyLbl.Parent = listScroll
	emptyListLabel = emptyLbl

	-- Right Column: Create Lobby
	local rightCol = Instance.new("Frame")
	rightCol.Name = "RightColumn"
	rightCol.AnchorPoint = Vector2.new(1, 0)
	rightCol.Position = UDim2.fromScale(1, 0)
	rightCol.Size = UDim2.new(0.42, -6, 1, 0)
	rightCol.BackgroundColor3 = COL_PANEL
	rightCol.BorderSizePixel = 0
	rightCol.Parent = browser
	addCorner(rightCol, 5)
	addStroke(rightCol, COL_BORDER, 1)

	local rightHeader = Instance.new("TextLabel")
	rightHeader.Position = UDim2.fromOffset(14, 8)
	rightHeader.Size = UDim2.new(1, -28, 0, 22)
	rightHeader.BackgroundTransparency = 1
	rightHeader.Font = Enum.Font.Code
	rightHeader.TextSize = 14
	rightHeader.TextXAlignment = Enum.TextXAlignment.Left
	rightHeader.TextColor3 = COL_AMBER
	rightHeader.Text = "CREATE NEW LOBBY"
	rightHeader.Parent = rightCol

	local maxLbl = Instance.new("TextLabel")
	maxLbl.Position = UDim2.fromOffset(14, 42)
	maxLbl.Size = UDim2.new(1, -28, 0, 18)
	maxLbl.BackgroundTransparency = 1
	maxLbl.Font = Enum.Font.Code
	maxLbl.TextSize = 12
	maxLbl.TextXAlignment = Enum.TextXAlignment.Left
	maxLbl.TextColor3 = COL_MUTED
	maxLbl.Text = "MAX SQUAD SIZE (1 - 4)"
	maxLbl.Parent = rightCol

	local maxRow = Instance.new("Frame")
	maxRow.Position = UDim2.fromOffset(14, 64)
	maxRow.Size = UDim2.new(1, -28, 0, 34)
	maxRow.BackgroundTransparency = 1
	maxRow.Parent = rightCol
	local maxGrid = Instance.new("UIGridLayout")
	maxGrid.CellSize = UDim2.new(0.25, -5, 1, 0)
	maxGrid.CellPadding = UDim2.fromOffset(6, 0)
	maxGrid.Parent = maxRow

	for n = 1, 4 do
		local b = Instance.new("TextButton")
		b.Font = Enum.Font.Code
		b.TextSize = 15
		b.Text = tostring(n)
		b.BorderSizePixel = 0
		b.Parent = maxRow
		addCorner(b, 4)
		addStroke(b, COL_BORDER, 1)
		maxPlayerButtons[n] = b
		b.MouseButton1Click:Connect(function()
			selectedMaxPlayers = n
			refreshCreateToggles()
		end)
	end

	local privLbl = Instance.new("TextLabel")
	privLbl.Position = UDim2.fromOffset(14, 114)
	privLbl.Size = UDim2.new(1, -28, 0, 18)
	privLbl.BackgroundTransparency = 1
	privLbl.Font = Enum.Font.Code
	privLbl.TextSize = 12
	privLbl.TextXAlignment = Enum.TextXAlignment.Left
	privLbl.TextColor3 = COL_MUTED
	privLbl.Text = "ACCESS / PRIVACY"
	privLbl.Parent = rightCol

	local privRow = Instance.new("Frame")
	privRow.Position = UDim2.fromOffset(14, 136)
	privRow.Size = UDim2.new(1, -28, 0, 34)
	privRow.BackgroundTransparency = 1
	privRow.Parent = rightCol
	local privGrid = Instance.new("UIGridLayout")
	privGrid.CellSize = UDim2.new(0.333, -4, 1, 0)
	privGrid.CellPadding = UDim2.fromOffset(6, 0)
	privGrid.Parent = privRow

	for _, priv in ipairs({ "Public", "Friends", "Private" }) do
		local b = Instance.new("TextButton")
		b.Font = Enum.Font.Code
		b.TextSize = 12
		b.Text = string.upper(priv)
		b.BorderSizePixel = 0
		b.Parent = privRow
		addCorner(b, 4)
		addStroke(b, COL_BORDER, 1)
		privacyButtons[priv] = b
		b.MouseButton1Click:Connect(function()
			selectedPrivacy = priv
			refreshCreateToggles()
		end)
	end

	local infoBlurb = Instance.new("TextLabel")
	infoBlurb.Position = UDim2.fromOffset(14, 186)
	infoBlurb.Size = UDim2.new(1, -28, 0, 90)
	infoBlurb.BackgroundTransparency = 1
	infoBlurb.Font = Enum.Font.Code
	infoBlurb.TextSize = 12
	infoBlurb.TextWrapped = true
	infoBlurb.TextXAlignment = Enum.TextXAlignment.Left
	infoBlurb.TextYAlignment = Enum.TextYAlignment.Top
	infoBlurb.TextColor3 = COL_MUTED
	infoBlurb.Text = "• PUBLIC: Anyone in this hub can join.\n• FRIENDS: Friends join freely; others need code.\n• PRIVATE: Join Code only.\n\nEach squad deploys into its own independent server."
	infoBlurb.Parent = rightCol

	local createBtn = Instance.new("TextButton")
	createBtn.AnchorPoint = Vector2.new(0.5, 1)
	createBtn.Position = UDim2.new(0.5, 0, 1, -14)
	createBtn.Size = UDim2.new(1, -28, 0, 42)
	createBtn.BackgroundColor3 = COL_GREEN_BG
	createBtn.TextColor3 = COL_GREEN
	createBtn.Font = Enum.Font.Code
	createBtn.TextSize = 15
	createBtn.Text = "+ CREATE LOBBY"
	createBtn.BorderSizePixel = 0
	createBtn.Parent = rightCol
	addCorner(createBtn, 4)
	addStroke(createBtn, COL_GREEN, 1.5)
	createBtn.MouseButton1Click:Connect(function()
		fireAction({
			action = "create",
			maxPlayers = selectedMaxPlayers,
			privacy = selectedPrivacy,
		})
	end)

	refreshCreateToggles()

	-- === PARTY VIEW ===
	local party = Instance.new("Frame")
	party.Name = "PartyView"
	party.Size = UDim2.fromScale(1, 1)
	party.BackgroundColor3 = COL_PANEL
	party.BorderSizePixel = 0
	party.Visible = false
	party.Parent = body
	addCorner(party, 5)
	addStroke(party, COL_BORDER, 1)
	partyView = party

	local pTitle = Instance.new("TextLabel")
	pTitle.Position = UDim2.fromOffset(16, 12)
	pTitle.Size = UDim2.new(0.6, 0, 0, 24)
	pTitle.BackgroundTransparency = 1
	pTitle.Font = Enum.Font.Code
	pTitle.TextSize = 18
	pTitle.TextXAlignment = Enum.TextXAlignment.Left
	pTitle.TextColor3 = COL_TEXT
	pTitle.Text = "SQUAD LOBBY"
	pTitle.Parent = party
	partyTitleLabel = pTitle

	local pCode = Instance.new("TextLabel")
	pCode.AnchorPoint = Vector2.new(1, 0)
	pCode.Position = UDim2.new(1, -16, 0, 10)
	pCode.Size = UDim2.fromOffset(180, 30)
	pCode.BackgroundColor3 = Color3.fromRGB(48, 36, 14)
	pCode.BorderSizePixel = 0
	pCode.Font = Enum.Font.Code
	pCode.TextSize = 15
	pCode.TextColor3 = COL_AMBER
	pCode.Text = "JOIN CODE: ----"
	pCode.Parent = party
	addCorner(pCode, 4)
	addStroke(pCode, COL_AMBER, 1)
	partyCodeLabel = pCode

	local pMeta = Instance.new("TextLabel")
	pMeta.Position = UDim2.fromOffset(16, 38)
	pMeta.Size = UDim2.new(0.65, 0, 0, 18)
	pMeta.BackgroundTransparency = 1
	pMeta.Font = Enum.Font.Code
	pMeta.TextSize = 12
	pMeta.TextXAlignment = Enum.TextXAlignment.Left
	pMeta.TextColor3 = COL_MUTED
	pMeta.Text = "PRIVACY: PUBLIC  |  SQUAD: 1 / 4"
	pMeta.Parent = party
	partyMetaLabel = pMeta

	-- Host Settings Bar
	local hostBar = Instance.new("Frame")
	hostBar.Name = "HostSettingsBar"
	hostBar.Position = UDim2.fromOffset(16, 62)
	hostBar.Size = UDim2.new(1, -32, 0, 30)
	hostBar.BackgroundTransparency = 1
	hostBar.Parent = party
	hostSettingsBar = hostBar

	local hostLayout = Instance.new("UIListLayout")
	hostLayout.FillDirection = Enum.FillDirection.Horizontal
	hostLayout.Padding = UDim.new(0, 6)
	hostLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	hostLayout.SortOrder = Enum.SortOrder.LayoutOrder
	hostLayout.Parent = hostBar

	local hostTag = Instance.new("TextLabel")
	hostTag.Size = UDim2.fromOffset(78, 26)
	hostTag.BackgroundTransparency = 1
	hostTag.Font = Enum.Font.Code
	hostTag.TextSize = 12
	hostTag.TextXAlignment = Enum.TextXAlignment.Left
	hostTag.TextColor3 = COL_MUTED
	hostTag.Text = "SETTINGS:"
	hostTag.LayoutOrder = 1
	hostTag.Parent = hostBar

	for idx, priv in ipairs({ "Public", "Friends", "Private" }) do
		local b = Instance.new("TextButton")
		b.Size = UDim2.fromOffset(72, 26)
		b.Font = Enum.Font.Code
		b.TextSize = 12
		b.Text = string.upper(priv)
		b.BorderSizePixel = 0
		b.LayoutOrder = 1 + idx
		b.Parent = hostBar
		addCorner(b, 3)
		addStroke(b, COL_BORDER, 1)
		hostPrivacyButtons[priv] = b
		b.MouseButton1Click:Connect(function()
			fireAction({ action = "updateSettings", privacy = priv })
		end)
	end

	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.fromOffset(16, 1)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 10
	spacer.Parent = hostBar

	local maxTag = Instance.new("TextLabel")
	maxTag.Size = UDim2.fromOffset(42, 26)
	maxTag.BackgroundTransparency = 1
	maxTag.Font = Enum.Font.Code
	maxTag.TextSize = 12
	maxTag.TextColor3 = COL_MUTED
	maxTag.Text = "MAX:"
	maxTag.LayoutOrder = 11
	maxTag.Parent = hostBar

	for n = 1, 4 do
		local b = Instance.new("TextButton")
		b.Size = UDim2.fromOffset(30, 26)
		b.Font = Enum.Font.Code
		b.TextSize = 12
		b.Text = tostring(n)
		b.BorderSizePixel = 0
		b.LayoutOrder = 11 + n
		b.Parent = hostBar
		addCorner(b, 3)
		addStroke(b, COL_BORDER, 1)
		hostMaxButtons[n] = b
		b.MouseButton1Click:Connect(function()
			fireAction({ action = "updateSettings", maxPlayers = n })
		end)
	end

	-- Member Roster
	local roster = Instance.new("ScrollingFrame")
	roster.Name = "MemberRoster"
	roster.Position = UDim2.fromOffset(16, 100)
	roster.Size = UDim2.new(1, -32, 1, -162)
	roster.BackgroundTransparency = 1
	roster.BorderSizePixel = 0
	roster.ScrollBarThickness = 4
	roster.AutomaticCanvasSize = Enum.AutomaticSize.Y
	roster.CanvasSize = UDim2.new(0, 0, 0, 0)
	roster.Parent = party
	memberListFrame = roster

	local rosterLayout = Instance.new("UIListLayout")
	rosterLayout.Padding = UDim.new(0, 8)
	rosterLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rosterLayout.Parent = roster

	-- Bottom Party Action Bar
	local leaveBtn = Instance.new("TextButton")
	leaveBtn.AnchorPoint = Vector2.new(0, 1)
	leaveBtn.Position = UDim2.new(0, 16, 1, -14)
	leaveBtn.Size = UDim2.fromOffset(130, 38)
	leaveBtn.BackgroundColor3 = COL_RED_BG
	leaveBtn.TextColor3 = COL_RED
	leaveBtn.Font = Enum.Font.Code
	leaveBtn.TextSize = 14
	leaveBtn.Text = "LEAVE LOBBY"
	leaveBtn.BorderSizePixel = 0
	leaveBtn.Parent = party
	addCorner(leaveBtn, 4)
	addStroke(leaveBtn, COL_RED, 1)
	leaveBtn.MouseButton1Click:Connect(function()
		fireAction({ action = "leave" })
	end)

	local primaryBtn = Instance.new("TextButton")
	primaryBtn.AnchorPoint = Vector2.new(1, 1)
	primaryBtn.Position = UDim2.new(1, -16, 1, -14)
	primaryBtn.Size = UDim2.fromOffset(220, 38)
	primaryBtn.BackgroundColor3 = COL_GREEN_BG
	primaryBtn.TextColor3 = COL_GREEN
	primaryBtn.Font = Enum.Font.Code
	primaryBtn.TextSize = 15
	primaryBtn.Text = "LAUNCH CONTRACT"
	primaryBtn.BorderSizePixel = 0
	primaryBtn.Parent = party
	addCorner(primaryBtn, 4)
	addStroke(primaryBtn, COL_GREEN, 1.5)
	primaryActionButton = primaryBtn

	primaryBtn.MouseButton1Click:Connect(function()
		if not currentState or not currentState.myLobbyId then
			return
		end
		local myLobby: LobbyInfo? = nil
		for _, l in ipairs(currentState.lobbies) do
			if l.id == currentState.myLobbyId then
				myLobby = l
				break
			end
		end
		if not myLobby or myLobby.status == "Launching" then
			return
		end
		if myLobby.hostUserId == localPlayer.UserId then
			fireAction({ action = "launch" })
		else
			fireAction({ action = "toggleReady" })
		end
	end)

	-- Launch Countdown Overlay
	local overlay = Instance.new("Frame")
	overlay.Name = "LaunchOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(6, 9, 14)
	overlay.BackgroundTransparency = 0.2
	overlay.BorderSizePixel = 0
	overlay.Visible = false
	overlay.ZIndex = 5
	overlay.Parent = party
	addCorner(overlay, 5)
	launchOverlay = overlay

	local oLbl = Instance.new("TextLabel")
	oLbl.AnchorPoint = Vector2.new(0.5, 0.5)
	oLbl.Position = UDim2.fromScale(0.5, 0.5)
	oLbl.Size = UDim2.new(0.9, 0, 0, 60)
	oLbl.BackgroundTransparency = 1
	oLbl.Font = Enum.Font.Code
	oLbl.TextSize = 20
	oLbl.TextColor3 = COL_AMBER
	oLbl.Text = "DEPLOYING..."
	oLbl.ZIndex = 6
	oLbl.Parent = overlay
	launchOverlayLabel = oLbl

	-- Bottom Toast Notification
	local toast = Instance.new("TextLabel")
	toast.Name = "Toast"
	toast.AnchorPoint = Vector2.new(0.5, 1)
	toast.Position = UDim2.new(0.5, 0, 1, -10)
	toast.Size = UDim2.new(1, -28, 0, 28)
	toast.BackgroundColor3 = Color3.fromRGB(14, 38, 26)
	toast.BorderSizePixel = 0
	toast.Font = Enum.Font.Code
	toast.TextSize = 13
	toast.TextColor3 = COL_GREEN
	toast.Visible = false
	toast.Parent = panel
	addCorner(toast, 4)
	toastLabel = toast
end

function LobbyUI.init()
	if initialized then
		return
	end
	initialized = true

	lobbyActionRemote = NetContracts.getRemoteEvent(NetContracts.Remotes.LobbyAction, false)
	lobbySyncRemote = NetContracts.getRemoteEvent(NetContracts.Remotes.LobbyStateSync, false)
	returnLobbyRemote = NetContracts.getRemoteEvent(NetContracts.Remotes.ReturnToLobby, false)

	createGui()

	lobbySyncRemote.OnClientEvent:Connect(function(payload: LobbyStatePayload)
		applyState(payload)
	end)

	ReplicatedStorage:GetAttributeChangedSignal(NetContracts.Attributes.ServerMode):Connect(function()
		updateMatchReturnHint()
		if ReplicatedStorage:GetAttribute(NetContracts.Attributes.ServerMode) == "Lobby" then
			fireAction({ action = "requestSync" })
		else
			mainPanel.Visible = false
			reopenButton.Visible = false
		end
	end)

	localPlayer:GetAttributeChangedSignal(NetContracts.Attributes.InSafeRoom):Connect(updateMatchReturnHint)

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if input.KeyCode == GameConfig.Lobby.ReturnLobbyKey then
			local mode = ReplicatedStorage:GetAttribute(NetContracts.Attributes.ServerMode)
			if mode == "Match" and localPlayer:GetAttribute(NetContracts.Attributes.InSafeRoom) == true then
				returnLobbyRemote:FireServer()
			end
		end
	end)

	updateMatchReturnHint()
	fireAction({ action = "requestSync" })
end

return LobbyUI
