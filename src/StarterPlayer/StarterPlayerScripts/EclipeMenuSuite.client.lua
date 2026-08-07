--[[
    ECLIPSE: LAST CIVILIZATION
    PS99-inspired UI readability, rebuilt as an original Eclipse survivor-tech skin.

    INSTALL:
      1. Put this LocalScript in StarterPlayer > StarterPlayerScripts.
      2. Press Play. A five-button demo dock appears at the bottom.
      3. Replace the demo data in DATA with your real client-readable data.
      4. Connect ACTION() to your own RemoteEvents / server systems.

    IMPORTANT:
      This script is the CLIENT UI only. Purchases, trading, currency changes,
      marketplace listings, and inventory edits must be validated on the server.

    OPEN FROM ANOTHER LOCAL SCRIPT:
      _G.EclipseUI.Open("Shop")
      _G.EclipseUI.Open("Offer")
      _G.EclipseUI.Open("Marketplace")
      _G.EclipseUI.Open("Supply")
      _G.EclipseUI.Open("Inventory")
      _G.EclipseUI.Close()
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local CONFIG = {
	GuiName = "EclipseSurvivorUI",
	ShowDemoDock = true,
	OpenOnStart = "Inventory", -- false, "Shop", "Offer", "Marketplace", "Supply", "Inventory"
	CurrencyName = "SCRAP",
	CurrencyAmount = 12450,
	PremiumCurrencyName = "ROBUX",
	-- Upload the PNG you sent to Roblox Asset Manager, then paste its IMAGE asset ID here.
	-- Example: RobuxLogoAssetId = 123456789012345
	RobuxLogoAssetId = 130278804220126,
	-- New-player deal. Set NewPlayerOfferEndsAt on the PLAYER from the server.
	-- The value must be a Unix timestamp. Studio gets a preview timer automatically.
	StarterOffer = {
		PurchaseType = "GamePass",
		PurchaseId = 0,
		Price = 129,
		OriginalPrice = 199,
		OfferEndsAtAttribute = "NewPlayerOfferEndsAt",
		StudioPreviewSeconds = 24 * 60 * 60,
	},
	-- Optional: set true once your old menu-opening buttons already exist.
	AutoConnectExistingButtons = true,
}

local DATA = {
	Shop = {
		-- Replace PurchaseId = 0 with your real Game Pass IDs from Creator Dashboard.
		{icon = "R", title = "FIELD RADIO", subtitle = "Portable comms cosmetic", price = 79, currency = "R$", accent = "Cyan", badge = "POPULAR", buttonTopText = "PERMANENT ITEM", rewardText = "1x Field Radio", purchaseType = "GamePass", purchaseId = 0},
		{icon = "S+", title = "EXTRA STORAGE", subtitle = "+2 organized loadout pages", price = 149, currency = "R$", accent = "Purple", badge = "UTILITY", buttonTopText = "PERMANENT UPGRADE", rewardText = "+2 Loadout Pages", purchaseType = "GamePass", purchaseId = 0},
		{icon = "H", title = "HAVEN SUPPORTER", subtitle = "Supporter tag + nameplate", price = 199, currency = "R$", accent = "Gold", badge = "DIRECT", buttonTopText = "SUPPORTER BUNDLE", rewardText = "Tag + Nameplate", purchaseType = "GamePass", purchaseId = 0},
		{icon = "SK", title = "GEAR SKIN PACK", subtitle = "Industrial equipment skins", price = 99, currency = "R$", accent = "Orange", badge = "COSMETIC", buttonTopText = "COSMETIC PACK", rewardText = "4x Gear Skins", purchaseType = "GamePass", purchaseId = 0},
	},

	Supply = {
		{title = "REPAIR KIT", subtitle = "Repairs damaged base structures.", price = 650, currency = "SCRAP", accent = "Green", badge = "REPAIR"},
		{title = "EMERGENCY MEDKIT", subtitle = "Expedition recovery supply.", price = 520, currency = "SCRAP", accent = "Red", badge = "RECOVERY"},
		{title = "FIELD RATIONS", subtitle = "Compact supplies for longer runs.", price = 240, currency = "SCRAP", accent = "Gold", badge = "SURVIVAL"},
		{title = "PORTABLE BATTERY", subtitle = "Keeps field equipment powered.", price = 360, currency = "SCRAP", accent = "Cyan", badge = "POWER"},
		{title = "POWER CELL", subtitle = "Machines, defenses and reserve power.", price = 420, currency = "SCRAP", accent = "Cyan", badge = "ENERGY"},
		{title = "FLARE PACK", subtitle = "Emergency visibility and signaling.", price = 190, currency = "SCRAP", accent = "Orange", badge = "SIGNAL"},
		{title = "ROPE KIT", subtitle = "General expedition utility kit.", price = 180, currency = "SCRAP", accent = "Orange", badge = "UTILITY"},
		{title = "TOOL REPAIR KIT", subtitle = "Restores damaged gathering tools.", price = 470, currency = "SCRAP", accent = "Slate", badge = "TOOLS"},
		{title = "THERMAL PACK", subtitle = "Preparation for Frozen Wasteland.", price = 760, currency = "SCRAP", accent = "Cyan", badge = "FROZEN"},
		{title = "RADIATION FILTER", subtitle = "Preparation for the Nuclear Zone.", price = 880, currency = "SCRAP", accent = "Toxic", badge = "NUCLEAR"},
		{title = "HEAT SHIELD PACK", subtitle = "Preparation for Volcanic zones.", price = 940, currency = "SCRAP", accent = "Orange", badge = "VOLCANIC"},
		{title = "EMERGENCY BEACON", subtitle = "Emergency return and location signal.", price = 1100, currency = "SCRAP", accent = "Red", badge = "EMERGENCY"},
	},

	Inventory = {
		{name = "Timber", category = "Raw", biome = "Forest / Ruins", amount = 142, stored = 580, rarity = "COMMON", accent = "Green", use = "Basic construction, walls and support structures."},
		{name = "Stone", category = "Raw", biome = "Forest / Ruins", amount = 86, stored = 310, rarity = "COMMON", accent = "Slate", use = "Foundations, fortifications and structure upgrades."},
		{name = "Scrap Metal", category = "Raw", biome = "Ruins", amount = 67, stored = 244, rarity = "COMMON", accent = "Slate", use = "General salvage resource for machines and processing."},
		{name = "Iron Ore", category = "Raw", biome = "Frozen Wasteland", amount = 34, stored = 125, rarity = "UNCOMMON", accent = "Cyan", use = "Smelt into Iron Ingots for stronger construction."},
		{name = "Copper Ore", category = "Raw", biome = "Forest / Ruins", amount = 29, stored = 96, rarity = "UNCOMMON", accent = "Orange", use = "Processed into Copper Wire for power and electronics."},
		{name = "Resin", category = "Raw", biome = "Forest", amount = 19, stored = 72, rarity = "UNCOMMON", accent = "Orange", use = "Adhesives, treated materials and repair production."},
		{name = "Mechanical Parts", category = "Components", biome = "Crafted / Salvaged", amount = 12, stored = 38, rarity = "RARE", accent = "Purple", use = "Machines, doors, production and defense mechanisms."},
		{name = "Power Cell", category = "Supplies", biome = "Crafted / Shop", amount = 4, stored = 18, rarity = "UNCOMMON", accent = "Cyan", use = "Machines, defense systems and Eclipse reserve power."},
		{name = "Repair Kit", category = "Supplies", biome = "Crafted / Shop", amount = 3, stored = 11, rarity = "UNCOMMON", accent = "Green", use = "Repairs damaged base structures."},
		{name = "Field Hatchet", category = "Equipment", biome = "Equipment", amount = 1, stored = 0, rarity = "STANDARD", accent = "Orange", use = "Gathering tool for timber and light salvage."},
		{name = "Salvage Pickaxe", category = "Equipment", biome = "Equipment", amount = 1, stored = 0, rarity = "STANDARD", accent = "Slate", use = "Gathering tool for stone, ore and ruin salvage."},
		{name = "Work Light", category = "Equipment", biome = "Equipment", amount = 1, stored = 2, rarity = "STANDARD", accent = "Gold", use = "Portable light for dark ruins and expeditions."},
	},

	Market = {
		{name = "Iron Ore", title = "Iron Ore x50", seller = "FrostRunner", price = 420, accent = "Cyan", category = "Raw"},
		{name = "Copper Ore", title = "Copper Ore x40", seller = "Scout_07", price = 390, accent = "Orange", category = "Raw"},
		{name = "Steel Plate", title = "Steel Plate x12", seller = "ForgeLine", price = 620, accent = "Slate", category = "Processed"},
		{name = "Mechanical Parts", title = "Mechanical Parts x10", seller = "Outpost42", price = 780, accent = "Purple", category = "Components"},
		{name = "Power Cell", title = "Power Cell x3", seller = "NorthGate", price = 540, accent = "Cyan", category = "Supplies"},
		{name = "Repair Kit", title = "Repair Kit x4", seller = "BuilderRin", price = 510, accent = "Green", category = "Supplies"},
	},
}

local C = {
	Ink = Color3.fromRGB(25, 31, 42),
	Ink2 = Color3.fromRGB(43, 52, 68),
	Steel = Color3.fromRGB(83, 98, 119),
	Canvas = Color3.fromRGB(237, 242, 246),
	Paper = Color3.fromRGB(251, 252, 253),
	Muted = Color3.fromRGB(105, 117, 134),
	White = Color3.fromRGB(255, 255, 255),
	Cyan = Color3.fromRGB(38, 190, 224),
	Purple = Color3.fromRGB(116, 83, 238),
	Gold = Color3.fromRGB(244, 184, 62),
	Orange = Color3.fromRGB(242, 132, 42),
	Green = Color3.fromRGB(55, 190, 101),
	Red = Color3.fromRGB(231, 63, 78),
	Toxic = Color3.fromRGB(151, 207, 54),
	Slate = Color3.fromRGB(111, 126, 147),
}

local FONT = Enum.Font.GothamBold
local FONT_HEAVY = Enum.Font.GothamBlack
local FONT_PRICE = Enum.Font.FredokaOne

local old = playerGui:FindFirstChild(CONFIG.GuiName)
if old then
	old:Destroy()
end

local function create(className, props, parent)
	local object = Instance.new(className)
	for key, value in pairs(props or {}) do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function round(parent, radius)
	-- Deliberately square: Eclipse now uses hard rectangular survivor-tech panels.
	return create("UICorner", {CornerRadius = UDim.new(0, 0)}, parent)
end

local function stroke(parent, color, thickness, transparency)
	return create("UIStroke", {
		Color = color or C.Ink,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

local function pad(parent, l, r, t, b)
	return create("UIPadding", {
		PaddingLeft = UDim.new(0, l or 0),
		PaddingRight = UDim.new(0, r or l or 0),
		PaddingTop = UDim.new(0, t or l or 0),
		PaddingBottom = UDim.new(0, b or t or l or 0),
	}, parent)
end

local function gradient(parent, a, b, rotation)
	return create("UIGradient", {
		Color = ColorSequence.new(a, b),
		Rotation = rotation or 0,
	}, parent)
end

local function label(parent, text, size, position, textSize, color, align, font)
	return create("TextLabel", {
		BackgroundTransparency = 1,
		Size = size,
		Position = position or UDim2.fromOffset(0, 0),
		Text = text,
		Font = font or FONT,
		TextSize = textSize or 16,
		TextColor3 = color or C.Ink,
		TextXAlignment = align or Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, parent)
end

local function button(parent, text, size, position, bg, fg)
	local b = create("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = bg or C.Ink,
		Size = size,
		Position = position or UDim2.fromOffset(0, 0),
		Text = text,
		Font = FONT_HEAVY,
		TextSize = 15,
		TextColor3 = fg or C.White,
	}, parent)
	round(b, 10)
	stroke(b, C.Ink, 2)

	b:SetAttribute("BaseColor", b.BackgroundColor3)
	b.MouseEnter:Connect(function()
		local baseColor = b:GetAttribute("BaseColor") or b.BackgroundColor3
		TweenService:Create(b, TweenInfo.new(0.1), {BackgroundColor3 = baseColor:Lerp(C.White, 0.12)}):Play()
	end)
	b.MouseLeave:Connect(function()
		local baseColor = b:GetAttribute("BaseColor") or b.BackgroundColor3
		TweenService:Create(b, TweenInfo.new(0.1), {BackgroundColor3 = baseColor}):Play()
	end)
	b.MouseButton1Down:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.06), {Rotation = -1}):Play()
	end)
	b.MouseButton1Up:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.08), {Rotation = 0}):Play()
	end)
	return b
