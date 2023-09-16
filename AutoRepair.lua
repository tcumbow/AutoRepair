local repairKits = {}
local function FindRepairKits()
	repairKits = {}
	local bagId = BAG_BACKPACK
	for slotId = 0, GetBagSize(bagId) do
		if IsItemRepairKit(bagId, slotId) then 
			local tier = GetRepairKitTier(bagId, slotId)
			if not repairKits[tier] then repairKits[tier] = {} end
			repairKits[tier][slotId] = (GetSlotStackSize(bagId, slotId))
		end
	end
	return repairKits
end

local function GetItemLevelTier(bagId, slotId)
	return math.floor(GetItemRequiredLevel(bagId, slotId) / 10) + 1
end

local function GetRepairKitSlot(repairKitTier)
	if repairKits[repairKitTier] then
		for slotId, count in pairs(repairKits[repairKitTier]) do
			return slotId, count, repairKitTier
		end
	elseif true then
		--Scan higher tiers first?
		while repairKitTier < 6 do
			repairKitTier = repairKitTier + 1
			if repairKits[repairKitTier] then
				for slotId, count in pairs(repairKits[repairKitTier]) do
					return slotId, count, repairKitTier
				end
			end
		end
	end
end 

local function RepairItemWithKit(bagId, slotId)
	local repairKitTier = GetItemLevelTier(bagId, slotId)
	local repaired = false
	local itemCondition = GetItemCondition(bagId, slotId)
	local oldCondition = itemCondition
	while itemCondition < 100 do
		local repairKitSlot, repairKitCount, repairKitTier = GetRepairKitSlot(repairKitTier)
		if repairKitSlot then
			local repairKitAmount = GetAmountRepairKitWouldRepairItem(bagId, slotId, BAG_BACKPACK, repairKitSlot)
			RepairItemWithRepairKit(bagId, slotId, BAG_BACKPACK, repairKitSlot)
			itemCondition = itemCondition + repairKitAmount --GetItemCondition isn't always updated right away (??)
			repairKits = FindRepairKits()
			repaired = true
		else
			break
		end
	end
end

local function RepairItemsWithKits(threshold)
	threshold = tonumber(threshold) or 0
	repairKits = FindRepairKits()
	local bagId = BAG_WORN
	for slotId = 0, GetBagSize(bagId) do
		if DoesItemHaveDurability(bagId, slotId) then
			local itemName, itemCondition = GetItemName(bagId, slotId), GetItemCondition(bagId, slotId)
			if itemName ~= "" and itemCondition <= threshold then
				RepairItemWithKit(bagId, slotId)
			end
		end
	end
end

local soulGems = {}
local function FindSoulGems()
	soulGems = {}
	local bagId = BAG_BACKPACK
	for slotId = 0, GetBagSize(bagId) do
		if IsItemSoulGem(SOUL_GEM_TYPE_FILLED, bagId, slotId) then 
			local tier = GetSoulGemItemInfo(bagId, slotId)
			if not soulGems[tier] then soulGems[tier] = {} end
			soulGems[tier][slotId] = (GetSlotStackSize(bagId, slotId))
		end
	end
	return soulGems
end
local function GetSoulGemSlot(soulGemTier)
	if soulGems[soulGemTier] then
		for slotId, count in pairs(soulGems[soulGemTier]) do
			return slotId, count, soulGemTier
		end
	end
end 

local function RechargeItemWithGem(bagId, slotId)
	local recharged = false
	local soulGemTier = 1 --GetItemLevelTier(bagId, slotId) -- Now there are only Grand Soulgems with tier of 1
	local itemCharge, itemMaxCharge = GetChargeInfoForItem(bagId, slotId)
	local oldCharge = itemCharge
	while itemCharge < itemMaxCharge do
		local soulGemSlot, soulGemCount, soulGemTier = GetSoulGemSlot(soulGemTier)
		if soulGemSlot then
			local chargeAmount = GetAmountSoulGemWouldChargeItem(bagId, slotId, BAG_BACKPACK, soulGemSlot)
			ChargeItemWithSoulGem(bagId, slotId, BAG_BACKPACK, soulGemSlot)
			itemCharge = itemCharge + chargeAmount
			soulGems = FindSoulGems()
			recharged = true
		else
			break
		end
	end
end

local function RechargeItemsWithGems(threshold)
	threshold = tonumber(threshold) or 0
	soulGems = FindSoulGems()
	for slotId = 0, GetBagSize(BAG_WORN) do
		if IsItemChargeable(BAG_WORN, slotId) then
			local itemName, itemCharge, itemMaxCharge = GetItemName(BAG_WORN, slotId), GetChargeInfoForItem(BAG_WORN, slotId)
			if itemName ~= "" and math.floor(itemCharge / itemMaxCharge * 100) <= threshold then
				RechargeItemWithGem(BAG_WORN, slotId)
			end
		end
	end
end

local function AllowRepair()
	if IsUnitDead("player") then return false end
	return true
end

local function AllowRecharge()
	if IsUnitDead("player") then return false end
	return true
end

local function OnInventorySingleSlotUpdate(_, bagId, slotId, isNewItem, _, updateReason)
	if updateReason == INVENTORY_UPDATE_REASON_DURABILITY_CHANGE or updateReason == INVENTORY_UPDATE_REASON_DEFAULT then
		if AllowRepair() and DoesItemHaveDurability(bagId, slotId) then
			local itemName, itemCondition = GetItemName(bagId, slotId), GetItemCondition(bagId, slotId)
			if itemName ~= "" and itemCondition <= 1 then
				repairKits = FindRepairKits()
				RepairItemWithKit(bagId, slotId)
			end
		end
	end
	if updateReason == INVENTORY_UPDATE_REASON_ITEM_CHARGE or updateReason == INVENTORY_UPDATE_REASON_DEFAULT then
		if AllowRecharge() and IsItemChargeable(bagId, slotId) then
			local itemName, itemCharge, itemMaxCharge = GetItemName(bagId, slotId), GetChargeInfoForItem(bagId, slotId)
			if itemName ~= "" and math.floor(itemCharge / itemMaxCharge * 100) <= 1 then
				soulGems = FindSoulGems()
				RechargeItemWithGem(bagId, slotId)
			end
		end
	end
end

local function OnPlayerAlive()
	if AllowRepair() then
		RepairItemsWithKits()
	end
	if AllowRecharge() then
		RechargeItemsWithGems()
	end
end

local function OnOpenStore()
	local repairCost = GetRepairAllCost()
	if repairCost <= 0 then
		-- nothing
	elseif repairCost < GetCurrentMoney() then
		RepairAll()
	end
end

local function Initialize()
	EVENT_MANAGER:RegisterForEvent("AutoRepair", EVENT_OPEN_STORE, OnOpenStore)
	EVENT_MANAGER:RegisterForEvent("AutoRepair", EVENT_PLAYER_ALIVE, OnPlayerAlive)
	EVENT_MANAGER:RegisterForEvent ("AutoRepair", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnInventorySingleSlotUpdate) -- we only care about worn items, do not filter for updateReason
	EVENT_MANAGER:AddFilterForEvent("AutoRepair", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)  -- because we also want it to trigger when items get equipped
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= "AutoRepair" then return end
    EVENT_MANAGER:UnregisterForEvent("AutoRepair", EVENT_ADD_ON_LOADED)
	Initialize()
end
EVENT_MANAGER:RegisterForEvent("AutoRepair", EVENT_ADD_ON_LOADED, OnAddonLoaded)
