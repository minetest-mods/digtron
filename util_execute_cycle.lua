-- internationalization boilerplate
local MP = minetest.get_modpath(minetest.get_current_modname())
local S, NS = dofile(MP.."/intllib.lua")

local dig_dust = function(pos, facing)
	local direction = minetest.facedir_to_dir(facing)
	return {
		amount = 10,
		time = 1.0,
		minpos = vector.subtract(pos, vector.new(0.5,0.5,0.5)),
		maxpos = vector.add(pos, vector.new(0.5,0.5,0.5)),
		minvel = vector.multiply(direction, -10),
		maxvel = vector.multiply(direction, -20),
		minacc = {x=0, y=-40, z=0},
		maxacc = {x=0, y=-40, z=0},
		minexptime = 0.25,
		maxexptime = 0.5,
		minsize = 2,
		maxsize = 5,
		collisiondetection = false,
		vertical = false,
		texture = "default_item_smoke.png^[colorize:#9F817080",
	}
end

local burn_smoke = function(pos, amount)
	return {
		amount = math.min(amount, 40),
		time = 1.0,
		minpos = vector.subtract(pos, vector.new(0.5,0.5,0.5)),
		maxpos = vector.add(pos, vector.new(0.5,0.5,0.5)),
		minvel = {x=0, y=2, z=0},
		maxvel = {x=0, y=5, z=0},
		minacc = {x=0, y=0, z=0},
		maxacc = {x=0, y=0, z=0},
		minexptime = 0.5,
		maxexptime = 1.5,
		minsize = 8,
		maxsize = 12,
		collisiondetection = false,
		vertical = false,
		texture = "default_item_smoke.png^[colorize:#000000DD",
	}
end

--Performs various tests on a layout to play warning noises and see if Digtron can move at all.
local function neighbour_test(layout, status_text, dir)
	if layout.ignore_touching == true then
		-- if the digtron array touches unloaded nodes, too dangerous to do anything in that situation. Abort.
		minetest.sound_play("buzzer", {gain=0.25, pos=layout.controller})
		return S("Digtron is adjacent to unloaded nodes.") .. "\n" .. status_text, 1
	end
	
	if layout.water_touching == true then
		minetest.sound_play("sploosh", {gain=1.0, pos=layout.controller})
	end
	
	if layout.lava_touching == true then
		minetest.sound_play("woopwoopwoop", {gain=1.0, pos=layout.controller})
	end	
	
	if dir and dir.y ~= -1 and layout.traction * digtron.config.traction_factor < table.getn(layout.all) then
		-- digtrons can't fly, though they can fall
		minetest.sound_play("squeal", {gain=1.0, pos=layout.controller})
		return S("Digtron has @1 blocks but only enough traction to move @2 blocks.\n", table.getn(layout.all), layout.traction * digtron.config.traction_factor)
			 .. status_text, 2
	end

	return status_text, 0
end

-- Checks if a player is within a layout's extents.
local function move_player_test(layout, player)
	local player_pos = player:get_pos()
	if player_pos.x >= layout.extents_min_x - 1 and player_pos.x <= layout.extents_max_x + 1 and
	   player_pos.y >= layout.extents_min_y - 1 and player_pos.y <= layout.extents_max_y + 1 and
	   player_pos.z >= layout.extents_min_z - 1 and player_pos.z <= layout.extents_max_z + 1 then
		return true
	end
	return false
end

local node_inventory_table = {type="node"} -- a reusable parameter for get_inventory calls, set the pos parameter before using.
local function test_stop_block(pos, items)
	node_inventory_table.pos = pos
	local inv = minetest.get_inventory(node_inventory_table)
	local item_stack = inv:get_stack("stop", 1)
	if not item_stack:is_empty() then
		for _, item in pairs(items) do
			if item == item_stack:get_name() then
				return true
			end
		end
	end
	return false
end

