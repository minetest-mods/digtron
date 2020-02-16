-- A random assortment of methods used in various places in this mod.

dofile( minetest.get_modpath( "digtron" ) .. "/util_item_place_node.lua" ) -- separated out to avoid potential for license complexity
dofile( minetest.get_modpath( "digtron" ) .. "/util_execute_cycle.lua" ) -- separated out simply for tidiness, there's some big code in there

local node_inventory_table = {type="node"} -- a reusable parameter for get_inventory calls, set the pos parameter before using.

-- Apparently node_sound_metal_defaults is a newer thing, I ran into games using an older version of the default mod without it.
if default.node_sound_metal_defaults ~= nil then
	digtron.metal_sounds = default.node_sound_metal_defaults()
else
	digtron.metal_sounds = default.node_sound_stone_defaults()
end


digtron.find_new_pos = function(pos, facing)
	-- finds the point one node "forward", based on facing
	local dir = minetest.facedir_to_dir(facing)
	return vector.add(pos, dir)
end

local facedir_to_down_dir_table = {
	[0]={x=0, y=-1, z=0},
	{x=0, y=0, z=-1},
	{x=0, y=0, z=1},
	{x=-1, y=0, z=0},
	{x=1, y=0, z=0},
	{x=0, y=1, z=0}
}
digtron.facedir_to_down_dir = function(facing)
	return facedir_to_down_dir_table[math.floor(facing/4)]
end

digtron.find_new_pos_downward = function(pos, facing)
	return vector.add(pos, digtron.facedir_to_down_dir(facing))
end

digtron.mark_diggable = function(pos, nodes_dug, player)
	-- mark the node as dug, if the player provided would have been able to dig it.
	-- Don't *actually* dig the node yet, though, because if we dig a node with sand over it the sand will start falling
	-- and then destroy whatever node we place there subsequently (either by a builder head or by moving a digtron node)
	-- I don't like sand. It's coarse and rough and irritating and it gets everywhere. And it necessitates complicated dig routines.
	-- returns fuel cost and what will be dropped by digging these nodes.

	local target = minetest.get_node(pos)
	
	-- prevent digtrons from being marked for digging.
	if minetest.get_item_group(target.name, "digtron") ~= 0 or
		minetest.get_item_group(target.name, "digtron_protected") ~= 0 or
		minetest.get_item_group(target.name, "immortal") ~= 0 then
		return 0
	end

	local targetdef = minetest.registered_nodes[target.name]
	if targetdef == nil or targetdef.can_dig == nil or targetdef.can_dig(pos, player) then
		nodes_dug:set(pos.x, pos.y, pos.z, true)
		if target.name ~= "air" then
			local in_known_group = false
			local material_cost = 0
			
			if digtron.config.uses_resources then
				if minetest.get_item_group(target.name, "cracky") ~= 0 then
					in_known_group = true
					material_cost = math.max(material_cost, digtron.config.dig_cost_cracky)
				end
				if minetest.get_item_group(target.name, "crumbly") ~= 0 then
					in_known_group = true
					material_cost = math.max(material_cost, digtron.config.dig_cost_crumbly)
				end
				if minetest.get_item_group(target.name, "choppy") ~= 0 then
					in_known_group = true
					material_cost = math.max(material_cost, digtron.config.dig_cost_choppy)
				end
				if not in_known_group then
					material_cost = digtron.config.dig_cost_default
				end
			end
	
			return material_cost, minetest.get_node_drops(target.name, "")
		end
	end
	return 0
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


digtron.place_in_inventory = function(itemname, inventory_positions, fallback_pos)
	--tries placing the item in each inventory node in turn. If there's no room, drop it at fallback_pos
	local itemstack = ItemStack(itemname)
	if inventory_positions ~= nil then
		for k, location in pairs(inventory_positions) do
			node_inventory_table.pos = location.pos
			local inv = minetest.get_inventory(node_inventory_table)
			itemstack = inv:add_item("main", itemstack)
			if itemstack:is_empty() then
				return nil
			end
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
	node_inventory_table.pos = pos
	local inv = minetest.get_inventory(node_inventory_table)
	local returned_stack = inv:add_item("main", itemstack)
	if not returned_stack:is_empty() then
		-- we weren't able to put the item back into that particular inventory for some reason.
		-- try putting it *anywhere.*
		digtron.place_in_inventory(returned_stack, inventory_positions, fallback_pos)
	end
end

