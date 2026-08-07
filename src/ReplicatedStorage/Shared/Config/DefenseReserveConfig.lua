--!strict
-- Approved Defense Reserve consumable types (Phase 4A) — DefenseReserveService
-- only allows allocating/consuming items on this list, so an owner can't
-- accidentally (or a helper can't maliciously) route arbitrary storage
-- items through the reserve.

export type DefenseReserveItem = {
	ItemId: string,
	Name: string,
}

local DefenseReserveConfig = {}

DefenseReserveConfig.ApprovedItems = {
	{ ItemId = "TurretAmmo", Name = "Turret Ammunition" },
	{ ItemId = "MachineGunAmmo", Name = "Machine Gun Ammunition" },
	{ ItemId = "PowerCell", Name = "Power Cell" },
	{ ItemId = "RepairScrap", Name = "Repair Scrap" },
	{ ItemId = "MedicalSupplies", Name = "Medical Supplies" },
	{ ItemId = "TrapCharge", Name = "Trap Charge" },
} :: { DefenseReserveItem }

local approvedIds: { [string]: boolean } = {}
for _, item in DefenseReserveConfig.ApprovedItems do
	approvedIds[item.ItemId] = true
end

function DefenseReserveConfig.IsApproved(itemId: string): boolean
	return approvedIds[itemId] == true
end

return DefenseReserveConfig
