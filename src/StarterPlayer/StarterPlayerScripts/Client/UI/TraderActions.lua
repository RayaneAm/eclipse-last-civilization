--!strict
-- The NPC trade calls (sell / buy / sell-junk) plus their shared result
-- handling, in one place.
--
-- Two screens front the same TraderService backend — the base Trader
-- Terminal and the Haven's Survivor Market — because it IS the same merchant
-- economy at server-computed TraderConfig prices, reachable from anywhere
-- since it trades your carried inventory rather than a location's stock.
-- Only the framing differs. Duplicating the remote calls, the reserve
-- confirmation and the rejection copy across both would guarantee they drift
-- apart, so both screens call through here.
--
-- The reserve confirmation deserves special note: when a sale would drop a
-- reserved material below its reserve, the server refuses and returns the
-- exact Remaining/Reserved figures. The warning copy is built from THOSE
-- numbers, never from a client-side recomputation, so what the player is
-- warned about is exactly what the server enforces.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)

local FacilityStyle = require(script.Parent.FacilityStyle)
local ConfirmDialog = require(script.Parent.Components.ConfirmDialog)

local NotificationController = require(script.Parent.Parent.Controllers.NotificationController)

local TraderActions = {}

-- Serialized against itself so a double-tap can't fire two sales.
local inFlight = false

function TraderActions.IsBusy(): boolean
	return inFlight
end

function TraderActions.Sell(itemId: string, amount: number, confirmOverride: boolean?)
	if inFlight or amount <= 0 then
		return
	end
	inFlight = true
	local ok, reasonOrPayout, extra = Net.GetFunction("RequestTraderSell"):InvokeServer({
		ItemId = itemId,
		Amount = amount,
		ConfirmOverride = confirmOverride,
	})
	inFlight = false

	if ok then
		NotificationController.Toast("ResourceCollected", `Sold {amount} {FacilityStyle.PrettyName(itemId)} for ◆{reasonOrPayout}`)
		return
	end

	if reasonOrPayout == "BelowReserve" and extra then
		ConfirmDialog.Show({
			Title = "Sell Below Reserve",
			Message = `{FacilityStyle.PrettyName(itemId)} is reserved for base upgrades. This sale would leave you with {extra.Remaining} of the {extra.Reserved} you reserved. Sell anyway?`,
			ConfirmText = "Sell Anyway",
			Danger = true,
			OnConfirm = function()
				TraderActions.Sell(itemId, amount, true)
			end,
		})
		return
	end

	local message = if reasonOrPayout == "InsufficientInventory"
		then "You are not carrying that many"
		elseif reasonOrPayout == "NotSellable" then "The trader does not buy that"
		else `Sale failed: {tostring(reasonOrPayout)}`
	NotificationController.Toast("BuildRejected", message)
end

function TraderActions.Buy(itemId: string, amount: number)
	if inFlight or amount <= 0 then
		return
	end
	inFlight = true
	local ok, reason = Net.GetFunction("RequestTraderBuy"):InvokeServer({ ItemId = itemId, Amount = amount })
	inFlight = false

	if ok then
		NotificationController.Toast("ResourceCollected", `Bought {amount} {FacilityStyle.PrettyName(itemId)}`)
		return
	end

	local message = if reason == "InsufficientScrap"
		then "Not enough Scrap"
		elseif reason == "NotBuyable" then "The trader does not stock that"
		else `Purchase failed: {tostring(reason)}`
	NotificationController.Toast("BuildRejected", message)
end

function TraderActions.SellJunk()
	if inFlight then
		return
	end
	inFlight = true
	local ok, total = Net.GetFunction("RequestTraderSellJunk"):InvokeServer()
	inFlight = false

	if ok and typeof(total) == "number" and total > 0 then
		NotificationController.Toast("ResourceCollected", `Sold junk for ◆{total}`)
	else
		NotificationController.Toast("BuildRejected", "No junk to sell")
	end
end

return TraderActions
