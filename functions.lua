local mod_meta = minetest.get_mod_storage()

digtron.layout = {}
digtron.adjacent = {}
digtron.bounding_box = {}

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
	local last_id = mod_meta:get_int("last_id") -- returns 0 when uninitialized, so 0 will never be a valid digtron_id.
	local new_id = last_id + 1
	mod_meta:set_int("last_id", new_id) -- ensure each call to this method gets a unique number
	
	local digtron_id = "digtron" .. tostring(new_id)
	local inv = minetest.create_detached_inventory(digtron_id, detached_inventory_callbacks)
	
	return digtron_id, inv
end

-- Deletes a Digtron record. Note: just throws everything away, this is not digtron.deconstruct.
local dispose_id = function(digtron_id)
	minetest.remove_detached_inventory(digtron_id)
	digtron.layout[digtron_id] = nil
	digtron.adjacent[digtron_id] = nil
	mod_meta:set_string(digtron_id..":inv", "")
	mod_meta:set_string(digtron_id..":layout", "")
	mod_meta:set_string(digtron_id..":adjacent", "")
	mod_meta:set_string(digtron_id..":name", "")
	mod_meta:set_string(digtron_id..":bounding_box", "")
end

--------------------------------------------------------------------------------------------
-- Name

digtron.get_name = function(digtron_id)
	return mod_meta:get_string(digtron_id..":name")
end

digtron.set_name = function(digtron_id, digtron_name)
	mod_meta:set_string(digtron_id..":name", digtron_name)
end

-------------------------------------------------------------------------------------------------------
-- Layout

local get_persist_table_function = function(identifier)
	return function(digtron_id, tbl)
		mod_meta:set_string(digtron_id..":"..identifier, minetest.serialize(tbl))
		digtron[identifier][digtron_id] = tbl
	end
end

local get_retrieve_table_function = function(identifier)
	return function(digtron_id)
		local current = digtron[identifier][digtron_id]
		if current then
			return current
		end
		local tbl_string = mod_meta:get_string(digtron_id..":"..identifier)
		if tbl_string ~= "" then
			current = minetest.deserialize(tbl_string)
			if current then
				digtron[identifier][digtron_id] = current
			end
			return current
		end
	end
end

local persist_layout = get_persist_table_function("layout")
local retrieve_layout = get_retrieve_table_function("layout")
local persist_adjacent = get_persist_table_function("adjacent")
local retrieve_adjacent = get_retrieve_table_function("adjacent")
local persist_bounding_box = get_persist_table_function("bounding_box")
local retrieve_bounding_box = get_retrieve_table_function("bounding_box")

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
-- Construct and deconstruct

local origin_hash = minetest.hash_node_position({x=0,y=0,z=0})