digtron.take_from_inventory = function(itemname, inventory_positions)
	if inventory_positions == nil then return nil end
	--tries to take an item from each inventory node in turn. Returns location of inventory item was taken from on success, nil on failure
	local itemstack = ItemStack(itemname)
	for k, location in pairs(inventory_positions) do
		node_inventory_table.pos = location.pos
		local inv = minetest.get_inventory(node_inventory_table)
		local output = inv:remove_item("main", itemstack)
		if not output:is_empty() then
			return location.pos
		end
	end
	return nil
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

local fuel_craft = {method="fuel", width=1, items={}} -- reusable crafting recipe table for get_craft_result calls below
-- Searches fuel store inventories for burnable items and burns them until target is reached or surpassed 
-- (or there's nothing left to burn). Returns the total fuel value burned
-- if the "test" parameter is set to true, doesn't actually take anything out of inventories.
-- We can get away with this sort of thing for fuel but not for builder inventory because there's just one
-- controller node burning stuff, not multiple build heads drawing from inventories in turn. Much simpler.
digtron.burn = function(fuelstore_positions, target, test)
	if fuelstore_positions == nil then
		return 0
	end

	local current_burned = 0
	for k, location in pairs(fuelstore_positions) do
		if current_burned > target then
			break
		end
		node_inventory_table.pos = location.pos
		local inv = minetest.get_inventory(node_inventory_table)
		local invlist = inv:get_list("fuel")

		if invlist == nil then -- This check shouldn't be needed, it's yet another guard against https://github.com/minetest/minetest/issues/8067
			break
		end
		
		for i, itemstack in pairs(invlist) do
			fuel_craft.items[1] = itemstack:peek_item(1)
			local fuel_per_item = minetest.get_craft_result(fuel_craft).time
			if fuel_per_item ~= 0 then
				local actual_burned = math.min(
						math.ceil((target - current_burned)/fuel_per_item), -- burn this many, if we can.
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
			inv:set_list("fuel", invlist)
		end
	end
	return current_burned
end

-- Consume energy from the batteries
-- The same as burning coal, except that instead of destroying the items in the inventory, we merely drain 
-- the charge in them, leaving them empty. The charge is converted into "coal heat units" by a downscaling 
-- factor, since if taken at face value (10000 EU), the batteries would be the ultimate power source barely
-- ever needing replacement.
digtron.tap_batteries = function(battery_positions, target, test)
	if (battery_positions == nil) then
		return 0
	end

	local current_burned = 0
	-- 1 coal block is 370 PU
	-- 1 coal lump is 40 PU
	-- An RE battery holds 10000 EU of charge
	-- local power_ratio = 100 -- How much charge equals 1 unit of PU from coal
	-- setting Moved to digtron.config.power_ratio
	
	for k, location in pairs(battery_positions) do
		if current_burned > target then
			break
		end
		node_inventory_table.pos = location.pos
		local inv = minetest.get_inventory(node_inventory_table)
		local invlist = inv:get_list("batteries")
		
		if (invlist == nil) then -- This check shouldn't be needed, it's yet another guard against https://github.com/minetest/minetest/issues/8067
			break
		end
		
		for i, itemstack in pairs(invlist) do
			local meta = minetest.deserialize(itemstack:get_metadata())
			if (meta ~= nil) then
				local power_available = math.floor(meta.charge / digtron.config.power_ratio)
				if power_available ~= 0 then
					local actual_burned = power_available -- we just take all we have from the battery, since they aren't stackable
					if test ~= true then
						-- don't bother recording the items if we're just testing, nothing is actually being removed.
						local charge_left = meta.charge - power_available * digtron.config.power_ratio
						local properties = itemstack:get_tool_capabilities()
						-- itemstack = technic.set_RE_wear(itemstack, charge_left, properties.groupcaps.fleshy.uses)
						-- we only need half the function, so why bother using it in the first place

						-- Charge is stored separately, but shown as wear level
						-- This calls for recalculating the value.
						local charge_level
						if charge_left == 0 then
							charge_level = 0
						else
							charge_level = 65536 - math.floor(charge_left / properties.groupcaps.fleshy.uses * 65535)
							if charge_level > 65535 then charge_level = 65535 end
							if charge_level < 1 then charge_level = 1 end
						end
						itemstack:set_wear(charge_level)
						
						meta.charge = charge_left
						itemstack:set_metadata(minetest.serialize(meta))

					end
					current_burned = current_burned + actual_burned
				end
			
			end
			
			if current_burned > target then
				break
			end
		end
				
		if test ~= true then
			-- only update the list if we're doing this for real.
			inv:set_list("batteries", invlist)
		end
	end
	return current_burned
end

digtron.remove_builder_item = function(pos)
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
	node_inventory_table.pos = pos
	local inv = minetest.get_inventory(node_inventory_table)
	if inv == nil or inv:get_size("main") < 1 then return end
	local item_stack = inv:get_stack("main", 1)
	if not item_stack:is_empty() then
		digtron.create_builder_item = item_stack:get_name()
		minetest.add_entity(pos,"digtron:builder_item")
	end
end

local damage_def = {
	full_punch_interval = 1.0,
	damage_groups = {},
}
digtron.damage_creatures = function(player, source_pos, target_pos, amount, items_dropped)
	if type(player) ~= 'userdata' then
		return
	end
	local objects = minetest.env:get_objects_inside_radius(target_pos, 1.0)
	if objects ~= nil then
		damage_def.damage_groups.fleshy = amount
		local velocity = {
			x = target_pos.x-source_pos.x,
			y = target_pos.y-source_pos.y + 0.2,
			z = target_pos.z-source_pos.z,
		}
		for _, obj in ipairs(objects) do
			if obj:is_player() then
				-- See issue #2960 for status of a "set player velocity" method
				-- instead, knock the player back
				local newpos = {
					x = target_pos.x + velocity.x,
					y = target_pos.y + velocity.y,
					z = target_pos.z + velocity.z,
				}
				obj:set_pos(newpos)
				obj:punch(player, 1.0, damage_def, nil)
			else
				local lua_entity = obj:get_luaentity()
				if lua_entity ~= nil then
					if lua_entity.name == "__builtin:item" then
						table.insert(items_dropped, lua_entity.itemstring)
						lua_entity.itemstring = ""
						obj:remove()
					else
						if obj.add_velocity ~= nil then
							obj:add_velocity(velocity)
						else
							local vel = obj:get_velocity()
							obj:set_velocity(vector.add(vel, velocity))
						end
						obj:punch(player, 1.0, damage_def, nil)
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
					table.insert(items_dropped, lua_entity.itemstring)
					lua_entity.itemstring = ""
					obj:remove()
				end
			end
		end		
	end
end

digtron.is_soft_material = function(target)
	local target_node = minetest.get_node(target)
	if  minetest.get_item_group(target_node.name, "crumbly") ~= 0 or
		minetest.get_item_group(target_node.name, "choppy") ~= 0 or
		minetest.get_item_group(target_node.name, "snappy") ~= 0 or
		minetest.get_item_group(target_node.name, "oddly_breakable_by_hand") ~= 0 or
		minetest.get_item_group(target_node.name, "fleshy") ~= 0 then
		return true
	end
	return false
end

-- If someone sets very large offsets or intervals for the offset markers they might be added too far
-- away. safe_add_entity causes these attempts to be ignored rather than crashing the game.
-- returns the entity if successful, nil otherwise
function safe_add_entity(pos, name)
	success, ret = pcall(minetest.add_entity, pos, name)
	if success then return ret else return nil end
end

digtron.show_offset_markers = function(pos, offset, period)
	local buildpos = digtron.find_new_pos(pos, minetest.get_node(pos).param2)
	local x_pos = math.floor((buildpos.x+offset)/period)*period - offset
	safe_add_entity({x=x_pos, y=buildpos.y, z=buildpos.z}, "digtron:marker")
	if x_pos >= buildpos.x then
		safe_add_entity({x=x_pos - period, y=buildpos.y, z=buildpos.z}, "digtron:marker")
	end
	if x_pos <= buildpos.x then
		safe_add_entity({x=x_pos + period, y=buildpos.y, z=buildpos.z}, "digtron:marker")
	end

	local y_pos = math.floor((buildpos.y+offset)/period)*period - offset
	safe_add_entity({x=buildpos.x, y=y_pos, z=buildpos.z}, "digtron:marker_vertical")
	if y_pos >= buildpos.y then
		safe_add_entity({x=buildpos.x, y=y_pos - period, z=buildpos.z}, "digtron:marker_vertical")
	end
	if y_pos <= buildpos.y then
		safe_add_entity({x=buildpos.x, y=y_pos + period, z=buildpos.z}, "digtron:marker_vertical")
	end

	local z_pos = math.floor((buildpos.z+offset)/period)*period - offset

	local entity = safe_add_entity({x=buildpos.x, y=buildpos.y, z=z_pos}, "digtron:marker")
	if entity ~= nil then entity:setyaw(1.5708) end
	
	if z_pos >= buildpos.z then
		local entity = safe_add_entity({x=buildpos.x, y=buildpos.y, z=z_pos - period}, "digtron:marker")
		if entity ~= nil then entity:setyaw(1.5708) end
	end
	if z_pos <= buildpos.z then
		local entity = safe_add_entity({x=buildpos.x, y=buildpos.y, z=z_pos + period}, "digtron:marker")
		if entity ~= nil then entity:setyaw(1.5708) end
	end
end
