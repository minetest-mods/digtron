DigtronLayout = {}
DigtronLayout.__index = DigtronLayout

-------------------------------------------------------------------------
-- Creation

local get_node_image = function(pos, node)
	local node_image = {node=node, pos={x=pos.x, y=pos.y, z=pos.z}}
	node_image.paramtype2 = minetest.registered_nodes[node.name].paramtype2
	local meta = minetest.get_meta(pos)
	node_image.meta = meta:to_table()
	
	-- Record what kind of thing we've got in a builder node so its facing can be rotated properly
	if minetest.get_item_group(node.name, "digtron") == 4 then
		local build_item = node_image.meta.inventory.main[1]
		if build_item ~= "" then
			local build_item_def = minetest.registered_nodes[ItemStack(build_item):get_name()]
			if build_item_def ~= nil then
				node_image.build_item_paramtype2 = build_item_def.paramtype2
			end
		end
	end
	return node_image
end

function DigtronLayout.create(pos, player)
	local self = {}
	setmetatable(self, DigtronLayout)

	--initialize. We're assuming that the start position is a controller digtron, should be a safe assumption since only the controller node should call this
	self.traction = 0
	self.all = {}
	self.inventories = {}
	self.fuelstores = {}
	self.diggers = {}
	self.builders = {}
	self.extents = {}
	self.water_touching = false
	self.lava_touching = false
	self.protected = Pointset.create() -- if any nodes we look at are protected, make note of that. That way we don't need to keep re-testing protection state later.
	self.old_pos_pointset = Pointset.create() -- For tracking original location of nodes if we do transformations on the Digtron
	self.nodes_dug = Pointset.create() -- For tracking adjacent nodes that will have been dug by digger heads in future
	self.contains_protected_node = false -- used to indicate if at least one node in this digtron array is protected from the player.
	self.controller = {x=pos.x, y=pos.y, z=pos.z} 	--Make a deep copy of the pos parameter just in case the calling code wants to play silly buggers with it

	table.insert(self.all, get_node_image(pos, minetest.get_node(pos))) -- We never visit the source node, so insert it into the all table a priori. Revisit this design decision if a controller node is created that contains fuel or inventory or whatever.

	self.extents.max_x = pos.x
	self.extents.min_x = pos.x
	self.extents.max_y = pos.y
	self.extents.min_y = pos.y
	self.extents.max_z = pos.z
	self.extents.min_z = pos.z
	
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
		self.protected:set(pos.x, pos.y, pos.z, true)
		self.contains_protected_node = true
	end
	
	-- Do a loop on to_test positions, adding new to_test positions as we find digtron nodes. This is a flood fill operation
	-- that follows node faces (no diagonals)
	local testpos, _ = to_test:pop()
	while testpos ~= nil do
		tested:set(testpos.x, testpos.y, testpos.z, true) -- track nodes we've looked at to prevent infinite loops
		local node = minetest.get_node(testpos)

		if node.name == "ignore" then
			--buildtron array is next to unloaded nodes, too dangerous to do anything. Abort.
			self.all = nil
			return self
		end
		
		if minetest.get_item_group(node.name, "water") ~= 0 then
			self.water_touching = true
		elseif minetest.get_item_group(node.name, "lava") ~= 0 then
			self.lava_touching = true
			if digtron.lava_impassible == true then
				self.protected:set(testpos.x, testpos.y, testpos.z, true)
			end
		end
		
		local group_number = minetest.get_item_group(node.name, "digtron")
		if group_number > 0 then
			--found one. Add it to the digtrons output
			local node_image = get_node_image(testpos, node)
			
			table.insert(self.all, node_image)

			-- add a reference to this node's position to special node lists
			if group_number == 2 then
				table.insert(self.inventories, node_image)
			elseif group_number == 3 then
				table.insert(self.diggers, node_image)
			elseif group_number == 4 then
				table.insert(self.builders, node_image)
			elseif group_number == 5 then
				table.insert(self.fuelstores, node_image)
			elseif group_number == 6 then
				table.insert(self.inventories, node_image)
				table.insert(self.fuelstores, node_image)
			end
			
			if minetest.is_protected(pos, player:get_player_name()) and not minetest.check_player_privs(player, "protection_bypass") then
				self.contains_protected_node = true
			end
			
			-- update extents
			self.extents.max_x = math.max(self.extents.max_x, testpos.x)
			self.extents.min_x = math.min(self.extents.min_x, testpos.x)
			self.extents.max_y = math.max(self.extents.max_y, testpos.y)
			self.extents.min_y = math.min(self.extents.min_y, testpos.y)
			self.extents.max_z = math.max(self.extents.max_z, testpos.z)
			self.extents.min_z = math.min(self.extents.min_z, testpos.z)
			
			--queue up potential new test points adjacent to this digtron node
			to_test:set_if_not_in(tested, testpos.x + 1, testpos.y, testpos.z, true)
			to_test:set_if_not_in(tested, testpos.x - 1, testpos.y, testpos.z, true)
			to_test:set_if_not_in(tested, testpos.x, testpos.y + 1, testpos.z, true)
			to_test:set_if_not_in(tested, testpos.x, testpos.y - 1, testpos.z, true)
			to_test:set_if_not_in(tested, testpos.x, testpos.y, testpos.z + 1, true)
			to_test:set_if_not_in(tested, testpos.x, testpos.y, testpos.z - 1, true)
		elseif minetest.registered_nodes[node.name].buildable_to ~= true then
			-- Tracks whether the digtron is hovering in mid-air. If any part of the digtron array touches something solid it gains traction.
			self.traction = self.traction + 1
		end
		
		testpos, _ = to_test:pop()
	end
	
	digtron.award_layout(self, player:get_player_name()) -- hook for achievements mod
	
	return self
