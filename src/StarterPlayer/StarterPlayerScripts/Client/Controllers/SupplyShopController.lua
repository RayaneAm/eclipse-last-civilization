--!strict
-- Phase 4A: the always-available, system-controlled Supply Shop panel —
-- distinct from the NPC trader (base-local) and the Player Marketplace
-- (player-to-player). Fixed catalog fetched fresh from the server every
-- open (RequestSupplyShopCatalog) rather than trusting a cached copy, since
-- requirements (base level, biome unlocks) can change between opens.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Trove = require(ReplicatedStorage.Shared.Modules.Trove)
local BiomeConfig = require(ReplicatedStorage.Shared.Config.BiomeConfig)

local Theme = require(script.Parent.Parent.UI.Theme)
local Motion = require(script.Parent.Parent.UI.Motion)
local GamepadNav = require(script.Parent.Parent.UI.GamepadNav)
local GlassPanel = require(script.Parent.Parent.UI.Components.GlassPanel)
local CloseButton = require(script.Parent.Parent.UI.Components.CloseButton)
local ConfirmDialog = require(script.Parent.Parent.UI.Components.ConfirmDialog)
local OfferCard = require(script.Parent.Parent.UI.Components.OfferCard)

local HUDController = require(script.Parent.HUDController)

local SupplyShopController = {}

local isOpen = false
local previousSelection: GuiObject? = nil

-- Real eligibility, not just informational text: base level comes from
-- RequestBaseState's own session (the same remote BasePlacementController
-- already uses), biome unlock mirrors SupplyShopService's own
-- (player Tier >= biome.unlockTier) check — so a requirement row's
-- green/red dot always agrees with what RequestSupplyShopPurchase would
-- actually accept or reject server-side.
local function buildRequirementLines(baseLevel: number, tier: number, item: any): { OfferCard.RequirementLine }
	local lines: { OfferCard.RequirementLine } = {}
	if item.Requirements.MinBaseLevel then
		table.insert(lines, { Text = `Base Level {item.Requirements.MinBaseLevel}`, Met = baseLevel >= item.Requirements.MinBaseLevel })
	end
	if item.Requirements.RequiredBiomeId then
		local biomeName = item.Requirements.RequiredBiomeId
		local unlocked = false
		for _, biome in BiomeConfig do
			if biome.id == item.Requirements.RequiredBiomeId then
				biomeName = biome.name
				unlocked = tier >= biome.unlockTier
				break
			end
		end
		table.insert(lines, { Text = biomeName, Met = unlocked })
	end
	return lines
end

