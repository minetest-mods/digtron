-- The default minetest.item_place_node from item.lua was hard to work with given some of the details
-- of how it handled pointed_thing. It also didn't work right with default:torch and seeds. It was simpler to
-- just copy it here and chop out the special cases that were causing problems, and add some special handling.
-- for nodes that define on_place

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

local function has_prefix(str, prefix)
	return str:sub(1, string.len(prefix)) == prefix
end

digtron.whitelisted_on_place = function (item_name)
	for listed_item, value in pairs(digtron.builder_on_place_items) do
		if item_name == listed_item then return value end
	end

	for prefix, value in pairs(digtron.builder_on_place_prefixes) do
		if has_prefix(item_name, prefix) then return value end
	end

	if minetest.get_item_group(item_name, "digtron_on_place") > 0 then return true end

	return false
end

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
	local item_name = itemstack:get_name()
	local def = itemstack:get_definition()
	if (not def) or (param2 < 0) or (def.paramtype2 == "wallmounted" and param2 > 5) or (param2 > 23) then -- validate parameters
		return itemstack, false
	end

	local pointed_thing = {}
	pointed_thing.type = "node"
	pointed_thing.above = {x=place_to.x, y=place_to.y, z=place_to.z}
	pointed_thing.under = {x=place_to.x, y=place_to.y - 1, z=place_to.z}

	-- Handle node-specific on_place calls as best we can.
	if def.on_place and def.on_place ~= minetest.nodedef_default.on_place and digtron.whitelisted_on_place(item_name) then
		if def.paramtype2 == "facedir" then
			pointed_thing.under = vector.add(place_to, minetest.facedir_to_dir(param2))
		elseif def.paramtype2 == "wallmounted" then
			pointed_thing.under = vector.add(place_to, minetest.wallmounted_to_dir(param2))
		end

		-- pass a copy of the item stack parameter because on_place might modify it directly and then we can't tell if we succeeded or not
		-- though note that some mods do "creative_mode" handling within their own on_place methods, which makes it impossible for Digtron
		-- to know what to do in that case - if you're in creative_mode Digtron will place such items but it will think it failed and not
		-- deduct them from inventory no matter what Digtron's settings are. Unfortunate, but not very harmful and I have no workaround.
		local returnstack, success = def.on_place(ItemStack(itemstack), placer, pointed_thing)
		if returnstack and returnstack:get_count() < itemstack:get_count() then success = true end -- some mods neglect to return a success condition
		if success then
			-- Override the param2 value to force it to be what Digtron wants
			local placed_node = minetest.get_node(place_to)
			placed_node.param2 = param2
			minetest.set_node(place_to, placed_node)
		end

		return returnstack, success
	end

	if minetest.registered_nodes[item_name] == nil then
		-- Permitted craft items are handled by the node-specific on_place call, above.
		-- if we are a craft item and we get here then we're not whitelisted and we should fail.
		-- Note that builder settings should be filtering out craft items like this before we get here,
		-- but this will protect us just in case.
		return itemstack, false
	end

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

	-- Add node and update
	minetest.add_node(place_to, newnode)

	local take_item = true

	-- Run callback, using genuine player for per-node definition.
	if def.after_place_node then
		-- Deepcopy place_to and pointed_thing because callback can modify it
		local place_to_copy = {x=place_to.x, y=place_to.y, z=place_to.z}
		local pointed_thing_copy = copy_pointed_thing(pointed_thing)
		if def.after_place_node(place_to_copy, placer, itemstack,
				pointed_thing_copy) then
			take_item = false
		end
	end

	-- Run script hook, using fake_player to take the blame.
	-- Note that fake_player:update is called in the DigtronLayout class's "create" function,
	-- which is called before Digtron does any of this building stuff, so it's not necessary
	-- to update it here.
	for _, callback in ipairs(minetest.registered_on_placenodes) do
		-- Deepcopy pos, node and pointed_thing because callback can modify them
		local place_to_copy = {x=place_to.x, y=place_to.y, z=place_to.z}
		local newnode_copy = {name=newnode.name, param1=newnode.param1, param2=newnode.param2}
		local oldnode_copy = {name=oldnode.name, param1=oldnode.param1, param2=oldnode.param2}
		local pointed_thing_copy = copy_pointed_thing(pointed_thing)
		if callback(place_to_copy, newnode_copy, digtron.fake_player, oldnode_copy, itemstack, pointed_thing_copy) then
			take_item = false
		end
	end

	if take_item then
		itemstack:take_item()
	end
	return itemstack, true
end