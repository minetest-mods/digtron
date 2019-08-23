local mod_meta = minetest.get_mod_storage()

local cache = {}

--minetest.debug(dump(mod_meta:to_table()))

-- Wipes mod_meta
--for field, value in pairs(mod_meta:to_table().fields) do
--	mod_meta:set_string(field, "")
--end

------------------------------------------------------------------------------------
-- Inventory

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
digtron.retrieve_inventory = function(digtron_id)
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

--------------------------------------------------------------------------------------

local create_new_id = function()
	local digtron_id = "digtron" .. tostring(math.random(1, 2^21)) -- TODO: use SecureRandom()
	-- It's super unlikely that we'll get a collision, but what the heck - maybe something will go
	-- wrong with the random number source
	while mod_meta:get_string(digtron_id..":layout") ~= "" do
		digtron_id = "digtron" .. tostring(math.random(1, 2^21))
	end	
	local inv = minetest.create_detached_inventory(digtron_id, detached_inventory_callbacks)
	return digtron_id, inv
end

-- Deletes a Digtron record. Note: just throws everything away, this is not digtron.disassemble.
local dispose_callbacks = {}
local dispose_id = function(digtron_id)
	-- name doesn't bother caching
	mod_meta:set_string(digtron_id..":name", "")

	-- inventory handles itself specially too
	mod_meta:set_string(digtron_id..":inv", "")
	minetest.remove_detached_inventory(digtron_id)

	-- clears the cache tables
	for i, func in ipairs(dispose_callbacks) do
		func(digtron_id)
	end
end

--------------------------------------------------------------------------------------------
-- Name

-- Not bothering with a dynamic table store for names, they're just strings with no need for serialization or deserialization
digtron.get_name = function(digtron_id)
	return mod_meta:get_string(digtron_id..":name")
end

digtron.set_name = function(digtron_id, digtron_name)
	-- Don't allow a name to be set for a non-existent Digtron
	if mod_meta:get(digtron_id..":layout") then
		mod_meta:set_string(digtron_id..":name", digtron_name)
	end
end

-------------------------------------------------------------------------------------------------------
-- Tables stored to metadata and cached locally

local get_table_functions = function(identifier)
	cache[identifier] = {}
	
	local persist_func = function(digtron_id, tbl)
		mod_meta:set_string(digtron_id..":"..identifier, minetest.serialize(tbl))
		cache[identifier][digtron_id] = tbl
	end
	
	local retrieve_func = function(digtron_id)
		local current = cache[identifier][digtron_id]
		if current then
			return current
		end
		local tbl_string = mod_meta:get_string(digtron_id..":"..identifier)
		if tbl_string ~= "" then
			current = minetest.deserialize(tbl_string)
			if current then
				cache[identifier][digtron_id] = current
			end
			return current
		end
	end
	
	local dispose_func = function(digtron_id)
		mod_meta:set_string(digtron_id..":"..identifier, "")
		cache[identifier][digtron_id] = nil
	end
	
	-- add a callback for dispose_id
	table.insert(dispose_callbacks, dispose_func)
	
	return persist_func, retrieve_func, dispose_func
end

local persist_layout, retrieve_layout = get_table_functions("layout")
local persist_adjacent, retrieve_adjacent = get_table_functions("adjacent")
local persist_bounding_box, retrieve_bounding_box = get_table_functions("bounding_box")
local persist_pos, retrieve_pos, dispose_pos = get_table_functions("pos")

digtron.get_pos = retrieve_pos

-------------------------------------------------------------------------------------------------------
-- Layout creation helpers

local cardinal_directions = {
	{x=1,y=0,z=0},
	{x=-1,y=0,z=0},
	{x=0,y=1,z=0},
	{x=0,y=-1,z=0},
	{x=0,y=0,z=1},
	{x=0,y=0,z=-1},
}