end

local function compactNumber(n)
	if n >= 1000000 then
		return string.format("%.1fM", n / 1000000)
	elseif n >= 1000 then
		return string.format("%.1fK", n / 1000)
	end
	return tostring(n)
end

local gui = create("ScreenGui", {
	Name = CONFIG.GuiName,
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	DisplayOrder = 80,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

-- Soft modal dim. This keeps the world visible, like a polished simulator menu,
-- while the inner surfaces stay original to Eclipse.
local dim = create("TextButton", {
	Name = "ModalDim",
	AutoButtonColor = false,
	BackgroundColor3 = Color3.fromRGB(4, 9, 15),
	BackgroundTransparency = 0.28,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
	Text = "",
	Visible = false,
}, gui)

local window = create("Frame", {
	Name = "Window",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(1030, 590),
	BackgroundColor3 = C.Canvas,
	BorderSizePixel = 0,
}, dim)
round(window, 18)
stroke(window, C.Ink, 4)

local scaler = create("UIScale", {Scale = 1}, window)

local function updateScale()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local v = camera.ViewportSize
	-- Target canvas is roughly 1120 x 690. This also fits landscape phones/tablets.
	scaler.Scale = math.clamp(math.min(v.X / 1120, v.Y / 690), 0.34, 1)
end


updateScale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	updateScale()
end)

local shadow = create("Frame", {
	Name = "Shadow",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 9, 0.5, 12),
	Size = UDim2.new(1, 8, 1, 10),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.58,
	BorderSizePixel = 0,
	ZIndex = 0,
}, window)
round(shadow, 20)

local header = create("Frame", {
	Name = "Header",
	Size = UDim2.new(1, 0, 0, 92),
	BackgroundColor3 = C.Ink,
	BorderSizePixel = 0,
}, window)
round(header, 15)
gradient(header, Color3.fromRGB(36, 45, 61), Color3.fromRGB(21, 27, 38), 0)

-- Cover the lower rounded corners of the header.
create("Frame", {
	Size = UDim2.new(1, 0, 0, 20),
	Position = UDim2.new(0, 0, 1, -20),
	BackgroundColor3 = Color3.fromRGB(25, 32, 44),
	BorderSizePixel = 0,
}, header)

local titleIcon = create("TextLabel", {
	Size = UDim2.fromOffset(64, 64),
	Position = UDim2.fromOffset(20, 14),
	BackgroundColor3 = C.Cyan,
	Text = "E",
	Font = FONT_HEAVY,
	TextSize = 32,
	TextColor3 = C.White,
}, header)
round(titleIcon, 14)
stroke(titleIcon, C.White, 2, 0.15)

local title = label(header, "INVENTORY", UDim2.fromOffset(420, 40), UDim2.fromOffset(100, 13), 28, C.White, Enum.TextXAlignment.Left, FONT_HEAVY)
local kicker = label(header, "ECLIPSE // SURVIVOR SYSTEM", UDim2.fromOffset(480, 24), UDim2.fromOffset(101, 52), 12, Color3.fromRGB(163, 181, 203), Enum.TextXAlignment.Left, FONT)

local currency = create("Frame", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -92, 0.5, 0),
	Size = UDim2.fromOffset(200, 46),
	BackgroundColor3 = Color3.fromRGB(48, 57, 70),
	BorderSizePixel = 0,
}, header)
round(currency, 12)
stroke(currency, C.Gold, 2)
local coin = create("TextLabel", {
	Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(7, 6),
	BackgroundColor3 = C.Gold, Text = "S", Font = FONT_HEAVY, TextSize = 18, TextColor3 = C.Ink,
}, currency)
round(coin, 17)
label(currency, compactNumber(CONFIG.CurrencyAmount), UDim2.fromOffset(94, 28), UDim2.fromOffset(50, 3), 19, C.White, Enum.TextXAlignment.Left, FONT_HEAVY)
label(currency, CONFIG.CurrencyName, UDim2.fromOffset(110, 18), UDim2.fromOffset(50, 25), 10, Color3.fromRGB(190, 197, 208), Enum.TextXAlignment.Left, FONT)

local close = button(header, "X", UDim2.fromOffset(58, 58), UDim2.new(1, -72, 0, 17), C.Red, C.White)
close.TextSize = 23
stroke(close, C.White, 3)

local content = create("Frame", {
	Name = "Content",
	Position = UDim2.fromOffset(18, 108),
	Size = UDim2.new(1, -36, 1, -126),
	BackgroundTransparency = 1,
}, window)

local toast = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -18),
	Size = UDim2.fromOffset(500, 42),
	BackgroundColor3 = C.Ink,
	BackgroundTransparency = 1,
	TextTransparency = 1,
	Text = "",
	Font = FONT,
	TextSize = 14,
	TextColor3 = C.White,
	ZIndex = 100,
	Visible = false,
}, gui)
round(toast, 11)
stroke(toast, C.Cyan, 2)

local toastToken = 0
local function showToast(message, accent)
	toastToken = toastToken + 1
	local token = toastToken
	toast.Text = message
	toast.Visible = true
	toast.BackgroundTransparency = 0.08
	toast.TextTransparency = 0
	local s = toast:FindFirstChildOfClass("UIStroke")
	if s then s.Color = accent or C.Cyan end
	task.delay(2.25, function()
		if token ~= toastToken then return end
		local tw = TweenService:Create(toast, TweenInfo.new(0.18), {BackgroundTransparency = 1, TextTransparency = 1})
		tw:Play()
		tw.Completed:Wait()
		if token == toastToken then toast.Visible = false end
	end)
end