-- Returns the id of the new Digtron record, or nil on failure
digtron.construct = function(root_pos, player_name)
	local node = minetest.get_node(root_pos)
	-- TODO: a more generic test? Not needed with the more generic controller design, as far as I can tell
	if node.name ~= "digtron:controller" then 
		-- Called on an incorrect node
		minetest.log("error", "[Digtron] digtron.construct called with pos " .. minetest.pos_to_string(root_pos)
			.. " but the node at this location was " .. node.name)
		return nil
	end
	local root_meta = minetest.get_meta(root_pos)
	if root_meta:contains("digtron_id") then
		-- Already constructed. TODO: validate that the digtron_id actually exists as well
		minetest.log("error", "[Digtron] digtron.construct called with pos " .. minetest.pos_to_string(root_pos)
			.. " but the controller at this location was already part of a constructed Digtron.")
		return nil
	end
	local root_hash = minetest.hash_node_position(root_pos)
	local digtron_nodes = {[root_hash] = node} -- Nodes that are part of Digtron
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
			minetest.log("error", "[Digtron] digtron.construct tried to incorporate a Digtron node of type "
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
	
	-- Wipe out the inventories of all in-world nodes, it's stored in the mod_meta now.
	-- Wait until now to do it in case the above loop fails partway through.
	for hash, node in pairs(digtron_nodes) do
		local digtron_meta
		if hash == root_hash then
			digtron_meta = root_meta -- we're processing the controller, we already have a reference to its meta
		else
			digtron_meta = minetest.get_meta(minetest.get_position_from_hash(hash))
		end
		local inv = digtron_meta:get_inventory()
		
		for listname, items in pairs(inv:get_lists()) do
			for i = 1, #items do
				inv:set_stack(listname, i, ItemStack(""))
			end
		end
		
		digtron_meta:set_string("digtron_id", digtron_id)
	end
	
	minetest.debug("constructed id " .. digtron_id)
	return digtron_id
end


-- Returns pos, node, and meta for the digtron node provided the in-world node matches the layout
-- returns nil otherwise
local get_valid_data = function(digtron_id, root_hash, hash, data, function_name)
	local ipos = minetest.get_position_from_hash(hash + root_hash - origin_hash)
	local node = minetest.get_node(ipos)
	local imeta = minetest.get_meta(ipos)

	if data.node.name ~= node.name then
		minetest.log("error", "[Digtron] " .. function_name .. " tried interacting with one of ".. digtron_id .. "'s "
			.. data.node.name .. "s at " .. minetest.pos_to_string(ipos) .. " but the node at that location was of type "
			.. node.name)
	elseif imeta:get_string("digtron_id") ~= digtron_id then
		minetest.log("error", "[Digtron] " .. function_name .. " tried interacting with ".. digtron_id .. "'s "
			.. data.node.name .. " at " .. minetest.pos_to_string(ipos)
			.. " but the node at that location had a non-matching digtron_id value of \""
			.. imeta:get_string("digtron_id") .. "\"")
	else
		return ipos, node, imeta
	end
end

-- Turns the Digtron back into pieces
digtron.deconstruct = function(digtron_id, root_pos, player_name)
	local root_meta = minetest.get_meta(root_pos)
	root_meta:set_string("infotext", digtron.get_name(digtron_id))
	
	local layout = retrieve_layout(digtron_id)
	local inv = digtron.retrieve_inventory(digtron_id)
	
	if not (layout and inv) then
		minetest.log("error", "Unable to find layout or inventory record for " .. digtron_id
			.. ", wiping any remaining metadata for this id to prevent corruption. Sorry!")
		dispose_id(digtron_id)
		return
	end
	
	local root_hash = minetest.hash_node_position(root_pos)
	
	-- Write metadata and inventory to in-world node at this location
	for hash, data in pairs(layout) do
		local ipos, node, imeta = get_valid_data(digtron_id, root_hash, hash, data, "digtron.deconstruct")
	
		if ipos then
			local iinv = imeta:get_inventory()
			for listname, size in pairs(data.meta.inventory) do
				iinv:set_size(listname, size)
				for i, itemstack in ipairs(inv:get_list(listname)) do
					-- add everything, putting leftovers back in the main inventory
					inv:set_stack(listname, i, iinv:add_item(listname, itemstack))
				end
			end
			
			-- TODO: special handling for builder node inventories

			-- Ensure node metadata fields are all set, too
			for field, value in pairs(data.meta.fields) do
				imeta:set_string(field, value)
			end
			
			-- Clear digtron_id, this node is no longer part of an active digtron
			imeta:set_string("digtron_id", "")
		end
	end	

	dispose_id(digtron_id)
end

-- Removes the in-world nodes of a digtron
-- Does not destroy its layout info
digtron.remove_from_world = function(digtron_id, root_pos, player_name)
	local layout = retrieve_layout(digtron_id)
	
	if not layout then
		minetest.log("error", "Unable to find layout record for " .. digtron_id
			.. ", wiping any remaining metadata for this id to prevent corruption. Sorry!")
		local meta = minetest.get_meta(root_pos)
		meta:set_string("digtron_id", "")
		dispose_id(digtron_id)
		return
	end
	
	local root_hash = minetest.hash_node_position(root_pos)
	local nodes_to_destroy = {}
	for hash, data in pairs(layout) do
		local ipos, node, imeta = get_valid_data(digtron_id, root_hash, hash, data, "digtron.destroy")
		if ipos then
			table.insert(nodes_to_destroy, ipos)
		end
	end
	
	-- TODO: voxelmanip might be better here?
	minetest.bulk_set_node(nodes_to_destroy, {name="air"})	
end

digtron.build_to_world = function(digtron_id, root_pos, player_name)
	local layout = retrieve_layout(digtron_id)
	local root_hash = minetest.hash_node_position(root_pos)
	local nodes_to_create = {}
	
	local permitted = true
	for hash, data in pairs(layout) do
		local ipos = minetest.get_position_from_hash(hash + root_hash - origin_hash)
		local node = minetest.get_node(ipos)
		local node_def = minetest.registered_nodes[node.name]
		-- TODO: lots of testing needed here
		if not (node_def and node_def.buildable_to) then
			minetest.chat_send_all("not permitted due to " .. node.name .. " at " .. minetest.pos_to_string(ipos))
			permitted = false
			break
		end		
	end

	if permitted then
		-- TODO: voxelmanip might be better here, less likely than with destroy though since metadata needs to be written
		for hash, data in pairs(layout) do
			local ipos = minetest.get_position_from_hash(hash + root_hash - origin_hash)
			minetest.set_node(ipos, data.node)
			local meta = minetest.get_meta(ipos)
			meta:set_string("digtron_id", digtron_id)
			for field, value in pairs(data.meta.fields) do
				meta:set_string(field, value)
			end
			-- Not needed - local inventories not used by active digtron, will be restored if deconstructed
--			local inv = meta:get_inventory()
--			for listname, size in pairs(data.meta.inventory) do
--				inv:set_size(listname, size)
--			end
		end
	end
	
	return permitted
end

---------------------------------------------------------------------------------
-- Misc

digtron.can_dig = function(pos, digger)
	local meta = minetest.get_meta(pos)
	local digtron_id = meta:get_string("digtron_id")
	if mod_meta:contains(digtron_id..":layout") then
		return false
	end
	return true
end