local update_bounding_box = function(bounding_box, pos)
	bounding_box.minp.x = math.min(bounding_box.minp.x, pos.x)
	bounding_box.minp.y = math.min(bounding_box.minp.y, pos.y)
	bounding_box.minp.z = math.min(bounding_box.minp.z, pos.z)
	bounding_box.maxp.x = math.max(bounding_box.maxp.x, pos.x)
	bounding_box.maxp.y = math.max(bounding_box.maxp.y, pos.y)
	bounding_box.maxp.z = math.max(bounding_box.maxp.z, pos.z)
end

-- recursive function searches out all connected unassigned digtron nodes
local get_all_adjacent_digtron_nodes
get_all_adjacent_digtron_nodes = function(pos, digtron_nodes, digtron_adjacent, bounding_box, player_name)
	for _, dir in ipairs(cardinal_directions) do
		local test_pos = vector.add(pos, dir)
		local test_hash = minetest.hash_node_position(test_pos)
		if not (digtron_nodes[test_hash] or digtron_adjacent[test_hash]) then -- don't test twice
			local test_node = minetest.get_node(test_pos)
			local group_value = minetest.get_item_group(test_node.name, "digtron")
			if group_value > 0 then
				local meta = minetest.get_meta(test_pos)
				if meta:contains("digtron_id") then
					-- Node is part of an existing digtron, don't incorporate it
					digtron_adjacent[test_hash] = true
				--elseif TODO test for protected node status using player_name
				else
					--test_node.group_value = group_value -- for later ease of reference
					digtron_nodes[test_hash] = test_node
					update_bounding_box(bounding_box, test_pos)
					get_all_adjacent_digtron_nodes(test_pos, digtron_nodes, digtron_adjacent, bounding_box, player_name) -- recurse
				end
			else
				-- don't record details, the content of this node will change as the digtron moves
				digtron_adjacent[test_hash] = true
			end
		end		
	end
end

--------------------------------------------------------------------------------------------------------
-- assemble and disassemble

local origin_hash = minetest.hash_node_position({x=0,y=0,z=0})