local function promptRobuxPurchase(item)
	local purchaseType = item.purchaseType or item.PurchaseType
	local purchaseId = tonumber(item.purchaseId or item.PurchaseId) or 0

	if purchaseId <= 0 then
		showToast("SETUP // Vul eerst de echte Game Pass ID in bij PurchaseId.", C.Red)
		return
	end

	if purchaseType == "GamePass" then
		local ownsOk, alreadyOwns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, purchaseId)
		end)
		if ownsOk and alreadyOwns then
			showToast("OWNED // Deze upgrade staat al op je account.", C.Green)
			return
		end

		local ok = pcall(function()
			MarketplaceService:PromptGamePassPurchase(player, purchaseId)
		end)
		if not ok then
			showToast("ROBLOX // Purchase prompt kon niet worden geopend.", C.Red)
		end
	elseif purchaseType == "DeveloperProduct" then
		local ok = pcall(function()
			MarketplaceService:PromptProductPurchase(player, purchaseId)
		end)
		if not ok then
			showToast("ROBLOX // Purchase prompt kon niet worden geopend.", C.Red)
		end
	else
		showToast("SETUP // PurchaseType moet GamePass of DeveloperProduct zijn.", C.Red)
	end
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(who, gamePassId, wasPurchased)
	if who ~= player then return end
	if wasPurchased then
		showToast("PURCHASE COMPLETE // Roblox heeft de Game Pass bevestigd.", C.Green)
	else
		-- Roblox' eigen prompt shows the exact reason, including insufficient Robux.
		showToast("PURCHASE NOT COMPLETED // Bekijk de Roblox-melding voor de reden.", C.Muted)
	end
end)

MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, wasPurchased)
	if userId ~= player.UserId then return end
	if wasPurchased then
		-- Developer Product rewards still belong in a server-side ProcessReceipt handler.
		showToast("PAYMENT SENT // Server verwerkt nu de aankoop.", C.Green)
	else
		showToast("PURCHASE NOT COMPLETED // Bekijk de Roblox-melding voor de reden.", C.Muted)
	end
end)

local function ACTION(actionName, payload)
	-- Replace this demo handler with your own RemoteEvent calls.
	-- Example: ReplicatedStorage.EclipseRemotes.RequestSupplyPurchase:FireServer(payload.id)
	print("[Eclipse UI]", actionName, payload and payload.title or payload and payload.name or "")
	showToast("DEMO // " .. actionName .. " is nog niet aan je server gekoppeld.", C.Gold)
end

local function clearContent()
	for _, child in ipairs(content:GetChildren()) do
		child:Destroy()
	end
end

local function section(parent, size, position, background)
	local f = create("Frame", {
		Size = size,
		Position = position or UDim2.fromOffset(0, 0),
		BackgroundColor3 = background or C.Paper,
		BorderSizePixel = 0,
	}, parent)
	round(f, 14)
	stroke(f, C.Ink, 2)
	return f
end

local function chip(parent, text, color, size, position)
	local ch = create("TextLabel", {
		Size = size or UDim2.fromOffset(88, 24),
		Position = position or UDim2.fromOffset(0, 0),
		BackgroundColor3 = color,
		Text = text,
		TextColor3 = C.White,
		Font = FONT_HEAVY,
		TextSize = 10,
		BorderSizePixel = 0,
	}, parent)
	round(ch, 8)
	return ch
end

local function searchBox(parent, placeholder, position, size)
	local shell = create("Frame", {
		Position = position,
		Size = size,
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
	}, parent)
	round(shell, 12)
	stroke(shell, C.Ink, 2)
	label(shell, "?", UDim2.fromOffset(34, 34), UDim2.fromOffset(8, 3), 17, C.Muted, Enum.TextXAlignment.Center, FONT_HEAVY)
	local box = create("TextBox", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(46, 0),
		Size = UDim2.new(1, -56, 1, 0),
		ClearTextOnFocus = false,
		PlaceholderText = placeholder or "Search",
		PlaceholderColor3 = Color3.fromRGB(153, 162, 176),
		Text = "",
		TextColor3 = C.Ink,
		TextSize = 15,
		Font = FONT,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, shell)
	return box
end

local function robuxLogoContent()
	local id = tonumber(CONFIG.RobuxLogoAssetId) or 0
	if id <= 0 then
		return ""
	end
	return "rbxassetid://" .. tostring(id)
end

local function robuxPrice(parent, price, size, position, color)
	local holder = create("Frame", {
		Size = size,
		Position = position or UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
	}, parent)
	local logoContent = robuxLogoContent()
	if logoContent ~= "" then
		create("ImageLabel", {
			Size = UDim2.fromOffset(24, 24),
			Position = UDim2.fromOffset(0, 2),
			BackgroundTransparency = 1,
			Image = logoContent,
			ImageColor3 = color or C.Green,
			ScaleType = Enum.ScaleType.Fit,
		}, holder)
	else
		label(holder, "R$", UDim2.fromOffset(26, 26), UDim2.fromOffset(0, 1), 11, color or C.Green, Enum.TextXAlignment.Center, FONT_HEAVY)
	end
	label(holder, tostring(price), UDim2.new(1, -30, 1, 0), UDim2.fromOffset(30, 0), 19, color or C.Green, Enum.TextXAlignment.Left, FONT_HEAVY)
	return holder
end

local function robuxBuyButton(parent, price, size, position, callback)
	local shadowPosition = UDim2.new(
		position.X.Scale, position.X.Offset,
		position.Y.Scale, position.Y.Offset + 6
	)
	local shadow = create("Frame", {
		Size = size,
		Position = shadowPosition,
		BackgroundColor3 = Color3.fromRGB(39, 82, 13),
		BorderSizePixel = 0,
	}, parent)
	create("UICorner", {CornerRadius = UDim.new(0, 9)}, shadow)

	local buy = button(parent, "", size, position, Color3.fromRGB(103, 232, 8), C.White)
	local buyCorner = buy:FindFirstChildOfClass("UICorner")
	if buyCorner then
		buyCorner.CornerRadius = UDim.new(0, 9)
	end
	local buyStroke = buy:FindFirstChildOfClass("UIStroke")
	if buyStroke then
		buyStroke.Color = Color3.fromRGB(42, 73, 17)
		buyStroke.Thickness = 4
		buyStroke.Transparency = 0
	end
	gradient(buy, Color3.fromRGB(126, 247, 18), Color3.fromRGB(79, 215, 4), 90)

	local iconSlot = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(46, 44),
		BackgroundColor3 = Color3.fromRGB(44, 104, 16),
		BorderSizePixel = 0,
	}, buy)
	create("UICorner", {CornerRadius = UDim.new(0, 6)}, iconSlot)
	create("UIStroke", {Color=Color3.fromRGB(36, 74, 15), Thickness=2, Transparency=0}, iconSlot)
	gradient(iconSlot, Color3.fromRGB(56, 128, 18), Color3.fromRGB(35, 87, 13), 90)

	local logoContent = robuxLogoContent()
	if logoContent ~= "" then
		create("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(35, 35),
			BackgroundTransparency = 1,
			Image = logoContent,
			ImageColor3 = Color3.fromRGB(113, 232, 37),
			ScaleType = Enum.ScaleType.Fit,
		}, iconSlot)
	else
		label(iconSlot, "R$", UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), 17, C.White, Enum.TextXAlignment.Center, FONT_HEAVY)
	end
	local priceLabel = label(buy, tostring(price), UDim2.new(1, -70, 1, 0), UDim2.fromOffset(64, 0), 31, C.White, Enum.TextXAlignment.Center, FONT_PRICE)
	create("UIStroke", {
		Color = Color3.fromRGB(31, 35, 29),
		Thickness = 3.25,
		Transparency = 0,
	}, priceLabel)
	buy.MouseButton1Click:Connect(callback)
	return buy
end

