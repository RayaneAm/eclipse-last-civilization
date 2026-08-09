--!strict
-- BASE STORAGE — opened at the storage crate or the field cache
-- (BaseStorageTerminal tag).
--
-- Replaces a spreadsheet of "amount (Reserved n)" rows each with a text box
-- you had to type a number into. Storage is now an icon list with a capacity
-- meter and tap-to-move amounts, which is both faster on desktop and the
-- only workable option on a phone (brief §23/§51).
--
-- Quantities are fixed choices (10 / All) rather than free entry: every
-- amount a player actually wants is one of those two, and neither can
-- produce an invalid request. The server still validates everything —
-- StorageService re-checks capacity and ownership on each call.
--
-- Raw vs Processed is derived from ProductionRecipeConfig (anything a
-- machine outputs is processed), not a hand-maintained second list that
-- could drift out of sync with the recipes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Trove = require(ReplicatedStorage.Shared.Modules.Trove)
local ProductionRecipeConfig = require(ReplicatedStorage.Shared.Config.ProductionRecipeConfig)

local Theme = require(script.Parent.Parent.UI.Theme)
local FacilityStyle = require(script.Parent.Parent.UI.FacilityStyle)
local FacilityRouter = require(script.Parent.Parent.UI.FacilityRouter)
local FacilityPrompts = require(script.Parent.Parent.UI.FacilityPrompts)
local FacilityModal = require(script.Parent.Parent.UI.Components.FacilityModal)
local SectionHeader = require(script.Parent.Parent.UI.Components.SectionHeader)
local MeterRow = require(script.Parent.Parent.UI.Components.MeterRow)
local EmptyState = require(script.Parent.Parent.UI.Components.EmptyState)
local ItemIcon = require(script.Parent.Parent.UI.Components.ItemIcon)
local Button = require(script.Parent.Parent.UI.Components.Button)
local Surface = require(script.Parent.Parent.UI.Components.Surface)

local BaseSessionController = require(script.Parent.BaseSessionController)
local NotificationController = require(script.Parent.NotificationController)

local StorageController = {}

local IDENTITY = FacilityStyle.Facilities.Storage
local ACCENT = IDENTITY.Accent
local QUICK_AMOUNT = 10

local TABS = {
	{ Id = "All", Label = "ALL" },
	{ Id = "Raw", Label = "RAW" },
	{ Id = "Processed", Label = "PROCESSED" },
	{ Id = "Deposit", Label = "DEPOSIT" },
}

local DEPOSIT_REJECTIONS: { [string]: string } = {
	StorageFull = "Base Storage is full",
	InsufficientInventory = "You are not carrying that much",
	NotInvited = "You cannot deposit into this base",
	BaseNotReady = "Your base is not ready yet",
}

local WITHDRAW_REJECTIONS: { [string]: string } = {
	InsufficientStorage = "Not enough in Base Storage",
	BaseNotReady = "Your base is not ready yet",
}

local modal: FacilityModal.FacilityModal? = nil
local currentTab = "All"
local pendingAction = false

-- Built once: every item any production recipe can output.
local processedItems: { [string]: boolean } = {}
for _, recipe in ProductionRecipeConfig.All do
	processedItems[recipe.OutputItemId] = true
end

local function deposit(itemId: string, amount: number)
	if pendingAction or amount <= 0 then
		return
	end
	pendingAction = true
	local ok, reason = Net.GetFunction("RequestDepositStorage"):InvokeServer({ ItemId = itemId, Amount = amount })
	pendingAction = false
	if not ok then
		NotificationController.Toast("BuildRejected", DEPOSIT_REJECTIONS[tostring(reason)] or `Deposit failed: {tostring(reason)}`)
	end
end

local function withdraw(itemId: string, amount: number)
	if pendingAction or amount <= 0 then
		return
	end
	pendingAction = true
	local ok, reason = Net.GetFunction("RequestWithdrawStorage"):InvokeServer({ ItemId = itemId, Amount = amount })
	pendingAction = false
	if not ok then
		NotificationController.Toast("BuildRejected", WITHDRAW_REJECTIONS[tostring(reason)] or `Withdraw failed: {tostring(reason)}`)
	end