-- Returns the id of the new Digtron record, or nil on failure
digtron.assemble = function(root_pos, player_name)
	local node = minetest.get_node(root_pos)
	-- TODO: a more generic test? Not needed with the more generic controller design, as far as I can tell. There's only going to be the one type of controller.
	if node.name ~= "digtron:controller" then 
		-- Called on an incorrect node
		minetest.log("error", "[Digtron] digtron.assemble called with pos " .. minetest.pos_to_string(root_pos)
			.. " but the node at this location was " .. node.name)
		return nil
	end
	local root_meta = minetest.get_meta(root_pos)
	if root_meta:contains("digtron_id") then
		-- Already assembled. TODO: validate that the digtron_id actually exists as well
		minetest.log("error", "[Digtron] digtron.assemble called with pos " .. minetest.pos_to_string(root_pos)
			.. " but the controller at this location was already part of a assembled Digtron.")
		return nil
	end
	local root_hash = minetest.hash_node_position(root_pos)
	local digtron_nodes = {[root_hash] = node} -- Nodes that are part of Digtron.
		-- Initialize with the controller, it won't be added by get_all_adjacent_digtron_nodes
	local digtron_adjacent = {} -- Nodes that are adjacent to Digtron but not a part of it
	local bounding_box = {minp=vector.new(root_pos), maxp=vector.new(root_pos)}
	get_all_adjacent_digtron_nodes(root_pos, digtron_nodes, digtron_adjacent, bounding_box, player_name)
	
	local digtron_id, digtron_inv = create_new_id(root_pos)
	
	local layout = {}
	
	for hash, node in pairs(digtron_nodes) do
		local relative_hash = hash - root_hash + origin_hash
		local current_meta
		if hash == root_hash then
			current_meta = root_meta -- we're processing the controller, we already have a reference to its meta
		else
			current_meta = minetest.get_meta(minetest.get_position_from_hash(hash))
		end
		
		local current_meta_table = current_meta:to_table()
		
		if current_meta_table.fields.digtron_id then
			-- Trying to incorporate part of an existing digtron, should be impossible.
			minetest.log("error", "[Digtron] digtron.assemble tried to incorporate a Digtron node of type "
				.. node.name .. " at " .. minetest.pos_to_string(minetest.get_position_from_hash(hash))
				.. " that was already assigned to digtron id " .. current_meta_table.fields.digtron_id)
			dispose_id(digtron_id)
			return nil
		end
		-- Process inventories specially
		-- TODO Builder inventory gets turned into an itemname in a special key in the builder's meta
		-- fuel and main get added to corresponding detached inventory lists
		for listname, items in pairs(current_meta_table.inventory) do
			local count = #items
			-- increase the corresponding detached inventory size
			digtron_inv:set_size(listname, digtron_inv:get_size(listname) + count)
			for _, stack in ipairs(items) do
				digtron_inv:add_item(listname, stack)
			end
			-- erase actual items from stored layout metadata, the detached inventory is authoritative
			-- store the inventory size so the inventory can be easily recreated
			current_meta_table.inventory[listname] = #items
		end
		
		local node_def = minetest.registered_nodes[node.name]
		if node_def and node_def._digtron_assembled_node then
			node.name = node_def._digtron_assembled_node
			minetest.swap_node(minetest.get_position_from_hash(hash), node)
		end
			
		node.param1 = nil -- we don't care about param1, wipe it to save space
		layout[relative_hash] = {meta = current_meta_table, node = node}
	end
	
	bounding_box.minp = vector.subtract(bounding_box.minp, root_pos)
	bounding_box.maxp = vector.subtract(bounding_box.maxp, root_pos)
	
	digtron.set_name(digtron_id, root_meta:get_string("infotext"))
	persist_inventory(digtron_id)
	persist_layout(digtron_id, layout)
	persist_adjacent(digtron_id, digtron_adjacent)
	persist_bounding_box(digtron_id, bounding_box)
	persist_pos(digtron_id, root_pos)
	
	-- Wipe out the inventories of all in-world nodes, it's stored in the mod_meta now.
	-- Wait until now to do it in case the above loop fails partway through.
	for hash, node in pairs(digtron_nodes) do
		local node_meta
		if hash == root_hash then
			node_meta = root_meta -- we're processing the controller, we already have a reference to its meta
		else
			node_meta = minetest.get_meta(minetest.get_position_from_hash(hash))
		end
		local inv = node_meta:get_inventory()
		
		for listname, items in pairs(inv:get_lists()) do
			for i = 1, #items do
				inv:set_stack(listname, i, ItemStack(""))
			end
		end
		
		node_meta:set_string("digtron_id", digtron_id)
		node_meta:mark_as_private("digtron_id")
	end

	minetest.log("action", "Digtron " .. digtron_id .. " assembled at " .. minetest.pos_to_string(root_pos)
		.. " by " .. player_name)
	minetest.sound_play("digtron_machine_assemble", {gain = 0.5, pos=root_pos})
	
	return digtron_id
end


-- Returns pos, node, and meta for the digtron node provided the in-world node matches the layout
-- returns nil otherwise
local get_valid_data = function(digtron_id, root_hash, hash, data, function_name)
	local node_hash = hash + root_hash - origin_hash -- TODO may want to return this as well?
	local node_pos = minetest.get_position_from_hash(node_hash)
	local node = minetest.get_node(node_pos)
	local node_meta = minetest.get_meta(node_pos)
	local target_digtron_id = node_meta:get_string("digtron_id")

	if data.node.name ~= node.name then
		minetest.log("error", "[Digtron] " .. function_name .. " tried interacting with one of ".. digtron_id .. "'s "
			.. data.node.name .. "s at " .. minetest.pos_to_string(node_pos) .. " but the node at that location was of type "
			.. node.name)
		return
	elseif target_digtron_id ~= digtron_id then
		if target_digtron_id ~= "" then
			minetest.log("error", "[Digtron] " .. function_name .. " tried interacting with ".. digtron_id .. "'s "
				.. data.node.name .. " at " .. minetest.pos_to_string(node_pos)
				.. " but the node at that location had a non-matching digtron_id value of \""
				.. target_digtron_id .. "\"")
			return
		else
			-- Allow digtron to recover from bad map metadata writes, the bane of Digtron 1.0's existence
			minetest.log("warning", "[Digtron] " .. function_name .. " tried interacting with ".. digtron_id .. "'s "
				.. data.node.name .. " at " .. minetest.pos_to_string(node_pos)
				.. " but the node at that location had no digtron_id in its metadata. "
				.. "Since the node type matched the layout, however, it was included anyway. It's possible "
				.. "its metadata was not written correctly by a previous Digtron activity.")
			return node_pos, node, node_meta
		end
	end
	return node_pos, node, node_meta
