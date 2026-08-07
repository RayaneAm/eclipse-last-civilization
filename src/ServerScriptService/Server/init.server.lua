--!strict
-- Server bootstrap. Requires every ModuleScript under Services/ and runs the
-- Init -> Start lifecycle via Loader. Keep this file empty of game logic —
-- logic belongs in a Service.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage.Shared.Framework.Loader)

Loader.LoadChildren(script.Services)