-- Creates original 3D inventory thumbnails entirely in code.
-- No external image assets are required for these material icons.
local function itemViewport(parent, item, size, position)
	local accent = C[item.accent] or C.Purple
	local viewport = create("ViewportFrame", {
		Size = size,
		Position = position or UDim2.fromOffset(0, 0),
		BackgroundColor3 = accent:Lerp(C.White, 0.78),
		BorderSizePixel = 0,
		Ambient = Color3.fromRGB(185, 190, 205),
		LightColor = Color3.fromRGB(255, 250, 236),
		LightDirection = Vector3.new(-1, -1, -1),
	}, parent)
	round(viewport, 10)

	local world = create("WorldModel", {}, viewport)
	local camera = create("Camera", {
		FieldOfView = 28,
		CFrame = CFrame.lookAt(Vector3.new(4.2, 3.1, 5.8), Vector3.new(0, 0, 0)),
	}, viewport)
	viewport.CurrentCamera = camera

	local function part(partSize, color, cf, material, shape, className)
		local p = Instance.new(className or "Part")
		p.Anchored = true
		p.CanCollide = false
		p.CastShadow = false
		p.Size = partSize
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.CFrame = cf or CFrame.new()
		if p:IsA("Part") and shape then
			p.Shape = shape
		end
		p.Parent = world
		return p
	end

	local name = string.lower(item.name or item.title or "")

	if name == "wood" or name == "timber" then
		local wood = Color3.fromRGB(137, 79, 42)
		local cut = Color3.fromRGB(225, 170, 99)
		for i, y in ipairs({-0.42, 0.08, 0.58}) do
			local z = (i % 2 == 0) and 0.14 or -0.08
			part(Vector3.new(1.65, 0.48, 0.48), wood, CFrame.new(0, y, z) * CFrame.Angles(0, 0, math.rad((i-2)*5)), Enum.Material.Wood, Enum.PartType.Cylinder)
			part(Vector3.new(0.045, 0.42, 0.42), cut, CFrame.new(0.83, y, z) * CFrame.Angles(0, 0, math.rad((i-2)*5)), Enum.Material.Wood, Enum.PartType.Cylinder)
		end
	elseif name == "stone" then
		local rock = Color3.fromRGB(116, 126, 139)
		part(Vector3.new(1.25, 1.0, 1.05), rock, CFrame.new(-0.35, -0.15, 0), Enum.Material.Slate, Enum.PartType.Ball)
		part(Vector3.new(0.9, 0.78, 0.8), rock:Lerp(C.White, 0.12), CFrame.new(0.48, -0.32, 0.12), Enum.Material.Slate, Enum.PartType.Ball)
		part(Vector3.new(0.68, 0.63, 0.62), rock:Lerp(C.Ink, 0.08), CFrame.new(0.22, 0.42, -0.08), Enum.Material.Slate, Enum.PartType.Ball)
	elseif name == "scrap metal" then
		local rust = Color3.fromRGB(118, 91, 73)
		local metal = Color3.fromRGB(104, 113, 124)
		part(Vector3.new(1.55, 0.24, 0.82), metal, CFrame.new(-0.12, -0.28, 0) * CFrame.Angles(0, math.rad(18), math.rad(-10)), Enum.Material.Metal)
		part(Vector3.new(1.18, 0.22, 0.72), rust, CFrame.new(0.18, 0.08, 0.05) * CFrame.Angles(0, math.rad(-14), math.rad(14)), Enum.Material.CorrodedMetal)
		part(Vector3.new(0.82, 0.18, 0.64), metal:Lerp(C.White, 0.1), CFrame.new(-0.25, 0.42, -0.05) * CFrame.Angles(0, math.rad(9), math.rad(-18)), Enum.Material.Metal)
	elseif name == "iron ore" then
		local rock = Color3.fromRGB(87, 96, 108)
		local ore = Color3.fromRGB(170, 181, 193)
		part(Vector3.new(1.35, 1.05, 1.0), rock, CFrame.new(-0.2, -0.12, 0), Enum.Material.Slate, Enum.PartType.Ball)
		part(Vector3.new(0.5, 0.48, 0.42), ore, CFrame.new(0.38, 0.18, 0.42), Enum.Material.Metal, Enum.PartType.Ball)
		part(Vector3.new(0.34, 0.3, 0.3), ore:Lerp(C.White, 0.18), CFrame.new(-0.35, -0.15, 0.53), Enum.Material.Metal, Enum.PartType.Ball)
	elseif name == "copper ore" then
		local rock = Color3.fromRGB(92, 83, 76)
		local copper = Color3.fromRGB(205, 117, 58)
		part(Vector3.new(1.35, 1.05, 1.0), rock, CFrame.new(-0.15, -0.1, 0), Enum.Material.Slate, Enum.PartType.Ball)
		part(Vector3.new(0.48, 0.43, 0.4), copper, CFrame.new(0.4, 0.12, 0.42), Enum.Material.Metal, Enum.PartType.Ball)
		part(Vector3.new(0.3, 0.32, 0.28), copper:Lerp(C.Gold, 0.2), CFrame.new(-0.32, -0.22, 0.52), Enum.Material.Metal, Enum.PartType.Ball)
	elseif name == "iron" then
		local metal = Color3.fromRGB(145, 158, 174)
		for i = -1, 1 do
			part(Vector3.new(1.45, 0.34, 0.62), metal:Lerp(C.White, (i+1)*0.05), CFrame.new(0, i*0.38, 0) * CFrame.Angles(0, math.rad(-12), math.rad(i*3)), Enum.Material.Metal)
		end
	elseif name == "steel plate" then
		local steel = Color3.fromRGB(133, 148, 164)
		for i = -1, 1 do
			part(Vector3.new(1.55, 0.24, 0.86), steel:Lerp(C.White, (i+1)*0.04), CFrame.new(0, i*0.32, 0) * CFrame.Angles(0, math.rad(-10), math.rad(i*2)), Enum.Material.Metal)
		end
	elseif name == "resin" then
		part(Vector3.new(1.18, 1.18, 1.18), Color3.fromRGB(236, 129, 24), CFrame.new(0, -0.12, 0), Enum.Material.Glass, Enum.PartType.Ball)
		part(Vector3.new(0.55, 0.22, 0.55), Color3.fromRGB(70, 82, 91), CFrame.new(0, 0.62, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Metal, Enum.PartType.Cylinder)
	elseif name == "mech parts" or name == "mechanical parts" then
		local metal = Color3.fromRGB(102, 112, 128)
		part(Vector3.new(0.55, 1.35, 0.55), metal, CFrame.new(), Enum.Material.Metal, Enum.PartType.Cylinder)
		part(Vector3.new(1.55, 0.25, 0.35), metal, CFrame.new(), Enum.Material.Metal)
		part(Vector3.new(0.25, 1.55, 0.35), metal, CFrame.new(), Enum.Material.Metal)
		part(Vector3.new(0.52, 0.52, 0.52), C.Purple, CFrame.new(0, 0, -0.24), Enum.Material.Neon, Enum.PartType.Ball)
	elseif name == "power cell" then
		part(Vector3.new(1.55, 0.78, 0.78), Color3.fromRGB(56, 66, 78), CFrame.new() * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Metal, Enum.PartType.Cylinder)
		part(Vector3.new(0.82, 0.83, 0.83), C.Cyan, CFrame.new() * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Neon, Enum.PartType.Cylinder)
	elseif name == "repair kit" then
		part(Vector3.new(1.5, 1.05, 0.62), Color3.fromRGB(205, 55, 55), CFrame.new(0, -0.05, 0), Enum.Material.SmoothPlastic)
		part(Vector3.new(0.26, 0.72, 0.08), C.White, CFrame.new(0, -0.05, 0.35), Enum.Material.SmoothPlastic)
		part(Vector3.new(0.72, 0.26, 0.08), C.White, CFrame.new(0, -0.05, 0.35), Enum.Material.SmoothPlastic)
		part(Vector3.new(0.7, 0.16, 0.16), C.Ink, CFrame.new(0, 0.62, 0), Enum.Material.Metal)
	elseif name == "field hatchet" then
		part(Vector3.new(0.26, 1.95, 0.28), Color3.fromRGB(120, 73, 43), CFrame.new(0, -0.15, 0) * CFrame.Angles(0, 0, math.rad(-28)), Enum.Material.Wood)
		part(Vector3.new(0.78, 0.62, 0.28), Color3.fromRGB(166, 177, 188), CFrame.new(-0.34, 0.66, 0), Enum.Material.Metal, nil, "WedgePart")
	elseif name == "salvage pickaxe" then
		part(Vector3.new(0.22, 2.05, 0.24), Color3.fromRGB(105, 70, 45), CFrame.new(0, -0.14, 0) * CFrame.Angles(0, 0, math.rad(30)), Enum.Material.Wood)
		part(Vector3.new(1.55, 0.24, 0.3), Color3.fromRGB(154, 165, 178), CFrame.new(-0.32, 0.66, 0) * CFrame.Angles(0, 0, math.rad(-6)), Enum.Material.Metal)
		part(Vector3.new(0.34, 0.48, 0.3), Color3.fromRGB(110, 120, 132), CFrame.new(0.47, 0.61, 0), Enum.Material.Metal, nil, "WedgePart")
	elseif name == "work light" then
		part(Vector3.new(1.35, 1.05, 0.48), Color3.fromRGB(53, 62, 73), CFrame.new(0, 0, 0), Enum.Material.Metal)
		part(Vector3.new(0.88, 0.62, 0.08), Color3.fromRGB(255, 213, 76), CFrame.new(0, 0.08, 0.29), Enum.Material.Neon)
		part(Vector3.new(0.9, 0.18, 0.18), C.Ink, CFrame.new(0, -0.72, 0), Enum.Material.Metal)
	elseif name == "nuclear fiber" then
		for i = -1, 1 do
			part(Vector3.new(0.28, 1.65, 0.28), C.Toxic:Lerp(C.White, (i+1)*0.08), CFrame.new(i*0.42, 0, 0) * CFrame.Angles(0, 0, math.rad(i*14)), Enum.Material.Neon, Enum.PartType.Cylinder)
		end
		part(Vector3.new(1.45, 0.18, 0.2), C.Ink2, CFrame.new(0, -0.55, 0), Enum.Material.Metal)
	elseif name == "field radio" then
		part(Vector3.new(1.45, 1.15, 0.55), Color3.fromRGB(52, 65, 77), CFrame.new(0, -0.08, 0), Enum.Material.Metal)
		part(Vector3.new(0.76, 0.4, 0.07), C.Cyan, CFrame.new(-0.18, 0.08, 0.31), Enum.Material.Neon)
		part(Vector3.new(0.18, 0.18, 0.1), C.Gold, CFrame.new(0.5, 0.18, 0.34), Enum.Material.Metal, Enum.PartType.Cylinder)
		part(Vector3.new(0.09, 1.2, 0.09), C.Ink, CFrame.new(0.56, 0.9, 0), Enum.Material.Metal)
	elseif name == "extra storage" then
		part(Vector3.new(1.55, 1.05, 0.9), Color3.fromRGB(78, 59, 173), CFrame.new(0, -0.08, 0), Enum.Material.Metal)
		part(Vector3.new(1.62, 0.12, 0.96), C.Ink2, CFrame.new(0, 0.25, 0), Enum.Material.Metal)
		part(Vector3.new(0.32, 0.34, 0.08), C.Gold, CFrame.new(0, 0.02, 0.49), Enum.Material.Metal)
	elseif name == "haven supporter" then
		part(Vector3.new(1.35, 1.35, 0.32), C.Gold, CFrame.new(), Enum.Material.Metal)
		part(Vector3.new(0.75, 0.75, 0.08), C.Cyan, CFrame.new(0, 0, 0.2) * CFrame.Angles(0, 0, math.rad(45)), Enum.Material.Neon)
		part(Vector3.new(0.3, 0.3, 0.08), C.White, CFrame.new(0, 0, 0.26), Enum.Material.Neon, Enum.PartType.Ball)
	elseif name == "gear skin pack" then
		part(Vector3.new(1.55, 1.05, 0.62), Color3.fromRGB(220, 92, 28), CFrame.new(0, -0.06, 0), Enum.Material.Metal)
		part(Vector3.new(0.24, 1.12, 0.08), C.Cyan, CFrame.new(-0.34, -0.06, 0.36), Enum.Material.Neon)
		part(Vector3.new(0.24, 1.12, 0.08), C.Purple, CFrame.new(0.12, -0.06, 0.36), Enum.Material.Neon)
		part(Vector3.new(0.64, 0.14, 0.14), C.Ink, CFrame.new(0, 0.62, 0), Enum.Material.Metal)
	elseif name == "emergency medkit" then
		part(Vector3.new(1.5, 1.05, 0.62), Color3.fromRGB(219, 65, 74), CFrame.new(0, -0.05, 0), Enum.Material.SmoothPlastic)
		part(Vector3.new(0.25, 0.72, 0.08), C.White, CFrame.new(0, -0.05, 0.35), Enum.Material.SmoothPlastic)
		part(Vector3.new(0.72, 0.25, 0.08), C.White, CFrame.new(0, -0.05, 0.35), Enum.Material.SmoothPlastic)
		part(Vector3.new(0.72, 0.15, 0.15), C.Ink, CFrame.new(0, 0.61, 0), Enum.Material.Metal)
	elseif name == "field rations" then
		part(Vector3.new(1.48, 1.05, 0.58), Color3.fromRGB(91, 112, 68), CFrame.new(), Enum.Material.Fabric)
		part(Vector3.new(1.12, 0.16, 0.08), C.Gold, CFrame.new(0, 0.14, 0.34), Enum.Material.SmoothPlastic)
		part(Vector3.new(0.78, 0.13, 0.08), C.White, CFrame.new(-0.14, -0.16, 0.34), Enum.Material.SmoothPlastic)
	elseif name == "portable battery" then
		part(Vector3.new(1.25, 1.3, 0.58), C.Ink2, CFrame.new(), Enum.Material.Metal)
		part(Vector3.new(0.72, 0.72, 0.08), C.Cyan, CFrame.new(0, 0.03, 0.34), Enum.Material.Neon)
		part(Vector3.new(0.42, 0.15, 0.26), C.Slate, CFrame.new(0, 0.73, 0), Enum.Material.Metal)
	elseif name == "flare pack" then
		for i = -1, 1 do
			part(Vector3.new(1.55, 0.32, 0.32), Color3.fromRGB(223, 72, 45), CFrame.new(i*0.4, 0, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		end
		part(Vector3.new(1.35, 0.2, 0.24), C.Ink2, CFrame.new(0, -0.35, 0.18), Enum.Material.Fabric)
	elseif name == "rope bundle" or name == "rope kit" then
		local rope = Color3.fromRGB(190, 139, 70)
		for i = -1, 1 do
			part(Vector3.new(1.45, 0.22, 0.22), rope, CFrame.new(0, i*0.3, i*0.04) * CFrame.Angles(0, 0, math.rad(i*7)), Enum.Material.Fabric, Enum.PartType.Cylinder)
		end
		part(Vector3.new(0.22, 1.22, 0.22), C.Ink2, CFrame.new(0, 0, 0), Enum.Material.Fabric)
	elseif name == "tool repair kit" then
		part(Vector3.new(1.5, 1.02, 0.58), Color3.fromRGB(219, 121, 35), CFrame.new(), Enum.Material.Metal)
		part(Vector3.new(1.0, 0.16, 0.08), C.Ink2, CFrame.new(0, 0.18, 0.34) * CFrame.Angles(0, 0, math.rad(-25)), Enum.Material.Metal)
		part(Vector3.new(0.28, 0.28, 0.08), C.White, CFrame.new(0.34, -0.16, 0.34), Enum.Material.Metal, Enum.PartType.Ball)
	elseif name == "thermal pack" then
		part(Vector3.new(1.45, 1.12, 0.62), Color3.fromRGB(74, 120, 166), CFrame.new(), Enum.Material.Fabric)
		part(Vector3.new(0.2, 1.18, 0.08), C.Cyan, CFrame.new(-0.3, 0, 0.36), Enum.Material.Neon)
		part(Vector3.new(0.2, 1.18, 0.08), C.White, CFrame.new(0.25, 0, 0.36), Enum.Material.Neon)
	elseif name == "radiation filter" then
		part(Vector3.new(1.15, 1.0, 1.0), Color3.fromRGB(62, 73, 64), CFrame.new(), Enum.Material.Metal, Enum.PartType.Cylinder)
		part(Vector3.new(0.5, 1.08, 0.5), C.Toxic, CFrame.new() * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Neon, Enum.PartType.Cylinder)
		part(Vector3.new(0.24, 0.24, 0.08), C.Ink, CFrame.new(0, 0, 0.56), Enum.Material.Metal, Enum.PartType.Ball)
	elseif name == "heat shield pack" then
		part(Vector3.new(1.45, 1.22, 0.36), Color3.fromRGB(138, 67, 36), CFrame.new(), Enum.Material.Metal)
		part(Vector3.new(1.0, 0.82, 0.08), C.Orange, CFrame.new(0, 0, 0.22), Enum.Material.Neon)
		part(Vector3.new(0.28, 0.86, 0.08), C.Gold, CFrame.new(0, 0, 0.28), Enum.Material.Neon)
	elseif name == "emergency beacon" then
		part(Vector3.new(0.7, 1.28, 0.7), C.Ink2, CFrame.new(0, -0.12, 0), Enum.Material.Metal)
		part(Vector3.new(0.74, 0.54, 0.74), C.Red, CFrame.new(0, 0.48, 0), Enum.Material.Neon)
		part(Vector3.new(1.25, 0.18, 0.62), Color3.fromRGB(64, 72, 84), CFrame.new(0, -0.8, 0), Enum.Material.Metal)
	elseif name == "parts crate" then
		part(Vector3.new(1.55, 1.15, 0.78), Color3.fromRGB(177, 111, 38), CFrame.new(), Enum.Material.WoodPlanks)
		part(Vector3.new(1.62, 0.14, 0.84), C.Ink2, CFrame.new(0, 0.34, 0), Enum.Material.Metal)
		part(Vector3.new(0.14, 1.22, 0.84), C.Ink2, CFrame.new(0, 0, 0), Enum.Material.Metal)
		part(Vector3.new(0.32, 0.32, 0.08), C.Cyan, CFrame.new(0.34, -0.14, 0.43), Enum.Material.Neon, Enum.PartType.Ball)
	elseif name == "arrival nameplate" then
		part(Vector3.new(1.65, 0.92, 0.22), C.Ink2, CFrame.new(), Enum.Material.Metal)
		part(Vector3.new(1.35, 0.12, 0.08), C.Purple, CFrame.new(0, 0.23, 0.16), Enum.Material.Neon)
		part(Vector3.new(0.92, 0.12, 0.08), C.White, CFrame.new(-0.12, -0.06, 0.16), Enum.Material.Neon)
		part(Vector3.new(0.26, 0.26, 0.08), C.Cyan, CFrame.new(0.55, -0.22, 0.16), Enum.Material.Neon, Enum.PartType.Ball)
	else
		part(Vector3.new(1.15, 1.15, 1.15), accent, CFrame.new(), Enum.Material.SmoothPlastic)
		part(Vector3.new(0.52, 0.52, 0.08), C.White, CFrame.new(0, 0, -0.62), Enum.Material.Neon)
	end

	return viewport
end

local function card(parent, item, cardSize)
	local accent = C[item.accent] or C.Cyan
	local f = create("Frame", {
		Size = cardSize or UDim2.fromOffset(222, 285),
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
	}, parent)
	round(f, 13)
	stroke(f, C.Ink, 2.5)

	local visual = create("Frame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 0, 106),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
	}, f)
	round(visual, 10)
	gradient(visual, accent:Lerp(C.White, 0.18), accent:Lerp(C.Ink, 0.18), 35)
	itemViewport(visual, item, UDim2.fromOffset(82, 82), UDim2.new(0.5, -41, 0.5, -41))
	if item.badge then
		chip(visual, item.badge, C.Ink, UDim2.fromOffset(82, 21), UDim2.new(1, -90, 0, 8))
	end

	label(f, item.title, UDim2.new(1, -22, 0, 24), UDim2.fromOffset(12, 126), 15, C.Ink, Enum.TextXAlignment.Left, FONT_HEAVY)
	local desc = label(f, item.subtitle or "", UDim2.new(1, -22, 0, 42), UDim2.fromOffset(12, 151), 11, C.Muted, Enum.TextXAlignment.Left, FONT)
	desc.TextWrapped = true
	desc.TextYAlignment = Enum.TextYAlignment.Top

	if item.currency == "R$" then
		local promo = label(f, item.buttonTopText or "DIRECT PURCHASE", UDim2.new(1, -22, 0, 22), UDim2.fromOffset(11, 191), 11, C.Gold, Enum.TextXAlignment.Center, FONT_HEAVY)
		create("UIStroke", {Color=C.Ink, Thickness=1.25, Transparency=0.05}, promo)
		robuxBuyButton(f, item.price, UDim2.new(1, -22, 0, 56), UDim2.fromOffset(11, 216), function()
			promptRobuxPurchase(item)
		end)
		local reward = label(f, item.rewardText or item.title, UDim2.new(1, -22, 0, 25), UDim2.fromOffset(11, 287), 11, C.Ink, Enum.TextXAlignment.Center, FONT_HEAVY)
		create("UIStroke", {Color=C.White, Thickness=1.5, Transparency=0.05}, reward)
	else
		label(f, "S " .. tostring(item.price), UDim2.new(1, -22, 0, 27), UDim2.fromOffset(12, 197), 19, C.Gold, Enum.TextXAlignment.Left, FONT_HEAVY)
		label(f, "SCRAP", UDim2.new(1, -22, 0, 16), UDim2.fromOffset(13, 220), 9, C.Muted, Enum.TextXAlignment.Left, FONT)
		local buy = button(f, "BUY  S " .. tostring(item.price), UDim2.new(1, -22, 0, 38), UDim2.new(0, 11, 1, -49), C.Green, C.White)
		buy.MouseButton1Click:Connect(function()
			ACTION("Buy supply", item)
		end)
	end
	return f
end

local render
local activeScreen = nil

local SCREEN_META = {
	Shop = {title = "SURVIVOR SHOP", kicker = "PREMIUM // DIRECT PURCHASES", icon = "S", accent = C.Purple},
	Offer = {title = "NEW SURVIVOR OFFER", kicker = "ARRIVAL SUPPORT // LIMITED OFFER", icon = "!", accent = C.Orange},
	Marketplace = {title = "MARKETPLACE", kicker = "HAVEN EXCHANGE // PLAYER LISTINGS", icon = "M", accent = C.Cyan},
	Supply = {title = "SUPPLY SHOP", kicker = "HAVEN QUARTERMASTER // SCRAP ONLY", icon = "+", accent = C.Green},
	Inventory = {title = "BACKPACK", kicker = "FIELD INVENTORY // RESOURCE CONTROL", icon = "B", accent = C.Purple},
}

local function setHeader(which)
	local meta = SCREEN_META[which]
	title.Text = meta.title
	kicker.Text = meta.kicker
	titleIcon.Text = meta.icon
	titleIcon.BackgroundColor3 = meta.accent
end

local function renderCardScreen(which, introTitle, introText, items)
	clearContent()
	local meta = SCREEN_META[which]

	local hero = section(content, UDim2.new(1, 0, 0, 78), UDim2.fromOffset(0, 0), meta.accent)
	gradient(hero, meta.accent:Lerp(C.White, 0.08), meta.accent:Lerp(C.Ink, 0.2), 0)
	stroke(hero, C.Ink, 2.5)
	label(hero, introTitle, UDim2.new(1, -32, 0, 30), UDim2.fromOffset(18, 10), 18, C.White, Enum.TextXAlignment.Left, FONT_HEAVY)
	local sub = label(hero, introText, UDim2.new(1, -32, 0, 28), UDim2.fromOffset(18, 40), 11, C.White, Enum.TextXAlignment.Left, FONT)
	sub.TextTransparency = 0.08

	local list = create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 92),
		Size = UDim2.new(1, 0, 1, -92),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = meta.accent,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.fromOffset(0, 0),
	}, content)
	pad(list, 3, 3, 3, 8)
	local layout = create("UIGridLayout", {
		CellSize = UDim2.fromOffset(230, 320),
		CellPadding = UDim2.fromOffset(18, 14),
		FillDirectionMaxCells = 4,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, list)
	for _, item in ipairs(items) do
		card(list, item, UDim2.fromOffset(230, 320))
	end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		list.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 10)
	end)