end

-- Turns the Digtron back into pieces
digtron.disassemble = function(digtron_id, player_name)
	local bbox = retrieve_bounding_box(digtron_id)
	local root_pos = retrieve_pos(digtron_id)

	local root_meta = minetest.get_meta(root_pos)
	root_meta:set_string("infotext", digtron.get_name(digtron_id))
	
	local layout = retrieve_layout(digtron_id)
	local inv = digtron.retrieve_inventory(digtron_id)
	
	if not (layout and inv) then
		minetest.log("error", "digtron.disassemble was unable to find either layout or inventory record for " .. digtron_id
			.. ", disassembly was impossible. Clearing any other remaining data for this id.")
		dispose_id(digtron_id)
		return
	end
	
	local root_hash = minetest.hash_node_position(root_pos)
	
	-- Write metadata and inventory to in-world node at this location
	for hash, data in pairs(layout) do
		local node_pos, node, node_meta = get_valid_data(digtron_id, root_hash, hash, data, "digtron.disassemble")
	
		if node_pos then
			local node_inv = node_meta:get_inventory()
			for listname, size in pairs(data.meta.inventory) do
				node_inv:set_size(listname, size)
				for i, itemstack in ipairs(inv:get_list(listname)) do
					-- add everything, putting leftovers back in the main inventory
					inv:set_stack(listname, i, node_inv:add_item(listname, itemstack))
				end
			end
			
			local node_def = minetest.registered_nodes[node.name]
			if node_def and node_def._digtron_disassembled_node then
				minetest.swap_node(node_pos, {name=node_def._digtron_disassembled_node, param2=node.param2})
			end
			
			-- TODO: special handling for builder node inventories

			-- Ensure node metadata fields are all set, too
			for field, value in pairs(data.meta.fields) do
				node_meta:set_string(field, value)
			end
			
			-- Clear digtron_id, this node is no longer part of an active digtron
			node_meta:set_string("digtron_id", "")
		end
	end	

	minetest.log("action", "Digtron " .. digtron_id .. " disassembled at " .. minetest.pos_to_string(root_pos)
		.. " by " .. player_name)
	minetest.sound_play("digtron_machine_disassemble", {gain = 0.5, pos=root_pos})

	dispose_id(digtron_id)

	return root_pos
end

-- Removes the in-world nodes of a digtron
-- Does not destroy its layout info
-- returns a table of vectors of all the nodes that were removed
digtron.remove_from_world = function(digtron_id, root_pos, player_name)
	local layout = retrieve_layout(digtron_id)
	
	if not layout then
		minetest.log("error", "Unable to find layout record for " .. digtron_id
			.. ", wiping any remaining metadata for this id to prevent corruption. Sorry!")
		local meta = minetest.get_meta(root_pos)
		meta:set_string("digtron_id", "")
		dispose_id(digtron_id)
		return {}
	end
	
	local root_hash = minetest.hash_node_position(root_pos)
	local nodes_to_destroy = {}
	for hash, data in pairs(layout) do
		local node_pos, node, node_meta = get_valid_data(digtron_id, root_hash, hash, data, "digtron.destroy")
		if node_pos then
			table.insert(nodes_to_destroy, node_pos)
		end
	end
	
	-- TODO: voxelmanip might be better here?
	minetest.bulk_set_node(nodes_to_destroy, {name="air"})
	dispose_pos(digtron_id)
	return nodes_to_destroy
end

