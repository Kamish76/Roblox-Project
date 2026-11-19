--!strict
--[[
	Client 3-layer spatial audio & proximity tell controller:
	1. Entity spatial Sound emitter (JointCracker scrapes/cracks, pitch scales in Chase)
	2. Active RepairNode electrical hum (~1.75 tiles roll-off)
	3. Ambient building creaks + headlamp click + panic gasp + scare sting
	Configured via GameConfig.Audio (empty SoundIds safely remain silent with zero console errors).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EntityProfiles = require(Shared:WaitForChild("EntityProfiles"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local NetContracts = require(Shared:WaitForChild("NetContracts"))

local AudioController = {}

local activeProfile = EntityProfiles.getActiveProfile()
local localPlayer = Players.LocalPlayer
local initialized = false

local entitySound: Sound? = nil
local faultHumSounds: { [Model]: Sound } = {}
local ambientSound: Sound? = nil
local gaspSound: Sound? = nil
local clickSound: Sound? = nil
local stingSound: Sound? = nil
local nextCreakTime = os.clock() + 10
local lastGaspPlay = 0

local function createSound(name: string, soundId: string, parent: Instance, looped: boolean, volume: number, maxDist: number?): Sound
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Sound") then
		return existing
	end
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = soundId
	s.Looped = looped
	s.Volume = volume
	if maxDist then
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = 4
		s.RollOffMaxDistance = maxDist
	end
	s.Parent = parent
	return s
end

local function ensureFaultHum(nodeModel: Model)
	if faultHumSounds[nodeModel] then
		return
	end
	task.spawn(function()
		local body: BasePart? = nodeModel.PrimaryPart
		if not body then
			local waited = nodeModel:WaitForChild("JunctionBox", 10)
			if waited and waited:IsA("BasePart") then
				body = waited
			end
		end
		if not body or not nodeModel.Parent then
			return
		end
		local hum = createSound(
			"FaultHum",
			GameConfig.Audio.FaultHumId,
			body,
			true,
			0.45,
			GameConfig.Audio.FaultHumMaxDistance
		)
		faultHumSounds[nodeModel] = hum

		local function refresh()
			local isFault = nodeModel:GetAttribute("IsActiveFault") == true and nodeModel:GetAttribute("IsRepaired") ~= true
			if isFault and GameConfig.Audio.FaultHumId ~= "" then
				if not hum.IsPlaying then
					hum:Play()
				end
			else
				if hum.IsPlaying then
					hum:Stop()
				end
			end
		end

		nodeModel:GetAttributeChangedSignal("IsActiveFault"):Connect(refresh)
		nodeModel:GetAttributeChangedSignal("IsRepaired"):Connect(refresh)
		refresh()
	end)
end

local function ensureEntityAudio()
	local ventMap = workspace:FindFirstChild("VentMap")
	local entity = if ventMap then ventMap:FindFirstChild(activeProfile.id) else nil
	local core = if entity and entity:IsA("Model") then entity.PrimaryPart else nil
	if not core then
		return
	end
	if entitySound and entitySound.Parent == core then
		return
	end

	local s = createSound(
		"EntityScrape",
		GameConfig.Audio.EntityScrapeId,
		core,
		true,
		0.75,
		GameConfig.Audio.EntityMaxDistance
	)
	entitySound = s
	if GameConfig.Audio.EntityScrapeId ~= "" and not s.IsPlaying then
		s:Play()
	end
end

function AudioController.playScareSting()
	if stingSound and GameConfig.Audio.ScareStingId ~= "" then
		stingSound:Play()
	end
end

function AudioController.init()
	if initialized then
		return
	end
	initialized = true

	local audioFolder = Instance.new("Folder")
	audioFolder.Name = "ClientAudio"
	audioFolder.Parent = SoundService

	ambientSound = createSound("AmbientCreak", GameConfig.Audio.AmbientCreakId, audioFolder, false, 0.35, nil)
	gaspSound = createSound("PanicGasp", GameConfig.Audio.PanicGaspId, audioFolder, false, 0.65, nil)
	clickSound = createSound("HeadlampClick", GameConfig.Audio.HeadlampClickId, audioFolder, false, 0.55, nil)
	stingSound = createSound("ScareSting", GameConfig.Audio.ScareStingId, audioFolder, false, 0.90, nil)

	for _, inst in ipairs(CollectionService:GetTagged(NetContracts.Tags.RepairNode)) do
		if inst:IsA("Model") then
			ensureFaultHum(inst)
		end
	end
	CollectionService:GetInstanceAddedSignal(NetContracts.Tags.RepairNode):Connect(function(inst)
		if inst:IsA("Model") then
			ensureFaultHum(inst)
		end
	end)

	localPlayer:GetAttributeChangedSignal(NetContracts.Attributes.HeadlampOn):Connect(function()
		if clickSound and GameConfig.Audio.HeadlampClickId ~= "" then
			clickSound:Play()
		end
	end)

	local eliminatedRemote = NetContracts.getRemoteEvent(NetContracts.Remotes.PlayerEliminated, false)
	eliminatedRemote.OnClientEvent:Connect(function()
		AudioController.playScareSting()
	end)

	RunService.Heartbeat:Connect(function()
		ensureEntityAudio()

		local ventMap = workspace:FindFirstChild("VentMap")
		local entity = if ventMap then ventMap:FindFirstChild(activeProfile.id) else nil
		if entity and entitySound then
			local state = entity:GetAttribute("EntityState")
			entitySound.PlaybackSpeed = if state == "Chase" then 1.35 else 1.0
		end

		local now = os.clock()
		local panicRatio = (localPlayer:GetAttribute(NetContracts.Attributes.PanicRatio) :: number?) or 0
		if panicRatio >= GameConfig.Panic.GaspThreshold and localPlayer:GetAttribute(NetContracts.Attributes.InSafeRoom) == false then
			if now - lastGaspPlay >= GameConfig.Panic.GaspInterval then
				lastGaspPlay = now
				if gaspSound and GameConfig.Audio.PanicGaspId ~= "" then
					gaspSound:Play()
				end
			end
		end

		if now >= nextCreakTime then
			nextCreakTime = now + math.random(GameConfig.Audio.CreakIntervalMin, GameConfig.Audio.CreakIntervalMax)
			if ambientSound and GameConfig.Audio.AmbientCreakId ~= "" and localPlayer:GetAttribute(NetContracts.Attributes.InSafeRoom) == false then
				ambientSound:Play()
			end
		end
	end)
end

return AudioController
