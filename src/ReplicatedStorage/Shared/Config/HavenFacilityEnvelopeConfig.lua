--!strict
-- Shared exterior contract for every staffed Haven service module. Interiors
-- remain bespoke; these values only standardize the distant silhouette,
-- facade line, signage and working height.

local HavenFacilityEnvelopeConfig = {
	Width = 22,
	Depth = 18,
	WallHeight = 13.5,
	RoofThickness = 1,
	RoofOverhang = 1,
	FrontHeaderHeight = 3.5,
	FrontOpeningHeight = 10,
	StructuralPostWidth = 1,
	SignWidth = 16,
	SignHeight = 3.2,
	SignCenterHeight = 11.75,
	CounterTopHeight = 3.5,
}

HavenFacilityEnvelopeConfig.OverallHeight = HavenFacilityEnvelopeConfig.WallHeight
	+ HavenFacilityEnvelopeConfig.RoofThickness / 2

return HavenFacilityEnvelopeConfig
