digtron.move_node = function(pos, newpos, player_name)
	-- Moves nodes, preserving digtron metadata and inventory
	local node = minetest.get_node(pos)
	local node_def = minetest.registered_nodes[node.name]
	local oldnode = minetest.get_node(newpos)
	minetest.log("action", string.format("%s moves %s from (%d, %d, %d) to (%d, %d, %d), displacing %s", player_name, node.name, pos.x, pos.y, pos.z, newpos.x, newpos.y, newpos.z, oldnode.name))
	minetest.add_node(newpos, { name=node.name, param1=node.param1, param2=node.param2 })
	if node_def.after_place_node then
		node_def.after_place_node(newpos)
	end

	local oldmeta = minetest.get_meta(pos)
	local oldinv = oldmeta:get_inventory()
	local list = oldinv:get_list("main")
	local fuel = oldinv:get_list("fuel")
	local oldformspec = oldmeta:get_string("formspec")
	
	local newmeta = minetest.get_meta(newpos)
	local newinv = newmeta:get_inventory()
	newinv:set_list("main", list)
	newinv:set_list("fuel", fuel)
	newmeta:set_string("formspec", oldformspec)
	
	newmeta:set_string("triggering_player", oldmeta:get_string("triggering_player")) -- for auto-controllers
	
	newmeta:set_int("offset", oldmeta:get_int("offset"))
	newmeta:set_int("period", oldmeta:get_int("period"))
	newmeta:set_int("build_facing", oldmeta:get_int("build_facing"))
	newmeta:set_float("fuel_burning", oldmeta:get_float("fuel_burning"))
	newmeta:set_string("infotext", oldmeta:get_string("infotext"))
	
	-- Move the little floaty entity inside the builders
	if minetest.get_item_group(node.name, "digtron") == 4 then
		digtron.update_builder_item(newpos)
	end
	
	-- remove node from old position
	minetest.remove_node(pos)
	if node_def.after_dig_node then
		node_def.after_dig_node(pos)
	end
end

digtron.move_digtron = function(facing, digtrons, extents, nodes_dug, player_name)
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
				digtron.move_node(location, newpos, player_name)
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