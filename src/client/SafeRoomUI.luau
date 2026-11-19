--!strict
--[[
	Client Work Order HUD, Elimination Jump-Scare Flash, and Teammate Spectate cycling.
	Synced from server RoundStateSync & PlayerEliminated broadcasts.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NetContracts = require(Shared:WaitForChild("NetContracts"))

type RoundStatePayload = {
	phase: string,
	activeSectors: { [string]: boolean },
	repairedCount: number,
	requiredCount: number,
	totalXP: number,
	lastOutcome: string?,
}

local SafeRoomUI = {}

local localPlayer = Players.LocalPlayer
local initialized = false

local statusLabel: TextLabel? = nil
local sectorsLabel: TextLabel? = nil
local bannerLabel: TextLabel? = nil
local scareFlash: Frame? = nil
local spectateLabel: TextLabel? = nil
local spectateIndex = 0

local function formatSectors(activeSectors: { [string]: boolean }?): string
	if not activeSectors then
		return "FAULT SECTORS: --"
	end
	local list: { string } = {}
	for _, sec in ipairs({ "A", "B", "C", "D" }) do
		if activeSectors[sec] then
			table.insert(list, sec)
		end
	end
	if #list == 0 then
		return "FAULT SECTORS: ALL CLEAR"
	end
	return "FAULT SECTORS: " .. table.concat(list, " · ")
end

local function restoreLocalCamera()
	local cam = workspace.CurrentCamera
	local char = localPlayer.Character
	local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
	if cam and hum then
		cam.CameraSubject = hum
	end
	if spectateLabel then
		if localPlayer:GetAttribute(NetContracts.Attributes.IsEliminated) == true then
			spectateLabel.Visible = true
			spectateLabel.Text = "ELIMINATED — SAFE ROOM LOCKDOWN  |  [TAB] SPECTATE SQUAD"
		else
			spectateLabel.Visible = false
		end
	end
end

local function cycleSpectate()
	if localPlayer:GetAttribute(NetContracts.Attributes.IsEliminated) ~= true then
		return
	end

	local aliveTargets: { Player } = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= localPlayer and p:GetAttribute(NetContracts.Attributes.IsEliminated) ~= true then
			local char = p.Character
			local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
			if hum and hum.Health > 0 then
				table.insert(aliveTargets, p)
			end
		end
	end

	local cam = workspace.CurrentCamera
	if not cam then
		return
	end

	spectateIndex += 1
	if spectateIndex > #aliveTargets then
		spectateIndex = 0
		restoreLocalCamera()
		return
	end

	local target = aliveTargets[spectateIndex]
	local hum = if target.Character then target.Character:FindFirstChildOfClass("Humanoid") else nil
	if hum then
		cam.CameraSubject = hum
		if spectateLabel then
			spectateLabel.Visible = true
			spectateLabel.Text = string.format("SPECTATING: %s  |  [TAB] NEXT / SAFE ROOM", target.Name)
		end
	end
end

local function triggerScareFlash()
	if not scareFlash then
		return
	end
	scareFlash.Visible = true
	scareFlash.BackgroundTransparency = 0.15
	task.spawn(function()
		for i = 1, 12 do
			task.wait(0.08)
			if scareFlash then
				scareFlash.BackgroundTransparency = 0.15 + (i / 12) * 0.85
			end
		end
		if scareFlash then
			scareFlash.Visible = false
		end
	end)
end

local function applyState(payload: RoundStatePayload)
	if not statusLabel or not sectorsLabel or not bannerLabel then
		return
	end

	statusLabel.Text = string.format(
		"WORK ORDER: %d / %d REPAIRED  |  XP: %d",
		payload.repairedCount or 0,
		payload.requiredCount or 5,
		payload.totalXP or 0
	)
	sectorsLabel.Text = formatSectors(payload.activeSectors)

	if payload.phase == "Summary" and payload.lastOutcome then
		bannerLabel.Visible = true
		bannerLabel.Text = payload.lastOutcome
	else
		bannerLabel.Visible = false
	end
end

local function createHud()
	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local existing = playerGui:FindFirstChild("WorkOrderHud")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "WorkOrderHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local flash = Instance.new("Frame")
	flash.Name = "ScareFlash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromRGB(165, 12, 12)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Visible = false
	flash.ZIndex = 10
	flash.Parent = gui

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(1, 0)
	card.Position = UDim2.new(1, -20, 0, 20)
	card.Size = UDim2.fromOffset(330, 56)
	card.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
	card.BackgroundTransparency = 0.35
	card.BorderSizePixel = 0
	card.Parent = gui

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingTop = UDim.new(0, 6)
	pad.Parent = card

	local sLbl = Instance.new("TextLabel")
	sLbl.Name = "Progress"
	sLbl.Size = UDim2.new(1, 0, 0, 22)
	sLbl.BackgroundTransparency = 1
	sLbl.Font = Enum.Font.Code
	sLbl.TextSize = 14
	sLbl.TextXAlignment = Enum.TextXAlignment.Left
	sLbl.TextColor3 = Color3.fromRGB(220, 236, 255)
	sLbl.Text = "WORK ORDER: 0 / 5 REPAIRED  |  XP: 0"
	sLbl.Parent = card

	local secLbl = Instance.new("TextLabel")
	secLbl.Name = "Sectors"
	secLbl.Position = UDim2.fromOffset(0, 24)
	secLbl.Size = UDim2.new(1, 0, 0, 20)
	secLbl.BackgroundTransparency = 1
	secLbl.Font = Enum.Font.Code
	secLbl.TextSize = 13
	secLbl.TextXAlignment = Enum.TextXAlignment.Left
	secLbl.TextColor3 = Color3.fromRGB(245, 185, 85)
	secLbl.Text = "FAULT SECTORS: --"
	secLbl.Parent = card

	local bLbl = Instance.new("TextLabel")
	bLbl.Name = "OutcomeBanner"
	bLbl.AnchorPoint = Vector2.new(0.5, 0)
	bLbl.Position = UDim2.new(0.5, 0, 0, 74)
	bLbl.Size = UDim2.fromOffset(440, 38)
	bLbl.BackgroundColor3 = Color3.fromRGB(16, 22, 30)
	bLbl.BackgroundTransparency = 0.2
	bLbl.BorderSizePixel = 0
	bLbl.Font = Enum.Font.Code
	bLbl.TextSize = 16
	bLbl.TextColor3 = Color3.fromRGB(255, 220, 120)
	bLbl.Visible = false
	bLbl.Parent = gui

	local spLbl = Instance.new("TextLabel")
	spLbl.Name = "SpectateBanner"
	spLbl.AnchorPoint = Vector2.new(0.5, 1)
	spLbl.Position = UDim2.new(0.5, 0, 1, -24)
	spLbl.Size = UDim2.fromOffset(490, 30)
	spLbl.BackgroundColor3 = Color3.fromRGB(24, 12, 14)
	spLbl.BackgroundTransparency = 0.25
	spLbl.BorderSizePixel = 0
	spLbl.Font = Enum.Font.Code
	spLbl.TextSize = 13
	spLbl.TextColor3 = Color3.fromRGB(255, 130, 120)
	spLbl.Visible = false
	spLbl.Parent = gui

	statusLabel = sLbl
	sectorsLabel = secLbl
	bannerLabel = bLbl
	scareFlash = flash
	spectateLabel = spLbl
end

function SafeRoomUI.init()
	if initialized then
		return
	end
	initialized = true

	createHud()

	local roundSync = NetContracts.getRemoteEvent(NetContracts.Remotes.RoundStateSync, false)
	roundSync.OnClientEvent:Connect(function(payload: RoundStatePayload)
		applyState(payload)
	end)

	local eliminatedRemote = NetContracts.getRemoteEvent(NetContracts.Remotes.PlayerEliminated, false)
	eliminatedRemote.OnClientEvent:Connect(function()
		triggerScareFlash()
	end)

	localPlayer:GetAttributeChangedSignal(NetContracts.Attributes.IsEliminated):Connect(function()
		spectateIndex = 0
		restoreLocalCamera()
	end)

	localPlayer.CharacterAdded:Connect(function()
		task.defer(restoreLocalCamera)
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Tab then
			cycleSpectate()
		end
	end)
end

return SafeRoomUI
