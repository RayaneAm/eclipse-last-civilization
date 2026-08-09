--!strict
-- Builds only physical Haven services. UI commerce entries are intentionally
-- bespoke/skipped; SURVIVOR_MARKET is the one physical trading location.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HavenFacilityConfig = require(ReplicatedStorage.Shared.Config.HavenFacilityConfig)
local HavenLayoutConfig = require(ReplicatedStorage.Shared.Config.HavenLayoutConfig)
local WorldMapConfig = require(ReplicatedStorage.Shared.Config.WorldMapConfig)
local CivicBuildingGenerator = require(script.Parent.Generators.CivicBuildingGenerator)
local CampCircleGenerator = require(script.Parent.Generators.CampCircleGenerator)
local LeaderboardHallGenerator = require(script.Parent.Generators.LeaderboardHallGenerator)

local ROOT_NAME = "HavenDistricts_Generated"
local HAVEN_ROOT_NAME = "SurvivorHaven_Generated"
local LEADERBOARD_NAME = "Leaderboards"
local BuildHavenDistricts = {}

local function cleanupNamedChildren(parent: Instance, name: string)
	for _, child in parent:GetChildren() do
		if child.Name == name then
			child:Destroy()
		end
	end
end

local function countLeaderboardHalls(): (number, Model?)
	local count = 0
	local hall: Model? = nil
	for _, descendant in Workspace:GetDescendants() do
		if descendant.Name == LEADERBOARD_NAME and descendant:IsA("Model") then
			count += 1
			hall = descendant
		end
	end
	return count, hall
end

function BuildHavenDistricts.Run()
	-- Remove every previous districts root, including accidental duplicate roots
	-- left by older tooling. The legacy hall used to live directly beneath the
	-- Survivor Haven root, so migrate that one explicit path as well.
	cleanupNamedChildren(Workspace, ROOT_NAME)
	local havenRoot = Workspace:FindFirstChild(HAVEN_ROOT_NAME)
	if havenRoot then
		cleanupNamedChildren(havenRoot, LEADERBOARD_NAME)
	end

	local root = Instance.new("Model")
	root.Name = ROOT_NAME
	local facilities = Instance.new("Folder")
	facilities.Name = "Facilities"
	facilities.Parent = root
	local origin = WorldMapConfig.WORLD_ORIGIN
	local count = 0
	for _, facility in HavenFacilityConfig do
		if not facility.bespoke then
			CivicBuildingGenerator.Build(facilities, origin, facility, origin:PointToWorldSpace(facility.localPosition))
			count += 1
		end
	end
	-- The Haven Guide installation that used to stand here (NPC, booth, map
	-- stand, direction board, "HAVEN GUIDE" sign) is gone. The plot is now the
	-- settlement's communal fire circle.
	CampCircleGenerator.Build(
		root,
		HavenLayoutConfig.CFrameFacing(
			origin,
			HavenLayoutConfig.CAMP_CIRCLE_LOCAL_POSITION,
			HavenLayoutConfig.SPAWN_LOCAL_POSITION
		)
	)
	local leaderboardHall = LeaderboardHallGenerator.Build(
		root,
		origin,
		origin:PointToWorldSpace(HavenLayoutConfig.LEADERBOARD_LOCAL_POSITION),
		Color3.fromRGB(100, 200, 255)
	)
	root.Parent = Workspace

	local leaderboardCount, generatedHall = countLeaderboardHalls()
	assert(leaderboardCount == 1, `[BuildHavenDistricts] Expected exactly one generated Leaderboards model, found {leaderboardCount}`)
	assert(generatedHall == leaderboardHall, "[BuildHavenDistricts] The live Leaderboards model is not the hall built by the current generator")
	assert(
		leaderboardHall:GetFullName() == `Workspace.{ROOT_NAME}.{LEADERBOARD_NAME}`,
		`[BuildHavenDistricts] Unexpected Leaderboards path: {leaderboardHall:GetFullName()}`
	)
	print(`[BuildHavenDistricts] Built {count} staffed physical services, the camp fire circle, and exactly one current Leaderboards hall.`)
end

return BuildHavenDistricts
