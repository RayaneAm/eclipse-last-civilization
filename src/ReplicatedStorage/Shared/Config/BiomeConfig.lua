--!strict
-- Single source of truth for the 4 biomes. Consumed by:
--   * tools/BuildSurvivorHaven.server.luau + GateGenerator (what to build, and how it looks)
--   * BiomeGateService (unlock tiers)
--   * GateController (holographic info panel text, lock visuals)
--
-- SoundId fields are left at 0 — real audio assets must be uploaded to the
-- developer's Roblox account and their asset IDs pasted in here; that step
-- can't be done on your behalf from outside Studio.

export type GateShapeLanguage = {
	archStyle: "Organic" | "Shattered" | "Brutalist" | "Molten",
	primaryMaterial: Enum.Material,
	secondaryMaterial: Enum.Material,
	primaryColor: Color3,
	accentColor: Color3,
	scale: number, -- relative to the baseline gate size; Volcanic (endgame) is largest
	icon: string, -- Prompt 4A.1: single glyph shown on the gate's holographic info panel title row
}

export type BiomeDefinition = {
	id: string,
	order: number,
	name: string,
	description: string,
	unlockTier: number, -- Progression.Tier required to pass through. Every new player starts at 0 (everything
	-- locked); Forest requires completing the tutorial quest (see QuestConfig/QuestService), not "unlocked at
	-- spawn" as in earlier prompts — see Prompt 4A plan §5.
	recommendedLevel: number, -- Prompt 4A.1: display-only, shown on the gate's holographic panel. Not a
	-- separate gameplay system — actual gating always runs on unlockTier/ProgressionService.
	unlockRequirementText: string, -- Prompt 4A.1: human-readable requirement line for the locked-state panel.
	isEndgame: boolean,
	resources: { string },
	enemies: { string },
	gate: GateShapeLanguage,
	ambienceSoundId: number,
}

local BiomeConfig: { BiomeDefinition } = {
	{
		id = "ForestWildlands",
		order = 1,
		name = "Forest Wildlands",
		description = "Beautiful forests reclaiming the ruins of the old world. The safest ground left standing.",
		unlockTier = 1,
		recommendedLevel = 1,
		unlockRequirementText = "Complete the tutorial",
		isEndgame = false,
		resources = { "Wood", "Stone", "Food", "Wildlife" },
		enemies = { "Wolves", "Boars", "Corrupted Creatures" },
		gate = {
			archStyle = "Organic",
			primaryMaterial = Enum.Material.Rock,
			secondaryMaterial = Enum.Material.Wood,
			primaryColor = Color3.fromRGB(90, 84, 66),
			accentColor = Color3.fromRGB(120, 200, 110),
			scale = 1,
			icon = "🌲",
		},
		ambienceSoundId = 0,
	},
	{
		id = "FrozenWasteland",
		order = 2,
		name = "Frozen Wasteland",
		description = "An old city trapped in eternal winter, its towers entombed in ice.",
		unlockTier = 2,
		recommendedLevel = 25,
		unlockRequirementText = "Reach Level 25",
		isEndgame = false,
		resources = { "Ice Crystals", "Rare Metals", "Frozen Technology" },
		enemies = { "Ice Beasts", "Frozen Guardians" },
		gate = {
			archStyle = "Shattered",
			primaryMaterial = Enum.Material.Ice,
			secondaryMaterial = Enum.Material.Metal,
			primaryColor = Color3.fromRGB(200, 225, 235),
			accentColor = Color3.fromRGB(120, 210, 255),
			scale = 1.1,
			icon = "❄",
		},
		ambienceSoundId = 0,
	},
	{
		id = "NuclearCity",
		order = 3,
		name = "Nuclear City",
		description = "The technological heart of the old civilization. Skyscrapers and labs, long since fallen silent.",
		unlockTier = 3,
		recommendedLevel = 50,
		unlockRequirementText = "Reach Level 50",
		isEndgame = false,
		resources = { "Advanced Technology", "Energy Cells", "High-tier Components" },
		enemies = { "Security Robots", "Corrupted Drones" },
		gate = {
			archStyle = "Brutalist",
			primaryMaterial = Enum.Material.Concrete,
			secondaryMaterial = Enum.Material.Metal,
			primaryColor = Color3.fromRGB(70, 70, 74),
			accentColor = Color3.fromRGB(255, 180, 60),
			scale = 1.25,
			icon = "☢",
		},
		ambienceSoundId = 0,
	},
	{
		id = "VolcanicCore",
		order = 4,
		name = "Volcanic Core",
		description = "The source of the Eclipse energy itself. Few who enter return.",
		unlockTier = 4,
		recommendedLevel = 100,
		unlockRequirementText = "Defeat the Eclipse Warden",
		isEndgame = true,
		resources = { "Mythic Materials", "Eclipse Crystals", "Legendary Crafting Resources" },
		enemies = { "Bosses" },
		gate = {
			archStyle = "Molten",
			primaryMaterial = Enum.Material.Basalt,
			secondaryMaterial = Enum.Material.Neon,
			primaryColor = Color3.fromRGB(35, 30, 32),
			accentColor = Color3.fromRGB(255, 90, 40),
			scale = 1.5,
			icon = "🌋",
		},
		ambienceSoundId = 0,
	},
}

return BiomeConfig
