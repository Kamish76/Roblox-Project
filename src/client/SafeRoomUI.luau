--!strict
--[[
	Client Work Order HUD synced from server RoundStateSync broadcasts.
	Displays active repair progress, faulted sectors, and extraction sign-off outcomes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

	statusLabel = sLbl
	sectorsLabel = secLbl
	bannerLabel = bLbl
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
end

return SafeRoomUI
