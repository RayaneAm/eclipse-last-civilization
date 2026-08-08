--!strict
-- One-shot world-build orchestrator for real biome terrain (Prompt 2:
-- portal architecture). Each biome now generates as a standalone region at
-- its own independent WorldMapConfig.RealOrigin, far from Haven and far
-- from every other destination — NOT as 4 wedges radiating from Haven's
-- shared origin like before. NOT part of the runtime game (see
-- BuildSurvivorHaven.luau for the full explanation of why this lives in
-- ServerStorage.Tools).
--
-- Preferred: the ECLIPSE TOOLS Studio plugin's "BUILD COMPLETE WORLD"
-- button (see plugin/), which reaches this stage through BuildCompleteWorld.
--
-- Command Bar fallback:
--
--   require(game:GetService("ServerStorage").Tools.BuildWorldMap).Run()
--
-- Exports Run() rather than executing at module-load time — see
-- BuildSurvivorHaven.luau's top comment for why (require() caching).
--
-- Expect this to take anywhere from several seconds to a couple of minutes
-- depending on machine — it's carving out thousands of studs of terrain via
-- ~12,000+ Terrain ops. Progress prints to the Output window.
--
-- CAUTION: re-running always clears each biome's OWN generated terrain
-- region back to Air first — Terrain has no per-object namespace to protect
-- hand sculpting the way the Part-based generators do (see TerrainGenerator's
-- top comment). This does NOT touch the old near-Haven terrain footprint
-- repeatedly — that one-time cleanup is handled once, ever, by
-- MigrateNearHavenTerrain (see below), never re-run after its first success.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BiomeConfig = require(ReplicatedStorage.Shared.Config.BiomeConfig)
local WorldMapConfig = require(ReplicatedStorage.Shared.Config.WorldMapConfig)

local GeneratorKit = require(script.Parent.Generators.GeneratorKit)
local TerrainGenerator = require(script.Parent.Generators.TerrainGenerator)
local LandmarkGenerator = require(script.Parent.Generators.LandmarkGenerator)
local PortalDestinationGenerator = require(script.Parent.Generators.PortalDestinationGenerator)
local MigrateNearHavenTerrain = require(script.Parent.MigrateNearHavenTerrain)
local PortalDestinationConfig = require(ReplicatedStorage.Shared.Config.PortalDestinationConfig)

local ROOT_NAME = "WorldMap_Generated"

local BuildWorldMap = {}

function BuildWorldMap.Run()
	local startTime = os.clock()

	-- One-time, self-gating: no-ops instantly on every rebuild after the
	-- first successful run (see MigrateNearHavenTerrain.luau's own header).
	MigrateNearHavenTerrain.Run()

	GeneratorKit.CleanupPrevious(Workspace, ROOT_NAME)
	local root = Instance.new("Model")
	root.Name = ROOT_NAME
	root.Parent = Workspace

	for _, biome in BiomeConfig do
		local origin = WorldMapConfig.RealOrigin[biome.id]
		assert(origin, `BuildWorldMap: no RealOrigin configured for biome "{biome.id}"`)

		print(`[BuildWorldMap] Sculpting standalone terrain for {biome.name} at its own hidden origin...`)
		TerrainGenerator.Build(origin, biome)

		local biomeFolder = Instance.new("Model")
		biomeFolder.Name = biome.id
		biomeFolder.Parent = root
		LandmarkGenerator.Build(biomeFolder, origin, biome)

		local destination = PortalDestinationConfig.Get(biome.id)
		assert(destination, `BuildWorldMap: no PortalDestinationConfig entry for biome "{biome.id}"`)
		PortalDestinationGenerator.Build(biomeFolder, {
			id = "PortalDestination",
			displayName = destination.displayName,
			realOrigin = origin,
			arrivalAnchorName = destination.arrivalAnchorName,
			returnAnchorName = destination.returnAnchorName,
			accentColor = biome.gate.accentColor,
		})
	end

	local elapsed = math.round(os.clock() - startTime)
	print(
		`[BuildWorldMap] Done in {elapsed}s. Built standalone terrain for {#BiomeConfig} biomes and their landmarks, `
			.. `each at its own independent hidden origin. Re-run any time to regenerate (clears each biome's own prior terrain — see this file's top comment).`
	)
end

return BuildWorldMap