end

local function renderOffer()
	clearContent()
	local cfg = CONFIG.StarterOffer
	local now = os.time()
	local serverEndsAt = player:GetAttribute(cfg.OfferEndsAtAttribute)
	local studioPreview = RunService:IsStudio() and type(serverEndsAt) ~= "number"
	local offerEndsAt = type(serverEndsAt) == "number" and serverEndsAt or now
	if studioPreview then
		offerEndsAt = now + cfg.StudioPreviewSeconds
	end
	local eligible = offerEndsAt > now and (studioPreview or type(serverEndsAt) == "number")

	local saved = math.max(0, cfg.OriginalPrice - cfg.Price)
	local discount = 0
	if cfg.OriginalPrice > 0 then
		discount = math.floor((saved / cfg.OriginalPrice) * 100 + 0.5)
	end

	local hero = section(content, UDim2.new(1, 0, 0, 104), UDim2.fromOffset(0, 0), C.Orange)
	gradient(hero, Color3.fromRGB(247, 145, 38), Color3.fromRGB(219, 77, 30), 0)
	label(hero, "NEW SURVIVOR DEAL", UDim2.new(1, -320, 0, 35), UDim2.fromOffset(18, 12), 26, C.White, Enum.TextXAlignment.Left, FONT_HEAVY)
	label(hero, "One-time arrival price for brand-new survivors.", UDim2.new(1, -320, 0, 22), UDim2.fromOffset(19, 43), 11, C.White, Enum.TextXAlignment.Left, FONT)
	chip(hero, "NEW PLAYERS ONLY", C.Ink, UDim2.fromOffset(132, 25), UDim2.fromOffset(19, 70))
	chip(hero, "24H FROM FIRST JOIN", Color3.fromRGB(153, 63, 24), UDim2.fromOffset(148, 25), UDim2.fromOffset(159, 70))

	local timerBox = create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 14),
		Size = UDim2.fromOffset(250, 76),
		BackgroundColor3 = C.Ink,
		BorderSizePixel = 0,
	}, hero)
	stroke(timerBox, C.White, 2, 0.15)
	label(timerBox, eligible and "OFFER ENDS IN" or "OFFER STATUS", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 7), 9, Color3.fromRGB(189, 199, 213), Enum.TextXAlignment.Left, FONT_HEAVY)
	local timerLabel = label(timerBox, eligible and "--:--:--" or "NOT ELIGIBLE", UDim2.new(1, -20, 0, 38), UDim2.fromOffset(10, 28), eligible and 24 or 18, C.White, Enum.TextXAlignment.Left, FONT_HEAVY)

	local pack = section(content, UDim2.new(0.65, -6, 0, 348), UDim2.fromOffset(0, 116), C.Paper)
	label(pack, "STARTER RECOVERY PACK", UDim2.new(1, -32, 0, 30), UDim2.fromOffset(16, 13), 19, C.Ink, Enum.TextXAlignment.Left, FONT_HEAVY)
	label(pack, "A fixed bundle for your first expeditions — every reward is shown below.", UDim2.new(1, -32, 0, 22), UDim2.fromOffset(16, 43), 10, C.Muted, Enum.TextXAlignment.Left, FONT)
	label(pack, "INCLUDED", UDim2.new(1, -32, 0, 20), UDim2.fromOffset(16, 76), 9, C.Orange, Enum.TextXAlignment.Left, FONT_HEAVY)

	local function offerItem(x, name, amountText, viewportItem, tileColor)
		local tile = create("Frame", {
			Position = UDim2.fromOffset(x, 101),
			Size = UDim2.fromOffset(140, 174),
			BackgroundColor3 = C.White,
			BorderSizePixel = 0,
		}, pack)
		stroke(tile, C.Ink, 2)

		if viewportItem then
			itemViewport(tile, viewportItem, UDim2.fromOffset(104, 96), UDim2.fromOffset(18, 12))
		else
			local coinTile = create("TextLabel", {
				Position = UDim2.fromOffset(18, 12),
				Size = UDim2.fromOffset(104, 96),
				BackgroundColor3 = tileColor or C.Gold,
				BorderSizePixel = 0,
				Text = "S",
				TextColor3 = C.Ink,
				Font = FONT_HEAVY,
				TextSize = 37,
			}, tile)
			stroke(coinTile, C.Ink, 1.5, 0.2)
		end
		chip(tile, amountText, tileColor or C.Orange, UDim2.fromOffset(48, 22), UDim2.new(1, -55, 0, 17))
		local nm = label(tile, name, UDim2.new(1, -16, 0, 48), UDim2.fromOffset(8, 118), 10, C.Ink, Enum.TextXAlignment.Center, FONT_HEAVY)
		nm.TextWrapped = true
		return tile
	end

	offerItem(16, "SCRAP", "x500", nil, C.Gold)
	offerItem(164, "FIELD HATCHET", "x1", {name="Field Hatchet", accent="Orange"}, C.Orange)
	offerItem(312, "REPAIR KITS", "x3", {name="Repair Kit", accent="Green"}, C.Green)
	offerItem(460, "ARRIVAL NAMEPLATE", "x1", {name="Arrival Nameplate", accent="Purple"}, C.Purple)

	local note = create("Frame", {Position=UDim2.fromOffset(16,289),Size=UDim2.new(1,-32,0,43),BackgroundColor3=Color3.fromRGB(236,240,245),BorderSizePixel=0}, pack)
	label(note, "NEW PLAYER BONUS", UDim2.fromOffset(124,43), UDim2.fromOffset(10,0), 9, C.Orange, Enum.TextXAlignment.Left, FONT_HEAVY)
	label(note, "Available only during your personal arrival window.", UDim2.new(1,-142,1,0), UDim2.fromOffset(136,0), 10, C.Ink, Enum.TextXAlignment.Left, FONT)

	local deal = section(content, UDim2.new(0.35, -6, 0, 348), UDim2.new(0.65, 6, 0, 116), C.White)
	chip(deal, "SAVE " .. tostring(discount) .. "%", C.Red, UDim2.fromOffset(92, 27), UDim2.fromOffset(16, 16))
	label(deal, "NEW PLAYER PRICE", UDim2.new(1, -32, 0, 22), UDim2.fromOffset(16, 54), 10, C.Muted, Enum.TextXAlignment.Left, FONT_HEAVY)
	label(deal, "REGULAR  " .. tostring(cfg.OriginalPrice) .. " ROBUX", UDim2.new(1, -32, 0, 24), UDim2.fromOffset(16, 79), 11, C.Muted, Enum.TextXAlignment.Left, FONT)
	create("Frame", {Position=UDim2.fromOffset(74,91),Size=UDim2.fromOffset(89,2),BackgroundColor3=C.Red,BorderSizePixel=0}, deal)
	robuxPrice(deal, cfg.Price, UDim2.new(1, -32, 0, 32), UDim2.fromOffset(16, 111), C.Green)
	label(deal, "YOU SAVE " .. tostring(saved) .. " ROBUX", UDim2.new(1, -32, 0, 22), UDim2.fromOffset(16, 145), 10, C.Green, Enum.TextXAlignment.Left, FONT_HEAVY)

	local rule = create("Frame", {Position=UDim2.fromOffset(16,181),Size=UDim2.new(1,-32,0,76),BackgroundColor3=Color3.fromRGB(255,239,216),BorderSizePixel=0}, deal)
	stroke(rule, C.Orange, 2)
	label(rule, "NEW SURVIVORS ONLY", UDim2.new(1,-20,0,24), UDim2.fromOffset(10,7), 10, C.Orange, Enum.TextXAlignment.Left, FONT_HEAVY)
	local ruleText = eligible and "Your personal offer window is active." or "This offer is not active for this player."
	local ruleLabel = label(rule, ruleText, UDim2.new(1,-20,0,34), UDim2.fromOffset(10,31), 10, C.Ink, Enum.TextXAlignment.Left, FONT)
	ruleLabel.TextWrapped = true

	local buy
	if eligible then
		buy = robuxBuyButton(deal, cfg.Price, UDim2.new(1, -32, 0, 56), UDim2.new(0, 16, 1, -72), function()
			if os.time() >= offerEndsAt then
				showToast("OFFER EXPIRED // Deze new-player deal is afgelopen.", C.Red)
				return
			end
			promptRobuxPurchase({
				title = "New Survivor Deal",
				purchaseType = cfg.PurchaseType,
				purchaseId = cfg.PurchaseId,
			})
		end)
	else
		buy = button(deal, "OFFER NOT AVAILABLE", UDim2.new(1, -32, 0, 56), UDim2.new(0, 16, 1, -72), C.Slate, C.White)
	end

	task.spawn(function()
		while timerLabel.Parent and eligible do
			local remaining = math.max(0, offerEndsAt - os.time())
			local hours = math.floor(remaining / 3600)
			local minutes = math.floor((remaining % 3600) / 60)
			local seconds = remaining % 60
			timerLabel.Text = string.format("%02d:%02d:%02d", hours, minutes, seconds)
			if remaining <= 0 then
				timerLabel.Text = "EXPIRED"
				timerLabel.TextColor3 = C.Red
				if buy and buy.Parent then
					buy.Active = false
					buy.BackgroundColor3 = C.Slate
				end
				break
			end
			task.wait(1)
		end
	end)
