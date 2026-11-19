--!strict
--[[
	Shared configuration for M1/M2 crawl physics, Safe Room standing defaults,
	headlamp optics, and modular vent kit standards.
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
}

return GameConfig
