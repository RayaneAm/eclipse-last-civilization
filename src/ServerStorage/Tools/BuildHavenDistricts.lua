--!strict
-- One-shot world-build orchestrator for Survivor Haven's facilities, the
-- Quest Giver stage + tutorial path, and the storytelling clusters. Run this
-- AFTER BuildSurvivorHaven (it reads Haven's origin, not its built
-- instances, so exact ordering relative to BuildWorldMap doesn't matter).
--
-- Preferred: the ECLIPSE TOOLS Studio plugin's "Build Haven Districts" /
-- "Build Complete World" buttons (see plugin/), which call this same Run().
--
-- Command Bar fallback:
--
--   require(game:GetService("ServerStorage").Tools.BuildHavenDistricts).Run()
--
-- Exports Run() rather than executing at module-load time — see
-- BuildSurvivorHaven.luau's top comment for why (require() caching).
--
-- Safe to re-run: each facility/cluster only touches its own named model,
-- per the same idempotent-generator rules as the other Build* tools.
--
-- Survivor Haven redesign Phase 1: facility placement is now direct
-- angle/radius per facility (HavenFacilityConfig) instead of the old
-- shared-ring "district" slot math — see HavenLayoutConfig.luau's header
-- comment. The old per-district banner pass is gone: individual facility
-- nameplates already exist via each facility's own bespoke sign, so a
-- second "district" label was redundant, and there's no longer a single
-- ring-center position per district to hang one from.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HavenFacilityConfig = require(ReplicatedStorage.Shared.Config.HavenFacilityConfig)
local HavenLayoutConfig = require(ReplicatedStorage.Shared.Config.HavenLayoutConfig)
local WorldMapConfig = require(ReplicatedStorage.Shared.Config.WorldMapConfig)

local GeneratorKit = require(script.Parent.Generators.GeneratorKit)
local CivicBuildingGenerator = require(script.Parent.Generators.CivicBuildingGenerator)
local GuidanceGenerator = require(script.Parent.Generators.GuidanceGenerator)
local StorytellingClusterGenerator = require(script.Parent.Generators.StorytellingClusterGenerator)
local SeasonPavilionGenerator = require(script.Parent.Generators.SeasonPavilionGenerator)

local ROOT_NAME = "HavenDistricts_Generated"

local BuildHavenDistricts = {}

local function findFacility(id: string): HavenFacilityConfig.FacilityDefinition
	for _, facility in HavenFacilityConfig do
		if facility.id == id then
			return facility
		end
	end
	error(`BuildHavenDistricts: HavenFacilityConfig has no "{id}" entry`)
end

local function facilityPosition(origin: CFrame, facility: HavenFacilityConfig.FacilityDefinition): Vector3
	local direction = WorldMapConfig.DirectionForAngle(math.rad(facility.angleDegrees))
	return origin.Position + direction * facility.radius
end

function BuildHavenDistricts.Run()
	GeneratorKit.CleanupPrevious(Workspace, ROOT_NAME)

	-- Phase 3B: Starter Pack / Gamepass Showcase no longer exist as world
	-- structures at all (UI-first now, see ShopController). The root wipe
	-- above already removes them if they were last built as part of this
	-- managed tree, but this explicit pass also catches any copy sitting
	-- directly under Workspace from an older Studio session (e.g. predating
	-- the ROOT_NAME convention) — it does NOT touch anything a builder
	-- deliberately renamed out of the generated namespace (that escape
	-- hatch, documented in BuildSurvivorHaven.luau, is intentional).
	for _, staleName in { "StarterPack", "GamepassShowcase" } do
		GeneratorKit.CleanupPrevious(Workspace, staleName)
	end

	local root = Instance.new("Model")
	root.Name = ROOT_NAME

	local origin = WorldMapConfig.WORLD_ORIGIN

	local buildingsFolder = Instance.new("Folder")
	buildingsFolder.Name = "Facilities"
	buildingsFolder.Parent = root
	local builtCount = 0
	for _, facility in HavenFacilityConfig do
		if not facility.bespoke then
			CivicBuildingGenerator.Build(buildingsFolder, origin, facility, facilityPosition(origin, facility))
			builtCount += 1
		end
		-- "Bespoke" facilities (QuestGiver, Leaderboards, and the SeasonEvent/
		-- SeasonPass and GamepassShowcase/StarterPack pairs) are built
		-- directly below instead of through this generic loop.
	end

	local questGiver = findFacility("QuestGiver")
	local onboardingAccent = HavenLayoutConfig.GetDistrict("Onboarding").accentColor
	local questGiverCenter = facilityPosition(origin, questGiver)
	GuidanceGenerator.Build(root, origin, questGiverCenter, questGiver.angleDegrees, onboardingAccent)

	-- Phase 3B: Season Pass/Event is UI-first now (see ShopController) — this
	-- is a small, non-interactive visual touchpoint only, at the midpoint of
	-- the (unchanged) SeasonEvent/SeasonPass facility positions. Gamepass
	-- Showcase/Starter Pack are also UI-first and get no world structure at
	-- all anymore (see the cleanup pass at the top of Run()).
	local seasonEvent = findFacility("SeasonEvent")
	local seasonPass = findFacility("SeasonPass")
	local eventSeasonAccent = HavenLayoutConfig.GetDistrict("EventSeason").accentColor
	local seasonTerminalPosition = facilityPosition(origin, seasonEvent):Lerp(facilityPosition(origin, seasonPass), 0.5)
	SeasonPavilionGenerator.Build(buildingsFolder, origin, seasonTerminalPosition, eventSeasonAccent)

	StorytellingClusterGenerator.Build(root, origin)

	root.Parent = Workspace

	print(
		`[BuildHavenDistricts] Built {builtCount} facilities, the Guidance stage + tutorial path, `
			.. `and storytelling clusters. Re-run any time to regenerate.`
	)
end

return BuildHavenDistricts
