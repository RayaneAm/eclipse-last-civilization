--!strict
local GeneratorKit = require(script.Parent.GeneratorKit)
local SurvivorFigureGenerator = {}
export type Role = "Guide" | "Engineer" | "Merchant" | "Scientist" | "Outfitter" | "RewardOfficer"

local PROFILES = {
	Guide = {
		jacket = Color3.fromRGB(88, 92, 69),
		pants = Color3.fromRGB(61, 55, 46),
		accent = Color3.fromRGB(184, 137, 72),
		skin = Color3.fromRGB(205, 166, 132),
	},
	Engineer = {
		jacket = Color3.fromRGB(76, 83, 88),
		pants = Color3.fromRGB(47, 50, 54),
		accent = Color3.fromRGB(221, 151, 67),
		skin = Color3.fromRGB(151, 106, 78),
	},
	Merchant = {
		jacket = Color3.fromRGB(101, 76, 55),
		pants = Color3.fromRGB(64, 51, 42),
		accent = Color3.fromRGB(190, 151, 91),
		skin = Color3.fromRGB(188, 137, 101),
	},
	Scientist = {
		jacket = Color3.fromRGB(184, 193, 197),
		pants = Color3.fromRGB(53, 64, 72),
		accent = Color3.fromRGB(83, 184, 203),
		skin = Color3.fromRGB(220, 180, 149),
	},
	Outfitter = {
		jacket = Color3.fromRGB(65, 92, 91),
		pants = Color3.fromRGB(43, 49, 52),
		accent = Color3.fromRGB(199, 104, 109),
		skin = Color3.fromRGB(112, 75, 59),
	},
	RewardOfficer = {
		jacket = Color3.fromRGB(72, 76, 91),
		pants = Color3.fromRGB(45, 47, 56),
		accent = Color3.fromRGB(218, 177, 79),
		skin = Color3.fromRGB(218, 169, 127),
	},
}

