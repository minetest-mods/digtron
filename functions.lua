local mod_meta = digtron.mod_meta

local cache = {}

-- internationalization boilerplate
local MP = minetest.get_modpath(minetest.get_current_modname())
local S, NS = dofile(MP.."/intllib.lua")


--minetest.debug(dump(mod_meta:to_table()))

-- Wipes mod_meta
--for field, value in pairs(mod_meta:to_table().fields) do
--	mod_meta:set_string(field, "")
--end

local damage_hp = digtron.config.damage_hp
-- see predict_dig for how punch_data gets calculated
local damage_creatures = function(root_pos, punch_data, items_dropped)
	local target_pos = punch_data[2]
	local objects = minetest.env:get_objects_inside_radius(target_pos, 1.0)
	if objects ~= nil then
		local source_pos = vector.add(minetest.get_position_from_hash(punch_data[1]), root_pos)
		for _, obj in ipairs(objects) do
			local dir = vector.normalize(vector.subtract(obj:get_pos(), source_pos))
			local armour_multiplier = 1
			local fleshy_armour = obj:get_armor_groups().fleshy
			if fleshy_armour then
				armour_multiplier = fleshy_armour/100
			end
			if obj:is_player() then
				if obj.add_player_velocity then -- added pretty recently, see https://github.com/minetest/minetest/commit/291e7730cf24ba5081f10b5ddbf2494951333827
					obj:add_player_velocity(dir)
				else
					obj:set_pos(vector.add(obj:get_pos(), vector.multiply(dir,1)))
				end
				obj:set_hp(math.max(obj:get_hp() - damage_hp*armour_multiplier, 0))
			else
				local lua_entity = obj:get_luaentity()
				if lua_entity ~= nil then
					-- suck up items in Digtron's path
					if lua_entity.name == "__builtin:item" then
						table.insert(items_dropped, ItemStack(lua_entity.itemstring))
						lua_entity.itemstring = ""
						obj:remove()
					else
						lua_entity:add_velocity(dir)
						obj:set_hp(math.max(obj:get_hp() - damage_hp*armour_multiplier, 0))
					end
				end
			end
		end
	end
	-- If we killed any mobs they might have dropped some stuff, vacuum that up now too.
	objects = minetest.env:get_objects_inside_radius(target_pos, 1.0)
	if objects ~= nil then
		for _, obj in ipairs(objects) do
			if not obj:is_player() then
				local lua_entity = obj:get_luaentity()
				if lua_entity ~= nil and lua_entity.name == "__builtin:item" then
					table.insert(items_dropped, ItemStack(lua_entity.itemstring))
					lua_entity.itemstring = ""
					obj:remove()
				end
			end
		end		
	end
end

-----------------------------------------------------------------------
-- Inventory

local modpath = minetest.get_modpath(minetest.get_current_modname())
local inventory_functions = dofile(modpath.."/inventories.lua")

local retrieve_inventory = inventory_functions.retrieve_inventory
local persist_inventory = inventory_functions.persist_inventory
local get_predictive_inventory = inventory_functions.get_predictive_inventory
local commit_predictive_inventory = inventory_functions.commit_predictive_inventory
local clear_predictive_inventory = inventory_functions.clear_predictive_inventory

----------------------------------------------------------------------------
-- Common utility functions

local protection_check = function(pos, player_name)
	if minetest.is_protected(pos, player_name) and
		not minetest.check_player_privs(player_name, "protection_bypass") then
		return true
	end
	return false
end

local function deep_copy(table_in)
	local table_out = {}
	for index, value in pairs(table_in) do
		if type(value) == "table" then
			table_out[index] = deep_copy(value)
		else
			table_out[index] = value
		end
	end
	return table_out
end

--------------------------------------------------------------------------------------

local create_new_id = function()
	local digtron_id = "digtron" .. tostring(math.random(1, 2^21))
	-- It's super unlikely that we'll get a collision, but what the heck - maybe something will go
	-- wrong with the random number source
	while mod_meta:get_string(digtron_id..":layout") ~= "" do
		digtron_id = "digtron" .. tostring(math.random(1, 2^21))
	end
	return digtron_id
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
local get_name = function(digtron_id)
	local digtron_name = mod_meta:get_string(digtron_id..":name")
	if digtron_name == "" then
		return S("Unnamed Digtron")
	else
		return digtron_name
	end
end

local set_name = function(digtron_id, digtron_name)
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
		return nil
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
local persist_pos, retrieve_pos, dispose_pos = get_table_functions("pos")
local persist_sequence, retrieve_sequence = get_table_functions("sequence")
local persist_step, retrieve_step = get_table_functions("step") -- actually just an integer, but table_functions works for that too

-------------------------------------------------------------------------------------------------------
-- Layout creation helpers