-- Tests if a Digtron can be built at the designated location
--TODO implement ignore_nodes, needed for ignoring nodes that have been flagged as dug
digtron.is_buildable_to = function(digtron_id, root_pos, player_name, ignore_nodes, return_immediately_on_failure)
	local layout = retrieve_layout(digtron_id)
	
	-- If this digtron is already in-world, we're likely testing as part of a movement attempt.
	-- Record its existing node locations, they will be treated as buildable_to
	local old_pos = retrieve_pos(digtron_id)
	local old_hashes = {}
	if old_pos then
		local old_root_hash = minetest.hash_node_position(old_pos)
		local old_root_minus_origin = old_root_hash - origin_hash
		for layout_hash, _ in pairs(layout) do
			old_hashes[layout_hash + old_root_minus_origin] = true
		end
	end
	
	local root_hash = minetest.hash_node_position(root_pos)
	local root_minus_origin = root_hash - origin_hash
	local succeeded = {}
	local failed = {}	
	local permitted = true
	
	for layout_hash, data in pairs(layout) do
		local node_hash = layout_hash + root_minus_origin
		local node_pos = minetest.get_position_from_hash(node_hash)
		local node = minetest.get_node(node_pos)
		local node_def = minetest.registered_nodes[node.name]
		-- TODO: lots of testing needed here
		if not ((node_def and node_def.buildable_to) or old_hashes[node_hash]) then
			if return_immediately_on_failure then
				return false -- no need to test further, don't return node positions
			else
				permitted = false
				table.insert(failed, node_pos)
			end
		elseif not return_immediately_on_failure then
			table.insert(succeeded, node_pos)
		end
	end
	
	return permitted, succeeded, failed
end

-- Places the Digtron into the world.
digtron.build_to_world = function(digtron_id, root_pos, player_name)
	local layout = retrieve_layout(digtron_id)
	local root_hash = minetest.hash_node_position(root_pos)
		
	for hash, data in pairs(layout) do
		local node_pos = minetest.get_position_from_hash(hash + root_hash - origin_hash)
		minetest.set_node(node_pos, data.node)
		local meta = minetest.get_meta(node_pos)
		for field, value in pairs(data.meta.fields) do
			meta:set_string(field, value)
		end
		meta:set_string("digtron_id", digtron_id)
		meta:mark_as_private("digtron_id")
	end
	local bbox = retrieve_bounding_box(digtron_id)
	persist_bounding_box(digtron_id, bbox)
	persist_pos(digtron_id, root_pos)
	
	return true
end

digtron.move = function(digtron_id, dest_pos, player_name)
	minetest.chat_send_all("move attempt")
	local current_pos = retrieve_pos(digtron_id)
	if current_pos == nil then
		minetest.chat_send_all("no pos recorded for digtron")
		return
	end
	local permitted, succeeded, failed = digtron.is_buildable_to(digtron_id, dest_pos, player_name)
	if permitted then
		local removed = digtron.remove_from_world(digtron_id, current_pos, player_name)
		digtron.build_to_world(digtron_id, dest_pos, player_name)
		minetest.sound_play("digtron_truck", {gain = 0.5, pos=dest_pos})
		for _, removed_pos in ipairs(removed) do
			minetest.check_for_falling(removed_pos)
		end
	else
		digtron.show_buildable_nodes({}, failed)
		minetest.sound_play("digtron_squeal", {gain = 0.5, pos=current_pos})
	end	
end


---------------------------------------------------------------------------------
-- Misc