end

local function renderMarketplace()
	clearContent()
	local banner = section(content, UDim2.new(1, 0, 0, 54), UDim2.fromOffset(0, 0), C.Ink2)
	label(banner, "MARKETPLACE FOUNDATION", UDim2.fromOffset(245, 54), UDim2.fromOffset(16, 0), 13, C.White, Enum.TextXAlignment.Left, FONT_HEAVY)
	chip(banner, "PREVIEW", C.Cyan, UDim2.fromOffset(78, 24), UDim2.fromOffset(246, 15))
	label(banner, "Server escrow + listing validation still required.", UDim2.new(1, -350, 1, 0), UDim2.fromOffset(338, 0), 11, Color3.fromRGB(190, 202, 216), Enum.TextXAlignment.Left, FONT)

	local search = searchBox(content, "Search listings...", UDim2.fromOffset(0, 69), UDim2.new(1, -185, 0, 42))
	local refresh = button(content, "REFRESH", UDim2.fromOffset(169, 42), UDim2.new(1, -169, 0, 69), C.Cyan, C.White)
	refresh.MouseButton1Click:Connect(function() ACTION("Refresh listings") end)

	local tabs = create("Frame", {Position=UDim2.fromOffset(0,122),Size=UDim2.new(1,0,0,38),BackgroundTransparency=1}, content)
	local tabNames = {"ALL", "RAW", "PROCESSED", "COMPONENTS", "SUPPLIES", "EQUIPMENT"}
	local tabButtons = {}
	local selectedMarketCategory = "ALL"
	local applyMarketFilters
	local x = 0
	for i, tabName in ipairs(tabNames) do
		local w = i == 1 and 70 or 118
		local tb = button(tabs, tabName, UDim2.fromOffset(w, 34), UDim2.fromOffset(x, 0), i == 1 and C.Cyan or C.White, i == 1 and C.White or C.Ink)
		tb.TextSize = 11
		tabButtons[tabName] = tb
		tb.MouseButton1Click:Connect(function()
			selectedMarketCategory = tabName
			for name, other in pairs(tabButtons) do
				local selected = name == selectedMarketCategory
				local base = selected and C.Cyan or C.White
				other.BackgroundColor3 = base
				other:SetAttribute("BaseColor", base)
				other.TextColor3 = selected and C.White or C.Ink
			end
			if applyMarketFilters then applyMarketFilters() end
		end)
		x = x + w + 8
	end

	local list = create("ScrollingFrame", {
		Position=UDim2.fromOffset(0,166), Size=UDim2.new(1,0,1,-166), BackgroundTransparency=1, BorderSizePixel=0,
		ScrollBarThickness=5, ScrollBarImageColor3=C.Cyan, AutomaticCanvasSize=Enum.AutomaticSize.Y, CanvasSize=UDim2.fromOffset(0,0)
	}, content)
	pad(list, 3, 3, 3, 8)
	local layout = create("UIGridLayout", {CellSize=UDim2.fromOffset(230,150),CellPadding=UDim2.fromOffset(18,14),FillDirectionMaxCells=4}, list)

	local function addListing(item)
		local accent = C[item.accent] or C.Cyan
		local f = section(list, UDim2.fromOffset(230,150), nil, C.White)
		itemViewport(f, item, UDim2.fromOffset(54,54), UDim2.fromOffset(12,12))
		label(f,item.title,UDim2.new(1,-82,0,22),UDim2.fromOffset(76,12),14,C.Ink,Enum.TextXAlignment.Left,FONT_HEAVY)
		label(f,"by "..item.seller,UDim2.new(1,-82,0,18),UDim2.fromOffset(76,35),9,C.Muted,Enum.TextXAlignment.Left,FONT)
		label(f,"S "..item.price,UDim2.fromOffset(92,28),UDim2.fromOffset(12,77),17,C.Gold,Enum.TextXAlignment.Left,FONT_HEAVY)
		local buy = button(f,"VIEW",UDim2.fromOffset(92,34),UDim2.new(1,-104,1,-46),accent,C.White)
		buy.MouseButton1Click:Connect(function() ACTION("View listing", item) end)
		return f
	end

	local cards = {}
	for _, item in ipairs(DATA.Market) do
		cards[#cards+1] = {frame = addListing(item), data = item}
	end

	applyMarketFilters = function()
		local q = string.lower(search.Text)
		for _, entry in ipairs(cards) do
			local categoryOK = selectedMarketCategory == "ALL" or string.upper(entry.data.category or "") == selectedMarketCategory
			local textOK = q == "" or string.find(string.lower(entry.data.title .. " " .. entry.data.seller .. " " .. (entry.data.category or "")), q, 1, true) ~= nil
			entry.frame.Visible = categoryOK and textOK
		end
	end
	search:GetPropertyChangedSignal("Text"):Connect(applyMarketFilters)
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() list.CanvasSize=UDim2.fromOffset(0,layout.AbsoluteContentSize.Y+10) end)
end

