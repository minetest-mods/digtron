local mod_meta = minetest.get_mod_storage()

------------------------------------------------------------------------------------
-- Inventory

-- indexed by digtron_id_name, set to true whenever the detached inventory's contents change
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
			local stack = inv:get_stack(from_list, from_index)
			if minetest.get_craft_result({method="fuel", width=1, items={stack}}).time ~= 0 then
				return stack:get_count()
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
digtron.ensure_inventory_exists = function(digtron_id_name)
	local inv = minetest.get_inventory({type="detached", name=digtron_id_name})
	if inv == nil then
		inv = minetest.create_detached_inventory(digtron_id_name, detached_inventory_callbacks)
		local inv_string = mod_meta:get_string("inv_"..digtron_id_name)
		if inv_string ~= "" then
			local inventory_table = minetest.deserialize(inv_string)
			for listname, invlist in pairs(inventory_table) do
				inv:set_size(listname, #invlist)
				inv:set_list(listname, invlist)
			end
		end
	end
end

local persist_inventory = function(digtron_id_name)
	local inv = minetest.get_inventory({type="detached", name=digtron_id_name})
	if inv == nil then
		minetest.log("error", "[Digtron] persist_inventory attempted to record a nonexistent inventory "
			.. digtron_id_name)
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
	
	mod_meta:set_string("inv_"..digtron_id_name, minetest.serialize(persist))
end

minetest.register_globalstep(function(dtime)
	for digtron_id_name, _ in pairs(dirty_inventories) do
		persist_inventory(digtron_id_name)
		dirty_inventories[digtron_id_name] = nil
	end
end)

--------------------------------------------------------------------------------------

local create_new_id = function()
	local last_id = mod_meta:get_int("last_id") -- returns 0 when uninitialized, so 0 will never be a valid digtron_id.
	local new_id = last_id + 1
	mod_meta:set_int("last_id", new_id) -- ensure each call to this method gets a unique number
	
	local digtron_id_name = "digtron_id_" .. tostring(new_id)
	local inv = minetest.create_detached_inventory(digtron_id_name, detached_inventory_callbacks)
	
	return digtron_id_name, inv
end

-- Deletes a Digtron record. Note: just throws everything away, this is not digtron.deconstruct.
local dispose_id = function(digtron_id_name)
	minetest.remove_detached_inventory(digtron_id_name)
	mod_meta:set_string("inv_"..digtron_id_name, "")
	mod_meta:set_string("layout_"..digtron_id_name, "")
end

-------------------------------------------------------------------------------------------------------

local persist_layout = function(digtron_id_name, layout)
	mod_meta:set_string("layout_"..digtron_id_name, minetest.serialize(layout))
end

local retrieve_layout = function(digtron_id_name)
	local layout_string = mod_meta:get_string("layout_"..digtron_id_name)
	if layout_string ~= "" then
		return minetest.deserialize(layout_string)
	end
end

--------------------------------------------------------------------------------------------------------

local cardinal_directions = {
	{x=1,y=0,z=0},
	{x=-1,y=0,z=0},
	{x=0,y=1,z=0},
	{x=0,y=-1,z=0},
	{x=0,y=0,z=1},
	{x=0,y=0,z=-1},
}
local origin_hash = minetest.hash_node_position({x=0,y=0,z=0})

-- recursive function searches out all connected unassigned digtron nodes
local get_all_adjacent_digtron_nodes
get_all_adjacent_digtron_nodes = function(pos, digtron_nodes, not_digtron, player_name)
	for _, dir in ipairs(cardinal_directions) do
		local test_pos = vector.add(pos, dir)
		local test_hash = minetest.hash_node_position(test_pos)
		if not (digtron_nodes[test_hash] or not_digtron[test_hash]) then -- don't test twice
			local test_node = minetest.get_node(test_pos)
			local group_value = minetest.get_item_group(test_node.name, "digtron")
			if group_value > 0 then
				local meta = minetest.get_meta(test_pos)
				if meta:contains("digtron_id") then
					-- Node is part of an existing digtron, don't incorporate it
					not_digtron[test_hash] = true
				--elseif TODO test for protected node status using player_name
				else
					--test_node.group_value = group_value -- for later ease of reference
					digtron_nodes[test_hash] = test_node
					get_all_adjacent_digtron_nodes(test_pos, digtron_nodes, not_digtron, player_name) -- recurse
				end
			else
				-- don't record details, the content of this node will change as the digtron moves
				not_digtron[test_hash] = true
			end
		end		
	end
end

-- Returns the id of the new Digtron record, or nil on failure
digtron.construct = function(pos, player_name)
	local node = minetest.get_node(pos)
	-- TODO: a more generic test? Not needed with the more generic controller design, as far as I can tell
	if node.name ~= "digtron:controller" then 
		-- Called on an incorrect node
		minetest.log("error", "[Digtron] digtron.construct called with pos " .. minetest.pos_to_string(pos)
			.. " but the node at this location was " .. node.name)
		return nil
	end
	local meta = minetest.get_meta(pos)
	if meta:contains("digtron_id") then
		-- Already constructed. TODO: validate that the digtron_id actually exists as well
		minetest.log("error", "[Digtron] digtron.construct called with pos " .. minetest.pos_to_string(pos)
			.. " but the controller at this location was already part of a constructed Digtron.")
		return nil
	end
	local root_hash = minetest.hash_node_position(pos)
	local digtron_nodes = {[root_hash] = node} -- Nodes that are part of Digtron
	local not_digtron = {} -- Nodes that are adjacent to Digtron but not a part of it
	get_all_adjacent_digtron_nodes(pos, digtron_nodes, not_digtron, player_name)
	
	local digtron_id, digtron_inv = create_new_id(pos)
	
	local layout = {}
	
	for hash, node in pairs(digtron_nodes) do
		local relative_hash = hash - root_hash + origin_hash
		minetest.chat_send_all("constructing " .. minetest.pos_to_string(minetest.get_position_from_hash(relative_hash)))
		local digtron_meta
		if hash == root_hash then
			digtron_meta = meta -- we're processing the controller, we already have a reference to its meta
		else
			digtron_meta = minetest.get_meta(minetest.get_position_from_hash(hash))
		end
		
		local meta_table = digtron_meta:to_table()
		
		if meta_table.fields.digtron_id then
			-- Trying to incorporate part of an existing digtron, should be impossible.
			minetest.log("error", "[Digtron] digtron.construct tried to incorporate a Digtron node of type "
				.. node.name .. " at " .. minetest.pos_to_string(minetest.get_position_from_hash(hash))
				.. " that was already assigned to digtron id " .. meta_table.fields.digtron_id)
			dispose_id(digtron_id)
			return nil
		end
		-- Process inventories specially
		-- TODO Builder inventory gets turned into an itemname in a special key in the builder's meta
		-- fuel and main get added to corresponding detached inventory lists
		for listname, items in pairs(meta_table.inventory) do
			local count = #items
			-- increase the corresponding detached inventory size
			minetest.chat_send_all("adding " .. count .. " to size of " .. listname)
			digtron_inv:set_size(listname, digtron_inv:get_size(listname) + count)
			for _, stack in ipairs(items) do
				digtron_inv:add_item(listname, stack)
			end
		end
		
		node.param1 = nil -- we don't care about param1, wipe it to save space
		layout[relative_hash] = {meta = meta_table.fields, node = node}
	end
	
	persist_inventory(digtron_id)
	persist_layout(digtron_id, layout)
	
	-- Wipe out the inventories of all in-world nodes, it's stored in the mod_meta now.
	-- Wait until now to do it in case the above loop fails partway through.
	for hash, node in pairs(digtron_nodes) do
		local digtron_meta
		if hash == root_hash then
			digtron_meta = meta -- we're processing the controller, we already have a reference to its meta
		else
			digtron_meta = minetest.get_meta(minetest.get_position_from_hash(hash))
		end
		local inv = digtron_meta:get_inventory()
		
		-- TODO: wipe
	end
	
	minetest.debug("constructed id " .. digtron_id)
	return digtron_id
end

-- TODO: skeletal!
digtron.deconstruct = function(digtron_id, pos, name)
	local meta = minetest.get_meta(pos)
	
	--TODO: go through layout and distribute inventory

	dispose_id(digtron_id)
end