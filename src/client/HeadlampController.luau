--!strict
--[[
	Client headlamp controller:
	- Drives a camera-tracked SpotLight rig (with subtle handheld damping) inside Workspace._LocalClientVFX.
	- Toggles via [F], replicates state to the server via HeadlampToggled, and renders co-op teammates' beams.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EntityProfiles = require(Shared:WaitForChild("EntityProfiles"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local NetContracts = require(Shared:WaitForChild("NetContracts"))

local HeadlampController = {}

local activeProfile = EntityProfiles.getActiveProfile()

local localPlayer = Players.LocalPlayer
local initialized = false
local isOn = true
local lastToggleTime = 0

local headlampPart: Part
local primaryBeam: SpotLight
local fillBeam: SpotLight
local statusLabel: TextLabel?
local remoteLights: { [Player]: SpotLight } = {}

local function updateHud()
	if not statusLabel then
		return
	end
	if isOn then
		statusLabel.Text = "[F] HEADLAMP: ON"
		statusLabel.TextColor3 = Color3.fromRGB(220, 236, 255)
	else
		statusLabel.Text = "[F] HEADLAMP: OFF"
		statusLabel.TextColor3 = Color3.fromRGB(145, 110, 110)
	end
end

local function applyLocalLightState(enabled: boolean)
	isOn = enabled
	primaryBeam.Enabled = enabled
	fillBeam.Enabled = enabled
	updateHud()
end

local function createLocalHud()
	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local existing = playerGui:FindFirstChild("M1Hud")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "M1Hud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local label = Instance.new("TextLabel")
	label.Name = "HeadlampStatus"
	label.AnchorPoint = Vector2.new(0, 1)
	label.Position = UDim2.new(0, 20, 1, -18)
	label.Size = UDim2.fromOffset(220, 28)
	label.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
	label.BackgroundTransparency = 0.45
	label.BorderSizePixel = 0
	label.Font = Enum.Font.Code
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = gui

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.Parent = label

	statusLabel = label
	updateHud()
end

local function createLocalHeadlampRig()
	local vfxFolder = workspace:FindFirstChild("_LocalClientVFX")
	if not vfxFolder then
		vfxFolder = Instance.new("Folder")
		vfxFolder.Name = "_LocalClientVFX"
		vfxFolder.Parent = workspace
	end

	local existing = vfxFolder:FindFirstChild("LocalHeadlampRig")
	if existing then
		existing:Destroy()
	end

	local part = Instance.new("Part")
	part.Name = "LocalHeadlampRig"
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = vfxFolder

	local beam = Instance.new("SpotLight")
	beam.Name = "Beam"
	beam.Face = Enum.NormalId.Front
	beam.Brightness = GameConfig.Headlamp.Brightness
	beam.Range = GameConfig.Headlamp.Range
	beam.Angle = GameConfig.Headlamp.Angle
	beam.Color = GameConfig.Headlamp.Color
	beam.Shadows = true
	beam.Enabled = isOn
	beam.Parent = part

	local fill = Instance.new("SpotLight")
	fill.Name = "Fill"
	fill.Face = Enum.NormalId.Front
	fill.Brightness = GameConfig.Headlamp.FillBrightness
	fill.Range = GameConfig.Headlamp.FillRange
	fill.Angle = GameConfig.Headlamp.FillAngle
	fill.Color = GameConfig.Headlamp.Color
	fill.Shadows = false
	fill.Enabled = isOn
	fill.Parent = part

	headlampPart = part
	primaryBeam = beam
	fillBeam = fill
end

local function attachTeammateLight(player: Player, character: Model)
	if player == localPlayer then
		return
	end
	local head = character:WaitForChild("Head", 10) :: BasePart?
	if not head then
		return
	end

	local existing = head:FindFirstChild("TeammateHeadlamp")
	if existing and existing:IsA("SpotLight") then
		remoteLights[player] = existing
	else
		local light = Instance.new("SpotLight")
		light.Name = "TeammateHeadlamp"
		light.Face = Enum.NormalId.Front
		light.Brightness = GameConfig.Headlamp.Brightness * 0.8
		light.Range = GameConfig.Headlamp.Range * 0.85
		light.Angle = GameConfig.Headlamp.Angle
		light.Color = GameConfig.Headlamp.Color
		light.Shadows = true
		light.Parent = head
		remoteLights[player] = light
	end

	local attrState = player:GetAttribute(NetContracts.Attributes.HeadlampOn)
	remoteLights[player].Enabled = if typeof(attrState) == "boolean" then attrState else true
end

local function watchRemotePlayer(player: Player)
	if player == localPlayer then
		return
	end

	player.CharacterAdded:Connect(function(character)
		attachTeammateLight(player, character)
	end)
	if player.Character then
		task.spawn(attachTeammateLight, player, player.Character)
	end

	player:GetAttributeChangedSignal(NetContracts.Attributes.HeadlampOn):Connect(function()
		local light = remoteLights[player]
		if light then
			local attrState = player:GetAttribute(NetContracts.Attributes.HeadlampOn)
			light.Enabled = if typeof(attrState) == "boolean" then attrState else true
		end
	end)
end

function HeadlampController.isEnabled(): boolean
	return isOn
end

function HeadlampController.init()
	if initialized then
		return
	end
	initialized = true

	local initialAttr = localPlayer:GetAttribute(NetContracts.Attributes.HeadlampOn)
	if typeof(initialAttr) == "boolean" then
		isOn = initialAttr
	end

	createLocalHeadlampRig()
	createLocalHud()

	local headlampRemote = NetContracts.getRemoteEvent(NetContracts.Remotes.HeadlampToggled, false)

	-- Sync if server updates attribute (e.g., force-off by future entity events)
	localPlayer:GetAttributeChangedSignal(NetContracts.Attributes.HeadlampOn):Connect(function()
		local serverVal = localPlayer:GetAttribute(NetContracts.Attributes.HeadlampOn)
		if typeof(serverVal) == "boolean" and serverVal ~= isOn then
			applyLocalLightState(serverVal)
		end
	end)

	headlampRemote.OnClientEvent:Connect(function(targetPlayer: Player, newState: boolean)
		if targetPlayer == localPlayer then
			if typeof(newState) == "boolean" and newState ~= isOn then
				applyLocalLightState(newState)
			end
			return
		end
		local light = remoteLights[targetPlayer]
		if light and typeof(newState) == "boolean" then
			light.Enabled = newState
		end
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if input.KeyCode ~= GameConfig.Headlamp.ToggleKey then
			return
		end

		local now = os.clock()
		if now - lastToggleTime < GameConfig.Headlamp.ToggleCooldown then
			return
		end
		lastToggleTime = now

		local nextState = not isOn
		applyLocalLightState(nextState)
		headlampRemote:FireServer(nextState)
	end)

	Players.PlayerAdded:Connect(watchRemotePlayer)
	Players.PlayerRemoving:Connect(function(player)
		remoteLights[player] = nil
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		watchRemotePlayer(player)
	end

	RunService.RenderStepped:Connect(function(dt: number)
		local camera = workspace.CurrentCamera
		if not camera or not headlampPart.Parent then
			return
		end
		local targetCFrame = camera.CFrame * GameConfig.Headlamp.CameraOffset
		local alpha = 1 - math.exp(-GameConfig.Headlamp.LagRate * dt)
		headlampPart.CFrame = headlampPart.CFrame:Lerp(targetCFrame, alpha)

		-- Diegetic proximity flicker when entity approaches inside vents
		if isOn and localPlayer:GetAttribute(NetContracts.Attributes.InSafeRoom) == false then
			local ventMap = workspace:FindFirstChild("VentMap")
			local entity = if ventMap then ventMap:FindFirstChild(activeProfile.id) else nil
			local core = if entity and entity:IsA("Model") then entity.PrimaryPart else nil
			if core then
				local dist = (camera.CFrame.Position - core.Position).Magnitude
				if dist <= activeProfile.proximityFlickerRange then
					local intensity = 1 - (dist / activeProfile.proximityFlickerRange)
					local flicker = 0.35 + 0.65 * math.abs(math.sin(os.clock() * (18 + intensity * 28)))
					if math.sin(os.clock() * 47) > (0.85 - intensity * 0.4) then
						flicker = 0.12
					end
					primaryBeam.Brightness = GameConfig.Headlamp.Brightness * flicker
					fillBeam.Brightness = GameConfig.Headlamp.FillBrightness * flicker
					return
				end
			end
		end

		primaryBeam.Brightness = GameConfig.Headlamp.Brightness
		fillBeam.Brightness = GameConfig.Headlamp.FillBrightness
	end)
end

return HeadlampController
