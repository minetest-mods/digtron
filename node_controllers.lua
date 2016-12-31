local controller_nodebox ={
	{-0.3125, -0.3125, -0.3125, 0.3125, 0.3125, 0.3125}, -- Core
	{-0.1875, 0.3125, -0.1875, 0.1875, 0.5, 0.1875}, -- +y_connector
	{-0.1875, -0.5, -0.1875, 0.1875, -0.3125, 0.1875}, -- -y_Connector
	{0.3125, -0.1875, -0.1875, 0.5, 0.1875, 0.1875}, -- +x_connector
	{-0.5, -0.1875, -0.1875, -0.3125, 0.1875, 0.1875}, -- -x_connector
	{-0.1875, -0.1875, 0.3125, 0.1875, 0.1875, 0.5}, -- +z_connector
	{-0.5, 0.125, -0.5, -0.125, 0.5, -0.3125}, -- back_connector_3
	{0.125, 0.125, -0.5, 0.5, 0.5, -0.3125}, -- back_connector_1
	{0.125, -0.5, -0.5, 0.5, -0.125, -0.3125}, -- back_connector_2
	{-0.5, -0.5, -0.5, -0.125, -0.125, -0.3125}, -- back_connector_4
}

-- Master controller. Most complicated part of the whole system. Determines which direction a digtron moves and triggers all of its component parts.
minetest.register_node("digtron:controller", {
	description = "Digtron Control Unit",
	groups = {cracky = 3, stone = 1, digtron = 1},
	drop = 'digtron:controller',
	paramtype2= 'facedir',
	-- Aims in the +Z direction by default
	tiles = {
		"digtron_plate.png^[transformR90",
		"digtron_plate.png^[transformR270",
		"digtron_plate.png",
		"digtron_plate.png^[transformR180",
		"digtron_plate.png",
		"digtron_control.png",
	},
	
	drawtype = "nodebox",
	paramtype = "light",
	node_box = {
		type = "fixed",
		fixed = controller_nodebox,
	},
	
	on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
		local meta = minetest.get_meta(pos)
		if meta:get_string("waiting") == "true" then
			-- Been too soon since last time the digtron did a cycle.
			return
		end

		local layout = digtron.get_all_digtron_neighbours(pos, clicker)
		if layout.all == nil then
			-- get_all_digtron_neighbours returns nil if the digtron array touches unloaded nodes, too dangerous to do anything in that situation. Abort.
			minetest.sound_play("buzzer", {gain=0.5, pos=pos})
			return
		end
		
		if layout.traction == false then
			-- digtrons can't fly
			minetest.sound_play("squeal", {gain=1.0, pos=pos})
			return
		end

		local facing = minetest.get_node(pos).param2
		local controlling_coordinate = digtron.get_controlling_coordinate(pos, facing)
		
		----------------------------------------------------------------------------------------------------------------------
		
		local nodes_dug = Pointset.create()
		local items_dropped = {}
		
		-- execute the execute_dig method on all digtron components that have one
		-- This builds a set of nodes that will be dug and returns a list of products that will be generated
		-- but doesn't actually dig the nodes yet. That comes later.
		-- If we dug them now, sand would fall and some digtron nodes would die.
		for k, location in pairs(layout.diggers) do
			local target = minetest.get_node(location)
			local targetdef = minetest.registered_nodes[target.name]
			if targetdef.execute_dig ~= nil then
				local dropped = targetdef.execute_dig(location, layout.protected, nodes_dug, controlling_coordinate)
				if dropped ~= nil then
					for _, itemname in pairs(dropped) do
						table.insert(items_dropped, itemname)
					end
				end
			else
				minetest.log(string.format("%s has digger group but is missing execute_dig method! This is an error in mod programming, file a bug.", targetdef.name))
			end
		end
		
		----------------------------------------------------------------------------------------------------------------------
		
		-- test if any digtrons are obstructed by non-digtron nodes that haven't been marked
		-- as having been dug.
		local can_move = true
		for _, location in pairs(layout.all) do
			local newpos = digtron.find_new_pos(location, facing)
			if not digtron.can_move_to(newpos, layout.protected, nodes_dug) then
				can_move = false
			end
		end
		
		if not can_move then
			-- mark this node as waiting, will clear this flag in digtron.refractory seconds
			minetest.get_meta(pos):set_string("waiting", "true")
			minetest.after(digtron.refractory,
				function (pos)
					minetest.get_meta(pos):set_string("waiting", nil)
				end, pos
			)
			minetest.sound_play("squeal", {gain=1.0, pos=pos})
			minetest.sound_play("buzzer", {gain=0.5, pos=pos})
			return --Abort, don't dig and don't build.
		end

		----------------------------------------------------------------------------------------------------------------------
		
		-- ask each builder node if it can get what it needs from inventory to build this cycle.
		-- This is a complicated test because each builder needs to actually *take* the item it'll
		-- need from inventory, and then we put it all back afterward.
		local can_build = true
		local test_build_return = nil
		local test_items = {}
		for k, location in pairs(layout.builders) do
			local target = minetest.get_node(location)
			local targetdef = minetest.registered_nodes[target.name]
			local test_location = digtron.find_new_pos(location, facing)
			if targetdef.test_build ~= nil then
				test_build_return = targetdef.test_build(location, test_location, layout.inventories, layout.protected, nodes_dug, controlling_coordinate, layout.controller)
				if test_build_return == 1 or test_build_return == 2 then
					can_build = false
					break
				end
				if test_build_return ~= 0 then
					table.insert(test_items, test_build_return)
				end
			else
				minetest.log(string.format("%s has builder group but is missing test_build method! This is an error in mod programming, file a bug.", targetdef.name))
			end
		end
		for k, item_return in pairs(test_items) do
			--Put everything back where it came from
			digtron.place_in_specific_inventory(item_return.item, item_return.location, layout.inventories, layout.controller)
		end
		
		if not can_build then
			minetest.get_meta(pos):set_string("waiting", "true")
			minetest.after(digtron.refractory,
				function (pos)
					minetest.get_meta(pos):set_string("waiting", nil)
				end, pos
			)
			if test_build_return == 1 then
				minetest.sound_play("honk", {gain=0.5, pos=pos}) -- A builder is not configured
			elseif test_build_return == 2 then
				minetest.sound_play("dingding", {gain=1.0, pos=pos}) -- Insufficient inventory
			end
			return --Abort, don't dig and don't build.
		end	

		----------------------------------------------------------------------------------------------------------------------
		
		-- All tests passed, ready to go for real!
		minetest.sound_play("construction", {gain=1.0, pos=pos})
	
		-- store or drop the products of the digger heads
		for _, itemname in pairs(items_dropped) do
			digtron.place_in_inventory(itemname, layout.inventories, pos)
		end

		-- if the player is standing within the array or next to it, move him too.
		local player_pos = clicker:getpos()
		local move_player = false
		if player_pos.x >= layout.extents.min_x - 1 and player_pos.x <= layout.extents.max_x + 1 and
		   player_pos.y >= layout.extents.min_y - 1 and player_pos.y <= layout.extents.max_y + 1 and
		   player_pos.z >= layout.extents.min_z - 1 and player_pos.z <= layout.extents.max_z + 1 then
			move_player = true
		end
			
		--move the array
		digtron.move_digtron(facing, layout.all, layout.extents, nodes_dug)
		local oldpos = {x=pos.x, y=pos.y, z=pos.z}
		pos = digtron.find_new_pos(pos, facing)
		if move_player then
			clicker:moveto(digtron.find_new_pos(player_pos, facing), true)
		end
		
		-- Start the delay before digtron can run again. Do this after moving the array or pos will be wrong.
		minetest.get_meta(pos):set_string("waiting", "true")
		minetest.after(digtron.refractory,
			function (pos)
				minetest.get_meta(pos):set_string("waiting", nil)
			end, pos
		)
		
		-- execute_build on all digtron components that have one
		for k, location in pairs(layout.builders) do
			local target = minetest.get_node(location)
			local targetdef = minetest.registered_nodes[target.name]
			if targetdef.execute_build ~= nil then
				--using the old location of the controller as fallback so that any leftovers land with the rest of the digger output. Not that there should be any.
				can_build = targetdef.execute_build(location, clicker, layout.inventories, layout.protected, nodes_dug, controlling_coordinate, oldpos)
			else
				minetest.log(string.format("%s has builder group but is missing execute_build method! This is an error in mod programming, file a bug.", targetdef.name))
			end
		end
		if can_build == false then
			-- We weren't able to detect this build failure ahead of time, so make a big noise now. This is strange, shouldn't happen often.
			minetest.sound_play("dingding", {gain=1.0, pos=pos})
			minetest.sound_play("buzzer", {gain=0.5, pos=pos})
		end
		
		-- finally, dig out any nodes remaining to be dug. Some of these will have had their flag revoked because
		-- a builder put something there or because they're another digtron node.
		local node_to_dig, whether_to_dig = nodes_dug:pop()
		while node_to_dig ~= nil do
			if whether_to_dig == true then
				minetest.remove_node(node_to_dig)
			end
			node_to_dig, whether_to_dig = nodes_dug:pop()
		end
	end,
})

