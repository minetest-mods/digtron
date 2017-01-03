-- A random assortment of methods used in various places in this mod.

digtron = {}

dofile( minetest.get_modpath( "digtron" ) .. "/util_item_place_node.lua" ) -- separated out to avoid potential for license complexity

digtron.find_new_pos = function(pos, facing)
	-- finds the point one node "forward", based on facing
	local dir = minetest.facedir_to_dir(facing)
	local newpos = {}
	newpos.x = pos.x + dir.x
	newpos.y = pos.y + dir.y
	newpos.z = pos.z + dir.z
	return newpos
end

digtron.mark_diggable = function(pos, nodes_dug)
	-- mark the node as dug, if the player provided would have been able to dig it.
	-- Don't *actually* dig the node yet, though, because if we dig a node with sand over it the sand will start falling
	-- and then destroy whatever node we place there subsequently (either by a builder head or by moving a digtron node)
	-- I don't like sand. It's coarse and rough and irritating and it gets everywhere. And it necessitates complicated dig routines.
	-- returns fuel cost and what will be dropped by digging these nodes.

	local target = minetest.get_node(pos)
	
	-- prevent digtrons from being marked for digging.
	if minetest.get_item_group(target.name, "digtron") ~= 0 then
		return 0, nil
	end

	local targetdef = minetest.registered_nodes[target.name]
	if targetdef.can_dig == nil or targetdef.can_dig(pos, player) then 
		nodes_dug:set(pos.x, pos.y, pos.z, true)
		if target.name ~= "air" then
			local in_known_group = false
			local material_cost = 0
			if minetest.get_item_group(target.name, "cracky") ~= 0 then
				in_known_group = true
				material_cost = math.max(material_cost, digtron.dig_cost_cracky)
			end
			if minetest.get_item_group(target.name, "crumbly") ~= 0 then
				in_known_group = true
				material_cost = math.max(material_cost, digtron.dig_cost_crumbly)
			end
			if minetest.get_item_group(target.name, "choppy") ~= 0 then
				in_known_group = true
				material_cost = math.max(material_cost, digtron.dig_cost_choppy)
			end
			if not in_known_group then
				material_cost = digtron.dig_cost_default
			end
	
			return material_cost, minetest.get_node_drops(target.name, "")
		end
	end
	return 0, nil
end
	
digtron.can_build_to = function(pos, protected_nodes, dug_nodes)
	-- Returns whether a space is clear to have something put into it

	if protected_nodes:get(pos.x, pos.y, pos.z) then
		return false
	end

	-- tests if the location pointed to is clear to move something into
	local target = minetest.get_node(pos)
	if target.name == "air" or
	   dug_nodes:get(pos.x, pos.y, pos.z) == true or
	   minetest.registered_nodes[target.name].buildable_to == true
	   then
		return true
	end
	return false
end

digtron.can_move_to = function(pos, protected_nodes, dug_nodes)
	-- Same as can_build_to, but also checks if the current node is part of the digtron.
	-- this allows us to disregard obstructions that *will* move out of the way.
	if digtron.can_build_to(pos, protected_nodes, dug_nodes) == true or
	   minetest.get_item_group(minetest.get_node(pos).name, "digtron") ~= 0 then
		return true
	end
	return false
end

digtron.move_node = function(pos, newpos)
	-- Moves nodes, preserving digtron metadata and inventory
	local node = minetest.get_node(pos)
	minetest.add_node(newpos, { name=node.name, param1=node.param1, param2=node.param2 })

	local oldmeta = minetest.get_meta(pos)
	local oldinv = oldmeta:get_inventory()
	local list = oldinv:get_list("main")
	local oldformspec = oldmeta:get_string("formspec")
	
	local newmeta = minetest.get_meta(newpos)
	local newinv = newmeta:get_inventory()
	newinv:set_list("main", list)
	newmeta:set_string("formspec", oldformspec)
	
	newmeta:set_int("offset", oldmeta:get_int("offset"))
	newmeta:set_int("period", oldmeta:get_int("period"))
	newmeta:set_int("build_facing", oldmeta:get_int("build_facing"))
	newmeta:set_float("fuel_burning", oldmeta:get_float("fuel_burning"))
	newmeta:set_string("infotext", oldmeta:get_string("infotext"))
	
	if minetest.get_item_group(node.name, "digtron") == 4 then
		digtron.update_builder_item(newpos)
	end
	
	-- remove node from old position
	minetest.remove_node(pos)