digtron.duplicate = function(digtron_id)
	local layout = retrieve_layout(digtron_id)
	if layout == nil then
		minetest.log("error", "[Digtron] digtron.duplicate called with non-existent id " .. digtron_id)
		return
	end
	local new_layout = deep_copy(layout) -- make a copy because persist_layout caches its parameter as-is
	local new_id = create_new_id()
	local new_name = S("Copy of @1", get_name(digtron_id))
	persist_layout(new_id, new_layout)
	set_name(new_id, new_name)
	
	local old_inv = retrieve_inventory(digtron_id)
	local new_inv = retrieve_inventory(new_id)
	for inv_name, item_list in pairs(old_inv:get_lists()) do
		-- Don't copy inventory contents, just copy sizes
		new_inv:set_size(inv_name, #item_list)
	end
	persist_inventory(new_id)
	
	local new_controller = ItemStack("digtron:controller")
	local meta = new_controller:get_meta()
	meta:set_string("digtron_id", new_id)
	meta:set_string("description", new_name)
	return new_controller
end

-- recursive function searches out all connected unassigned digtron nodes
local get_all_digtron_nodes
get_all_digtron_nodes = function(pos, digtron_nodes, digtron_adjacent, player_name)
	for _, dir in ipairs(digtron.cardinal_dirs) do
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
					get_all_digtron_nodes(test_pos, digtron_nodes, digtron_adjacent, player_name) -- recurse
				end
			else
				-- don't record details, just keeping track of Digtron's borders
				digtron_adjacent[test_hash] = true
			end
		end		
	end
end

-------------------------------------------------------------------------------------------------
-- Cache-only data, not persisted

cache_bounding_box = {}
local update_bounding_box = function(bounding_box, pos)
	bounding_box.minp.x = math.min(bounding_box.minp.x, pos.x)
	bounding_box.minp.y = math.min(bounding_box.minp.y, pos.y)
	bounding_box.minp.z = math.min(bounding_box.minp.z, pos.z)
	bounding_box.maxp.x = math.max(bounding_box.maxp.x, pos.x)
	bounding_box.maxp.y = math.max(bounding_box.maxp.y, pos.y)
	bounding_box.maxp.z = math.max(bounding_box.maxp.z, pos.z)
end
local retrieve_bounding_box = function(digtron_id)
	local val = cache_bounding_box[digtron_id]
	if val then return val end
	
	local layout = retrieve_layout(digtron_id)
	if layout == nil then return nil end

	local bbox = {minp = {x=0, y=0, z=0}, maxp = {x=0, y=0, z=0}}
	for hash, data in pairs(layout) do
		update_bounding_box(bbox, minetest.get_position_from_hash(hash))
	end
	cache_bounding_box[digtron_id] = bbox
	return bbox	
end

cache_all_adjacent_pos = {}
cache_all_digger_targets = {}
cache_all_builder_targets = {}
local refresh_adjacent = function(digtron_id)
	local layout = retrieve_layout(digtron_id)
	if layout == nil then return nil end
	
	local adjacent = {} -- all adjacent nodes. TODO: if implementing traction wheels, won't be needed
	local adjacent_to_diggers = {}
	local adjacent_to_builders = {}
	for hash, data in pairs(layout) do
		for _, dir_hash in ipairs(digtron.cardinal_dirs_hash) do
			local potential_adjacent = hash + dir_hash
			if layout[potential_adjacent] == nil then
				adjacent[potential_adjacent] = true
			end
		end
		
		local digtron_group = minetest.get_item_group(data.node.name, "digtron")
		
		-- Diggers
		if digtron_group >= 10 and digtron_group <= 13 then
			-- All diggers target the node directly in front of them
			local dir_hashes = {}
			local dir_hash = digtron.facedir_to_dir_hash(data.node.param2)
			local potential_target = hash + dir_hash -- pointed at this hash
			if layout[potential_target] == nil then -- not pointed at another Digtron node
				table.insert(dir_hashes, dir_hash)
			end
			
			-- If it's a dual digger, add a second dir
			if digtron_group == 11 or digtron_group == 13 then
				dir_hash = digtron.facedir_to_down_hash(data.node.param2)
				potential_target = hash + dir_hash -- pointed at this hash
				if layout[potential_target] == nil then -- not pointed at another Digtron node
					table.insert(dir_hashes, dir_hash)
				end
			end
			
			local soft = nil
			-- if it's a soft digger note that fact.
			if digtron_group == 12 or digtron_group == 13 then
				soft = true
			end
			
			if #dir_hashes > 0 then
				local fields = data.meta.fields
				adjacent_to_diggers[hash] = {
					period = tonumber(fields.period) or 1,
					offset = tonumber(fields.offset) or 0,
					dir_hashes = dir_hashes,
					soft = soft,
				}
			end			
		end
		
		-- Builders
		if digtron_group == 4 then
			local dir_hash = digtron.facedir_to_dir_hash(data.node.param2)
			local potential_target = hash + dir_hash
			if layout[potential_target] == nil then
				local fields = data.meta.fields
				-- TODO: trace extrusion and if it intersects Digtron layout cap it there.
				adjacent_to_builders[hash] = {
					period = tonumber(fields.period) or 1,
					offset = tonumber(fields.offset) or 0,
					item = fields.item,
					facing = tonumber(fields.facing) or 0, -- facing of built node
					extrusion = tonumber(fields.extrusion) or 1,
					dir_hash = dir_hash, -- Record in table form, it'll be more convenient for use later
				}
			end
		end
	end
	cache_all_adjacent_pos[digtron_id] = adjacent
	cache_all_digger_targets[digtron_id] = adjacent_to_diggers
	cache_all_builder_targets[digtron_id] = adjacent_to_builders	
end
local retrieve_all_adjacent_pos = function(digtron_id)
	local val = cache_all_adjacent_pos[digtron_id]
	if val then return val end
	refresh_adjacent(digtron_id)
	return cache_all_adjacent_pos[digtron_id]
end
local retrieve_all_digger_targets = function(digtron_id)
	local val = cache_all_digger_targets[digtron_id]
	if val then return val end
	refresh_adjacent(digtron_id)
	return cache_all_digger_targets[digtron_id]
end
local retrieve_all_builder_targets = function(digtron_id)
	local val = cache_all_builder_targets[digtron_id]
	if val then return val end
	refresh_adjacent(digtron_id)
	return cache_all_builder_targets[digtron_id]
end

-- call this whenever a stored layout is modified (eg, by rotating it)
-- automatically called on dispose
local invalidate_layout_cache = function(digtron_id)
	cache_bounding_box[digtron_id] = nil
	cache_all_adjacent_pos[digtron_id] = nil
	cache_all_digger_targets[digtron_id] = nil
	cache_all_builder_targets[digtron_id] = nil
end
table.insert(dispose_callbacks, invalidate_layout_cache)

--------------------------------------------------------------------------------------------------------
-- assemble and disassemble

-- Returns the id of the new Digtron record, or nil on failure
local assemble = function(root_pos, player_name)
	local root_node = minetest.get_node(root_pos)
		
	local root_meta = minetest.get_meta(root_pos)
	if root_meta:contains("digtron_id") then
		-- Already assembled. TODO: validate that the digtron_id actually exists as well
		minetest.log("error", "[Digtron] digtron.assemble called with pos " .. minetest.pos_to_string(root_pos)
			.. " but the controller at this location was already part of a assembled Digtron.")
		return nil
	end
	local digtron_name = root_meta:get_string("infotext")
	
	-- This should be called on an unassembled node.
	if root_node.name ~= "digtron:controller_unassembled" then
		-- Called on an incorrect node
		minetest.log("error", "[Digtron] digtron.assemble called with pos " .. minetest.pos_to_string(root_pos)
			.. " but the node at this location was " .. root_node.name)
		return nil
	end
	
	local root_hash = minetest.hash_node_position(root_pos)
	local digtron_nodes = {[root_hash] = root_node} -- Nodes that are part of Digtron.
		-- Initialize with the controller, it won't be added by get_all_adjacent_digtron_nodes
	local digtron_adjacent = {} -- Nodes that are adjacent to Digtron but not a part of it.
	-- There's a slight inefficiency in throwing away digtron_adjacent when retrieve_all_adjacent_pos could
	-- use this info, but it's small and IMO not worth the complexity.
	get_all_digtron_nodes(root_pos, digtron_nodes, digtron_adjacent, player_name)
	
	local digtron_id = create_new_id(root_pos)
	local digtron_inv = retrieve_inventory(digtron_id)
	
	local layout = {}
	
	for hash, node in pairs(digtron_nodes) do
		local relative_hash = minetest.hash_node_position(vector.subtract(minetest.get_position_from_hash(hash), root_pos))
		
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
	
	persist_inventory(digtron_id)
	persist_layout(digtron_id, layout)
	set_name(digtron_id, digtron_name)
	invalidate_layout_cache(digtron_id)
	persist_pos(digtron_id, root_pos)
	persist_sequence(digtron_id, {{cmd="dmb",cnt=1}}) -- TODO find a better place to set a default like this
	
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
local get_valid_data = function(digtron_id, root_pos, hash, data, function_name)
	local node_pos = vector.add(minetest.get_position_from_hash(hash), root_pos)
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
			node_meta:set_string("digtron_id", digtron_id)
			node_meta:mark_as_private("digtron_id")
			return node_pos, node, node_meta
		end
	end
	return node_pos, node, node_meta
end

-- Turns the Digtron back into pieces
local disassemble = function(digtron_id, player_name)
	local root_pos = retrieve_pos(digtron_id)
	if not root_pos then
		minetest.log("error", "[Digtron] digtron.disassemble was unable to find a position for " .. digtron_id
			.. ", disassembly was impossible. Has the digtron been removed from world?")
		return
	end

	local layout = retrieve_layout(digtron_id)
	local inv = retrieve_inventory(digtron_id)
	
	if not (layout and inv) then
		minetest.log("error", "[Digtron] digtron.disassemble was unable to find either layout or inventory record for " .. digtron_id
			.. ", disassembly was impossible. Clearing any other remaining data for this id.")
		dispose_id(digtron_id)
		return
	end
	
	-- Write metadata and inventory to in-world node at this location
	for hash, data in pairs(layout) do
		local node_pos, node, node_meta = get_valid_data(digtron_id, root_pos, hash, data, "disassemble")
	
		if node_pos then
			local node_inv = node_meta:get_inventory()
			for listname, size in pairs(data.meta.inventory) do
				node_inv:set_size(listname, size)
				local digtron_inv_list = inv:get_list(listname)
				if digtron_inv_list then
					for i, itemstack in ipairs(digtron_inv_list) do
						-- add everything, putting leftovers back in the main inventory
						inv:set_stack(listname, i, node_inv:add_item(listname, itemstack))
					end
				else
					minetest.log("warning", "[Digtron] inventory list " .. listname .. " existed in " .. node.name
						.. " that was part of " .. digtron_id .. " but was not present in the detached inventory for this digtron."
						.. " This should not have happened, please report an issue to Digtron programmers,"
						.. " but it shouldn't impact digtron disassembly.")
				end
			end
			
			local node_def = minetest.registered_nodes[node.name]
			if node_def and node_def._digtron_disassembled_node then
				minetest.swap_node(node_pos, {name=node_def._digtron_disassembled_node, param2=node.param2})
			end
			
			-- Ensure node metadata fields are all set, too
			for field, value in pairs(data.meta.fields) do
				node_meta:set_string(field, value)
			end
			
			-- Clear digtron_id, this node is no longer part of an active digtron
			node_meta:set_string("digtron_id", "")
		end
	end
	
	-- replace the controller node with the disassembled version
	local root_node = minetest.get_node(root_pos)
	if root_node.name == "digtron:controller" then
		root_node.name = "digtron:controller_disassembled"
		minetest.set_node(root_pos, root_node)
	end
	local root_meta = minetest.get_meta(root_pos)
	root_meta:set_string("infotext", get_name(digtron_id))

	minetest.log("action", "Digtron " .. digtron_id .. " disassembled at " .. minetest.pos_to_string(root_pos)
		.. " by " .. player_name)
	minetest.sound_play("digtron_machine_disassemble", {gain = 0.5, pos=root_pos})

	dispose_id(digtron_id)

	return root_pos
end

------------------------------------------------------------------------------------------
-- Moving Digtrons around

-- Removes the in-world nodes of a digtron
-- Does not destroy its layout info
-- returns a table of vectors of all the nodes that were removed, or nil on failure
local remove_from_world = function(digtron_id, player_name)
	local layout = retrieve_layout(digtron_id)
	local root_pos = retrieve_pos(digtron_id)
	
	if not layout then
		minetest.log("error", "[Digtron] digtron.remove_from_world Unable to find layout record for " .. digtron_id
			.. ", wiping any remaining metadata for this id to prevent corruption. Sorry!")
		if root_pos then
			local meta = minetest.get_meta(root_pos)
			meta:set_string("digtron_id", "")
		end
		dispose_id(digtron_id)
		return nil
	end
	
	if not root_pos then
		minetest.log("error", "[Digtron] digtron.remove_from_world Unable to find position for " .. digtron_id
			.. ", it may have already been removed from the world.")
		return nil
	end
	
	local nodes_to_destroy = {}
	for hash, data in pairs(layout) do
		local node_pos = get_valid_data(digtron_id, root_pos, hash, data, "remove_from_world")
		if node_pos then
			table.insert(nodes_to_destroy, node_pos)
		end
	end
	
	minetest.bulk_set_node(nodes_to_destroy, {name="air"})
	dispose_pos(digtron_id)
	return nodes_to_destroy
end

-- Tests if a Digtron can be built at the designated location
local is_buildable_to = function(digtron_id, layout, root_pos, player_name, ignore_nodes, return_immediately_on_failure)
	-- If this digtron is already in-world, we're likely testing as part of a movement attempt.
	-- Record its existing node locations, they will be treated as buildable_to
	local old_root_pos = retrieve_pos(digtron_id)
	local old_layout = retrieve_layout(digtron_id)
	if layout == nil then
		layout = old_layout
	end
	
	local ignore_hashes = {}
	if old_root_pos then
		for hash, _ in pairs(old_layout) do
			local old_hash = minetest.hash_node_position(vector.add(minetest.get_position_from_hash(hash), old_root_pos))		
			ignore_hashes[old_hash] = true
		end
	end
	if ignore_nodes then
		for _, ignore_pos in ipairs(ignore_nodes) do
			ignore_hashes[minetest.hash_node_position(ignore_pos)] = true
		end
	end
	
	local succeeded = {}
	local failed = {}	
	local permitted = true
	
	for hash, data in pairs(layout) do
		-- Don't use get_valid_data, the Digtron isn't in-world yet
		local node_pos = vector.add(minetest.get_position_from_hash(hash), root_pos)
		local node_hash = minetest.hash_node_position(node_pos)
		local node = minetest.get_node(node_pos)
		local node_def = minetest.registered_nodes[node.name]
		if not (
			(node_def and node_def.buildable_to)
			or ignore_hashes[node_hash]) or
			protection_check(node_pos, player_name)
		then
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
local build_to_world = function(digtron_id, layout, root_pos, player_name)
	if layout == nil then
		layout = retrieve_layout(digtron_id)
	end
	local built_positions = {}
	for hash, data in pairs(layout) do
		-- Don't use get_valid_data, the Digtron isn't in-world yet
		local node_pos = vector.add(minetest.get_position_from_hash(hash), root_pos)
		minetest.set_node(node_pos, data.node)
		local meta = minetest.get_meta(node_pos)
		for field, value in pairs(data.meta.fields) do
			meta:set_string(field, value)
		end
		meta:set_string("digtron_id", digtron_id)
		meta:mark_as_private("digtron_id")
		table.insert(built_positions, node_pos)
	end
	persist_pos(digtron_id, root_pos)
	
	return built_positions
end

local move = function(digtron_id, dest_pos, player_name)
	local layout = retrieve_layout(digtron_id)
	local permitted, succeeded, failed = is_buildable_to(digtron_id, layout, dest_pos, player_name)
	if permitted then
		local removed = remove_from_world(digtron_id, player_name)
		if removed then
			build_to_world(digtron_id, layout, dest_pos, player_name)
			minetest.sound_play("digtron_truck", {gain = 0.5, pos=dest_pos})
			for _, removed_pos in ipairs(removed) do
				minetest.check_for_falling(removed_pos)
			end
		end
	else
		digtron.show_buildable_nodes({}, failed)
		minetest.sound_play("digtron_squeal", {gain = 0.5, pos=dest_pos})
	end	
end



------------------------------------------------------------------------
-- Rotation

local rotate_layout = function(digtron_id, axis)
	local layout = retrieve_layout(digtron_id)
	local axis_hash = minetest.hash_node_position(axis)
	local rotated_layout = {}
	for hash, data in pairs(layout) do
		local duplicate_data = deep_copy(data)
		-- Facings
		local node_name = duplicate_data.node.name
		local node_def = minetest.registered_nodes[node_name]
		if node_def.paramtype2 == "wallmounted" then
			duplicate_data.node.param2 = digtron.rotate_wallmounted(axis_hash, duplicate_data.node.param2)
		elseif node_def.paramtype2 == "facedir" then
			duplicate_data.node.param2 = digtron.rotate_facedir(axis_hash, duplicate_data.node.param2)
		end
		
		-- Rotate builder item facings
		if minetest.get_item_group(node_name, "digtron") == 4 then
			local build_item = duplicate_data.meta.fields.item
			local build_item_def = minetest.registered_items[build_item]
			if build_item_def.paramtype2 == "wallmounted" then
				duplicate_data.meta.fields.facing = digtron.rotate_wallmounted(axis_hash, tonumber(duplicate_data.meta.fields.facing))
			elseif build_item_def.paramtype2 == "facedir" then
				duplicate_data.meta.fields.facing = digtron.rotate_facedir(axis_hash, tonumber(duplicate_data.meta.fields.facing))
			end
		end
		
		-- Position
		local pos = minetest.get_position_from_hash(hash)
		pos = digtron.rotate_pos(axis_hash, pos)
		local new_hash = minetest.hash_node_position(pos)
		rotated_layout[new_hash] = duplicate_data
	end
	
	return rotated_layout
end

local rotate = function(digtron_id, axis, player_name)
	local rotated_layout = rotate_layout(digtron_id, axis)
	local root_pos = retrieve_pos(digtron_id)
	local permitted, succeeded, failed = is_buildable_to(digtron_id, rotated_layout, root_pos, player_name)
	if permitted then
		local removed = remove_from_world(digtron_id, player_name)
		if removed then
			build_to_world(digtron_id, rotated_layout, root_pos, player_name)
			minetest.sound_play("digtron_hydraulic", {gain = 0.5, pos=dest_pos})
			persist_layout(digtron_id, rotated_layout)
			-- Don't need to do fancy callback checking for digtron nodes since I made all those
			-- nodes and I know they don't have anything that needs to be done for them.
			-- Just check for falling nodes.
			for _, removed_pos in ipairs(removed) do
				minetest.check_for_falling(removed_pos)
			end
		end
	else
		digtron.show_buildable_nodes({}, failed)
		minetest.sound_play("digtron_squeal", {gain = 0.5, pos=root_pos})
	end	
end

------------------------------------------------------------------------------------
-- Digging

local is_soft_material = function(target_name)
	if  minetest.get_item_group(target_name, "crumbly") ~= 0 or
		minetest.get_item_group(target_name, "choppy") ~= 0 or
		minetest.get_item_group(target_name, "snappy") ~= 0 or
		minetest.get_item_group(target_name, "oddly_breakable_by_hand") ~= 0 or
		minetest.get_item_group(target_name, "fleshy") ~= 0 then
		return true
	end
	return false
end

local get_material_cost = function(target_name)
	local material_cost = 0
	local in_known_group = false
	if minetest.get_item_group(target_name, "cracky") ~= 0 then
		in_known_group = true
		material_cost = math.max(material_cost, digtron.config.dig_cost_cracky)
	end
	if minetest.get_item_group(target_name, "crumbly") ~= 0 then
		in_known_group = true
		material_cost = math.max(material_cost, digtron.config.dig_cost_crumbly)
	end
	if minetest.get_item_group(target_name, "choppy") ~= 0 then
		in_known_group = true
		material_cost = math.max(material_cost, digtron.config.dig_cost_choppy)
	end
	if not in_known_group then
		material_cost = digtron.config.dig_cost_default
	end
	return material_cost
end

local predict_dig = function(digtron_id, player_name, controlling_coordinate)
	local predictive_inv = get_predictive_inventory(digtron_id)
	local root_pos = retrieve_pos(digtron_id)
	if not (root_pos and predictive_inv) then
		minetest.log("error", "[Digtron] predict_dig failed to retrieve either "
			.."a predictive inventory or a root position for " .. digtron_id)
		return
	end
	
	local leftovers = {}
	local dug_positions = {}
	local cost = 0
	local dug_hashes = {} -- to ensure the same node isn't dug twice
	local punches_thrown
	if damage_hp ~= 0 then
		punches_thrown = {}
	end
	
	for digger_hash, digger_data in pairs(retrieve_all_digger_targets(digtron_id)) do
		for _, dir_hash in ipairs(digger_data.dir_hashes) do
			local target_hash = digger_hash + dir_hash
			if not dug_hashes[target_hash] then
				local target_pos = vector.add(minetest.get_position_from_hash(target_hash), root_pos)
				local target_node = minetest.get_node(target_pos)
				local target_name = target_node.name
				local targetdef = minetest.registered_nodes[target_name]
				if
					(target_pos[controlling_coordinate] + digger_data.offset) % digger_data.period == 0 and -- test periodicity and offset
					minetest.get_item_group(target_name, "digtron") == 0 and
					minetest.get_item_group(target_name, "digtron_protected") == 0 and
					minetest.get_item_group(target_name, "immortal") == 0 and
					(
						targetdef == nil or -- can dig undefined nodes, why not
						targetdef.can_dig == nil or
						targetdef.can_dig(target_pos, minetest.get_player_by_name(player_name))
					) and
					not protection_check(target_pos, player_name)
					and (not digger_data.soft or is_soft_material(target_name))
				then
					if punches_thrown then
						-- storing digger_hash rather than converting it into a vector because
						-- in most cases there won't be something to punch and that calculation can be skipped
						-- convert to digger_pos by adding root_pos
						table.insert(punches_thrown, {digger_hash, target_pos})
					end				
					if target_name ~= "air" then -- TODO: generalise this somehow for liquids and other undiggables
						if digtron.config.uses_resources then
							cost = cost + get_material_cost(target_name)
						end
						local drops = minetest.get_node_drops(target_name, "")
						for _, drop in ipairs(drops) do
							local leftover = predictive_inv:add_item("main", ItemStack(drop))
							if leftover:get_count() > 0 then
								table.insert(leftovers, leftover)
							end
						end
						table.insert(dug_positions, target_pos)
						dug_hashes[target_hash] = true
					end
				end
			end
		end
	end

	return leftovers, dug_positions, cost, punches_thrown
end

-- Removes nodes and records node info so execute_dug_callbacks can be called later
local get_and_remove_nodes = function(nodes_to_dig)
	local ret = {}
	for _, pos in ipairs(nodes_to_dig) do
		local record = {}
		record.pos = pos
		record.node = minetest.get_node(pos)
		record.meta = minetest.get_meta(pos)
		minetest.remove_node(pos)
		table.insert(ret, record)
	end
	return ret
end

local log_dug_nodes = function(nodes_to_dig, digtron_id, root_pos, player_name)
	local nodes_dug_count = #nodes_to_dig
	if nodes_dug_count > 0 then
		local pluralized = "node"
		if nodes_dug_count > 1 then
			pluralized = "nodes"
		end
		minetest.log("action", nodes_dug_count .. " " .. pluralized .. " dug by "
			.. digtron_id .. " near ".. minetest.pos_to_string(root_pos)
			.. " operated by by " .. player_name)
	end
end

-- Execute all the callbacks that would normally be called on a node after it's been dug.
-- This is a separate step from actually removing the nodes because we don't want to execute
-- these until after *everything* has been dug - this can trigger sand falling, we don't
-- want that getting in the way of nodes yet to be built.
local execute_dug_callbacks = function(nodes_dug)
	-- Execute various on-dig callbacks for the nodes that Digtron dug
	for _, dug_data in ipairs(nodes_dug) do
		local old_pos = dug_data.pos
		local old_node = dug_data.node
		local old_name = old_node.name

		for _, callback in ipairs(minetest.registered_on_dignodes) do
			-- Copy pos and node because callback can modify them
			local pos_copy = {x=old_pos.x, y=old_pos.y, z=old_pos.z}
			local oldnode_copy = {name=old_name, param1=old_node.param1, param2=old_node.param2}
			callback(pos_copy, oldnode_copy, digtron.fake_player)
		end

		local old_def = minetest.registered_nodes[old_name]
		if old_def ~= nil then
			local old_after_dig = old_def.after_dig_node
			if old_after_dig ~= nil then
				old_after_dig(old_pos, old_node, dug_data.meta, digtron.fake_player)
			end
		end
	end
end

------------------------------------------------------------------------------------------------------
-- Building

-- need to provide root_pos because Digtron moves before building
local predict_build = function(digtron_id, root_pos, player_name, ignore_nodes, controlling_coordinate)
	local predictive_inv = get_predictive_inventory(digtron_id)
	if not predictive_inv then
		minetest.log("error", "[Digtron] predict_build failed to retrieve "
			.."a predictive inventory for " .. digtron_id)
		return
	end

	local ignore_hashes = {}
	if ignore_nodes then
		for _, ignore_pos in ipairs(ignore_nodes) do
			ignore_hashes[minetest.hash_node_position(ignore_pos)] = true
		end
	end
	
	local missing_items = {}
	local built_nodes = {}
	local cost = 0
	
	for target_hash, builder_data in pairs(retrieve_all_builder_targets(digtron_id)) do
		local dir_hash = builder_data.dir_hash
		local periodicity_permitted = nil
		for i = 1, builder_data.extrusion do
			local target_pos = vector.add(minetest.get_position_from_hash(target_hash + i * dir_hash), root_pos)
			if periodicity_permitted == nil then
				-- test periodicity and offset once
				periodicity_permitted = (target_pos[controlling_coordinate] + builder_data.offset) % builder_data.period == 0
				if not periodicity_permitted then
					break -- period/offset doesn't line up with the target
				end
			end
			local target_node = minetest.get_node(target_pos)
			local target_name = target_node.name
			local targetdef = minetest.registered_nodes[target_name]
			if
				ignore_hashes[target_hash] or
				(targetdef ~= nil
					and targetdef.buildable_to
					and not protection_check(target_pos, player_name)
				)
			then
				local item = builder_data.item
				local facing = builder_data.facing
				
				local removed_item = predictive_inv:remove_item("main", ItemStack(item))
				if removed_item:get_count() < 1 then
					missing_items[item] = (missing_items[item] or 0) + 1
				end
				
				if digtron.config.uses_resources then
					cost = cost + digtron.config.build_cost
				end
	
				table.insert(built_nodes, {
					pos = target_pos,
					node = {name=item, param2=facing },
					old_node = target_node,
				})
			else
				break -- extrusion reached an obstacle
			end
		end
	end
	
	return missing_items, built_nodes, cost
end

-- Place all items listed in built_nodes in-world, returning any itemstacks that item_place_node returned.
-- Also returns the number of successes for logging purposes
local build_nodes = function(built_nodes)
	local leftovers = {}
	local success_count = 0
	for _, build_info in ipairs(built_nodes) do
		local item_stack = ItemStack(build_info.node.name)
		local buildpos = build_info.pos
		local build_facing = build_info.node.param2
		local returned_stack, success = digtron.item_place_node(item_stack, digtron.fake_player, buildpos, build_facing)
		if success then
			success_count = success_count + 1
		end
		if returned_stack:get_count() > 0 then
			table.insert(leftovers, returned_stack)
		end
	end
	return leftovers, success_count
end

local log_built_nodes = function(success_count, digtron_id, root_pos, player_name)
	if success_count > 0 then
		local pluralized = "node"
		if success_count > 1 then
			pluralized = "nodes"
		end
		minetest.log("action", success_count .. " " .. pluralized .. " built by "
			.. digtron_id .. " near ".. minetest.pos_to_string(root_pos)
			.. " operated by by " .. player_name)
	end
end

-- Execute all the callbacks that would normally be called on a node after it's been built.
-- This is a separate step from actually placing the nodes because we don't want to execute
-- these until after *everything* has been built - this can trigger sand falling, we don't
-- want that getting in the way of nodes yet to be built.
local execute_built_callbacks = function(built_nodes)
	for _, build_info in ipairs(built_nodes) do
		local new_pos = build_info.pos
		local new_node = build_info.node
		local old_node = build_info.old_node
		for _, callback in ipairs(minetest.registered_on_placenodes) do
			-- Copy pos and node because callback can modify them
			local pos_copy = {x=new_pos.x, y=new_pos.y, z=new_pos.z}
			local oldnode_copy = {name=old_node.name, param1=old_node.param1, param2=old_node.param2}
			local newnode_copy = {name=new_node.name, param1=new_node.param1, param2=new_node.param2}
			callback(pos_copy, newnode_copy, digtron.fake_player, oldnode_copy)
		end
		
		local new_def = minetest.registered_nodes[new_node.name]
		if new_def ~= nil and new_def.after_place_node ~= nil then
			new_def.after_place_node(new_pos, digtron.fake_player)
		end
	end
end

-------------------------------------------------------------------------------------------------------
-- Execute cycle

-- Used to determine which coordinate is being checked for periodicity. eg, if the digtron is moving in the z direction, then periodicity is checked for every n nodes in the z axis.
local get_controlling_coordinate = function(facedir)
	-- used for determining builder period and offset
	local dir = digtron.facedir_to_dir_map[facedir]
	if dir == 1 or dir == 3 then
		return "z"
	elseif dir == 2 or dir == 4 then
		return "x"
	else
		return "y"
	end
end

-- Attempts to insert the item list into the digtron inventory, and whatever doesn't fit
-- gets placed as an item at pos
local insert_or_eject = function(digtron_id, item_list, pos)
	local predictive_inv = get_predictive_inventory(digtron_id)
	if not predictive_inv then
		minetest.log("error", "[Digtron] predict_build failed to retrieve "
			.."a predictive inventory for " .. digtron_id)
		return
	end
	for _, item in ipairs(item_list) do
		local final_leftover = predictive_inv:add_item("main", item)
		minetest.item_drop(final_leftover, digtron.fake_player, pos)
	end
end

-- TODO: the dig_down parameter is a bit hacky, see if I can come up with a better way to arrange this code
local execute_dig_move_build_cycle = function(digtron_id, player_name, dig_down)
	local old_root_pos = retrieve_pos(digtron_id)
	local root_node = minetest.get_node(old_root_pos)
	local root_facedir = root_node.param2
	local controlling_coordinate = get_controlling_coordinate(root_facedir)

	local dig_leftovers, nodes_to_dig, dig_cost, punches_thrown = predict_dig(digtron_id, player_name, controlling_coordinate)
	local new_root_pos
	
	if dig_down then
		new_root_pos = vector.add(old_root_pos, digtron.facedir_to_down(root_facedir))
	else
		new_root_pos = vector.add(old_root_pos, digtron.facedir_to_dir(root_facedir))
	end
	
	local layout = retrieve_layout(digtron_id)
	local buildable_to, succeeded, failed = digtron.is_buildable_to(digtron_id, layout, new_root_pos, player_name, nodes_to_dig)
	local missing_items, built_nodes, build_cost

	if dig_down then
		missing_items = {}
		built_nodes = {}
		build_cost = 0
	else
		missing_items, built_nodes, build_cost = predict_build(digtron_id, new_root_pos, player_name, nodes_to_dig, controlling_coordinate)
	end

	if not buildable_to then
		clear_predictive_inventory(digtron_id)
		digtron.show_buildable_nodes({}, failed)
		minetest.sound_play("digtron_squeal", {gain = 0.5, pos=old_root_pos})	
		minetest.chat_send_player(player_name, S("@1 at @2 has encountered an obstacle.",
			get_name(digtron_id), minetest.pos_to_string(old_root_pos)))
	elseif next(missing_items) ~= nil then
		clear_predictive_inventory(digtron_id)
		local items = {}
		for item, count in ipairs(missing_items) do
			local item_def = minetest.registered_items[item]
			if item_def == nil then -- Shouldn't be a problem, but don't crash if it does happen somehow
				table.insert(items, count .. " " .. item)
			else
				table.insert(items, count .. " " .. item_def.description)
			end
		end
		minetest.chat_send_player(player_name, S("@1 at @2 requires @3 to execute its next build cycle.",
			get_name(digtron_id), minetest.pos_to_string(old_root_pos), table.concat(items, ", ")))
		minetest.sound_play("digtron_dingding", {gain = 0.5, pos=old_root_pos})
	else
		digtron.fake_player:update(old_root_pos, player_name)
		
		-- Removing old nodes
		local removed = digtron.remove_from_world(digtron_id, player_name)
		if removed then
			local nodes_dug = get_and_remove_nodes(nodes_to_dig, player_name)
			log_dug_nodes(nodes_to_dig, digtron_id, old_root_pos, player_name)
			
			local items_dropped = {}
			if punches_thrown then
				for _, punch_data in ipairs(punches_thrown) do
					damage_creatures(old_root_pos, punch_data, items_dropped)
				end
			end
			
			-- Building new Digtron
			digtron.build_to_world(digtron_id, layout, new_root_pos, player_name)
			minetest.sound_play("digtron_construction", {gain = 0.5, pos=new_root_pos})
			
			local build_leftovers, success_count = build_nodes(built_nodes, player_name)
			log_built_nodes(success_count, digtron_id, old_root_pos, player_name)
			
			-- Don't need to do fancy callback checking for digtron nodes since I made all those
			-- nodes and I know they don't have anything that needs to be done for them.
			-- Just check for falling nodes.
			for _, removed_pos in ipairs(removed) do
				minetest.check_for_falling(removed_pos)
			end
	
			-- Must be called after digtron.build_to_world because it triggers falling nodes
			execute_dug_callbacks(nodes_dug)
			execute_built_callbacks(built_nodes)
			
			-- try putting dig_leftovers and build_leftovers into the inventory one last time before ejecting it
			insert_or_eject(digtron_id, dig_leftovers, old_root_pos)
			insert_or_eject(digtron_id, build_leftovers, old_root_pos)
			insert_or_eject(digtron_id, items_dropped, old_root_pos)
		
			commit_predictive_inventory(digtron_id)
		end
	end
end

---------------------------------------------------------------------------------
-- Node callbacks

-- If the digtron node has an assigned ID and a layout for that ID exists and
-- a matching node exists in the layout then don't let it be dug.
local can_dig = function(pos, digger)
	if digger then
		local player_name = digger:get_player_name()
		if protection_check(pos, player_name) then
			return false
		end
	end

	local meta = minetest.get_meta(pos)
	local digtron_id = meta:get_string("digtron_id")
	if digtron_id == "" then
		return true
	end

	local node = minetest.get_node(pos)
	
	local root_pos = retrieve_pos(digtron_id)
	local layout = retrieve_layout(digtron_id)
	if root_pos == nil or layout == nil then
		-- Somehow, this belongs to a digtron id that's missing information that should exist in persistence.
		local missing = ""
		if root_pos == nil then missing = missing .. "root_pos " end
		if layout == nil then missing = missing .. "layout " end
		
		minetest.log("error", "[Digtron] can_dig was called on a " .. node.name .. " at location "
			.. minetest.pos_to_string(pos) .. " that claimed to belong to " .. digtron_id
			.. ". However, layout and/or location data are missing: " .. missing)
		-- TODO May be better to do this to prevent node duplication. But we're already in bug land here so tread gently.
		--minetest.remove_node(pos)
		--return false
		return true
	end
	
	local layout_hash = minetest.hash_node_position(vector.subtract(pos, root_pos))
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
local on_blast = function(pos, intensity)
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

-- Use this inside other on_rightclicks for configuring Digtron nodes, this
-- overrides if you're right-clicking with another Digtron node and assumes
-- that you're trying to build it.
local on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
	local item_def = itemstack:get_definition()
	if item_def.type == "node" and minetest.get_item_group(itemstack:get_name(), "digtron") > 0 then
		local returnstack, success = minetest.item_place_node(itemstack, clicker, pointed_thing)
		if success and item_def.sounds and item_def.sounds.place and item_def.sounds.place.name then
			minetest.sound_play(item_def.sounds.place, {pos = pos})
		end
		return returnstack, success
	end
end

------------------------------------------------------------------------------------
-- Creative trash

-- Catch when someone throws a Digtron controller with an ID into the trash, dispose
-- of the persisted layout.
if minetest.get_modpath("creative") then
	local trash = minetest.detached_inventories["creative_trash"]
	if trash then
		local old_on_put = trash.on_put
		if old_on_put then
			local digtron_on_put = function(inv, listname, index, stack, player)
				local stack = inv:get_stack(listname, index)
				local stack_meta = stack:get_meta()
				local digtron_id = stack_meta:get_string("digtron_id")
				if stack:get_name() == "digtron:controller" and digtron_id ~= "" then
					minetest.log("action", player:get_player_name() .. " disposed of " .. digtron_id
						.. " in the creative inventory's trash receptacle.")
					dispose_id(digtron_id)
				end
				return old_on_put(inv, listname, index, stack, player)
			end
		trash.on_put = digtron_on_put
		end
	end
end

--------------------------------------------------------------------------------------
-- Fallback method for recovering missing metadata
-- If this gets called frequently then something's wrong.

local recover_digtron_id = function(root_pos)
	for field, value in pairs(mod_meta:to_table().fields) do
		local fields = field:split(":")
		if #fields == 2 and fields[2] == "pos" and vector.equals(root_pos, minetest.deserialize(value)) then
			local digtron_id = fields[1]
			minetest.log("warning", "[Digtron] had to use recover_digtron_id to restore "
				..digtron_id .. " to the controller at " .. minetest.pos_to_string(root_pos)
				..". If this happens frequently please file an issue with Digtron's developers. "
				.."recover_digtron_id will now attempt to restore the digtron_id metadata key to all "
				.."nodes in this Digtron's layout.")
			local layout = retrieve_layout(digtron_id)
			for hash, data in pairs(layout) do
				-- get_valid_data will attempt to repair node metadata that's missing digtron_id
				local node_pos, node, node_meta = get_valid_data(digtron_id, root_pos, hash, data, "recover_digtron_id")
			end		
			return true
		end
	end
	return false
end

---------------------------------------------------------------------------------------------------------------------------
-- External API

-- node definition methods
digtron.can_dig = can_dig
digtron.on_blast = on_blast
digtron.on_rightclick = on_rightclick

digtron.get_name = get_name
digtron.set_name = set_name
digtron.get_pos = retrieve_pos
digtron.get_bounding_box = retrieve_bounding_box

-- used by formspecs
digtron.get_inventory = retrieve_inventory
digtron.set_sequence = persist_sequence
digtron.get_sequence = retrieve_sequence
digtron.set_step = persist_step
digtron.get_step = retrieve_step

-- Used by duplicator
digtron.get_layout = retrieve_layout

digtron.assemble = assemble
digtron.disassemble = disassemble
digtron.remove_from_world = remove_from_world
digtron.is_buildable_to = is_buildable_to
digtron.build_to_world = build_to_world
digtron.move = move
digtron.rotate = rotate
digtron.execute_dig_move_build_cycle = execute_dig_move_build_cycle

digtron.recover_digtron_id = recover_digtron_id