-- UI/HUD Visual Direction Pass: "Stacked" layout — dominant preview plate,
-- cost/requirements grouped into their own Surface sub-block, full-width
-- CTA — Supply Shop's small set of high-value items deserves a card the
-- player stops and inspects, not a compact browsable row (that's what
-- Marketplace's "Row" layout is for). Returns the Buy button for GamepadNav
-- chaining.
local function renderOfferCard(parent: Instance, item: any, baseLevel: number, tier: number, layoutOrder: number): TextButton
	local requirements = buildRequirementLines(baseLevel, tier, item)
	local allMet = true
	for _, line in requirements do
		if not line.Met then
			allMet = false
			break
		end
	end

	local _card, button = OfferCard.new({
		Name = item.Id,
		ItemId = item.Id,
		Title = item.Name,
		Description = item.Description,
		ScrapCost = item.ScrapCost,
		Materials = item.Materials,
		Requirements = requirements,
		StatusText = if allMet then nil else "Locked",
		StatusVariant = "Locked",
		Layout = "Stacked",
		-- Self-explanatory label instead of a disabled "Purchase" that just
		-- looks broken/unresponsive — the preview plate also mutes to gray
		-- and the unmet requirement row stays red, per OfferCard's own
		-- locked-state chrome.
		ButtonText = if allMet then "Purchase" else "Locked",
		ButtonDisabled = not allMet,
		LayoutOrder = layoutOrder,
		OnActivated = function()
			ConfirmDialog.Show({
				Title = item.Name,
				Message = `Purchase for ◆ {item.ScrapCost} plus required materials?`,
				ConfirmText = "Purchase",
				OnConfirm = function()
					local ok, reason = Net.GetFunction("RequestSupplyShopPurchase"):InvokeServer({ ItemId = item.Id })
					if not ok then
						warn(`SupplyShopController: purchase failed: {tostring(reason)}`)
					end
				end,
			})
		end,
		Parent = parent,
	})
	return button
end

function SupplyShopController:_buildPanel()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SupplyShopUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui
	self._trove:Add(screenGui)

	local backdrop = Instance.new("CanvasGroup")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.5
	backdrop.GroupTransparency = 1
	backdrop.Visible = false
	backdrop.Parent = screenGui
	self._backdrop = backdrop

	local backdropButton = Instance.new("TextButton")
	backdropButton.Name = "BackdropCatcher"
	backdropButton.Size = UDim2.fromScale(1, 1)
	backdropButton.BackgroundTransparency = 1
	backdropButton.Text = ""
	backdropButton.AutoButtonColor = false
	backdropButton.Parent = backdrop
	self._trove:Add(backdropButton.Activated:Connect(function()
		SupplyShopController.Close()
	end))

	local panel = GlassPanel.new({
		Name = "Panel",
		Size = UDim2.new(0.7, 0, 0.75, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = backdrop,
	})
	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(360, 400)
	sizeConstraint.MaxSize = Vector2.new(560, 620)
	sizeConstraint.Parent = panel
	self._panel = panel

	local panelScale = Instance.new("UIScale")
	panelScale.Name = "PanelScale"
	panelScale.Scale = 0.94
	panelScale.Parent = panel
	self._panelScale = panelScale

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, Theme.Spacing.L)
	padding.PaddingRight = UDim.new(0, Theme.Spacing.L)
	padding.PaddingTop = UDim.new(0, Theme.Spacing.L)
	padding.PaddingBottom = UDim.new(0, Theme.Spacing.L)
	padding.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -52, 0, 28)
	title.Font = Theme.Font.Title.Font
	title.TextSize = Theme.Font.Title.Size
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Theme.Colors.TextPrimary
	title.Text = "SURVIVOR SUPPLY NETWORK"
	title.Parent = panel

	local closeButton = CloseButton.new({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		OnActivated = function()
			SupplyShopController.Close()
		end,
		Parent = panel,
	})

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "ItemList"
	scroll.Size = UDim2.new(1, 0, 1, -44)
	scroll.Position = UDim2.new(0, 0, 0, 44)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 6
	scroll.Parent = panel
	self._itemList = scroll

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, Theme.Spacing.S)
	listLayout.Parent = scroll

	GamepadNav.LinkChain({ closeButton })
end

function SupplyShopController:_refreshCatalog()
	for _, child in self._itemList:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	local ok, catalog = pcall(function()
		return Net.GetFunction("RequestSupplyShopCatalog"):InvokeServer()
	end)
	if not ok or not catalog then
		return
	end

	local player = Players.LocalPlayer
	local baseOk, baseResult = pcall(function()
		return Net.GetFunction("RequestBaseState"):InvokeServer(player.UserId)
	end)
	local baseLevel = if baseOk and baseResult and baseResult.Session then baseResult.Session.Level else 1

	local sessionOk, session = pcall(function()
		return Net.GetFunction("RequestPlayerSession"):InvokeServer()
	end)
	local tier = if sessionOk and session then session.Progression.Tier else 0

	local order = 1
	local buyButtons: { TextButton } = {}
	for _, item in catalog do
		table.insert(buyButtons, renderOfferCard(self._itemList, item, baseLevel, tier, order))
		order += 1
	end
	GamepadNav.LinkChain(buyButtons)
end

function SupplyShopController:Init()
	self._trove = Trove.new()
	self:_buildPanel()
end

function SupplyShopController.Open()
	if isOpen then
		return
	end
	isOpen = true

	local self = SupplyShopController
	self:_refreshCatalog()
	self._backdrop.Visible = true
	Motion.Tween(self._backdrop, "Fade", Theme.Motion.PanelOpen, { GroupTransparency = 0 })
	Motion.Tween(self._panelScale, "Scale", Theme.Motion.PanelOpen, { Scale = 1 })

	previousSelection = GuiService.SelectedObject
	GamepadNav.FocusFirst(self._panel)
end

function SupplyShopController.Close()
	if not isOpen then
		return
	end
	isOpen = false

	local self = SupplyShopController
	local tween = Motion.Tween(self._backdrop, "Fade", Theme.Motion.PanelClose, { GroupTransparency = 1 })
	Motion.Tween(self._panelScale, "Scale", Theme.Motion.PanelClose, { Scale = 0.94 })
	tween.Completed:Once(function()
		if not isOpen then
			self._backdrop.Visible = false
		end
	end)
	GamepadNav.Restore(previousSelection)
end

function SupplyShopController:Start()
	self._trove:Add(HUDController.SupplyShopOpenRequested:Connect(function()
		SupplyShopController.Open()
	end))
end

return SupplyShopController
