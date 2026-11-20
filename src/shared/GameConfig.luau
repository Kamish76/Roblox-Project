--!strict
--[[
	Shared configuration for Safe Room, crawl & fast-crawl physics, headlamp optics,
	modular vent kit, interruptible repairs, Work Order rewards, Entity AI, and Audio.
]]

local GameConfig = {
	SafeRoom = {
		WalkSpeed = 10,
		StandingHipHeight = 0,
		BaseCameraOffset = Vector3.zero,
		FloorY = 14.0,
		CeilingHeight = 9.0,
		ReturnCFrame = CFrame.new(0, 17.1, 4.0),
	},

	Crawl = {
		ForwardWalkSpeed = 5.5,
		StrafeWalkSpeed = 4.2,
		ReverseWalkSpeed = 3.4,
		FastCrawlKey = Enum.KeyCode.LeftShift,
		FastForwardWalkSpeed = 8.4,
		FastStrafeWalkSpeed = 6.0,
		FastReverseWalkSpeed = 4.4,
		StaminaDrainRate = 0.24,
		StaminaRegenRate = 0.18,
		StaminaRegenDelay = 1.2,
		StaminaResumeThreshold = 0.20,
		FastBobMultiplier = 1.55,
		BaseFov = 70,
		FastFovBoost = 4.5,
		SpeedLerpRate = 12,
		HipHeight = -1.6,
		-- Offsets Roblox's built-in R6 first-person +1.5Y eye height down to prone Head level (~1.7 studs above duct floor).
		BaseCameraOffset = Vector3.new(0, -1.20, 0),
		BobVerticalAmp = 0.08,
		BobHorizontalAmp = 0.06,
		BobFrequency = 6.2,
		-- Leave empty to use procedural Motor6D crawl; set to "rbxassetid://..." to use an uploaded R6 Animation.
		CustomCrawlAnimationId = "",
		DropEntryCFrame = CFrame.new(0, 5.4, 0),
	},

	Headlamp = {
		ToggleKey = Enum.KeyCode.F,
		ToggleCooldown = 0.25,
		Brightness = 2.8,
		Range = 46,
		Angle = 52,
		Color = Color3.fromRGB(235, 242, 255),
		FillBrightness = 0.55,
		FillRange = 14,
		FillAngle = 95,
		LagRate = 14,
		CameraOffset = CFrame.new(0, 0.12, -0.35),
	},

	VentKit = {
		CellSize = 8,
		InteriorWidth = 4.6,
		InteriorHeight = 4.2,
		WallThickness = 0.6,
		FloorY = 4.0,
	},

	Repair = {
		ActiveFaultCount = 5,
		RepairDurationSeconds = 6.0,
		PromptMaxDistance = 6.5,
	},

	WorkOrder = {
		BaseXPPerRepair = 50,
		FullClearBonusXP = 150,
		RoundResetDelay = 4.0,
	},

	Panic = {
		BuildRateDarkStill = 0.055,
		BuildRateDarkMoving = 0.015,
		DecayRateLightOn = 0.08,
		DecayRateSafeRoom = 0.25,
		GaspThreshold = 0.85,
		GaspInterval = 3.5,
	},

	Entity = {
		SpawnTileKey = "0,-10",
		KillRadius = 3.4,
		AmbushRadius = 8.5,
		CloseStareRange = 14.0,
		StalkAcquireRange = 38.0,
		StalkSpeed = 4.8,
		RetreatSpeed = 24.0,
		RetreatCooldown = 3.5,
		StareDotThreshold = 0.62,
		StareMaxDuration = 1.2,
		FlinchDelayLightOn = 0.20,
		FlinchDelayDark = 0.35,
		ChaseLostSightTimeout = 3.2,
		LurkDuration = 8.0,
		RepairPeekChance = 0.55,
		RepairPeekCooldown = 14.0,
		RepairPeekMinDist = 11.0,
		RepairPeekMaxDist = 36.0,
		PatrolSpeedMultiplier = 0.82,
		ChaseSpeedMultiplier = 1.15,
		CrawlNoiseRadius = 18.0,
		FastCrawlNoiseRadius = 42.0,
		FastCrawlChaseRadius = 22.0,
		RepairNoiseRadius = 32.0,
		GaspNoiseRadius = 36.0,
		-- Multiplayer intensity scaling when >= 2 active crawlers are inside the vents
		MultiplayerStalkSpeedBonus = 1.2,
		MultiplayerRetreatCooldownScale = 0.70,
		MultiplayerAcquireRangeBonus = 10.0,
	},

	Audio = {
		-- Verified free Creator Store (ProSoundEffects / APMOfficial) IDs;
		-- swap with custom CC0 FreeSound uploads sourced via sandraschi/sfx-mcp as desired.
		EntityScrapeId = "rbxassetid://9125666321",
		FaultHumId = "rbxassetid://110483919798635",
		AmbientCreakId = "rbxassetid://9125666441",
		HeadlampClickId = "rbxassetid://9114480271",
		PanicGaspId = "rbxassetid://94952921557556",
		ScareStingId = "rbxassetid://1841353939",
		CrawlScrapeId = "rbxassetid://9113757109",
		FastCrawlScrapeId = "rbxassetid://9114801898",
		VentAmbienceId = "rbxassetid://9112839813",
		EntityMaxDistance = 48,
		FaultHumMaxDistance = 16,
		CreakIntervalMin = 12,
		CreakIntervalMax = 24,
	},
}

return GameConfig