end

-- One row: icon, name, amount, and two fixed-amount actions.
local function buildRow(parent: Instance, itemId: string, amount: number, reserved: number, actionLabel: string, layoutOrder: number, onMove: (quantity: number) -> ())
	local row = Surface.new({
		Name = `Row_{itemId}`,
		Size = UDim2.new(1, 0, 0, 48),
		LayoutOrder = layoutOrder,
		Parent = parent,
	})

	ItemIcon.new({
		ItemId = itemId,
		Size = UDim2.fromOffset(30, 30),
		Position = UDim2.fromOffset(10, 9),
		Parent = row,
	})

	local name = Instance.new("TextLabel")
	name.Name = "ItemName"
	name.Position = UDim2.fromOffset(50, 6)
	name.Size = UDim2.new(1, -190, 0, 20)
	name.BackgroundTransparency = 1
	name.Font = Theme.Font.Body.Font
	name.TextSize = Theme.Font.Body.Size
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.TextColor3 = Theme.Colors.TextPrimary
	name.Text = FacilityStyle.PrettyName(itemId)
	name.Parent = row

	local detail = Instance.new("TextLabel")
	detail.Name = "Detail"
	detail.Position = UDim2.fromOffset(50, 25)
	detail.Size = UDim2.new(1, -190, 0, 16)
	detail.BackgroundTransparency = 1
	detail.Font = Theme.Font.Caption.Font
	detail.TextSize = Theme.Font.Caption.Size
	detail.TextXAlignment = Enum.TextXAlignment.Left
	detail.TextColor3 = Theme.Colors.TextMuted
	detail.Text = if reserved > 0 then `{amount} held · {reserved} reserved` else `{amount} held`
	detail.Parent = row

	local actions = Instance.new("Frame")
	actions.Name = "Actions"
	actions.AnchorPoint = Vector2.new(1, 0.5)
	actions.Position = UDim2.new(1, -10, 0.5, 0)
	actions.Size = UDim2.fromOffset(124, 32)
	actions.BackgroundTransparency = 1
	actions.Parent = row

	local actionsLayout = Instance.new("UIListLayout")
	actionsLayout.FillDirection = Enum.FillDirection.Horizontal
	actionsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	actionsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	actionsLayout.Padding = UDim.new(0, Theme.Spacing.XS)
	actionsLayout.Parent = actions

	if amount > QUICK_AMOUNT then
		Button.new({
			Name = "Quick",
			Text = tostring(QUICK_AMOUNT),
			Variant = "Secondary",
			AccentColor = ACCENT,
			Size = UDim2.fromOffset(44, 32),
			LayoutOrder = 1,
			OnActivated = function()
				onMove(QUICK_AMOUNT)
			end,
			Parent = actions,
		})
	end

	Button.new({
		Name = "All",
		Text = actionLabel,
		Variant = "Primary",
		AccentColor = ACCENT,
		Size = UDim2.fromOffset(if amount > QUICK_AMOUNT then 74 else 118, 32),
		LayoutOrder = 2,
		OnActivated = function()
			onMove(amount)
		end,
		Parent = actions,
	})
end

local function renderCapacity(content: GuiObject, layoutOrder: number)
	local storage = BaseSessionController.GetStorageSummary()
	local fraction = if storage.Capacity > 0 then storage.Used / storage.Capacity else 0
	MeterRow.new({
		Label = "Capacity",
		Value = `{storage.Used} / {storage.Capacity}`,
		Progress = fraction,
		Accent = ACCENT,
		ValueColor = if fraction >= 0.9 then Theme.Colors.Warning else Theme.Colors.TextPrimary,
		Info = "Total units across every material stored in your base.",
		LayoutOrder = layoutOrder,
		Parent = content,
	})
end