end

------------------------------------------------------------------------
-- Rotation

local facedir_rotate = {
	['x'] = {
		[-1] = {[0]=4, 5, 6, 7, 22, 23, 20, 21, 0, 1, 2, 3, 13, 14, 15, 12, 19, 16, 17, 18, 10, 11, 8, 9}, -- 270 degrees
		[1] = {[0]=8, 9, 10, 11, 0, 1, 2, 3, 22, 23, 20, 21, 15, 12, 13, 14, 17, 18, 19, 16, 6, 7, 4, 5}, -- 90 degrees
	},
	['y'] = {
		[-1] = {[0]=3, 0, 1, 2, 19, 16, 17, 18, 15, 12, 13, 14, 7, 4, 5, 6, 11, 8, 9, 10, 21, 22, 23, 20}, -- 270 degrees
		[1] = {[0]=1, 2, 3, 0, 13, 14, 15, 12, 17, 18, 19, 16, 9, 10, 11, 8, 5, 6, 7, 4, 23, 20, 21, 22}, -- 90 degrees
	},
	['z'] = {
		[-1] = {[0]=16, 17, 18, 19, 5, 6, 7, 4, 11, 8, 9, 10, 0, 1, 2, 3, 20, 21, 22, 23, 12, 13, 14, 15}, -- 270 degrees
		[1] = {[0]=12, 13, 14, 15, 7, 4, 5, 6, 9, 10, 11, 8, 20, 21, 22, 23, 0, 1, 2, 3, 16, 17, 18, 19}, -- 90 degrees
	}
}

