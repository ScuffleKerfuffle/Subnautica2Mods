--#region Imports
require("utils")

--#endregion

local ModName = "ScufflesMetalFarmCollection"
local LIB_ROOT = "./ue4ss/Mods/SN2ModSettings/"
local MANIFEST_PATH = LIB_ROOT .. "registrations/" .. ModName .. ".lua"
local defaultOutputName = "%o"

local config = require("config")

local function log(msg)
    print(string.format("[%s] %s\n", ModName, msg))
end

--#region SN2ModSettings Config Foo

local function WriteManifest()
    local manifest = [=[
    return {
        name        = "ScufflesMetalFarmCollection",
        version     = "1.0.0",
        author      = "Scuffle Kerfuffle",
        display     = "Scuffle's Metal Farm Collection",
        github      = "scufflekerfuffle/subnautica2mods/scufflesmetalfarmcollection",
        nexus_id    = "",
        settings    = {
            {
                key="Enabled", 
                title="Enable Automatic Metal Farm Collection",
                type="toggle",
                default=true,
                description="Master switch. When off, all metal farms will need to be collected manually."
            }
        },
    ]=]

    if WriteText(MANIFEST_PATH, manifest) then
        log("Manifest written successfully.")
    else
        log("Failed to write manifest (is SN2ModSettings installed?).")
    end
end
--#endregion

--#region Farm Collection Logic

local function transferItems(farm, farmInventory)

    if not farm or not farm:IsValid() then
        return
    end

    if not farmInventory or not farmInventory:IsValid() then
        return
    end

    if not FindAllOf then
        log("FindAllOf function not found. Is ue4ss installed?")
        return
    end

    local containerSource = { class = "SN2Locker", getInventory = function(locker) return locker.Inventory end, hasLabel = true}

    local targetLockers = {}

    local actors = FindAllOf(containerSource.class)
    if not actors then
        return
    end

    for _, actor in ipairs(actors) do
        if not actor or not actor:IsValid() then
            goto continue
        end

        local distance = GetDistance(farm, actor)
        --look for lockers within 10000 unreal units (100 meters) that have a label starting with the default output name
        if distance and distance <= 10000 then
            local ok, inventory = pcall(function () return containerSource.getInventory(actor) end)

            if ok and inventory and inventory:IsValid() then
                local rawLabel = nil
                --NOTE: This differs from how QuickSort behaves due to having only the one type of source.
                local ok2, label = pcall(function() return GetActorLabel(actor) end)

                if ok2 and label then
                    rawLabel = label
                end

                if rawLabel and rawLabel:sub(1, #defaultOutputName) == defaultOutputName then
                    
                    local okMax, maxItems = pcall(function() return inventory.MaxItems end)
                    local okItems, items = pcall(function() return inventory:GetItems() end)

                    if not okMax or not maxItems or not okItems or not items then
                        goto continue
                    end

                    local currentItemCount = #items

                    if currentItemCount < maxItems then
                        table.insert(targetLockers, {inventory = inventory, inventoryid = inventory.InventoryId,label = rawLabel, currentItemCount = currentItemCount, maxItems = maxItems})
                    end
                end
            end
        end
        ::continue::
    end

    if #targetLockers <=0 then
        return
    end

    local ok, itemsToTransfer = pcall(function() return farmInventory:GetItems() end)

    if not ok or not itemsToTransfer then
        return
    end

    for _, rawItem in ipairs(itemsToTransfer) do
        local innerItem = rawItem:get()

        for _, locker in ipairs(targetLockers) do
            if locker.currentItemCount >= locker.maxItems then
                goto lockerContinue
            end

            local okTransfer, err = pcall(function() return farmInventory:MoveItemBetweenInventories(innerItem.ItemId, farmInventory.InventoryId, locker.inventory.Inventory) end)

            if not okTransfer then
                log("Error transferring item: " .. tostring(err))
            else
                locker.currentItemCount = locker.currentItemCount + 1
                break
            end
            ::lockerContinue::
        end
        ::continue::
    end
end

local function CollectAllFarms()
    if not FindAllOf then
        log("FindAllOf function not found. Is ue4ss installed?")
        return
    end

    local farms = FindAllOf("SN2MetalFarm")

    if not farms then
        return
    end

    for _, farm in ipairs(farms) do
        if not farm or not farm:IsValid() then
            goto continue
        end

        local growers = farm.SeedGrowerComponents
        
        if not growers or growers.Count == 0 then
            goto continue
        end

        for i = 1, #growers do
            local grower = growers[i]

            if grower and grower:IsValid() and grower.HasFullyRipenedSeed() then
                --local harvestAmount = grower.GetRipenedAmount()

                --if harvestAmount and harvestAmount > 0 then                    
                --end
                local inventory = farm.InventoryComponent

                if inventory and inventory:IsValid() then
                    transferItems(farm, inventory)
                end
            end
        end

        ::continue::
    end
end

LoopAsync(1000, function()
        if not ModRef then
            return
        end

        for k, currentPair in pairs(config) do
            local sharedVariable = ModRef:GetSharedVariable("SN2ModSettings/" .. ModName .. "/" .. k)
            
            if sharedVariable ~= nil and type(sharedVariable) == type(currentPair) and sharedVariable ~= currentPair then
                config[k] = sharedVariable
            end
        end

        if config.Enabled then
            ExecuteInGameThread(pcall(CollectAllFarms))
        end
    end
)

--#endregion