local function check_digtron_size(layout)
	if #layout.all > digtron.config.size_limit then
		return S("Size limit of @1 reached with @2 nodes!", digtron.config.size_limit, #layout.all)
	end
end

-- returns newpos, status string, and a return code indicating why the method returned (so the auto-controller can keep trying if it's due to unloaded nodes)
-- 0 - success
-- 1 - failed due to unloaded nodes
-- 2 - failed due to insufficient traction
-- 3 - obstructed by undiggable node
-- 4 - insufficient fuel
-- 5 - unknown builder error during testing
-- 6 - builder with unset output
-- 7 - insufficient builder materials in inventory
-- 8 - size/node limit reached
digtron.execute_dig_cycle = function(pos, clicker)
	local meta = minetest.get_meta(pos)
	local facing = minetest.get_node(pos).param2
	local dir = minetest.facedir_to_dir(facing)
	local fuel_burning = meta:get_float("fuel_burning") -- get amount of burned fuel left over from last cycle
	local status_text = S("Heat remaining in controller furnace: @1", math.floor(math.max(0, fuel_burning)))
	local exhaust = meta:get_int("on_coal")
	
	local layout = DigtronLayout.create(pos, clicker)

	local status_text, return_code = neighbour_test(layout, status_text, dir)
	if return_code ~= 0 then
		return pos, status_text, return_code
	end

	local size_check_error = check_digtron_size(layout)
	if size_check_error then
		return pos, size_check_error, 8
	end
	
	local controlling_coordinate = digtron.get_controlling_coordinate(pos, facing)
	
	----------------------------------------------------------------------------------------------------------------------
	
	local items_dropped = {}
	local digging_fuel_cost = 0
	local particle_systems = {}
	
	-- execute the execute_dig method on all digtron components that have one
	-- This builds a set of nodes that will be dug and returns a list of products that will be generated
	-- but doesn't actually dig the nodes yet. That comes later.
	-- If we dug them now, sand would fall and some digtron nodes would die.
	if layout.diggers ~= nil then
		for k, location in pairs(layout.diggers) do
			local target = minetest.get_node(location.pos)
			local targetdef = minetest.registered_nodes[target.name]
			if targetdef.execute_dig ~= nil then
				local fuel_cost, dropped = targetdef.execute_dig(location.pos, layout.protected, layout.nodes_dug, controlling_coordinate, false, clicker)
				if dropped ~= nil then
					for _, itemname in pairs(dropped) do
						table.insert(items_dropped, itemname)
					end
					if digtron.config.particle_effects then
						table.insert(particle_systems, dig_dust(vector.add(location.pos, dir), target.param2))
					end
				end
				digging_fuel_cost = digging_fuel_cost + fuel_cost
			else
				minetest.log(string.format("%s has digger group but is missing execute_dig method! This is an error in mod programming, file a bug.", targetdef.name))
			end
		end
	end
	
	----------------------------------------------------------------------------------------------------------------------
	
	-- test if any digtrons are obstructed by non-digtron nodes that haven't been marked
	-- as having been dug.
	local can_move = true
	for _, location in pairs(layout.all) do
		local newpos = vector.add(location.pos, dir)
		if not digtron.can_move_to(newpos, layout.protected, layout.nodes_dug) then
			can_move = false
		end
	end
	
	if test_stop_block(pos, items_dropped) then
		can_move = false
	end
	
	if not can_move then
		-- mark this node as waiting, will clear this flag in digtron.config.cycle_time seconds
		minetest.get_meta(pos):set_string("waiting", "true")
		minetest.get_node_timer(pos):start(digtron.config.cycle_time)
		minetest.sound_play("squeal", {gain=1.0, pos=pos})
		minetest.sound_play("buzzer", {gain=0.5, pos=pos})
		return pos, S("Digtron is obstructed.") .. "\n" .. status_text, 3 --Abort, don't dig and don't build.
	end

	----------------------------------------------------------------------------------------------------------------------
	
	-- ask each builder node if it can get what it needs from inventory to build this cycle.
	-- This is a complicated test because each builder needs to actually *take* the item it'll
	-- need from inventory, and then we put it all back afterward.
	-- Note that this test may overestimate the amount of work that will actually need to be done so don't treat its fuel cost as authoritative.
	local can_build = true
	local test_build_return_code = nil
	local test_build_return_items = nil
	local failed_to_find = nil
	local test_items = {}
	local test_fuel_items = {}
	local test_build_fuel_cost = 0
	if layout.builders ~= nil then
		for k, location in pairs(layout.builders) do
			local target = minetest.get_node(location.pos)
			local targetdef = minetest.registered_nodes[target.name]
			local test_location = vector.add(location.pos, dir)
			if targetdef.test_build ~= nil then
				test_build_return_code, test_build_return_items, failed_to_find = targetdef.test_build(location.pos, test_location, layout.inventories, layout.protected, layout.nodes_dug, controlling_coordinate, layout.controller)
				for k, return_item in pairs(test_build_return_items) do
					table.insert(test_items, return_item)
					test_build_fuel_cost = test_build_fuel_cost + digtron.config.build_cost
				end
				if test_build_return_code > 1 then
					can_build = false
					break
				end
			else
				minetest.log(string.format("%s has builder group but is missing test_build method! This is an error in mod programming, file a bug.", targetdef.name))
			end
		end
	end
	
	local test_fuel_needed = test_build_fuel_cost + digging_fuel_cost - fuel_burning
	local test_fuel_burned = 0

	local power_from_cables = 0
	if minetest.get_modpath("technic") then
		if layout.power_connectors ~= nil then
			local power_inputs = {}
			for _, power_connector in pairs(layout.power_connectors) do
				if power_connector.meta.fields.HV_network and power_connector.meta.fields.HV_EU_input then
					power_inputs[power_connector.meta.fields.HV_network] = tonumber(power_connector.meta.fields.HV_EU_input)
				end
			end
			for _, power in pairs(power_inputs) do
				power_from_cables = power_from_cables + power
			end
			power_from_cables = power_from_cables / digtron.config.power_ratio
			test_fuel_burned = power_from_cables
		end
		
		if test_fuel_needed - test_fuel_burned > 0 then
			-- check for the available electrical power
			test_fuel_burned = test_fuel_burned + digtron.tap_batteries(layout.battery_holders, test_fuel_needed, true)
		end
	end
	if (test_fuel_needed < test_fuel_burned) then
		exhaust = 0 -- all power needs met by electricity, don't blow smoke
	else 
		-- burn combustible fuel if not enough power
		test_fuel_burned = test_fuel_burned + digtron.burn(layout.fuelstores, test_fuel_needed - test_fuel_burned, true)
		exhaust = 1 -- burning fuel produces smoke
	end
	
	--Put everything back where it came from
	for k, item_return in pairs(test_items) do
		digtron.place_in_specific_inventory(item_return.item, item_return.location, layout.inventories, layout.controller)
	end
	
	if test_fuel_needed > fuel_burning + test_fuel_burned then
		minetest.sound_play("buzzer", {gain=0.5, pos=pos})
		return pos, S("Digtron needs more fuel."), 4 -- abort, don't dig and don't build.
	end
	
	if not can_build then
		minetest.get_meta(pos):set_string("waiting", "true")
		minetest.get_node_timer(pos):start(digtron.config.cycle_time)
		local return_string = nil
		local return_code = 5
		if test_build_return_code == 3 then
			minetest.sound_play("honk", {gain=0.5, pos=pos}) -- A builder is not configured
			return_string = S("Digtron connected to at least one builder with no output material assigned.") .. "\n"
			return_code = 6
		elseif test_build_return_code == 2 then
			minetest.sound_play("dingding", {gain=1.0, pos=pos}) -- Insufficient inventory
			return_string = S("Digtron has insufficient building materials. Needed: @1", failed_to_find:get_name()) .. "\n"
			return_code = 7
		end
		return pos, return_string .. status_text, return_code --Abort, don't dig and don't build.
	end	

	----------------------------------------------------------------------------------------------------------------------
	
	-- All tests passed, ready to go for real!
	minetest.sound_play("construction", {gain=1.0, pos=pos})

	-- if the player is standing within the array or next to it, move him too.
	local move_player = move_player_test(layout, clicker)
	
	-- damage the weak flesh
	if digtron.config.damage_hp > 0 and layout.diggers ~= nil then
		for k, location in pairs(layout.diggers) do
			local target = minetest.get_node(location.pos)
			local targetdef = minetest.registered_nodes[target.name]
			if targetdef.damage_creatures ~= nil then
				targetdef.damage_creatures(clicker, location.pos, controlling_coordinate, items_dropped)
			end
		end
	end
	
	--move the array
	layout:move_layout_image(dir)
	if not layout:write_layout_image(clicker) then
		return pos, "unrecoverable write_layout_image error", 1
	end
	local oldpos = {x=pos.x, y=pos.y, z=pos.z}
	pos = vector.add(pos, dir)
	meta = minetest.get_meta(pos)
	if move_player then
		clicker:moveto(vector.add(dir, clicker:get_pos()), true)
	end
	
	-- store or drop the products of the digger heads
	for _, itemname in pairs(items_dropped) do
		digtron.place_in_inventory(itemname, layout.inventories, oldpos)
	end
	digtron.award_item_dug(items_dropped, clicker) -- Achievements mod hook
	
	local building_fuel_cost = 0
	local strange_failure = false
	-- execute_build on all digtron components that have one
	if layout.builders ~= nil then
		for k, location in pairs(layout.builders) do
			local target = minetest.get_node(location.pos)
			local targetdef = minetest.registered_nodes[target.name]
			if targetdef.execute_build ~= nil then
				--using the old location of the controller as fallback so that any leftovers land with the rest of the digger output. Not that there should be any.
				local build_return = targetdef.execute_build(location.pos, clicker, layout.inventories, layout.protected, layout.nodes_dug, controlling_coordinate, oldpos)
				if build_return < 0 then
					-- This happens if there's insufficient inventory, but we should have confirmed there was sufficient inventory during test phase.
					-- So this should never happen. However, "should never happens" happen sometimes. So
					-- don't interrupt the build cycle as a whole, we've already moved so might as well try to complete as much as possible.
					strange_failure = true
					build_return = (build_return * -1) - 1
				elseif digtron.config.uses_resources then
					building_fuel_cost = building_fuel_cost + (digtron.config.build_cost * build_return)
				end
			else
				minetest.log(string.format("%s has builder group but is missing execute_build method! This is an error in mod programming, file a bug.", targetdef.name))
			end
		end
	end
	
	if layout.auto_ejectors ~= nil then
		for k, location in pairs(layout.auto_ejectors) do
			local target = minetest.get_node(location.pos)
			local targetdef = minetest.registered_nodes[target.name]
			if targetdef.execute_eject ~= nil then
				targetdef.execute_eject(location.pos, target, clicker, layout)
			else
				minetest.log(string.format("%s has an ejector group but is missing execute_eject method! This is an error in mod programming, file a bug.", targetdef.name))
			end
		end
	end

	local status_text = ""
	if strange_failure then
		-- We weren't able to detect this build failure ahead of time, so make a big noise now. This is strange, shouldn't happen.
		minetest.sound_play("dingding", {gain=1.0, pos=pos})
		minetest.sound_play("buzzer", {gain=0.5, pos=pos})
		status_text = S("Digtron unexpectedly failed to execute one or more build operations, likely due to an inventory error.") .. "\n"
	end
	
	local total_fuel_cost = math.max(digging_fuel_cost + building_fuel_cost - power_from_cables, 0)
	
	-- actually burn the fuel needed
	fuel_burning = fuel_burning - total_fuel_cost
	if digtron.config.particle_effects and exhaust == 1 then
		table.insert(particle_systems, burn_smoke(pos, total_fuel_cost))
	end
	if fuel_burning < 0 then
		-- we tap into the batteries either way
		fuel_burning = fuel_burning + digtron.tap_batteries(layout.battery_holders, -fuel_burning, false)
		if exhaust == 1 then
			-- but we burn coal only if we must (exhaust = flag)
			fuel_burning = fuel_burning + digtron.burn(layout.fuelstores, -fuel_burning, false)
		end
	end
	                                        
	meta:set_float("fuel_burning", fuel_burning)
	meta:set_int("on_coal", exhaust)
	status_text = status_text .. S("Heat remaining in controller furnace: @1", math.floor(math.max(0, fuel_burning)))

	-- Eyecandy
	for _, particles in pairs(particle_systems) do
		minetest.add_particlespawner(particles)
	end
	
	-- finally, dig out any nodes remaining to be dug. Some of these will have had their flag revoked because
	-- a builder put something there or because they're another digtron node.
	local node_to_dig, whether_to_dig = layout.nodes_dug:pop()
	while node_to_dig ~= nil do
		if whether_to_dig == true then
			minetest.log("action", string.format("%s uses Digtron to dig %s at (%d, %d, %d)", clicker:get_player_name(), minetest.get_node(node_to_dig).name, node_to_dig.x, node_to_dig.y, node_to_dig.z))
			minetest.remove_node(node_to_dig)
		end
		-- all of the digtron's nodes wind up in nodes_dug, so this is an ideal place to stick
		-- a check to make sand fall after the digtron has passed.
		minetest.check_for_falling({x=node_to_dig.x, y=node_to_dig.y+1, z=node_to_dig.z})
		node_to_dig, whether_to_dig = layout.nodes_dug:pop()
	end
	return pos, status_text, 0
end


-- Simplified version of the above method that only moves, and doesn't execute diggers or builders.
digtron.execute_move_cycle = function(pos, clicker)
	local meta = minetest.get_meta(pos)
	local layout = DigtronLayout.create(pos, clicker)

	local status_text = ""
	local status_text, return_code = neighbour_test(layout, status_text, nil) -- skip traction check for pusher by passing nil for direction
	if return_code ~= 0 then
		return pos, status_text, return_code
	end

	local size_check_error = check_digtron_size(layout)
	if size_check_error then
		return pos, size_check_error, 8
	end

	local facing = minetest.get_node(pos).param2
	local dir = minetest.facedir_to_dir(facing)
	local controlling_coordinate = digtron.get_controlling_coordinate(pos, facing)

	-- if the player is standing within the array or next to it, move him too.
	local move_player = move_player_test(layout, clicker)
	
	-- test if any digtrons are obstructed by non-digtron nodes
	layout:move_layout_image(dir)
	if not layout:can_write_layout_image() then
		-- mark this node as waiting, will clear this flag in digtron.config.cycle_time seconds
		minetest.get_meta(pos):set_string("waiting", "true")
		minetest.get_node_timer(pos):start(digtron.config.cycle_time)
		minetest.sound_play("squeal", {gain=1.0, pos=pos})
		minetest.sound_play("buzzer", {gain=0.5, pos=pos})
		return pos, S("Digtron is obstructed.") .. "\n" .. status_text, 3 --Abort, don't dig and don't build.
	end

	minetest.sound_play("truck", {gain=1.0, pos=pos})
		
	--move the array
	if not layout:write_layout_image(clicker) then
		return pos, "unrecoverable write_layout_image error", 1
	end
	
	pos = vector.add(pos, dir)
	if move_player then
		clicker:moveto(vector.add(clicker:get_pos(), dir), true)
	end
	return pos, "", 0
end

-- Simplified version of the dig cycle that moves laterally relative to the controller's orientation ("downward")
-- Does the dig portion of the cycle, but skips the build portion.
-- returns newpos, status string, and a return code indicating why the method returned (so the auto-controller can keep trying if it's due to unloaded nodes)
-- 0 - success
-- 1 - failed due to unloaded nodes
-- 2 - failed due to insufficient traction
-- 3 - obstructed by undiggable node
-- 4 - insufficient fuel
digtron.execute_downward_dig_cycle = function(pos, clicker)
	local meta = minetest.get_meta(pos)
	local facing = minetest.get_node(pos).param2
	local dir = digtron.facedir_to_down_dir(facing)
	local fuel_burning = meta:get_float("fuel_burning") -- get amount of burned fuel left over from last cycle
	local status_text = S("Heat remaining in controller furnace: @1", math.floor(math.max(0, fuel_burning)))
	local exhaust = meta:get_int("on_coal")
	                                        
	local layout = DigtronLayout.create(pos, clicker)

	local status_text, return_code = neighbour_test(layout, status_text, dir)
	if return_code ~= 0 then
		return pos, status_text, return_code
	end

	local size_check_error = check_digtron_size(layout)
	if size_check_error then
		return pos, size_check_error, 8
	end

	
	local controlling_coordinate = digtron.get_controlling_coordinate(pos, facing)
	
	----------------------------------------------------------------------------------------------------------------------
	
	local items_dropped = {}
	local digging_fuel_cost = 0
	local particle_systems = {}
	
	-- execute the execute_dig method on all digtron components that have one
	-- This builds a set of nodes that will be dug and returns a list of products that will be generated
	-- but doesn't actually dig the nodes yet. That comes later.
	-- If we dug them now, sand would fall and some digtron nodes would die.
	if layout.diggers ~= nil then
		for k, location in pairs(layout.diggers) do
			local target = minetest.get_node(location.pos)
			local targetdef = minetest.registered_nodes[target.name]
			if targetdef.execute_dig ~= nil then
				local fuel_cost, dropped = targetdef.execute_dig(location.pos, layout.protected, layout.nodes_dug, controlling_coordinate, true, clicker)
				if dropped ~= nil then
					for _, itemname in pairs(dropped) do
						table.insert(items_dropped, itemname)
					end
					if digtron.config.particle_effects then
						table.insert(particle_systems, dig_dust(vector.add(location.pos, dir), target.param2))
					end
				end
				digging_fuel_cost = digging_fuel_cost + fuel_cost
			else
				minetest.log(string.format("%s has digger group but is missing execute_dig method! This is an error in mod programming, file a bug.", targetdef.name))
			end
		end
	end
	
	----------------------------------------------------------------------------------------------------------------------
	
	-- test if any digtrons are obstructed by non-digtron nodes that haven't been marked
	-- as having been dug.
	local can_move = true
	for _, location in pairs(layout.all) do
		local newpos = vector.add(location.pos, dir)
		if not digtron.can_move_to(newpos, layout.protected, layout.nodes_dug) then
			can_move = false
		end
	end

	if test_stop_block(pos, items_dropped) then
		can_move = false
	end

	if not can_move then
		-- mark this node as waiting, will clear this flag in digtron.config.cycle_time seconds
		minetest.get_meta(pos):set_string("waiting", "true")
		minetest.get_node_timer(pos):start(digtron.config.cycle_time)
		minetest.sound_play("squeal", {gain=1.0, pos=pos})
		minetest.sound_play("buzzer", {gain=0.5, pos=pos})
		return pos, S("Digtron is obstructed.") .. "\n" .. status_text, 3 --Abort, don't dig and don't build.
	end

	----------------------------------------------------------------------------------------------------------------------
	
	-- All tests passed, ready to go for real!
	minetest.sound_play("construction", {gain=1.0, pos=pos})

	-- if the player is standing within the array or next to it, move him too.
	local move_player = move_player_test(layout, clicker)
	
	-- damage the weak flesh
	if digtron.config.damage_hp > 0 and layout.diggers ~= nil then
		for k, location in pairs(layout.diggers) do
			local target = minetest.get_node(location.pos)
			local targetdef = minetest.registered_nodes[target.name]
			if targetdef.damage_creatures ~= nil then
				targetdef.damage_creatures(clicker, location.pos, controlling_coordinate, items_dropped)
			end
		end
	end
	
	--move the array
	layout:move_layout_image(digtron.facedir_to_down_dir(facing))
	if not layout:write_layout_image(clicker) then
		return pos, "unrecoverable write_layout_image error", 1
	end
	local oldpos = {x=pos.x, y=pos.y, z=pos.z}
	pos = vector.add(pos, dir)
	meta = minetest.get_meta(pos)
	if move_player then
		clicker:moveto(vector.add(clicker:get_pos(), dir), true)
	end
	
	-- store or drop the products of the digger heads
	for _, itemname in pairs(items_dropped) do
		digtron.place_in_inventory(itemname, layout.inventories, oldpos)
	end
	digtron.award_item_dug(items_dropped, clicker) -- Achievements mod hook
	
	local status_text = ""
	
	-- actually burn the fuel needed
	fuel_burning = fuel_burning - digging_fuel_cost
	if digtron.config.particle_effects and exhaust == 1 then
		table.insert(particle_systems, burn_smoke(pos, digging_fuel_cost))
	end
	if fuel_burning < 0 then
		-- we tap into the batteries either way
		fuel_burning = fuel_burning + digtron.tap_batteries(layout.battery_holders, -fuel_burning, false)
		if exhaust == 1 then
			-- but we burn coal only if we must (exhaust = flag)
			fuel_burning = fuel_burning + digtron.burn(layout.fuelstores, -fuel_burning, false)
		end
	end

	meta:set_float("fuel_burning", fuel_burning)
	meta:set_int("on_coal", exhaust)
	status_text = status_text .. S("Heat remaining in controller furnace: @1", math.floor(math.max(0, fuel_burning)))

	-- Eyecandy
	for _, particles in pairs(particle_systems) do
		minetest.add_particlespawner(particles)
	end
	
	-- finally, dig out any nodes remaining to be dug. Some of these will have had their flag revoked because
	-- a builder put something there or because they're another digtron node.
	local node_to_dig, whether_to_dig = layout.nodes_dug:pop()
	while node_to_dig ~= nil do
		if whether_to_dig == true then
			minetest.log("action", string.format("%s uses Digtron to dig %s at (%d, %d, %d)", clicker:get_player_name(), minetest.get_node(node_to_dig).name, node_to_dig.x, node_to_dig.y, node_to_dig.z))
			minetest.remove_node(node_to_dig)
		end
		node_to_dig, whether_to_dig = layout.nodes_dug:pop()
	end
	return pos, status_text, 0
end