local function renderInventory()
	clearContent()

	local sidebar = section(content, UDim2.fromOffset(166, 464), UDim2.fromOffset(0, 0), C.Ink2)
	label(sidebar, "CATEGORIES", UDim2.new(1,-22,0,26), UDim2.fromOffset(12,10), 11, Color3.fromRGB(188,200,215), Enum.TextXAlignment.Left, FONT_HEAVY)
	local categories = {"All", "Raw", "Components", "Supplies", "Equipment", "Special"}
	local categoryButtons = {}
	for i, cat in ipairs(categories) do
		local b = button(sidebar, string.upper(cat), UDim2.new(1,-20,0,40), UDim2.fromOffset(10,43+(i-1)*48), i==1 and C.Purple or C.White, i==1 and C.White or C.Ink)
		b.TextSize = 11
		categoryButtons[cat] = b
	end

	local rightX = 182
	local search = searchBox(content, "Search backpack...", UDim2.fromOffset(rightX, 0), UDim2.new(1, -rightX, 0, 42))
	local list = create("ScrollingFrame", {
		Position=UDim2.fromOffset(rightX,54), Size=UDim2.new(1,-rightX-250,1,-54), BackgroundTransparency=1, BorderSizePixel=0,
		ScrollBarThickness=5, ScrollBarImageColor3=C.Purple, AutomaticCanvasSize=Enum.AutomaticSize.Y, CanvasSize=UDim2.fromOffset(0,0)
	}, content)
	pad(list, 3, 3, 3, 6)
	local layout = create("UIGridLayout", {CellSize=UDim2.fromOffset(154,112),CellPadding=UDim2.fromOffset(12,12),FillDirectionMaxCells=3}, list)

	local detail = section(content, UDim2.fromOffset(232, 410), UDim2.new(1,-232,0,54), C.White)
	local dIconHolder = create("Frame", {Size=UDim2.fromOffset(72,72),Position=UDim2.fromOffset(16,16),BackgroundTransparency=1}, detail)
	local dName = label(detail,"SELECT ITEM",UDim2.new(1,-32,0,27),UDim2.fromOffset(16,102),16,C.Ink,Enum.TextXAlignment.Left,FONT_HEAVY)
	local dRarity = label(detail,"BACKPACK DETAILS",UDim2.new(1,-32,0,20),UDim2.fromOffset(16,129),9,C.Muted,Enum.TextXAlignment.Left,FONT)
	local dBiome = label(detail,"SOURCE // --",UDim2.new(1,-32,0,18),UDim2.fromOffset(16,149),9,C.Cyan,Enum.TextXAlignment.Left,FONT_HEAVY)
	local dUse = label(detail,"Select an item to inspect carried and stored amounts.",UDim2.new(1,-32,0,48),UDim2.fromOffset(16,174),11,C.Muted,Enum.TextXAlignment.Left,FONT)
	dUse.TextWrapped = true
	dUse.TextYAlignment = Enum.TextYAlignment.Top
	local amountBox = create("Frame", {Position=UDim2.fromOffset(16,230),Size=UDim2.new(1,-32,0,70),BackgroundColor3=C.Canvas,BorderSizePixel=0}, detail)
	round(amountBox, 10)
	local dCarried = label(amountBox,"CARRIED  --",UDim2.new(1,-16,0,30),UDim2.fromOffset(8,5),11,C.Ink,Enum.TextXAlignment.Left,FONT_HEAVY)
	local dStored = label(amountBox,"STORED   --",UDim2.new(1,-16,0,28),UDim2.fromOffset(8,35),11,C.Muted,Enum.TextXAlignment.Left,FONT)
	local lock = button(detail,"LOCK / RESERVE",UDim2.new(1,-32,0,42),UDim2.new(0,16,1,-58),C.Ink2,C.White)
	lock.MouseButton1Click:Connect(function() ACTION("Open resource controls") end)

	local entries = {}
	local selectedCategory = "All"

	local function selectItem(item)
		for _, child in ipairs(dIconHolder:GetChildren()) do
			child:Destroy()
		end
		itemViewport(dIconHolder, item, UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0))
		dName.Text = string.upper(item.name)
		dRarity.Text = item.rarity .. " // " .. string.upper(item.category)
		dBiome.Text = "SOURCE // " .. string.upper(item.biome or "Unknown")
		dUse.Text = item.use
		dCarried.Text = "CARRIED  " .. tostring(item.amount)
		dStored.Text = "STORED   " .. tostring(item.stored)
	end

	local function addItem(item)
		local accent = C[item.accent] or C.Purple
		local f = create("TextButton", {AutoButtonColor=false,Size=UDim2.fromOffset(154,112),BackgroundColor3=C.White,Text="",BorderSizePixel=0}, list)
		round(f, 12)
		stroke(f, C.Ink, 2)
		itemViewport(f, item, UDim2.fromOffset(56,56), UDim2.fromOffset(9,9))
		label(f,"x"..item.amount,UDim2.fromOffset(72,24),UDim2.fromOffset(72,12),15,C.Ink,Enum.TextXAlignment.Right,FONT_HEAVY)
		label(f,item.rarity,UDim2.fromOffset(72,18),UDim2.fromOffset(72,38),8,accent,Enum.TextXAlignment.Right,FONT_HEAVY)
		local nm = label(f,string.upper(item.name),UDim2.new(1,-18,0,32),UDim2.fromOffset(9,73),10,C.Ink,Enum.TextXAlignment.Left,FONT_HEAVY)
		nm.TextWrapped = true
		f.MouseButton1Click:Connect(function() selectItem(item) end)
		entries[#entries+1] = {frame=f,data=item}
	end

	for _, item in ipairs(DATA.Inventory) do addItem(item) end
	if DATA.Inventory[1] then selectItem(DATA.Inventory[1]) end

	local function filter()
		local q = string.lower(search.Text)
		for _, entry in ipairs(entries) do
			local item = entry.data
			local categoryOK = selectedCategory == "All" or item.category == selectedCategory
			local textOK = q == "" or string.find(string.lower(item.name .. " " .. item.category .. " " .. item.rarity .. " " .. (item.biome or "")), q, 1, true) ~= nil
			entry.frame.Visible = categoryOK and textOK
		end
	end

	for cat, b in pairs(categoryButtons) do
		b.MouseButton1Click:Connect(function()
			selectedCategory = cat
			for otherCat, other in pairs(categoryButtons) do
				local selected = otherCat == cat
				local base = selected and C.Purple or C.White
				other.BackgroundColor3 = base
				other:SetAttribute("BaseColor", base)
				other.TextColor3 = selected and C.White or C.Ink
			end
			filter()
		end)
	end
	search:GetPropertyChangedSignal("Text"):Connect(filter)
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() list.CanvasSize=UDim2.fromOffset(0,layout.AbsoluteContentSize.Y+10) end)
end

