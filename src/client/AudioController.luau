--!strict
--[[
	Client psychological spatial audio & acoustic atmosphere controller:
	1. DSP SoundGroup architecture:
	   - VentDuctGroup: metallic sheet-metal reverb + resonant EQ for spatial duct realism
	   - EntityAudioGroup: dedicated creature bus with dynamic distance + wall-occlusion low-pass EQ
	   - SubliminalTensionGroup: dry, low-passed internal dread bed + muffled heartbeat
	   - SafeRoomGroup: warm, grounded overhead fluorescent room tone for acoustic contrast
	2. Uncanny multi-layer Entity audio (JointCracker):
	   - Movement & state-gated EntityScrape (dead-silent in Lurk so silence becomes the tell)
	   - Cadenced MoveSpeed-synced limb foley (EntityLimbSlide + EntityLimbThud)
	   - Intermittent dry EntityJointCrack, close-range EntityWetShift & studio EntityLurkExhale
	   - Headlamp-triggered faint EntityWhisper ("turn it off...") when lurking/stalking nearby
	   - Spotted/whip-back startle burst (EntityStartleSlap + EntityTendonSnap) on Scramble/Retreat
	   - Pre-cue Room Tone Vacuum briefly dips VentAmbience before close creature micro-cues
	3. 3D Blind-Spot Phantom Ambience (Workspace._LocalClientVFX.PhantomAudioAnchor):
	   - Spawns ambiguous thermal duct groans/knocks/creaks 18–36 studs behind/flanking the camera
	   - Automatically pauses when entity is close (<18 studs) or chasing so real tells stay readable
	4. Dynamic Tension & Silence Ducking:
	   - Smooth tensionRatio ducks VentAmbience, swells subliminal TensionDrone & muffled Heartbeat
	5. Diegetic World Polish:
	   - Safe Room <-> Vent acoustic crossfade + HatchThump transition
	   - Headlamp proximity flicker filament buzz + RepairNode active spark arcing
	   - Restrained elimination sting (chilling dread over ear-blasting jumpscares)
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

-- DSP SoundGroups & live filter references
local ventDuctGroup: SoundGroup? = nil
local entityAudioGroup: SoundGroup? = nil
local entityOcclusionEq: EqualizerSoundEffect? = nil
local subliminalGroup: SoundGroup? = nil
local safeRoomGroup: SoundGroup? = nil

-- Entity spatial emitters (attached to JointCracker.PrimaryPart)
local entityScrapeSound: Sound? = nil
local entityJointCrackSound: Sound? = nil
local entityWetShiftSound: Sound? = nil
local entityLurkExhaleSound: Sound? = nil
local entityWhisperSound: Sound? = nil
local entityLimbSlideSound: Sound? = nil
local entityLimbThudSound: Sound? = nil
local entityStartleSlapSound: Sound? = nil
local entityTendonSnapSound: Sound? = nil

-- Entity cadence & occlusion state
local lastEntityState = ""
local nextJointCrackTime = os.clock() + 4.0
local nextWetShiftTime = os.clock() + 6.5
local nextLurkExhaleTime = os.clock() + 5.0
local nextWhisperTime = os.clock() + 10.0
local limbStepAccumulator = 0.0
local nextLimbStepDistance = 2.6
local limbStepToggle = false
local lastOcclusionCheck = 0.0
local entityIsOccluded = true
local snippetTokens: { [Sound]: number } = {}

-- World repair node sounds
local faultHumSounds: { [Model]: Sound } = {}
local repairSparkSounds: { [Model]: Sound } = {}

-- 3D blind-spot phantom ambience anchor
local phantomAnchor: Part? = nil
local phantomGroanSound: Sound? = nil
local phantomKnockSound: Sound? = nil
local phantomCreakSound: Sound? = nil
local nextPhantomTime = os.clock() + 11.0

-- Local / internal psychological sounds
local ventAmbienceSound: Sound? = nil
local safeRoomHumSound: Sound? = nil
local tensionDroneSound: Sound? = nil
local heartbeatSound: Sound? = nil
local flickerBuzzSound: Sound? = nil
local hatchThumpSound: Sound? = nil
local crawlScrapeSound: Sound? = nil
local fastCrawlScrapeSound: Sound? = nil
local gaspSound: Sound? = nil
local clickSound: Sound? = nil
local stingSound: Sound? = nil

-- Runtime smoothing & timers
local currentTension = 0.0
local roomToneVacuumUntil = 0.0
local wasInVents: boolean? = nil
local lastGaspPlay = 0
local lastCrawlAudioPlay = 0

local function randRange(minVal: number, maxVal: number): number
	return minVal + math.random() * (maxVal - minVal)
end

local function createSound(
	name: string,
	soundId: string,
	parent: Instance,
	looped: boolean,
	volume: number,
	maxDist: number?,
	group: SoundGroup?
): Sound
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Sound") then
		existing.SoundId = soundId
		existing.Looped = looped
		existing.SoundGroup = group
		return existing
	end
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = soundId
	s.Looped = looped
	s.Volume = volume
	s.SoundGroup = group
	if maxDist then
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = 4
		s.RollOffMaxDistance = maxDist
	end
	s.Parent = parent
	return s
end

local function playOneShot(sound: Sound?, soundId: string, volume: number, speedMin: number, speedMax: number)
	if not sound or soundId == "" then
		return
	end
	sound.Volume = volume
	sound.PlaybackSpeed = randRange(speedMin, speedMax)
	sound.TimePosition = 0
	sound:Play()
end

local function playFadeSnippet(
	sound: Sound?,
	soundId: string,
	volume: number,
	speedMin: number,
	speedMax: number,
	startMin: number,
	startMax: number,
	durationMin: number,
	durationMax: number
)
	if not sound or soundId == "" then
		return
	end
	local token = (snippetTokens[sound] or 0) + 1
	snippetTokens[sound] = token

	sound:Stop()
	sound.PlaybackSpeed = randRange(speedMin, speedMax)
	sound.Volume = volume
	sound.TimePosition = if startMax > startMin then randRange(startMin, startMax) else startMin
	sound:Play()

	local dur = randRange(durationMin, durationMax)
	task.delay(dur, function()
		if snippetTokens[sound] ~= token or not sound.Parent then
			return
		end
		local startVol = sound.Volume
		for i = 1, 6 do
			if snippetTokens[sound] ~= token or not sound.Parent then
				return
			end
			sound.Volume = startVol * (1 - i / 6)
			task.wait(0.08)
		end
		if snippetTokens[sound] == token and sound.Parent then
			sound:Stop()
		end
	end)
end

local function setupDspBuses()
	local existingVent = SoundService:FindFirstChild("VentDuctGroup")
	if existingVent then
		existingVent:Destroy()
	end
	local vGroup = Instance.new("SoundGroup")
	vGroup.Name = "VentDuctGroup"
	vGroup.Volume = 1.0
	vGroup.Parent = SoundService

	local ductReverb = Instance.new("ReverbSoundEffect")
	ductReverb.Name = "DuctMetallicReverb"
	ductReverb.DecayTime = 1.15
	ductReverb.Density = 0.85
	ductReverb.Diffusion = 0.72
	ductReverb.DryLevel = 0
	ductReverb.WetLevel = -9
	ductReverb.Parent = vGroup

	local ductEq = Instance.new("EqualizerSoundEffect")
	ductEq.Name = "DuctSheetMetalEQ"
	ductEq.LowGain = -2
	ductEq.MidGain = 2.5
	ductEq.HighGain = -3.5
	ductEq.Parent = vGroup
	ventDuctGroup = vGroup

	local existingEnt = SoundService:FindFirstChild("EntityAudioGroup")
	if existingEnt then
		existingEnt:Destroy()
	end
	local eGroup = Instance.new("SoundGroup")
	eGroup.Name = "EntityAudioGroup"
	eGroup.Volume = 1.0
	eGroup.Parent = SoundService

	local entReverb = Instance.new("ReverbSoundEffect")
	entReverb.Name = "EntityDuctReverb"
	entReverb.DecayTime = 1.25
	entReverb.Density = 0.88
	entReverb.Diffusion = 0.72
	entReverb.DryLevel = 0
	entReverb.WetLevel = -8
	entReverb.Parent = eGroup

	local entEq = Instance.new("EqualizerSoundEffect")
	entEq.Name = "EntityOcclusionEQ"
	entEq.LowGain = 0.5
	entEq.MidGain = -1.0
	entEq.HighGain = -12.0
	entEq.Parent = eGroup
	entityAudioGroup = eGroup
	entityOcclusionEq = entEq

	local existingSub = SoundService:FindFirstChild("SubliminalTensionGroup")
	if existingSub then
		existingSub:Destroy()
	end
	local sGroup = Instance.new("SoundGroup")
	sGroup.Name = "SubliminalTensionGroup"
	sGroup.Volume = 1.0
	sGroup.Parent = SoundService

	local subEq = Instance.new("EqualizerSoundEffect")
	subEq.Name = "InternalLowPassEQ"
	subEq.LowGain = 2.5
	subEq.MidGain = -5.5
	subEq.HighGain = -12
	subEq.Parent = sGroup
	subliminalGroup = sGroup

	local existingSafe = SoundService:FindFirstChild("SafeRoomGroup")
	if existingSafe then
		existingSafe:Destroy()
	end
	local rGroup = Instance.new("SoundGroup")
	rGroup.Name = "SafeRoomGroup"
	rGroup.Volume = 1.0
	rGroup.Parent = SoundService

	local safeEq = Instance.new("EqualizerSoundEffect")
	safeEq.Name = "SafeRoomWarmEQ"
	safeEq.LowGain = 0
	safeEq.MidGain = -1
	safeEq.HighGain = -4
	safeEq.Parent = rGroup
	safeRoomGroup = rGroup
end

local function ensurePhantomAnchor()
	if phantomAnchor and phantomAnchor.Parent then
		return
	end
	local vfxFolder = workspace:FindFirstChild("_LocalClientVFX")
	if not vfxFolder then
		vfxFolder = Instance.new("Folder")
		vfxFolder.Name = "_LocalClientVFX"
		vfxFolder.Parent = workspace
	end

	local existing = vfxFolder:FindFirstChild("PhantomAudioAnchor")
	if existing then
		existing:Destroy()
	end

	local part = Instance.new("Part")
	part.Name = "PhantomAudioAnchor"
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = vfxFolder

	phantomAnchor = part
	phantomGroanSound = createSound(
		"PhantomGroan",
		GameConfig.Audio.PhantomGroanId,
		part,
		false,
		0.18,
		GameConfig.Audio.PhantomMaxDistance,
		ventDuctGroup
	)
	phantomKnockSound = createSound(
		"PhantomKnock",
		GameConfig.Audio.PhantomKnockId,
		part,
		false,
		0.17,
		GameConfig.Audio.PhantomMaxDistance,
		ventDuctGroup
	)
	phantomCreakSound = createSound(
		"PhantomCreak",
		GameConfig.Audio.AmbientCreakId,
		part,
		false,
		0.16,
		GameConfig.Audio.PhantomMaxDistance,
		ventDuctGroup
	)
end

local function triggerBlindSpotPhantomCue(camera: Camera)
	ensurePhantomAnchor()
	if not phantomAnchor then
		return
	end

	local camPos = camera.CFrame.Position
	local lookFlat = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
	if lookFlat.Magnitude < 0.01 then
		lookFlat = Vector3.new(0, 0, -1)
	else
		lookFlat = lookFlat.Unit
	end

	-- Position 18..36 studs behind or flanking the player's blind spot [105°, 255°]
	local blindAngle = math.rad(randRange(105, 255))
	local cosA = math.cos(blindAngle)
	local sinA = math.sin(blindAngle)
	local dir = Vector3.new(
		lookFlat.X * cosA - lookFlat.Z * sinA,
		0,
		lookFlat.X * sinA + lookFlat.Z * cosA
	).Unit

	local dist = randRange(18, 36)
	local yJitter = randRange(-0.8, 1.2)
	phantomAnchor.CFrame = CFrame.new(camPos + dir * dist + Vector3.new(0, yJitter, 0))

	local roll = math.random()
	if roll < 0.42 then
		playFadeSnippet(
			phantomGroanSound,
			GameConfig.Audio.PhantomGroanId,
			randRange(0.13, 0.21),
			0.76,
			0.96,
			0.0,
			11.5,
			2.2,
			3.8
		)
	elseif roll < 0.76 then
		playOneShot(phantomKnockSound, GameConfig.Audio.PhantomKnockId, randRange(0.12, 0.19), 0.75, 1.02)
	else
		playOneShot(phantomCreakSound, GameConfig.Audio.AmbientCreakId, randRange(0.12, 0.18), 0.78, 1.05)
	end
end

local function ensureRepairNodeAudio(nodeModel: Model)
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
			0.34,
			GameConfig.Audio.FaultHumMaxDistance,
			ventDuctGroup
		)
		faultHumSounds[nodeModel] = hum

		local spark = createSound(
			"RepairSpark",
			GameConfig.Audio.RepairSparkId,
			body,
			true,
			0.32,
			GameConfig.Audio.RepairSparkMaxDistance,
			ventDuctGroup
		)
		repairSparkSounds[nodeModel] = spark

		local function refreshHum()
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

		local function bindSparkEmitter(emitter: Instance)
			if not emitter:IsA("ParticleEmitter") then
				return
			end
			local function refreshSpark()
				if emitter.Enabled and GameConfig.Audio.RepairSparkId ~= "" then
					if not spark.IsPlaying then
						spark.PlaybackSpeed = randRange(0.95, 1.12)
						spark.TimePosition = randRange(0, 18)
						spark:Play()
					end
				else
					if spark.IsPlaying then
						spark:Stop()
					end
				end
			end
			emitter:GetPropertyChangedSignal("Enabled"):Connect(refreshSpark)
			refreshSpark()
		end

		local existingEmitter = body:FindFirstChild("SparkEmitter")
		if existingEmitter then
			bindSparkEmitter(existingEmitter)
		end
		body.ChildAdded:Connect(function(child)
			if child.Name == "SparkEmitter" then
				bindSparkEmitter(child)
			end
		end)

		nodeModel:GetAttributeChangedSignal("IsActiveFault"):Connect(refreshHum)
		nodeModel:GetAttributeChangedSignal("IsRepaired"):Connect(refreshHum)
		refreshHum()
	end)
