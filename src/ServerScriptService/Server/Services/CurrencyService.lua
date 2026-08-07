--!strict
-- Owns Currencies.Scrap inside the player's session. Earn-only — no
-- purchase hooks, per Prompt 4A's explicit "no monetization yet" boundary.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Signal = require(ReplicatedStorage.Shared.Modules.Signal)
local PlayerSessionService = require(script.Parent.PlayerSessionService)

local CurrencyService = {}

CurrencyService.BalanceChanged = Signal.new() -- (player, newBalance)

function CurrencyService.GetBalance(player: Player): number
	return PlayerSessionService.Get(player).Currencies.Scrap
end

local function setBalance(player: Player, balance: number)
	local session = PlayerSessionService.Get(player)
	session.Currencies.Scrap = balance
	CurrencyService.BalanceChanged:Fire(player, balance)
	Net.GetEvent("CurrencyChanged"):FireClient(player, balance)
end

function CurrencyService.Add(player: Player, amount: number)
	if amount <= 0 then
		return
	end
	setBalance(player, CurrencyService.GetBalance(player) + amount)
end

-- Returns false if the player can't afford it; never lets a balance go negative.
function CurrencyService.Remove(player: Player, amount: number): boolean
	if amount <= 0 then
		return true
	end
	local balance = CurrencyService.GetBalance(player)
	if balance < amount then
		return false
	end
	setBalance(player, balance - amount)
	return true
end

return CurrencyService