local wallmounted_rotate = {
	['x'] = {
		[-1] = {[0]=4, 5, 2, 3, 1, 0}, -- 270 degrees
		[1] = {[0]=5, 4, 2, 3, 0, 1}, -- 90 degrees
	},
	['y'] = {
		[-1] = {[0]=0, 1, 4, 5, 3, 2}, -- 270 degrees
		[1] = {[0]=0, 1, 5, 4, 2, 3}, -- 90 degrees
	},
	['z'] = {
		[-1] = {[0]=3, 2, 0, 1, 4, 5}, -- 270 degrees
		[1] = {[0]=2, 3, 1, 0, 4, 5}, -- 90 degrees
	}
}

	--90 degrees CW about x-axis: (x, y, z) -> (x, -z, y)
	--90 degrees CCW about x-axis: (x, y, z) -> (x, z, -y)
	--90 degrees CW about y-axis: (x, y, z) -> (-z, y, x)
	--90 degrees CCW about y-axis: (x, y, z) -> (z, y, -x)
	--90 degrees CW about z-axis: (x, y, z) -> (y, -x, z)
	--90 degrees CCW about z-axis: (x, y, z) -> (-y, x, z)
local rotate_pos = function(axis, direction, pos)
	if axis == "x" then
		if direction < 0 then
			return {x= pos.x, y= -pos.z, z= pos.y}
		else
			return {x= pos.x, y= pos.z, z= -pos.y}
		end
	elseif axis == "y" then
		if direction < 0 then
			return {x= -pos.z, y= pos.y, z= pos.x}
		else
			return {x= pos.z, y= pos.y, z= -pos.x}
		end
	else	
		if direction < 0 then
			return {x= -pos.y, y= pos.x, z= pos.z}
		else
			return {x= pos.y, y= -pos.x, z= pos.z}
		end
	end
end

local rotate_node_image = function(node_image, origin, axis, direction, old_pos_pointset)
	-- Facings
	if node_image.paramtype2 == "wallmounted" then
		node_image.node.param2 = wallmounted_rotate[axis][direction][node_image.node.param2]
	elseif node_image.paramtype2 == "facedir" then
		node_image.node.param2 = facedir_rotate[axis][direction][node_image.node.param2]
	end
	
	if node_image.build_item_paramtype2 == "wallmounted" then
		node_image.meta.fields.build_facing = wallmounted_rotate[axis][direction][tonumber(node_image.meta.fields.build_facing)]
	elseif node_image.build_item_paramtype2 == "facedir" then
		node_image.meta.fields.build_facing = facedir_rotate[axis][direction][tonumber(node_image.meta.fields.build_facing)]
	end
	
	node_image.meta.fields.waiting = nil -- If we're rotating a controller that's in the "waiting" state, clear it. Otherwise it may stick like that.

	-- record the old location so we can destroy the old node if the rotation operation is possible
	old_pos_pointset:set(node_image.pos.x, node_image.pos.y, node_image.pos.z, true)
	
	-- position in space relative to origin
	local pos = vector.subtract(node_image.pos, origin)
	pos = rotate_pos(axis, direction, pos)
	-- Move back to original reference frame
	node_image.pos = vector.add(pos, origin)
	
	return node_image	
end

-- Rotates 90 degrees widdershins around the axis defined by facedir (which in this case is pointing out the front of the node, so it needs to be converted into an upward-pointing axis internally)
function DigtronLayout.rotate_layout_image(self, facedir)
	-- To convert this into the direction the "top" of the axle node is pointing in:
	-- 0, 1, 2, 3 == (0,1,0)
	-- 4, 5, 6, 7 == (0,0,1)
	-- 8, 9, 10, 11 == (0,0,-1)
	-- 12, 13, 14, 15 == (1,0,0)
	-- 16, 17, 18, 19 == (-1,0,0)
	-- 20, 21, 22, 23== (0,-1,0)
	
	local top = {
		[0]={axis="y", dir=-1},
		{axis="z", dir=1},
		{axis="z", dir=-1},
		{axis="x", dir=1},
		{axis="x", dir=-1},
		{axis="y", dir=1},
	}
	local params = top[math.floor(facedir/4)]
	
	for k, node_image in pairs(self.all) do
		rotate_node_image(node_image, self.controller, params.axis, params.dir, self.old_pos_pointset)
	end
	return self