end

local function ensureEntityAudio()
	local ventMap = workspace:FindFirstChild("VentMap")
	local entity = if ventMap then ventMap:FindFirstChild(activeProfile.id) else nil
	local core = if entity and entity:IsA("Model") then entity.PrimaryPart else nil
	if not core then
		return
	end
	if entityScrapeSound and entityScrapeSound.Parent == core then
		return
	end

	local scrape = createSound(
		"EntityScrape",
		GameConfig.Audio.EntityScrapeId,
		core,
		true,
		0.0,
		GameConfig.Audio.EntityMaxDistance,
		entityAudioGroup
	)
	entityScrapeSound = scrape
	if GameConfig.Audio.EntityScrapeId ~= "" and not scrape.IsPlaying then
		scrape:Play()
	end

	entityJointCrackSound = createSound(
		"EntityJointCrack",
		GameConfig.Audio.EntityJointCrackId,
		core,
		false,
		0.48,
		GameConfig.Audio.EntityMaxDistance,
		entityAudioGroup
	)

	entityWetShiftSound = createSound(
		"EntityWetShift",
		GameConfig.Audio.EntityWetShiftId,
		core,
		false,
		0.24,
		GameConfig.Audio.EntitySubtleMaxDistance,
		entityAudioGroup
	)

	entityLurkExhaleSound = createSound(
		"EntityLurkExhale",
		GameConfig.Audio.EntityLurkExhaleId,
		core,
		false,
		0.20,
		GameConfig.Audio.EntitySubtleMaxDistance,
		entityAudioGroup
	)

	entityWhisperSound = createSound(
		"EntityWhisper",
		GameConfig.Audio.EntityWhisperId,
		core,
		false,
		0.18,
		GameConfig.Audio.EntityWhisperMaxDistance,
		entityAudioGroup
	)

	entityLimbSlideSound = createSound(
		"EntityLimbSlide",
		GameConfig.Audio.EntityLimbSlideId,
		core,
		false,
		0.22,
		GameConfig.Audio.EntityMaxDistance,
		entityAudioGroup
	)

	entityLimbThudSound = createSound(
		"EntityLimbThud",
		GameConfig.Audio.EntityLimbThudId,
		core,
		false,
		0.20,
		GameConfig.Audio.EntityMaxDistance,
		entityAudioGroup
	)

	entityStartleSlapSound = createSound(
		"EntityStartleSlap",
		GameConfig.Audio.EntityStartleSlapId,
		core,
		false,
		0.44,
		GameConfig.Audio.EntityMaxDistance,
		entityAudioGroup
	)

	entityTendonSnapSound = createSound(
		"EntityTendonSnap",
		GameConfig.Audio.EntityTendonSnapId,
		core,
		false,
		0.38,
		GameConfig.Audio.EntityMaxDistance,
		entityAudioGroup
	)