end

digtron.get_all_digtron_neighbours = function(pos, player)
	-- returns table containing a list of all digtron node locations, lists of special digtron node types, a table of the coordinate extents of the digtron array, a Pointset of protected nodes, and a number to determine how many adjacent solid non-digtron nodes there are (for traction)
	
	local layout = {}
	--initialize. We're assuming that the start position is a controller digtron, should be a safe assumption since only the controller node should call this
	layout.traction = 0
	layout.all = {}
	layout.inventories = {}
	layout.fuelstores = {}
	layout.diggers = {}
	layout.builders = {}
	layout.extents = {}
	layout.protected = Pointset.create() -- if any nodes we look at are protected, make note of that. That way we don't need to keep re-testing protection state later.
	layout.controller = {x=pos.x, y=pos.y, z=pos.z} 	--Make a deep copy of the pos parameter just in case the calling code wants to play silly buggers with it

	table.insert(layout.all, layout.controller)
	layout.extents.max_x = pos.x
	layout.extents.min_x = pos.x
	layout.extents.max_y = pos.y
	layout.extents.min_y = pos.y
	layout.extents.max_z = pos.z
	layout.extents.min_z = pos.z
	
	-- temporary pointsets used while searching
	local to_test = Pointset.create()
	local tested = Pointset.create()

	tested:set(pos.x, pos.y, pos.z, true)
	to_test:set(pos.x + 1, pos.y, pos.z, true)
	to_test:set(pos.x - 1, pos.y, pos.z, true)
	to_test:set(pos.x, pos.y + 1, pos.z, true)
	to_test:set(pos.x, pos.y - 1, pos.z, true)
	to_test:set(pos.x, pos.y, pos.z + 1, true)
	to_test:set(pos.x, pos.y, pos.z - 1, true)
	
	if minetest.is_protected(pos, player:get_player_name()) and not minetest.check_player_privs(player, "protection_bypass") then
		layout.protected:set(pos.x, pos.y, pos.z, true)
	end
	
	-- Do a loop on to_test positions, adding new to_test positions as we find digtron nodes. This is a flood fill operation
	-- that follows node faces (no diagonals)
	local testpos, _ = to_test:pop()
	while testpos ~= nil do
		tested:set(testpos.x, testpos.y, testpos.z, true) -- track nodes we've looked at to prevent infinite loops
		local node = minetest.get_node(testpos)

		if node.name == "ignore" then
			--buildtron array is next to unloaded nodes, too dangerous to do anything. Abort.
			layout.all = nil
			return layout
		end

		if minetest.is_protected(pos, player:get_player_name()) and not minetest.check_player_privs(player, "protection_bypass") then
			layout.protected:set(testpos.x, testpos.y, testpos.z, true)
		end
		
		local group_number = minetest.get_item_group(node.name, "digtron")
		if group_number > 0 then
			--found one. Add it to the digtrons output
			table.insert(layout.all, testpos)
		
			-- update extents
			layout.extents.max_x = math.max(layout.extents.max_x, testpos.x)
			layout.extents.min_x = math.min(layout.extents.min_x, testpos.x)
			layout.extents.max_y = math.max(layout.extents.max_y, testpos.y)
			layout.extents.min_y = math.min(layout.extents.min_y, testpos.y)
			layout.extents.max_z = math.max(layout.extents.max_z, testpos.z)
			layout.extents.min_z = math.min(layout.extents.min_z, testpos.z)
			
			-- add a reference to this node's position to special node lists
			if group_number == 2 then
				table.insert(layout.inventories, testpos)
			elseif group_number == 3 then
				table.insert(layout.diggers, testpos)
			elseif group_number == 4 then
				table.insert(layout.builders, testpos)
			elseif group_number == 5 then
				table.insert(layout.fuelstores, testpos)
			end
			
			--queue up potential new test points adjacent to this digtron node
			to_test:set_if_not_in(tested, testpos.x + 1, testpos.y, testpos.z, true)
			to_test:set_if_not_in(tested, testpos.x - 1, testpos.y, testpos.z, true)
			to_test:set_if_not_in(tested, testpos.x, testpos.y + 1, testpos.z, true)
			to_test:set_if_not_in(tested, testpos.x, testpos.y - 1, testpos.z, true)
			to_test:set_if_not_in(tested, testpos.x, testpos.y, testpos.z + 1, true)
			to_test:set_if_not_in(tested, testpos.x, testpos.y, testpos.z - 1, true)
		elseif minetest.registered_nodes[node.name].buildable_to ~= true then
			-- Tracks whether the digtron is hovering in mid-air. If any part of the digtron array touches something solid it gains traction.
			layout.traction = layout.traction + 1
		end
		
		testpos, _ = to_test:pop()
	end
			
	return layout
