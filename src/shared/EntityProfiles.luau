--!strict
--[[
	Modular EntityProfile registry (ADR-004 & ADR-006).
	MVP v0.1 launches with JointCracker; v0.2 expands into multi-entity deduction.
]]

export type EntityProfile = {
	id: string,
	displayName: string,
	passiveVisionRange: number,
	lightAggroRange: number,
	noiseSensitivity: number,
	mimicEnabled: boolean,
	patrolCadence: number,
	chaseCadence: number,
	proximityFlickerRange: number,
	audioTells: { string },
	deductionClues: { string },
}

local EntityProfiles = {}

EntityProfiles.ActiveMVPId = "JointCracker"

EntityProfiles.Profiles = {
	JointCracker = {
		id = "JointCracker",
		displayName = "The Joint-Cracker",
		passiveVisionRange = 11,
		lightAggroRange = 42,
		noiseSensitivity = 1.0,
		mimicEnabled = false,
		patrolCadence = 1.0,
		chaseCadence = 1.85,
		proximityFlickerRange = 25,
		audioTells = { "JointCrack", "MetalScrape", "WhisperTurnItOff" },
		deductionClues = { "LightReactive", "JointCracking", "YellowEyeShine" },
	},

	-- Queued v0.2 Entity #2 for Demonology-style deduction
	ClickingCrawler = {
		id = "ClickingCrawler",
		displayName = "The Clicking Crawler",
		passiveVisionRange = 5,
		lightAggroRange = 12,
		noiseSensitivity = 1.8,
		mimicEnabled = false,
		patrolCadence = 1.15,
		chaseCadence = 2.05,
		proximityFlickerRange = 20,
		audioTells = { "RhythmicClick", "AcceleratingClick", "DeadSilence" },
		deductionClues = { "VibrationReactive", "RhythmicClicking", "LowLightVision" },
	},
} :: { [string]: EntityProfile }

function EntityProfiles.getActiveProfile(): EntityProfile
	return EntityProfiles.Profiles[EntityProfiles.ActiveMVPId]
end

return EntityProfiles
