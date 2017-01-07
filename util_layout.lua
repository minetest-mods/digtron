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
	layout.water_touching = false
	layout.lava_touching = false
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
		
		if minetest.get_item_group(node.name, "water") ~= 0 then
			layout.water_touching = true
		elseif minetest.get_item_group(node.name, "lava") ~= 0 then
			layout.lava_touching = true
			if digtron.lava_impassible == true then
				layout.protected:set(testpos.x, testpos.y, testpos.z, true)
			end
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
			elseif group_number == 6 then
				table.insert(layout.inventories, testpos)
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