-- A much simplified control unit that only moves the digtron, and doesn't trigger the diggers or builders.
-- Handy for shoving a digtron to the side if it's been built a bit off.
minetest.register_node("digtron:pusher", {
	description = "Digtron Pusher Unit",
	groups = {cracky = 3, stone = 1, digtron = 1},
	drop = 'digtron:pusher',
	paramtype2= 'facedir',
	-- Aims in the +Z direction by default
	tiles = {
		"digtron_plate.png^[transformR90^[colorize:#00880030",
		"digtron_plate.png^[transformR270^[colorize:#00880030",
		"digtron_plate.png^[colorize:#00880030",
		"digtron_plate.png^[transformR180^[colorize:#00880030",
		"digtron_plate.png^[colorize:#00880030",
		"digtron_control.png^[colorize:#00880030",
	},
	
	drawtype = "nodebox",
	paramtype = "light",
	node_box = {
		type = "fixed",
		fixed = controller_nodebox,
	},
	
	on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)	
		local meta = minetest.get_meta(pos)
		if meta:get_string("waiting") == "true" then
			-- Been too soon since last time the digtron did a cycle.
			return
		end

		local layout = digtron.get_all_digtron_neighbours(pos, clicker)
		if layout.all == nil then
			-- get_all_digtron_neighbours returns nil if the digtron array touches unloaded nodes, too dangerous to do anything in that situation. Abort.
			minetest.sound_play("buzzer", {gain=0.5, pos=pos})
			return
		end
		
		if layout.traction == false then
			-- digtrons can't fly
			minetest.sound_play("squeal", {gain=1.0, pos=pos})
			return
		end

		local facing = minetest.get_node(pos).param2
		local controlling_coordinate = digtron.get_controlling_coordinate(pos, facing)
		
		local nodes_dug = Pointset.create() -- empty set, we're not digging anything

		-- test if any digtrons are obstructed by non-digtron nodes that haven't been marked
		-- as having been dug.
		local can_move = true
		for _, location in pairs(layout.all) do
			local newpos = digtron.find_new_pos(location, facing)
			if not digtron.can_move_to(newpos, layout.protected, nodes_dug) then
				can_move = false
			end
		end
		
		if not can_move then
			-- mark this node as waiting, will clear this flag in digtron.refractory seconds
			minetest.get_meta(pos):set_string("waiting", "true")
			minetest.after(digtron.refractory,
				function (pos)
					minetest.get_meta(pos):set_string("waiting", nil)
				end, pos
			)
			minetest.sound_play("squeal", {gain=1.0, pos=pos})
			minetest.sound_play("buzzer", {gain=0.5, pos=pos})
			return --Abort
		end

		minetest.sound_play("truck", {gain=1.0, pos=pos})
	
		-- if the player is standing within the array or next to it, move him too.
		local player_pos = clicker:getpos()
		local move_player = false
		if player_pos.x >= layout.extents.min_x - 1 and player_pos.x <= layout.extents.max_x + 1 and
		   player_pos.y >= layout.extents.min_y - 1 and player_pos.y <= layout.extents.max_y + 1 and
		   player_pos.z >= layout.extents.min_z - 1 and player_pos.z <= layout.extents.max_z + 1 then
			move_player = true
		end
			
		--move the array
		digtron.move_digtron(facing, layout.all, layout.extents, nodes_dug)
		local oldpos = {x=pos.x, y=pos.y, z=pos.z}
		pos = digtron.find_new_pos(pos, facing)
		if move_player then
			clicker:moveto(digtron.find_new_pos(player_pos, facing), true)
		end
		
		-- Start the delay before digtron can run again. Do this after moving the array or pos will be wrong.
		minetest.get_meta(pos):set_string("waiting", "true")
		minetest.after(digtron.refractory,
			function (pos)
				minetest.get_meta(pos):set_string("waiting", nil)
			end, pos
		)
	end,
})