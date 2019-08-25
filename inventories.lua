local mod_meta = digtron.mod_meta

-- indexed by digtron_id, set to true whenever the detached inventory's contents change
local dirty_inventories = {}

local detached_inventory_callbacks = {
    -- Called when a player wants to move items inside the inventory.
    -- Return value: number of items allowed to move.
    allow_move = function(inv, from_list, from_index, to_list, to_index, count, player)
		--allow anything in "main"
		if to_list == "main" then
			return count
		end
	
		--only allow fuel items in "fuel"
		if to_list == "fuel" then
			local stack = inv:get_stack(from_list, from_index)
			if minetest.get_craft_result({method="fuel", width=1, items={stack}}).time ~= 0 then
				return count
			end
		end
		return 0			
	end,

    -- Called when a player wants to put something into the inventory.
    -- Return value: number of items allowed to put.
    -- Return value -1: Allow and don't modify item count in inventory.
    allow_put = function(inv, listname, index, stack, player)
		-- Only allow fuel items to be placed in fuel
		if listname == "fuel" then
			if minetest.get_craft_result({method="fuel", width=1, items={stack}}).time ~= 0 then
				return stack:get_count()
			else
				return 0
			end
		end
		return stack:get_count() -- otherwise, allow all drops
	end,

    -- Called when a player wants to take something out of the inventory.
    -- Return value: number of items allowed to take.
    -- Return value -1: Allow and don't modify item count in inventory.
    allow_take = function(inv, listname, index, stack, player)
		return stack:get_count()
	end,

    -- Called after the actual action has happened, according to what was
    -- allowed.
    -- No return value.
	on_move = function(inv, from_list, from_index, to_list, to_index, count, player)
		dirty_inventories[inv:get_location().name] = true
	end,
	on_put = function(inv, listname, index, stack, player)
		dirty_inventories[inv:get_location().name] = true
	end,
	on_take = function(inv, listname, index, stack, player)
		dirty_inventories[inv:get_location().name] = true
	end,
}

-- If the detached inventory doesn't exist, reads saved metadata version of the inventory and creates it
-- Doesn't do anything if the detached inventory already exists, the detached inventory is authoritative
local retrieve_inventory = function(digtron_id)
	local inv = minetest.get_inventory({type="detached", name=digtron_id})
	if inv == nil then
		inv = minetest.create_detached_inventory(digtron_id, detached_inventory_callbacks)
		local inv_string = mod_meta:get_string(digtron_id..":inv")
		if inv_string ~= "" then
			local inventory_table = minetest.deserialize(inv_string)
			for listname, invlist in pairs(inventory_table) do
				inv:set_size(listname, #invlist)
				inv:set_list(listname, invlist)
			end
		end
	end
	return inv
end

-- Stores contents of detached inventory as a metadata string
local persist_inventory = function(digtron_id)
	local inv = minetest.get_inventory({type="detached", name=digtron_id})
	if inv == nil then
		minetest.log("error", "[Digtron] persist_inventory attempted to record a nonexistent inventory "
			.. digtron_id)
		return
	end
	local lists = inv:get_lists()
	
	local persist = {}
	for listname, invlist in pairs(lists) do
		local inventory = {}
		for i, stack in ipairs(invlist) do
			table.insert(inventory, stack:to_string()) -- convert into strings for serialization
		end		
		persist[listname] = inventory
	end
	
	mod_meta:set_string(digtron_id..":inv", minetest.serialize(persist))
end

minetest.register_globalstep(function(dtime)
	for digtron_id, _ in pairs(dirty_inventories) do
		persist_inventory(digtron_id)
		dirty_inventories[digtron_id] = nil
	end
end)

-- There should only be one of these at a time, but it doesn't cost much to be safe.
local predictive_inventory = {}
-- Copies digtron's inventory into a temporary location so that a dig cycle can be run
-- using it without affecting the actual inventory until everything's been confirmed to work
local get_predictive_inventory = function(digtron_id)
	local existing = predictive_inventory[digtron_id]
	if existing then return existing end
	
	local predictive_inv = minetest.create_detached_inventory("digtron_predictive_"..digtron_id, detached_inventory_callbacks)
	predictive_inventory[digtron_id] = predictive_inv
	local source_inv = retrieve_inventory(digtron_id)
	
	-- Populate predictive inventory with the digtron's contents
	for listname, invlist in pairs(source_inv:get_lists()) do
		predictive_inv:set_size(listname, #invlist)
		predictive_inv:set_list(listname, invlist)
	end
	
	return predictive_inv
end
-- Wipes predictive inventory without committing it (eg, on failure of predicted operation)
local clear_predictive_inventory = function(digtron_id)
	local predictive_inv = predictive_inventory[digtron_id]
	if not predictive_inv then
		minetest.log("error", "[Digtron] clear_predictive_inventory called for " .. digtron_id
			.. " but predictive inventory did not exist")
		return
	end

	minetest.remove_detached_inventory("digtron_predictive_"..digtron_id)
	predictive_inventory[digtron_id] = nil
	
	if not next(predictive_inventory) then
		minetest.log("warning", "[Digtron] multiple predictive inventories were in existence, this shouldn't be happening. File an issue with Digtron programmers.")
	end
end
-- Copies the predictive inventory's contents into the actual digtron's inventory and wipes the predictive inventory
local commit_predictive_inventory = function(digtron_id)
	local predictive_inv = predictive_inventory[digtron_id]
	if not predictive_inv then
		minetest.log("error", "[Digtron] commit_predictive_inventory called for " .. digtron_id
			.. " but predictive inventory did not exist")
		return
	end

	local source_inv = retrieve_inventory(digtron_id)
	for listname, invlist in pairs(predictive_inv:get_lists()) do
		source_inv:set_list(listname, invlist)
	end
	dirty_inventories[digtron_id] = true
	clear_predictive_inventory(digtron_id)
end

return {
	retrieve_inventory = retrieve_inventory,
	persist_inventory = persist_inventory,
	get_predictive_inventory = get_predictive_inventory,
	commit_predictive_inventory = commit_predictive_inventory,
	clear_predictive_inventory = clear_predictive_inventory,
}