local function bodyPart(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	return GeneratorKit.NewPart({
		Name = name,
		Size = size,
		CFrame = cf,
		Material = Enum.Material.SmoothPlastic,
		Color = color,
		CanCollide = false,
		Parent = model,
	})
end

function SurvivorFigureGenerator.Build(parent: Instance, figureCFrame: CFrame, role: Role): Model
	local profile = PROFILES[role]
	local model = Instance.new("Model")
	model.Name = role
	local root = bodyPart(model, "HumanoidRootPart", Vector3.new(1.4, 2, 1), figureCFrame * CFrame.new(0, 3.4, 0), Color3.new())
	root.Transparency = 1
	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayName = role
	humanoid.NameDisplayDistance = 0
	humanoid.Parent = model
	for _, side in { -1, 1 } do
		local label = if side < 0 then "Left" else "Right"
		bodyPart(
			model,
			`{label}LowerLeg`,
			Vector3.new(0.68, 1.5, 0.75),
			figureCFrame * CFrame.new(side * 0.42, 0.9, 0),
			profile.pants
		)
		bodyPart(
			model,
			`{label}UpperLeg`,
			Vector3.new(0.78, 1.5, 0.82),
			figureCFrame * CFrame.new(side * 0.42, 2.35, 0),
			profile.pants
		)
		bodyPart(
			model,
			`{label}Foot`,
			Vector3.new(0.75, 0.45, 1.1),
			figureCFrame * CFrame.new(side * 0.42, 0.22, -0.16),
			Color3.fromRGB(41, 38, 35)
		)
		bodyPart(
			model,
			`{label}UpperArm`,
			Vector3.new(0.62, 1.35, 0.68),
			figureCFrame * CFrame.new(side * 1.28, 4.15, 0),
			profile.jacket
		)
		bodyPart(
			model,
			`{label}LowerArm`,
			Vector3.new(0.56, 1.25, 0.62),
			figureCFrame * CFrame.new(side * 1.28, 3.02, 0),
			profile.skin
		)
	end
	bodyPart(model, "LowerTorso", Vector3.new(1.8, 1.15, 1), figureCFrame * CFrame.new(0, 3.15, 0), profile.pants)
	bodyPart(model, "UpperTorso", Vector3.new(2.2, 1.65, 1.1), figureCFrame * CFrame.new(0, 4.42, 0), profile.jacket)
	local head =
		bodyPart(model, "Head", Vector3.new(1.2, 1.2, 1.1), figureCFrame * CFrame.new(0, 5.95, 0), profile.skin)
	local face = Instance.new("Decal")
	face.Name = "Face"
	face.Face = Enum.NormalId.Front
	face.Texture = "rbxasset://textures/face.png"
	face.Parent = head
	bodyPart(
		model,
		"Hair",
		Vector3.new(if role == "Outfitter" then 1.5 else 1.28, 0.48, 1.2),
		figureCFrame
			* CFrame.new(if role == "Outfitter" then 0.15 else 0, 6.52, 0.05)
			* CFrame.Angles(0, 0, if role == "Outfitter" then math.rad(-10) else 0),
		Color3.fromRGB(48, 38, 31)
	)
	-- Distinct, layered silhouettes instead of one recolored block hairstyle.
	if role == "Engineer" then
		bodyPart(model, "MessyHairTuft", Vector3.new(0.6, 0.75, 0.65), figureCFrame * CFrame.new(-0.35, 6.75, -0.05) * CFrame.Angles(0, 0, math.rad(18)), Color3.fromRGB(42, 34, 29))
	elseif role == "Merchant" then
		bodyPart(model, "RuggedSideHair", Vector3.new(0.35, 0.9, 1), figureCFrame * CFrame.new(-0.65, 6.25, 0.08), Color3.fromRGB(61, 45, 34))
	elseif role == "Scientist" then
		bodyPart(model, "TiedHair", Vector3.new(0.65, 0.65, 0.65), figureCFrame * CFrame.new(0, 6.25, 0.72), Color3.fromRGB(52, 39, 32))
	elseif role == "Outfitter" then
		bodyPart(model, "StyledHairSweep", Vector3.new(0.5, 1.1, 0.55), figureCFrame * CFrame.new(0.68, 6.25, 0.05) * CFrame.Angles(0, 0, math.rad(-16)), Color3.fromRGB(39, 31, 29))
	elseif role == "RewardOfficer" then
		bodyPart(model, "ServiceCap", Vector3.new(1.5, 0.35, 1.45), figureCFrame * CFrame.new(0, 6.72, 0), profile.accent)
	else
		bodyPart(model, "PracticalHairSweep", Vector3.new(0.55, 0.6, 0.7), figureCFrame * CFrame.new(0.45, 6.65, 0), Color3.fromRGB(48, 38, 31))
	end
	bodyPart(model, "RoleTrim", Vector3.new(2.22, 0.25, 1.13), figureCFrame * CFrame.new(0, 3.7, -0.03), profile.accent)
	if role == "Guide" then
		bodyPart(
			model,
			"FieldBackpack",
			Vector3.new(1.55, 2, 0.65),
			figureCFrame * CFrame.new(0, 4.1, 0.75),
			Color3.fromRGB(55, 58, 45)
		)
		bodyPart(
			model,
			"Radio",
			Vector3.new(0.42, 0.75, 0.25),
			figureCFrame * CFrame.new(0.85, 4.45, -0.62),
			profile.accent
		)
	elseif role == "Engineer" then
		bodyPart(
			model,
			"ToolBelt",
			Vector3.new(2.05, 0.35, 1.15),
			figureCFrame * CFrame.new(0, 3.18, 0),
			profile.accent
		)
		bodyPart(
			model,
			"ForeheadGoggles",
			Vector3.new(1.05, 0.28, 0.18),
			figureCFrame * CFrame.new(0, 6.2, -0.59),
			Color3.fromRGB(82, 178, 190)
		)
	elseif role == "Merchant" then
		bodyPart(
			model,
			"MerchantApron",
			Vector3.new(1.75, 2.2, 0.16),
			figureCFrame * CFrame.new(0, 3.85, -0.59),
			Color3.fromRGB(116, 82, 52)
		)
		bodyPart(
			model,
			"CoinSatchel",
			Vector3.new(0.7, 0.85, 0.38),
			figureCFrame * CFrame.new(-0.92, 3.2, -0.48),
			profile.accent
		)
	elseif role == "Scientist" then
		bodyPart(
			model,
			"LabCoat",
			Vector3.new(2.3, 2.55, 1.18),
			figureCFrame * CFrame.new(0, 3.95, 0.02),
			profile.jacket
		)
		bodyPart(
			model,
			"ResearchTablet",
			Vector3.new(0.95, 1.2, 0.12),
			figureCFrame * CFrame.new(0.75, 3.45, -0.65),
			Color3.fromRGB(36, 52, 58)
		)
	elseif role == "Outfitter" then
		bodyPart(model, "Scarf", Vector3.new(1.5, 0.42, 1.2), figureCFrame * CFrame.new(0, 5.05, 0), profile.accent)
		bodyPart(
			model,
			"MeasuringTape",
			Vector3.new(0.2, 1.7, 0.15),
			figureCFrame * CFrame.new(-0.62, 4.1, -0.61),
			Color3.fromRGB(220, 196, 101)
		)
	else
		bodyPart(
			model,
			"OfficerSash",
			Vector3.new(0.32, 2.45, 0.18),
			figureCFrame * CFrame.new(0.48, 4.3, -0.61) * CFrame.Angles(0, 0, math.rad(-22)),
			profile.accent
		)
		bodyPart(
			model,
			"Clipboard",
			Vector3.new(0.85, 1.15, 0.15),
			figureCFrame * CFrame.new(-0.82, 3.35, -0.6),
			Color3.fromRGB(104, 76, 47)
		)
	end
	-- One anchored invisible root plus welds makes this a coherent Humanoid
	-- character model rather than a collection of independently anchored
	-- mannequin blocks. R15 body-part names remain available to animation,
	-- targeting and avatar-aware systems.
	for _, descendant in model:GetChildren() do
		if descendant:IsA("BasePart") and descendant ~= root then
			descendant.Anchored = false
			descendant.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end
	model.PrimaryPart = root
	model.Parent = parent
	return model
end
return SurvivorFigureGenerator
