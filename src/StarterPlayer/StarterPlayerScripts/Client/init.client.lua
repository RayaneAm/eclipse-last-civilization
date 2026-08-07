--!strict
-- Client bootstrap. Requires every ModuleScript under Controllers/ and runs
-- the Init -> Start lifecycle via Loader. Keep this file empty of game logic.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage.Shared.Framework.Loader)

Loader.LoadChildren(script.Controllers)