-- If the digtron node has an assigned ID and a layout for that ID exists and
-- a matching node exists in the layout then don't let it be dug.
-- TODO: add protection check?
digtron.can_dig = function(pos, digger)
	local meta = minetest.get_meta(pos)
	local digtron_id = meta:get_string("digtron_id")
	if digtron_id == "" then
		return true
	end

	local node = minetest.get_node(pos)
	
	local bbox = retrieve_bounding_box(digtron_id)
	local root_pos = retrieve_pos(digtron_id)
	local layout = retrieve_layout(digtron_id)
	if bbox == nil or root_pos == nil or layout == nil then
		-- Somehow, this belongs to a digtron id that's missing information that should exist in persistence.
		local missing = ""
		if bbox == nil then missing = missing .. "bounding_box " end
		if root_pos == nil then missing = missing .. "root_pos " end
		if layout == nil then missing = missing .. "layout " end
		
		minetest.log("error", "[Digtron] can_dig was called on a " .. node.name .. " at location "
			.. minetest.pos_to_string(pos) .. " that claimed to belong to " .. digtron_id
			.. ". However, layout and/or location data are missing: " .. missing)
		-- May be better to do this to prevent node duplication. But we're already in bug land here so tread gently.
		--minetest.remove_node(pos)
		--return false
		return true
	end
	
	local root_hash = minetest.hash_node_position(root_pos)
	local here_hash = minetest.hash_node_position(pos)
	local layout_hash = here_hash - root_hash + origin_hash
	local layout_data = layout[layout_hash]
	if layout_data == nil or layout_data.node == nil then
		minetest.log("error", "[Digtron] can_dig was called on a " .. node.name .. " at location "
			.. minetest.pos_to_string(pos) .. " that claimed to belong to " .. digtron_id
			.. ". However, the layout for that digtron_id didn't contain any corresponding node at its location.")
		return true
	end
	if layout_data.node.name ~= node.name or layout_data.node.param2 ~= node.param2 then
		minetest.log("error", "[Digtron] can_dig was called on a " .. node.name .. " with param2 "
			.. node.param2 .." at location " .. minetest.pos_to_string(pos) .. " that belonged to " .. digtron_id
			.. ". However, the layout for that digtron_id contained a " .. layout_data.node.name
			.. "with param2 ".. layout_data.node.param2 .. " at its location.")
		return true
	end
	
	-- We're part of a valid Digtron. No touchy.
	return false
end

-- put this on all Digtron nodes. If other inventory types are added (eg, batteries)
-- update this.
digtron.on_blast = function(pos, intensity)
	if intensity < 1.0 then return end -- The Almighty Digtron ignores weak-ass explosions

	local meta = minetest.get_meta(pos)
	local digtron_id = meta:get_string("digtron_id")
	if digtron_id ~= "" then
		if not digtron.disassemble(digtron_id, "an explosion") then
			minetest.log("error", "[Digtron] a digtron node at " .. minetest.pos_to_string(pos)
				.. " was hit by an explosion and had digtron_id " .. digtron_id
				.. " but didn't have a root position recorded, so it could not be disassembled.")
			return
		end
	end

	local drops = {}
	default.get_inventory_drops(pos, "main", drops)
	default.get_inventory_drops(pos, "fuel", drops)
	local node = minetest.get_node(pos)
	table.insert(drops, ItemStack(node.name))	
	minetest.remove_node(pos)
	return drops
end


------------------------------------------------------------------------------------
-- Creative trash

-- This is wrapped in an after() call as a workaround for to https://github.com/minetest/minetest/issues/8827
if minetest.get_modpath("creative") then
	minetest.after(1, function()
		if minetest.get_inventory({type="detached", name="creative_trash"}) then
			if minetest.remove_detached_inventory("creative_trash") then
				-- Create the trash field
				local trash = minetest.create_detached_inventory("creative_trash", {
					-- Allow the stack to be placed and remove it in on_put()
					-- This allows the creative inventory to restore the stack
					allow_put = function(inv, listname, index, stack, player)
						return stack:get_count()
					end,
					on_put = function(inv, listname, index, stack, player)
						local stack = inv:get_stack(listname, index)
						local stack_meta = stack:get_meta()
						local digtron_id = stack_meta:get_string("digtron_id")
						if digtron_id ~= "" then
							minetest.log("action", player:get_player_name() .. " disposed of " .. digtron_id
								.. " in the creative inventory's trash receptacle.")
							dispose_id(digtron_id)
						end
						inv:set_list(listname, {})
					end,
				})
				trash:set_size("main", 1)
			end
		end
	end)
end