end

digtron.place_in_inventory = function(itemname, inventory_positions, fallback_pos)
	--tries placing the item in each inventory node in turn. If there's no room, drop it at fallback_pos
	local itemstack = ItemStack(itemname)
	for k, location in pairs(inventory_positions) do
		local inv = minetest.get_inventory({type="node", pos=location})
		itemstack = inv:add_item("main", itemstack)
		if itemstack:is_empty() then
			return nil
		end
	end
	minetest.add_item(fallback_pos, itemstack)
end

digtron.place_in_specific_inventory = function(itemname, pos, inventory_positions, fallback_pos)
	--tries placing the item in a specific inventory. Other parameters are used as fallbacks on failure
	--Use this method for putting stuff back after testing and failed builds so that if the player
	--is trying to keep various inventories organized manually stuff will go back where it came from,
	--probably.
	local itemstack = ItemStack(itemname)
	local inv = minetest.get_inventory({type="node", pos=pos})
	local returned_stack = inv:add_item("main", itemstack)
	if not returned_stack:is_empty() then
		-- we weren't able to put the item back into that particular inventory for some reason.
		-- try putting it *anywhere.*
		digtron.place_in_inventory(returned_stack, inventory_positions, fallback_pos)
	end
end

digtron.take_from_inventory = function(itemname, inventory_positions)
	--tries to take an item from each inventory node in turn. Returns location of inventory item was taken from on success, nil on failure
	local itemstack = ItemStack(itemname)
	for k, location in pairs(inventory_positions) do
		local inv = minetest.get_inventory({type="node", pos=location})
		local output = inv:remove_item("main", itemstack)
		if not output:is_empty() then
			return location
		end
	end
	return nil
end

