--!strict
-- Stable backing-store and lifecycle tuning for canonical PlayerSessionData.
-- Studio uses a separate key namespace inside the same store so an API-enabled
-- local test can never overwrite a production player's profile.

local RunService = game:GetService("RunService")

local PlayerSessionPersistenceConfig = {}

PlayerSessionPersistenceConfig.DATASTORE_NAME = "EclipsePlayerSession_v1"
PlayerSessionPersistenceConfig.AUTOSAVE_INTERVAL_SECONDS = 120
PlayerSessionPersistenceConfig.LOAD_ATTEMPTS = 3
PlayerSessionPersistenceConfig.SAVE_ATTEMPTS = 3

function PlayerSessionPersistenceConfig.KeyForUserId(userId: number): string
	if RunService:IsStudio() then
		return `studio:{game.PlaceId}:{userId}`
	end
	return `player:{userId}`
end

return PlayerSessionPersistenceConfig