render = function(which)
	if not SCREEN_META[which] then return end
	activeScreen = which
	setHeader(which)

	if which == "Shop" then
		renderCardScreen("Shop", "HAVEN SUPPORT", "Premium extras stay separate from Scrap progression. Direct items only in this mockup.", DATA.Shop)
	elseif which == "Offer" then
		renderOffer()
	elseif which == "Marketplace" then
		renderMarketplace()
	elseif which == "Supply" then
		renderCardScreen("Supply", "QUARTERMASTER STOCK", "Reliable expedition supplies bought with normal Scrap — easy to scan before leaving Haven.", DATA.Supply)
	elseif which == "Inventory" then
		renderInventory()
	end
end

local function open(which)
	if not SCREEN_META[which] then
		warn("[Eclipse UI] Unknown screen: " .. tostring(which))
		return
	end
	render(which)
	dim.Visible = true
	window.Position = UDim2.new(0.5, 0, 0.5, 18)
	window.BackgroundTransparency = 0.12
	TweenService:Create(window, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 0,
	}):Play()
end

local function closeUI()
	if not dim.Visible then return end
	local tw = TweenService:Create(window, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.new(0.5, 0, 0.5, 12),
		BackgroundTransparency = 0.08,
	})
	tw:Play()
	tw.Completed:Wait()
	dim.Visible = false
end

close.MouseButton1Click:Connect(closeUI)

-- Demo dock. Keep this while styling; hide it once your own HUD buttons call _G.EclipseUI.Open(...).
local dock = create("Frame", {
	Name = "DemoDock",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -14),
	Size = UDim2.fromOffset(710, 72),
	BackgroundColor3 = C.Ink,
	BorderSizePixel = 0,
	Visible = CONFIG.ShowDemoDock,
}, gui)
round(dock, 18)
stroke(dock, C.White, 2, 0.15)
create("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 8),
}, dock)
pad(dock, 10, 10, 8, 8)

local dockButtons = {
	{"SHOP", "Shop", C.Purple},
	{"OFFER", "Offer", C.Orange},
	{"MARKET", "Marketplace", C.Cyan},
	{"SUPPLY", "Supply", C.Green},
	{"BACKPACK", "Inventory", C.Gold},
}
for _, info in ipairs(dockButtons) do
	local b = button(dock, info[1], UDim2.fromOffset(128, 52), nil, info[3], C.White)
	b.MouseButton1Click:Connect(function() open(info[2]) end)
	if info[2] == "Offer" and not RunService:IsStudio() then
		local function updateOfferVisibility()
			local endsAt = player:GetAttribute(CONFIG.StarterOffer.OfferEndsAtAttribute)
			b.Visible = type(endsAt) == "number" and endsAt > os.time()
		end
		updateOfferVisibility()
		player:GetAttributeChangedSignal(CONFIG.StarterOffer.OfferEndsAtAttribute):Connect(updateOfferVisibility)
	end
end

-- Optional convenience: connect common existing HUD button names to the new screens.
-- This does not delete or rewrite any of your old GUI objects.
local aliases = {
	Shop = {ShopButton=true, PremiumShopButton=true},
	Offer = {SurvivorOfferButton=true, OfferButton=true, NewSurvivorOfferButton=true},
	Marketplace = {MarketplaceButton=true, MarketButton=true},
	Supply = {SupplyShopButton=true, SuppliesButton=true},
	Inventory = {InventoryButton=true, BackpackButton=true},
}

if CONFIG.AutoConnectExistingButtons then
	for _, descendant in ipairs(playerGui:GetDescendants()) do
		if descendant:IsA("GuiButton") and not descendant:IsDescendantOf(gui) then
			for screenName, names in pairs(aliases) do
				if names[descendant.Name] then
					descendant.MouseButton1Click:Connect(function()
						open(screenName)
					end)
				end
			end
		end
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.Escape and dim.Visible then
		closeUI()
	end
end)

_G.EclipseUI = {
	Open = open,
	Close = closeUI,
	Render = render,
	Screen = gui,
	GetActiveScreen = function() return activeScreen end,
}

if CONFIG.OpenOnStart and SCREEN_META[CONFIG.OpenOnStart] then
	task.defer(function()
		open(CONFIG.OpenOnStart)
	end)
end