--!strict
-- Pure schema/reconciliation checks safe to run from the canonical world
-- build. DataStore lifecycle itself is exercised in Studio with API Services.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerSessionTypes = require(ReplicatedStorage.Shared.Config.PlayerSessionTypes)
local CraftingConfig = require(ReplicatedStorage.Shared.Config.CraftingConfig)
local QuestConfig = require(ReplicatedStorage.Shared.Config.QuestConfig)

local ValidatePlayerSessionProfile = {}

function ValidatePlayerSessionProfile.Run(): { string }
	local checks = {}
	local function check(condition: boolean, message: string)
		assert(condition, `[PlayerSessionProfileValidation] {message}`)
		table.insert(checks, message)
	end

	local defaults = PlayerSessionTypes.NewDefault()
	check(defaults.SchemaVersion == PlayerSessionTypes.CURRENT_SCHEMA_VERSION, "new profile uses current schema")
	check(defaults.TutorialCompleted == false, "new profile defaults TutorialCompleted to false")

	local migratedMissing = PlayerSessionTypes.Reconcile({ SchemaVersion = 0, UnrelatedFutureField = "preserve-on-save" })
	check(migratedMissing.TutorialCompleted == false, "old profile without TutorialCompleted reconciles false")
	check(migratedMissing.SchemaVersion == PlayerSessionTypes.CURRENT_SCHEMA_VERSION, "old profile migrates to current schema")
	local current = PlayerSessionTypes.Reconcile({
		SchemaVersion = PlayerSessionTypes.CURRENT_SCHEMA_VERSION,
		TutorialCompleted = true,
		Progression = { Tier = 3, XP = 12 },
	})
	check(current.TutorialCompleted and current.Progression.Tier == 3 and current.Progression.XP == 12, "current profile preserves valid values")

	local malformed = PlayerSessionTypes.Reconcile({
		TutorialCompleted = "yes",
		Progression = { Tier = -4, XP = 0 / 0 },
		Quest = { CompletedQuestIds = { "TutorialQuest", 42, "TutorialQuest" } },
	})
	check(malformed.TutorialCompleted == false, "malformed boolean falls back safely")
	check(malformed.Progression.Tier == 0 and malformed.Progression.XP == 0, "malformed progression falls back safely")
	check(#malformed.Quest.CompletedQuestIds == 1, "completed quest ids are validated and deduplicated")

	local completed = PlayerSessionTypes.NewDefault()
	completed.TutorialCompleted = true
	completed.Progression.Tier = 1
	table.insert(completed.Quest.CompletedQuestIds, "TutorialQuest")
	local serialized = PlayerSessionTypes.SerializePersistent(completed)
	local reloaded = PlayerSessionTypes.Reconcile(serialized)
	check(reloaded.TutorialCompleted, "completed tutorial survives profile round-trip")
	check(reloaded.Progression.Tier == 1, "tutorial progression tier survives profile round-trip")
	check(table.find(reloaded.Quest.CompletedQuestIds, "TutorialQuest") ~= nil, "completed tutorial quest survives profile round-trip")

	local old = { UnknownField = { Keep = true }, SchemaVersion = 0 }
	local merged = table.clone(old)
	for field, value in PlayerSessionTypes.SerializePersistent(completed) do
		merged[field] = value
	end
	check(merged.UnknownField == old.UnknownField, "merge-aware save preserves unknown top-level fields")

	local hatchetRecipe = assert(CraftingConfig.Get("Hatchet"))
	local craftObjective = QuestConfig.TutorialQuest.objectives[#QuestConfig.TutorialQuest.objectives - 1]
	local finalObjective = QuestConfig.TutorialQuest.objectives[#QuestConfig.TutorialQuest.objectives]
	check(hatchetRecipe.output.itemId == "Hatchet", "canonical Hatchet recipe grants canonical Hatchet item")
	check(craftObjective.type == "CraftItem" and craftObjective.targetId == hatchetRecipe.id, "server-validated Hatchet craft precedes tutorial turn-in")
	check(finalObjective.type == "TalkToNPC", "Survivor Guide turn-in is the final tutorial objective")

	return checks
end

return ValidatePlayerSessionProfile