end

local function checkEntityOccluded(camera: Camera, entity: Model, entityCore: BasePart): boolean
	local origin = camera.CFrame.Position
	local delta = entityCore.Position - origin
	if delta.Magnitude < 2.0 then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { entity }
	if localPlayer.Character then
		table.insert(ignore, localPlayer.Character)
	end
	local vfx = workspace:FindFirstChild("_LocalClientVFX")
	if vfx then
		table.insert(ignore, vfx)
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(origin, delta, params)
	return hit ~= nil
end

function AudioController.playScareSting()
	if stingSound and GameConfig.Audio.ScareStingId ~= "" then
		stingSound.Volume = GameConfig.Audio.ScareStingVolume
		stingSound.PlaybackSpeed = 0.92
		stingSound.TimePosition = 0
		stingSound:Play()
	end
end

function AudioController.init()
	if initialized then
		return
	end
	initialized = true

	setupDspBuses()

	local existingFolder = SoundService:FindFirstChild("ClientAudio")
	if existingFolder then
		existingFolder:Destroy()
	end
	local audioFolder = Instance.new("Folder")
	audioFolder.Name = "ClientAudio"
	audioFolder.Parent = SoundService

	ventAmbienceSound = createSound("VentAmbience", GameConfig.Audio.VentAmbienceId, audioFolder, true, 0.0, nil, ventDuctGroup)
	safeRoomHumSound = createSound("SafeRoomHum", GameConfig.Audio.SafeRoomHumId, audioFolder, true, 0.0, nil, safeRoomGroup)
	tensionDroneSound = createSound("TensionDrone", GameConfig.Audio.TensionDroneId, audioFolder, true, 0.0, nil, subliminalGroup)
	heartbeatSound = createSound("TensionHeartbeat", GameConfig.Audio.HeartbeatId, audioFolder, true, 0.0, nil, subliminalGroup)
	flickerBuzzSound = createSound("HeadlampFlickerBuzz", GameConfig.Audio.FlickerBuzzId, audioFolder, true, 0.0, nil, ventDuctGroup)
	hatchThumpSound = createSound("HatchThump", GameConfig.Audio.HatchThumpId, audioFolder, false, 0.28, nil, ventDuctGroup)
	crawlScrapeSound = createSound("CrawlScrape", GameConfig.Audio.CrawlScrapeId, audioFolder, false, 0.16, nil, ventDuctGroup)
	fastCrawlScrapeSound = createSound("FastCrawlScrape", GameConfig.Audio.FastCrawlScrapeId, audioFolder, false, 0.40, nil, ventDuctGroup)
	gaspSound = createSound("PanicGasp", GameConfig.Audio.PanicGaspId, audioFolder, false, 0.48, nil, subliminalGroup)
	clickSound = createSound("HeadlampClick", GameConfig.Audio.HeadlampClickId, audioFolder, false, 0.42, nil, ventDuctGroup)
	stingSound = createSound("ScareSting", GameConfig.Audio.ScareStingId, audioFolder, false, GameConfig.Audio.ScareStingVolume, nil, ventDuctGroup)

	if ventAmbienceSound and GameConfig.Audio.VentAmbienceId ~= "" then
		ventAmbienceSound:Play()
	end
	if safeRoomHumSound and GameConfig.Audio.SafeRoomHumId ~= "" then
		safeRoomHumSound:Play()
	end
	if tensionDroneSound and GameConfig.Audio.TensionDroneId ~= "" then
		tensionDroneSound:Play()
	end
	if heartbeatSound and GameConfig.Audio.HeartbeatId ~= "" then
		heartbeatSound.PlaybackSpeed = 0.72
		heartbeatSound:Play()
	end
	if flickerBuzzSound and GameConfig.Audio.FlickerBuzzId ~= "" then
		flickerBuzzSound:Play()
	end

	ensurePhantomAnchor()

	for _, inst in ipairs(CollectionService:GetTagged(NetContracts.Tags.RepairNode)) do
		if inst:IsA("Model") then
			ensureRepairNodeAudio(inst)
		end
	end
	CollectionService:GetInstanceAddedSignal(NetContracts.Tags.RepairNode):Connect(function(inst)
		if inst:IsA("Model") then
			ensureRepairNodeAudio(inst)
		end
	end)

	localPlayer:GetAttributeChangedSignal(NetContracts.Attributes.HeadlampOn):Connect(function()
		playOneShot(clickSound, GameConfig.Audio.HeadlampClickId, 0.42, 0.96, 1.04)
	end)

	local eliminatedRemote = NetContracts.getRemoteEvent(NetContracts.Remotes.PlayerEliminated, false)
	eliminatedRemote.OnClientEvent:Connect(function()
		AudioController.playScareSting()
	end)

	RunService.Heartbeat:Connect(function(dt: number)
		ensureEntityAudio()

		local now = os.clock()
		local camera = workspace.CurrentCamera
		local inVents = localPlayer:GetAttribute(NetContracts.Attributes.InSafeRoom) == false
		local panicRatio = (localPlayer:GetAttribute(NetContracts.Attributes.PanicRatio) :: number?) or 0
		local headlampOn = localPlayer:GetAttribute(NetContracts.Attributes.HeadlampOn) ~= false

		-- Acoustic space switching (Safe Room <-> Resonant Ducts) + tactile hatch thump
		if wasInVents ~= inVents then
			if wasInVents ~= nil then
				playOneShot(hatchThumpSound, GameConfig.Audio.HatchThumpId, 0.28, 0.78, 0.92)
			end
			wasInVents = inVents
			SoundService.AmbientReverb = if inVents then Enum.ReverbType.Hallway else Enum.ReverbType.Room
		end

		-- Locate entity & compute distance
		local ventMap = workspace:FindFirstChild("VentMap")
		local entity = if ventMap then ventMap:FindFirstChild(activeProfile.id) else nil
		local entityModel = if entity and entity:IsA("Model") then entity else nil
		local entityCore = if entityModel then entityModel.PrimaryPart else nil
		local entityDist = math.huge
		local entityState = ""
		local entityMoveSpeed = 0

		if entityModel and entityCore and camera then
			entityDist = (camera.CFrame.Position - entityCore.Position).Magnitude
			entityState = (entityModel:GetAttribute("EntityState") :: string?) or "Patrol"
			entityMoveSpeed = (entityModel:GetAttribute("MoveSpeed") :: number?) or 0

			-- 1a. Dynamic distance & wall-occlusion EQ on EntityAudioGroup
			if now - lastOcclusionCheck >= 0.18 then
				lastOcclusionCheck = now
				entityIsOccluded = checkEntityOccluded(camera, entityModel, entityCore)
			end
			if entityOcclusionEq then
				local closeness = math.clamp(1 - (entityDist / GameConfig.Audio.EntityMaxDistance), 0, 1)
				local targetHigh = -14.0 + closeness * 16.0 - (if entityIsOccluded then 5.0 else 0.0)
				local targetMid = if entityIsOccluded then -2.0 else (1.5 + closeness * 2.0)
				local eqLerp = math.min(1, dt * 5.0)
				entityOcclusionEq.HighGain += (math.clamp(targetHigh, -20, 4) - entityOcclusionEq.HighGain) * eqLerp
				entityOcclusionEq.MidGain += (targetMid - entityOcclusionEq.MidGain) * eqLerp
			end
		end

		-- 1b. Uncanny Multi-Layer Entity Spatial Audio
		if entityScrapeSound and entityModel and entityCore then
			local targetScrapeVol = 0.0
			local targetScrapeSpeed = 0.90

			if entityState == "Lurk" then
				-- Dead silence while peeking around a corner: silence IS the tell
				targetScrapeVol = 0.0
				targetScrapeSpeed = 0.55
			elseif entityState == "Retreat" or entityState == "Scramble" then
				targetScrapeVol = 0.58
				targetScrapeSpeed = 1.55
			elseif entityState == "Chase" then
				targetScrapeVol = 0.68
				targetScrapeSpeed = 1.32
			elseif entityState == "Stalk" then
				targetScrapeVol = if entityMoveSpeed > 0.5 then 0.09 else 0.02
				targetScrapeSpeed = 0.65
			else -- Patrol
				targetScrapeVol = if entityMoveSpeed > 0.5 then 0.14 else 0.03
				targetScrapeSpeed = 0.82
			end

			local lerpAlpha = math.min(1, dt * 6.0)
			entityScrapeSound.Volume += (targetScrapeVol - entityScrapeSound.Volume) * lerpAlpha
			entityScrapeSound.PlaybackSpeed += (targetScrapeSpeed - entityScrapeSound.PlaybackSpeed) * lerpAlpha

			-- State transition reaction cues
			if entityState ~= lastEntityState then
				if entityState == "Lurk" and entityDist <= GameConfig.Audio.EntityMaxDistance then
					if entityDist <= 30 then
						roomToneVacuumUntil = now + 0.65
					end
					playOneShot(entityJointCrackSound, GameConfig.Audio.EntityJointCrackId, 0.34, 0.78, 0.94)
					nextWetShiftTime = now + randRange(3.5, 6.5)
					nextLurkExhaleTime = now + randRange(2.2, 5.0)
				elseif (entityState == "Scramble" or entityState == "Retreat") and entityDist <= GameConfig.Audio.EntityMaxDistance then
					-- Spotted / whip-back metallic duct slap + taut tendon snap right as it flees
					playFadeSnippet(entityStartleSlapSound, GameConfig.Audio.EntityStartleSlapId, 0.42, 1.15, 1.32, 0.0, 0.3, 0.8, 1.2)
					playFadeSnippet(entityTendonSnapSound, GameConfig.Audio.EntityTendonSnapId, 0.36, 0.92, 1.10, 0.0, 0.4, 0.6, 1.0)
				end
				lastEntityState = entityState
			end

			-- Cadenced MoveSpeed-synced limb-by-limb crawl foley
			if entityState ~= "Lurk" and entityMoveSpeed > 0.6 and entityDist <= GameConfig.Audio.EntityMaxDistance then
				limbStepAccumulator += entityMoveSpeed * dt
				if limbStepAccumulator >= nextLimbStepDistance then
					limbStepAccumulator = 0.0
					-- Asymmetrical stride spacing so it sounds gaunt & uncanny, never robotic
					nextLimbStepDistance = randRange(2.1, 3.1)
					limbStepToggle = not limbStepToggle

					if entityState == "Scramble" or entityState == "Retreat" or entityState == "Chase" then
						playFadeSnippet(entityLimbThudSound, GameConfig.Audio.EntityLimbThudId, randRange(0.32, 0.44), 1.16, 1.40, 0.0, 0.2, 0.35, 0.55)
					elseif limbStepToggle then
						playFadeSnippet(entityLimbSlideSound, GameConfig.Audio.EntityLimbSlideId, randRange(0.15, 0.24), 0.72, 0.94, 0.0, 0.4, 0.45, 0.75)
					else
						playFadeSnippet(entityLimbThudSound, GameConfig.Audio.EntityLimbThudId, randRange(0.11, 0.18), 0.76, 0.98, 0.0, 0.2, 0.35, 0.60)
					end
				end
			else
				limbStepAccumulator = 0.0
			end

			-- Intermittent dry bone/joint cracks during Patrol & Stalk
			if (entityState == "Patrol" or entityState == "Stalk") and now >= nextJointCrackTime then
				if entityState == "Stalk" then
					nextJointCrackTime = now + randRange(GameConfig.Audio.JointCrackStalkMin, GameConfig.Audio.JointCrackStalkMax)
				else
					nextJointCrackTime = now + randRange(GameConfig.Audio.JointCrackPatrolMin, GameConfig.Audio.JointCrackPatrolMax)
				end
				if entityDist <= GameConfig.Audio.EntityMaxDistance then
					if entityDist <= 30 then
						roomToneVacuumUntil = now + 0.65
					end
					local crackVol = if entityState == "Stalk" then 0.50 else 0.42
					playOneShot(entityJointCrackSound, GameConfig.Audio.EntityJointCrackId, crackVol, 0.82, 1.14)
				end
			end

			-- Close-range wet ligament shift & uncanny studio horror breath
			if (entityState == "Stalk" or entityState == "Lurk") and entityDist <= GameConfig.Audio.EntitySubtleMaxDistance then
				if now >= nextWetShiftTime then
					nextWetShiftTime = now + randRange(5.5, 11.0)
					roomToneVacuumUntil = now + 0.60
					playOneShot(entityWetShiftSound, GameConfig.Audio.EntityWetShiftId, 0.24, 0.78, 0.98)
				end
				if now >= nextLurkExhaleTime then
					nextLurkExhaleTime = now + randRange(5.2, 10.5)
					playFadeSnippet(entityLurkExhaleSound, GameConfig.Audio.EntityLurkExhaleId, randRange(0.16, 0.23), 0.82, 0.94, 0.0, 1.5, 2.2, 3.6)
				end
			end

			-- Headlamp-triggered faint whisper ("turn it off...") when lurking/stalking nearby
			if inVents and headlampOn and (entityState == "Lurk" or entityState == "Stalk") and entityDist <= GameConfig.Audio.EntityWhisperMaxDistance then
				if now >= nextWhisperTime then
					nextWhisperTime = now + randRange(GameConfig.Audio.WhisperIntervalMin, GameConfig.Audio.WhisperIntervalMax)
					roomToneVacuumUntil = now + 0.75
					playFadeSnippet(entityWhisperSound, GameConfig.Audio.EntityWhisperId, randRange(0.14, 0.20), 0.85, 0.98, 0.0, 2.0, 1.8, 3.0)
				end
			end
		end

		-- 2. Dynamic Psychological Tension & Silence Ducking
		local targetTension = 0.0
		if inVents then
			local tensionRange = GameConfig.Audio.TensionRange
			local prox = 0.0
			if entityDist < tensionRange then
				prox = math.pow(math.clamp(1 - (entityDist / tensionRange), 0, 1), 1.35)
			end
			if (entityState == "Lurk" or entityState == "Stalk") and entityDist <= 34 then
				prox = math.clamp(prox + 0.24 * (1 - entityDist / 34), 0, 1)
			elseif entityState == "Chase" and entityDist <= 40 then
				prox = math.max(prox, 0.78)
			end
			targetTension = math.clamp(math.max(prox, panicRatio * 0.65), 0, 1)
		end

		local tensionRate = if targetTension > currentTension then 1.8 else 0.9
		currentTension += (targetTension - currentTension) * math.min(1, dt * tensionRate)

		local mixLerp = math.min(1, dt * 3.0)
		if ventAmbienceSound then
			-- Duck HVAC drone under tension AND briefly dip during pre-cue Room Tone Vacuum
			local vacuumScale = if now < roomToneVacuumUntil then 0.58 else 1.0
			local targetVentVol = if inVents then ((0.14 - currentTension * 0.095) * vacuumScale) else 0.0
			ventAmbienceSound.Volume += (targetVentVol - ventAmbienceSound.Volume) * math.min(1, dt * 4.5)
		end
		if safeRoomHumSound then
			local targetSafeVol = if inVents then 0.0 else 0.09
			safeRoomHumSound.Volume += (targetSafeVol - safeRoomHumSound.Volume) * mixLerp
		end
		if tensionDroneSound then
			local targetDroneVol = if inVents then (0.025 + currentTension * 0.22) else 0.0
			tensionDroneSound.Volume += (targetDroneVol - tensionDroneSound.Volume) * mixLerp
		end
		if heartbeatSound then
			local targetBeatVol = 0.0
			if inVents and currentTension > 0.22 then
				local beatNorm = math.clamp((currentTension - 0.22) / 0.78, 0, 1)
				targetBeatVol = beatNorm * 0.26
			end
			heartbeatSound.Volume += (targetBeatVol - heartbeatSound.Volume) * mixLerp
			local targetBeatSpeed = 0.72 + currentTension * 0.38
			heartbeatSound.PlaybackSpeed += (targetBeatSpeed - heartbeatSound.PlaybackSpeed) * mixLerp
		end

		-- 3. Diegetic Headlamp Proximity Flicker Filament Buzz
		if flickerBuzzSound then
			local targetFlickerVol = 0.0
			if inVents and headlampOn and entityDist <= activeProfile.proximityFlickerRange then
				local intensity = 1 - (entityDist / activeProfile.proximityFlickerRange)
				local pulse = 0.5 + 0.5 * math.abs(math.sin(now * (16 + intensity * 24)))
				targetFlickerVol = (0.03 + intensity * 0.13) * pulse
			end
			flickerBuzzSound.Volume += (targetFlickerVol - flickerBuzzSound.Volume) * math.min(1, dt * 10)
		end

		-- 4. 3D Blind-Spot Phantom Ambience (pauses when entity is close or chasing)
		if inVents and camera and now >= nextPhantomTime then
			nextPhantomTime = now + randRange(GameConfig.Audio.PhantomIntervalMin, GameConfig.Audio.PhantomIntervalMax)
			local entityTooCloseOrChasing = (entityState == "Chase") or (entityDist < 18)
			if not entityTooCloseOrChasing then
				triggerBlindSpotPhantomCue(camera)
			end
		end

		-- 5. Local Crawl vs FastCrawl metallic duct contact audio
		if inVents and localPlayer:GetAttribute(NetContracts.Attributes.IsCrawling) == true then
			local char = localPlayer.Character
			local root = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
			if root then
				local horizSpeed = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
				local isFast = localPlayer:GetAttribute(NetContracts.Attributes.IsFastCrawling) == true
				if isFast and horizSpeed > 3.5 then
					if now - lastCrawlAudioPlay >= 0.42 then
						lastCrawlAudioPlay = now
						playOneShot(fastCrawlScrapeSound, GameConfig.Audio.FastCrawlScrapeId, 0.40, 1.05, 1.25)
					end
				elseif horizSpeed > 1.8 then
					if now - lastCrawlAudioPlay >= 0.85 then
						lastCrawlAudioPlay = now
						playOneShot(crawlScrapeSound, GameConfig.Audio.CrawlScrapeId, 0.16, 0.85, 1.03)
					end
				end
			end
		end

		-- 6. High-Panic Stale Air Gasp
		if panicRatio >= GameConfig.Panic.GaspThreshold and inVents then
			if now - lastGaspPlay >= GameConfig.Panic.GaspInterval then
				lastGaspPlay = now
				playOneShot(gaspSound, GameConfig.Audio.PanicGaspId, 0.48, 0.94, 1.06)
			end
		end
	end)
end

return AudioController
