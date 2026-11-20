--!strict
--[[
	Client Panic, Stamina & Noise emitter:
	- Renders Stale Air / Panic HUD bar & pulsing red edge vignette when PanicRatio > 0.04 in vents.
	- Renders auto-hiding Scramble Stamina bar when stamina < 0.99 inside vents.
	- Emits rate-limited Crawl or loud FastCrawl noise alerts to server when moving inside vents.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NetContracts = require(Shared:WaitForChild("NetContracts"))

local PanicController = {}

local localPlayer = Players.LocalPlayer
local initialized = false
local lastCrawlNoiseTime = 0

local container: Frame? = nil
local fillBar: Frame? = nil
local statusLbl: TextLabel? = nil
local vignette: Frame? = nil

local staminaBox: Frame? = nil
local staminaFill: Frame? = nil
local staminaLbl: TextLabel? = nil

local function updateVisuals(ratio: number)
	if not container or not fillBar or not statusLbl or not vignette then
		return
	end

	local inSafeRoom = localPlayer:GetAttribute(NetContracts.Attributes.InSafeRoom) == true
	local visible = (not inSafeRoom) and ratio > 0.04
	container.Visible = visible
	vignette.Visible = visible and ratio > 0.45

	if visible then
		fillBar.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
		if ratio >= 0.85 then
			fillBar.BackgroundColor3 = Color3.fromRGB(235, 65, 55)
			statusLbl.Text = "PANIC: GASPING!"
			statusLbl.TextColor3 = Color3.fromRGB(255, 110, 100)
		elseif ratio >= 0.50 then
			fillBar.BackgroundColor3 = Color3.fromRGB(240, 165, 55)
			statusLbl.Text = "STALE AIR: TENSE"
			statusLbl.TextColor3 = Color3.fromRGB(245, 195, 95)
		else
			fillBar.BackgroundColor3 = Color3.fromRGB(130, 185, 225)
			statusLbl.Text = "STALE AIR"
			statusLbl.TextColor3 = Color3.fromRGB(190, 215, 235)
		end

		if vignette.Visible then
			local pulse = (math.sin(os.clock() * (4 + ratio * 6)) + 1) * 0.5
			local baseAlpha = 1 - math.clamp((ratio - 0.45) * 0.9, 0.05, 0.55)
			vignette.BackgroundTransparency = math.clamp(baseAlpha - pulse * 0.08, 0.35, 0.96)
		end
	end

	if staminaBox and staminaFill and staminaLbl then
		local stamina = (localPlayer:GetAttribute(NetContracts.Attributes.StaminaRatio) :: number?) or 1.0
		local isFast = localPlayer:GetAttribute(NetContracts.Attributes.IsFastCrawling) == true
		local showStamina = (not inSafeRoom) and (stamina < 0.99 or isFast)
		staminaBox.Visible = showStamina
		if showStamina then
			staminaFill.Size = UDim2.fromScale(math.clamp(stamina, 0, 1), 1)
			if isFast then
				staminaFill.BackgroundColor3 = Color3.fromRGB(245, 185, 65)
				staminaLbl.Text = "SCRAMBLING [LOUD]"
				staminaLbl.TextColor3 = Color3.fromRGB(255, 210, 115)
			elseif stamina < 0.20 then
				staminaFill.BackgroundColor3 = Color3.fromRGB(220, 75, 65)
				staminaLbl.Text = "WINDED"
				staminaLbl.TextColor3 = Color3.fromRGB(245, 130, 120)
			else
				staminaFill.BackgroundColor3 = Color3.fromRGB(165, 215, 175)
				staminaLbl.Text = "STAMINA [SHIFT]"
				staminaLbl.TextColor3 = Color3.fromRGB(195, 225, 200)
			end
		end
	end
end

local function createHud()
	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local existing = playerGui:FindFirstChild("PanicHud")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "PanicHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local vig = Instance.new("Frame")
	vig.Name = "Vignette"
	vig.Size = UDim2.fromScale(1, 1)
	vig.BackgroundColor3 = Color3.fromRGB(90, 8, 8)
	vig.BackgroundTransparency = 0.9
	vig.BorderSizePixel = 0
	vig.Visible = false
	vig.ZIndex = 1
	vig.Parent = gui

	local frame = Instance.new("Frame")
	frame.Name = "PanicBox"
	frame.AnchorPoint = Vector2.new(0, 1)
	frame.Position = UDim2.new(0, 20, 1, -54)
	frame.Size = UDim2.fromOffset(220, 32)
	frame.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
	frame.BackgroundTransparency = 0.35
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.ZIndex = 2
	frame.Parent = gui

	local lbl = Instance.new("TextLabel")
	lbl.Name = "Label"
	lbl.Position = UDim2.fromOffset(8, 2)
	lbl.Size = UDim2.new(1, -16, 0, 16)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.Code
	lbl.TextSize = 12
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Text = "STALE AIR"
	lbl.ZIndex = 3
	lbl.Parent = frame

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Position = UDim2.fromOffset(8, 21)
	track.Size = UDim2.new(1, -16, 0, 6)
	track.BackgroundColor3 = Color3.fromRGB(28, 34, 42)
	track.BorderSizePixel = 0
	track.ZIndex = 3
	track.Parent = frame

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(130, 185, 225)
	fill.BorderSizePixel = 0
	fill.ZIndex = 4
	fill.Parent = track

	local sBox = Instance.new("Frame")
	sBox.Name = "StaminaBox"
	sBox.AnchorPoint = Vector2.new(0, 1)
	sBox.Position = UDim2.new(0, 20, 1, -92)
	sBox.Size = UDim2.fromOffset(220, 30)
	sBox.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
	sBox.BackgroundTransparency = 0.35
	sBox.BorderSizePixel = 0
	sBox.Visible = false
	sBox.ZIndex = 2
	sBox.Parent = gui

	local sLbl = Instance.new("TextLabel")
	sLbl.Name = "Label"
	sLbl.Position = UDim2.fromOffset(8, 2)
	sLbl.Size = UDim2.new(1, -16, 0, 14)
	sLbl.BackgroundTransparency = 1
	sLbl.Font = Enum.Font.Code
	sLbl.TextSize = 11
	sLbl.TextXAlignment = Enum.TextXAlignment.Left
	sLbl.Text = "STAMINA [SHIFT]"
	sLbl.ZIndex = 3
	sLbl.Parent = sBox

	local sTrack = Instance.new("Frame")
	sTrack.Name = "Track"
	sTrack.Position = UDim2.fromOffset(8, 19)
	sTrack.Size = UDim2.new(1, -16, 0, 5)
	sTrack.BackgroundColor3 = Color3.fromRGB(28, 34, 42)
	sTrack.BorderSizePixel = 0
	sTrack.ZIndex = 3
	sTrack.Parent = sBox

	local sFill = Instance.new("Frame")
	sFill.Name = "Fill"
	sFill.Size = UDim2.fromScale(1, 1)
	sFill.BackgroundColor3 = Color3.fromRGB(165, 215, 175)
	sFill.BorderSizePixel = 0
	sFill.ZIndex = 4
	sFill.Parent = sTrack

	container = frame
	fillBar = fill
	statusLbl = lbl
	vignette = vig
	staminaBox = sBox
	staminaFill = sFill
	staminaLbl = sLbl
end

function PanicController.init()
	if initialized then
		return
	end
	initialized = true

	createHud()

	local noiseRemote = NetContracts.getRemoteEvent(NetContracts.Remotes.NoiseEmitted, false)
	local panicSyncRemote = NetContracts.getRemoteEvent(NetContracts.Remotes.PanicStateSync, false)

	panicSyncRemote.OnClientEvent:Connect(function(payload: unknown)
		if typeof(payload) == "table" and typeof((payload :: any).panicRatio) == "number" then
			updateVisuals((payload :: any).panicRatio)
		end
	end)

	localPlayer:GetAttributeChangedSignal(NetContracts.Attributes.InSafeRoom):Connect(function()
		local ratio = (localPlayer:GetAttribute(NetContracts.Attributes.PanicRatio) :: number?) or 0
		updateVisuals(ratio)
	end)

	RunService.Heartbeat:Connect(function()
		local ratio = (localPlayer:GetAttribute(NetContracts.Attributes.PanicRatio) :: number?) or 0
		updateVisuals(ratio)

		if localPlayer:GetAttribute(NetContracts.Attributes.IsCrawling) ~= true then
			return
		end
		local char = localPlayer.Character
		local root = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		if not root then
			return
		end

		local horizSpeed = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
		local isFast = localPlayer:GetAttribute(NetContracts.Attributes.IsFastCrawling) == true
		local now = os.clock()

		if isFast and horizSpeed > 3.5 then
			if now - lastCrawlNoiseTime >= 0.55 then
				lastCrawlNoiseTime = now
				noiseRemote:FireServer({ noiseType = "FastCrawl" })
			end
		elseif horizSpeed > 2.2 then
			if now - lastCrawlNoiseTime >= 1.2 then
				lastCrawlNoiseTime = now
				noiseRemote:FireServer({ noiseType = "Crawl" })
			end
		end
	end)
end

return PanicController