end

-----------------------------------------------------------------------------------------------
-- Translation

function DigtronLayout.move_layout_image(self, dir)
	local extents = self.extents
	
	extents.max_x = extents.max_x + dir.x
	extents.min_x = extents.min_x + dir.x
	extents.max_y = extents.max_y + dir.y
	extents.min_y = extents.min_y + dir.y
	extents.max_z = extents.max_z + dir.z
	extents.min_z = extents.min_z + dir.z
	
	for k, node_image in pairs(self.all) do
		self.old_pos_pointset:set(node_image.pos.x, node_image.pos.y, node_image.pos.z, true)
		node_image.pos = vector.add(node_image.pos, dir)
		self.nodes_dug:set(node_image.pos.x, node_image.pos.y, node_image.pos.z, false) -- we've moved a digtron node into this space, mark it so that we don't dig it.
	end
end

-----------------------------------------------------------------------------------------------
-- Writing to world

function DigtronLayout.can_write_layout_image(self)
	for k, node_image in pairs(self.all) do
		--check if we're moving into a protected node
		if self.protected:get(node_image.pos.x, node_image.pos.y, node_image.pos.z) then
			return false
		end
		-- check if the target node is buildable_to or is marked as part of the digtron that's moving
		if not (
			self.old_pos_pointset:get(node_image.pos.x, node_image.pos.y, node_image.pos.z)
			or minetest.registered_nodes[minetest.get_node(node_image.pos).name].buildable_to
			) then
			return false
		end
	end
	return true
end

function DigtronLayout.write_layout_image(self, player)
	-- destroy the old digtron
	local oldpos, _ = self.old_pos_pointset:pop()
	while oldpos ~= nil do
		local old_node = minetest.get_node(oldpos)
		local old_meta = minetest.get_meta(oldpos)
		local old_def = minetest.registered_nodes[old_node.name]
		minetest.remove_node(oldpos)
		minetest.log("action", string.format("%s removes Digtron component %s at (%d, %d, %d)", player:get_player_name(), old_node.name, oldpos.x, oldpos.y, oldpos.z))
		if old_def.after_dig_node ~= nil then
			old_def.after_dig_node(oldpos, old_node, old_meta, player)
		end
		oldpos, _ = self.old_pos_pointset:pop()
	end		

	-- create the new one
	for k, node_image in pairs(self.all) do
		minetest.set_node(node_image.pos, node_image.node)
		minetest.get_meta(node_image.pos):from_table(node_image.meta)
		minetest.log("action", string.format("%s adds Digtron component %s at (%d, %d, %d)", player:get_player_name(), node_image.node.name, node_image.pos.x, node_image.pos.y, node_image.pos.z))

		local new_def = minetest.registered_nodes[node_image.node.name]
		if new_def.after_place_node ~= nil then
			new_def.after_place_node(node_image.pos, player)
		end
	end
end


---------------------------------------------------------------------------------------------
-- Serialization. Currently only serializes the data that is needed by the crate, upgrade this function if more is needed

function DigtronLayout.serialize(self)
	-- serialize can't handle ItemStack objects, convert them to strings.
	for _, node_image in pairs(self.all) do
		for k, inv in pairs(node_image.meta.inventory) do
			for index, item in pairs(inv) do
				inv[index] = item:to_string()
			end
		end
	end

	return minetest.serialize({controller=self.controller, all=self.all})
end

function DigtronLayout.deserialize(layout_string)
	local self = {}
	setmetatable(self, DigtronLayout)
	
	if not layout_string or layout_string == "" then
		return nil
	end
	deserialized_layout = minetest.deserialize(layout_string)

	self.all = deserialized_layout.all
	self.controller = deserialized_layout.controller
	self.old_pos_pointset = Pointset.create() -- needed by the write_layout method, leave empty

	return self
end