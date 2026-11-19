--!strict
--[[
	Replaces Roblox's default R6 Animate script inside StarterCharacterScripts.
	If GameConfig.Crawl.CustomCrawlAnimationId is blank, CrawlController drives
	the prone R6 Motor6D pose procedurally.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local character = script.Parent :: Model
local humanoid = character:WaitForChild("Humanoid") :: Humanoid
local animator = humanoid:FindFirstChildOfClass("Animator")
if not animator then
	local newAnimator = Instance.new("Animator")
	newAnimator.Parent = humanoid
	animator = newAnimator
end

local function stopAllTracks(targetAnimator: Animator)
	for _, track in ipairs(targetAnimator:GetPlayingAnimationTracks()) do
		track:Stop(0)
	end
end

if animator then
	stopAllTracks(animator)

	local customId = GameConfig.Crawl.CustomCrawlAnimationId
	if customId ~= "" then
		local animation = Instance.new("Animation")
		animation.Name = "CustomCrawl"
		animation.AnimationId = customId
		animation.Parent = script

		local crawlTrack = animator:LoadAnimation(animation)
		crawlTrack.Looped = true
		crawlTrack.Priority = Enum.AnimationPriority.Action
		crawlTrack:Play(0.1)

		humanoid.Running:Connect(function(speed: number)
			crawlTrack:AdjustSpeed(math.clamp(speed / GameConfig.Crawl.ForwardWalkSpeed, 0, 1.5))
		end)
	end
end
