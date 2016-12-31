-- The default minetest.item_place_node from item.lua was hard to work with given some of the details
-- of how it handled pointed_thing. It also didn't work right with default:torch. It was simpler to
-- just copy it here and chop out the special cases that were causing problems.

-- This specific file is therefore licensed under the LGPL 2.1

--GNU Lesser General Public License, version 2.1
--Copyright (C) 2011-2016 celeron55, Perttu Ahola <celeron55@gmail.com>
--Copyright (C) 2011-2016 Various Minetest developers and contributors

--This program is free software; you can redistribute it and/or modify it under the terms
--of the GNU Lesser General Public License as published by the Free Software Foundation;
--either version 2.1 of the License, or (at your option) any later version.

--This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
--without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
--See the GNU Lesser General Public License for more details:
--https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html

-- Mapping from facedir value to index in facedir_to_dir.
digtron.facedir_to_dir_map = {
	[0]=1, 2, 3, 4,
	5, 2, 6, 4,
	6, 2, 5, 4,
	1, 5, 3, 6,
	1, 6, 3, 5,
	1, 4, 3, 2,
}

local function copy_pointed_thing(pointed_thing)
	return {
		type  = pointed_thing.type,
		above = vector.new(pointed_thing.above),
		under = vector.new(pointed_thing.under),
	}
end

local function check_attached_node(p, n)
	local def = minetest.registered_nodes[n.name]
	local d = {x = 0, y = 0, z = 0}
	if def.paramtype2 == "wallmounted" then
		-- The fallback vector here is in case 'wallmounted to dir' is nil due
		-- to voxelmanip placing a wallmounted node without resetting a
		-- pre-existing param2 value that is out-of-range for wallmounted.
		-- The fallback vector corresponds to param2 = 0.
		d = minetest.wallmounted_to_dir(n.param2) or {x = 0, y = 1, z = 0}
	else
		d.y = -1
	end
	local p2 = vector.add(p, d)
	local nn = minetest.get_node(p2).name
	local def2 = minetest.registered_nodes[nn]
	if def2 and not def2.walkable then
		return false
	end
	return true
end

digtron.item_place_node = function(itemstack, placer, place_to, param2)
	local item = itemstack:peek_item()
	local def = itemstack:get_definition()
	if def.type ~= "node" then
		return itemstack, false
	end

	local pointed_thing = {}
	pointed_thing.type = "node"
	pointed_thing.above = {x=place_to.x, y=place_to.y, z=place_to.z}
	pointed_thing.under = {x=place_to.x, y=place_to.y - 1, z=place_to.z}

	local oldnode = minetest.get_node_or_nil(place_to)

	--this should never happen, digtron is testing for adjacent unloaded nodes before getting here.
	if not oldnode then
		minetest.log("info", placer:get_player_name() .. " tried to place"
			.. " node in unloaded position " .. minetest.pos_to_string(place_to)
			.. " using a digtron.")
		return itemstack, false
	end

	local newnode = {name = def.name, param1 = 0, param2 = param2}
	if def.place_param2 ~= nil then
		newnode.param2 = def.place_param2
	end

	-- Check if the node is attached and if it can be placed there
	if minetest.get_item_group(def.name, "attached_node") ~= 0 and
		not check_attached_node(place_to, newnode) then
		minetest.log("action", "attached node " .. def.name ..
			" can not be placed at " .. minetest.pos_to_string(place_to))
		return itemstack, false
	end
	
	-- digtron HACK! the default torch mod uses "on_place" to change its model to the correct one,
	-- not "after_place_node". It probably should be using after_place_node, but until then I must
	-- adapt as best I can to the quirks of default.
	if newnode.name == "default:torch" then
		if newnode.param2 == 0 then
			newnode.name = "default:torch_ceiling"
		elseif newnode.param2 > 1 then
			newnode.name = "default:torch_wall"
		end
	end

	-- Add node and update
	minetest.add_node(place_to, newnode)

	local take_item = true

	-- Run callback
	if def.after_place_node then
		-- Deepcopy place_to and pointed_thing because callback can modify it
		local place_to_copy = {x=place_to.x, y=place_to.y, z=place_to.z}
		local pointed_thing_copy = copy_pointed_thing(pointed_thing)
		if def.after_place_node(place_to_copy, placer, itemstack,
				pointed_thing_copy) then
			take_item = false
		end
	end

	-- Run script hook
	local _, callback
	for _, callback in ipairs(minetest.registered_on_placenodes) do
		-- Deepcopy pos, node and pointed_thing because callback can modify them
		local place_to_copy = {x=place_to.x, y=place_to.y, z=place_to.z}
		local newnode_copy = {name=newnode.name, param1=newnode.param1, param2=newnode.param2}
		local oldnode_copy = {name=oldnode.name, param1=oldnode.param1, param2=oldnode.param2}
		local pointed_thing_copy = copy_pointed_thing(pointed_thing)
		if callback(place_to_copy, newnode_copy, placer, oldnode_copy, itemstack, pointed_thing_copy) then
			take_item = false
		end
	end

	if take_item then
		itemstack:take_item()
	end
	return itemstack, true
end