--!strict
-- Shared world-prompt wiring for base facilities.
--
-- Every base facility screen opens the same way: find parts carrying a
-- CollectionService tag, ignore any that belong to a different player's base,
-- find the ProximityPrompt on them, and connect Triggered. Nine controllers
-- were about to repeat that (including the owner walk-up-the-ancestry check,
-- which is easy to get subtly wrong), so it lives here once.
--
-- Both the already-tagged set AND the InstanceAdded signal are handled,
-- because base structures are spawned and respawned at runtime — a building
-- finished after you walked up, or a blueprint pad restored after a
-- dismantle, must still get its prompt wired without a rejoin.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local FacilityPrompts = {}

-- Walks up the ancestry for the OwnerUserId attribute the base generator
-- stamps on structures. Returns nil for anything outside a personal base.
function FacilityPrompts.OwnerUserId(instance: Instance): number?
	local cursor: Instance? = instance
	while cursor do
		local value = cursor:GetAttribute("OwnerUserId")
		if typeof(value) == "number" then
			return value
		end
		cursor = cursor.Parent
	end
	return nil
end

function FacilityPrompts.IsLocalPlayersBase(instance: Instance): boolean
	return FacilityPrompts.OwnerUserId(instance) == Players.LocalPlayer.UserId
end

export type BindOptions = {
	Tag: string,
	-- Which ProximityPrompt to use. Defaults to the first one found, which is
	-- correct for parts carrying exactly one; pass a name where a part has
	-- several (a wall segment has both a label and an UpgradePrompt).
	PromptName: string?,
	-- Skip the owner check for facilities that are not inside a personal base
	-- (Haven anchors).
	RequireOwnership: boolean?,
	OnTriggered: (host: BasePart) -> (),
}

-- Binds `OnTriggered` to every current and future instance carrying the tag.
-- Returns a cleanup function that disconnects everything it created.
function FacilityPrompts.Bind(options: BindOptions): () -> ()
	local requireOwnership = options.RequireOwnership ~= false
	local connections: { RBXScriptConnection } = {}

	local function setup(instance: Instance)
		if not instance:IsA("BasePart") then
			return
		end
		if requireOwnership and not FacilityPrompts.IsLocalPlayersBase(instance) then
			return
		end

		local prompt: ProximityPrompt?
		if options.PromptName then
			local named = instance:FindFirstChild(options.PromptName, true)
			prompt = if named and named:IsA("ProximityPrompt") then named else nil
		else
			prompt = instance:FindFirstChildWhichIsA("ProximityPrompt", true)
		end
		if not prompt then
			return
		end

		table.insert(
			connections,
			prompt.Triggered:Connect(function()
				options.OnTriggered(instance :: BasePart)
			end)
		)
	end

	for _, instance in CollectionService:GetTagged(options.Tag) do
		setup(instance)
	end
	table.insert(connections, CollectionService:GetInstanceAddedSignal(options.Tag):Connect(setup))

	return function()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
	end
end

return FacilityPrompts