local function renderStored(content: GuiObject, filter: string, nextOrder: () -> number)
	local session = BaseSessionController.GetSession()
	renderCapacity(content, nextOrder())

	local itemIds: { string } = {}
	if session then
		for itemId, amount in session.Storage do
			if amount <= 0 then
				continue
			end
			local isProcessed = processedItems[itemId] == true
			if filter == "Raw" and isProcessed then
				continue
			elseif filter == "Processed" and not isProcessed then
				continue
			end
			table.insert(itemIds, itemId)
		end
		table.sort(itemIds, function(a, b)
			return session.Storage[a] > session.Storage[b]
		end)
	end

	if #itemIds == 0 then
		EmptyState.new({
			Glyph = "Storage",
			Text = if filter == "All" then "Base Storage is empty" else "Nothing here yet",
			Subtext = if filter == "Processed"
				then "Run a production job to make processed materials."
				else "Deposit expedition materials from your backpack.",
			Card = true,
			LayoutOrder = nextOrder(),
			Parent = content,
		})
		return
	end

	SectionHeader.new({
		Text = "Withdraw",
		Accent = ACCENT,
		Info = "Withdrawn materials go back into your backpack.",
		LayoutOrder = nextOrder(),
		Parent = content,
	})

	for _, itemId in itemIds do
		local amount = session.Storage[itemId]
		buildRow(content, itemId, amount, session.Reserved[itemId] or 0, "Withdraw", nextOrder(), function(quantity)
			withdraw(itemId, quantity)
		end)
	end
end

local function renderDeposit(content: GuiObject, nextOrder: () -> number)
	renderCapacity(content, nextOrder())

	local inventory = BaseSessionController.GetInventory()
	local itemIds: { string } = {}
	for itemId, amount in inventory do
		if amount > 0 then
			table.insert(itemIds, itemId)
		end
	end
	table.sort(itemIds, function(a, b)
		return inventory[a] > inventory[b]
	end)

	if #itemIds == 0 then
		EmptyState.new({
			Glyph = "Storage",
			Text = "Your backpack is empty",
			Subtext = "Gather materials on an expedition, then deposit them here.",
			Card = true,
			LayoutOrder = nextOrder(),
			Parent = content,
		})
		return
	end

	SectionHeader.new({
		Text = "Deposit from backpack",
		Accent = ACCENT,
		LayoutOrder = nextOrder(),
		Parent = content,
	})

	for _, itemId in itemIds do
		buildRow(content, itemId, inventory[itemId], 0, "Deposit", nextOrder(), function(quantity)
			deposit(itemId, quantity)
		end)
	end
end

local function render()
	local activeModal = modal
	if not activeModal then
		return
	end
	activeModal:ClearContent()

	local layoutOrder = 0
	local function nextOrder(): number
		layoutOrder += 1
		return layoutOrder
	end

	if currentTab == "Deposit" then
		renderDeposit(activeModal.Content, nextOrder)
	else
		renderStored(activeModal.Content, currentTab, nextOrder)
	end

	activeModal:RevealContent()
end

function StorageController.Open(initialTab: string?)
	local activeModal = modal
	if not activeModal then
		return
	end
	BaseSessionController.Refresh()
	currentTab = initialTab or "All"
	activeModal:Open(currentTab)
	render()
end

function StorageController:Init()
	self._trove = Trove.new()

	modal = FacilityModal.new({
		Id = "Storage",
		Icon = IDENTITY.Icon,
		Title = IDENTITY.Title,
		Subtitle = IDENTITY.Subtitle,
		Accent = ACCENT,
		WidthClass = "Regular",
		Tabs = TABS,
		OnTabSelected = function(tabId: string)
			currentTab = tabId
			render()
		end,
	})

	FacilityRouter.Register("Storage", function(tabId: string?)
		StorageController.Open(tabId)
	end)
end

function StorageController:Start()
	self._trove:Add(FacilityPrompts.Bind({
		Tag = "BaseStorageTerminal",
		OnTriggered = function()
			StorageController.Open("All")
		end,
	}))

	self._trove:Add(BaseSessionController.Changed:Connect(function()
		local activeModal = modal
		if activeModal and activeModal:IsOpen() then
			render()
		end
	end))
end

return StorageController