digtron.move_digtron = function(facing, digtrons, extents, nodes_dug)
	-- move everything. Note! order is important or they'll step on each other, that's why this has complicated loops and filtering.
	-- Nodes are moved in a "caterpillar" pattern - front plane first, then next plane back, then next plane back, etc.
	-- positions in the digtron list will be updated when this method executes. Note that the inventories list shares
	-- references to the node position tables in the digtron list, so it will reflect the updates too.
	local dir = digtron.facedir_to_dir_map[facing]
	local increment
	local filter
	local index
	local target
	if dir == 1 then -- z+
		filter = "z"
		increment = -1
		index = extents.max_z
		target = extents.min_z
		extents.max_z = extents.max_z + 1
		extents.min_z = extents.min_z + 1
	elseif dir == 2 then -- x+
		filter = "x"
		increment = -1
		index = extents.max_x
		target = extents.min_x
		extents.max_x = extents.max_x + 1
		extents.min_x = extents.min_x + 1
	elseif dir == 3 then -- z-
		filter = "z"
		increment = 1
		index = extents.min_z
		target = extents.max_z
		extents.max_z = extents.max_z - 1
		extents.min_z = extents.min_z - 1
	elseif dir == 4 then -- x-
		filter = "x"
		increment = 1
		index = extents.min_x
		target = extents.max_x
		extents.max_x = extents.max_x - 1
		extents.min_x = extents.min_x - 1
	elseif dir == 5 then -- y-
		filter = "y"
		increment = 1
		index = extents.min_y
		target = extents.max_y
		extents.max_y = extents.max_y - 1
		extents.min_y = extents.min_y - 1
	elseif dir == 6 then -- y+
		filter = "y"
		increment = -1
		index = extents.max_y
		target = extents.min_y
		extents.max_y = extents.max_y + 1
		extents.min_y = extents.min_y + 1
	end

	while index ~= target + increment do
		for k, location in pairs(digtrons) do
			if location[filter] == index then
				local newpos = digtron.find_new_pos(location, facing)
				digtron.move_node(location, newpos)
				--By updating the digtron position table in-place we also update all the special node tables as well
				digtrons[k].x= newpos.x
				digtrons[k].y= newpos.y
				digtrons[k].z= newpos.z
				nodes_dug:set(newpos.x, newpos.y, newpos.z, false) -- we've moved a digtron node into this space, mark it so that we don't dig it.
			end
		end
		index = index + increment
	end
end

-- Used to determine which coordinate is being checked for periodicity. eg, if the digtron is moving in the z direction, then periodicity is checked for every n nodes in the z axis.
digtron.get_controlling_coordinate = function(pos, facedir)
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

-- Searches fuel store inventories for burnable items and burns them until target is reached or surpassed (or there's nothing left to burn). Returns the total fuel value burned
-- if the "test" parameter is set to true, doesn't actually take anything out of inventories. We can get away with this sort of thing for fuel but not for builder inventory because there's just one
-- controller node burning stuff, not multiple build heads drawing from inventories in turn. Much simpler.
digtron.burn = function(fuelstore_positions, target, test)
	local current_burned = 0
	for k, location in pairs(fuelstore_positions) do
		if current_burned > target then
			break
		end
		local inv = minetest.get_inventory({type="node", pos=location})
		local invlist = inv:get_list("main")
		for i, itemstack in pairs(invlist) do
			local fuel_per_item = minetest.get_craft_result({method="fuel", width=1, items={itemstack:peek_item(1)}}).time
			if fuel_per_item ~= 0 then
				local actual_burned = math.min(
						math.ceil((target - current_burned)/fuel_per_item ), -- burn this many, if we can.
						itemstack:get_count() -- how many we have at most.
					)
				if test ~= true then
					-- don't bother recording the items if we're just testing, nothing is actually being removed.
					itemstack:set_count(itemstack:get_count() - actual_burned)
				end
				current_burned = current_burned + actual_burned * fuel_per_item
			end
			if current_burned > target then
				break
			end
		end
		if test ~= true then
			-- only update the list if we're doing this for real.
			inv:set_list("main", invlist)
		end
	end
	return current_burned
end

digtron.remove_builder_item = function(pos)
	minetest.debug("removing builder item")
	local objects = minetest.env:get_objects_inside_radius(pos, 0.5)
	if objects ~= nil then
		for _, obj in ipairs(objects) do
			if obj and obj:get_luaentity() and obj:get_luaentity().name == "digtron:builder_item" then
				obj:remove()
			end
		end
	end
end

digtron.update_builder_item = function(pos)
	digtron.remove_builder_item(pos)
	local inv = minetest.get_inventory({type="node", pos=pos})
	local item_stack = inv:get_stack("main", 1)
	if not item_stack:is_empty() then
		digtron.create_builder_item = item_stack:get_name()
		minetest.add_entity(pos,"digtron:builder_item")
	end
end