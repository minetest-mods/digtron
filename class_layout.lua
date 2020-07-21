DigtronLayout = {}
DigtronLayout.__index = DigtronLayout

local modpath_awards = minetest.get_modpath("awards")

-------------------------------------------------------------------------
-- Creation

local get_node_image = function(pos, node)
	local node_image = {node=node, pos={x=pos.x, y=pos.y, z=pos.z}}
	local node_def = minetest.registered_nodes[node.name]
	node_image.paramtype2 = node_def.paramtype2
	local meta = minetest.get_meta(pos)
	node_image.meta = meta:to_table()
	if node_image.meta ~= nil and node_def._digtron_formspec ~= nil then
		node_image.meta.fields.formspec = node_def._digtron_formspec(pos, meta) -- causes formspec to be automatically upgraded whenever Digtron moves
	end
	
	local group = minetest.get_item_group(node.name, "digtron")
	-- group 1 has no special metadata
	if group > 1 and group < 10 then
		assert(node_image ~= nil and node_image.meta ~= nil, "[Digtron] Digtron failed to get a metadata table for a Digtron node in group "
			.. tostring(group) .. ". This error should not be possible. Please see https://github.com/minetest/minetest/issues/8067")
		-- These groups have inventories
		if group == 2 or (group > 3 and group < 8) then
			assert(node_image.meta.inventory ~= nil, "[Digtron] Digtron failed to get a metadata inventory table for a Digtron node in group "
			.. tostring(group) .. ". This error should not be possible. Please see https://github.com/minetest/minetest/issues/8067")
		end
	end
	
	-- Record what kind of thing we've got in a builder node so its facing can be rotated properly
	if group == 4 then
		local build_item = ""
		if node_image.meta.inventory.main then
			build_item = node_image.meta.inventory.main[1]
		end
		if build_item ~= "" then
			local build_item_def = minetest.registered_nodes[ItemStack(build_item):get_name()]
			if build_item_def ~= nil then
				node_image.build_item_paramtype2 = build_item_def.paramtype2
			end
		end
	end
	return node_image
end

-- temporary pointsets used while searching
local to_test = Pointset.create()
local tested = Pointset.create()

function DigtronLayout.create(pos, player)
	local self = {}
	setmetatable(self, DigtronLayout)

	--initialize. We're assuming that the start position is a controller digtron, should be a safe assumption since only the controller node should call this
	self.traction = 0
	self.all = {}
	self.water_touching = false
	self.lava_touching = false
	self.protected = Pointset.create() -- if any nodes we look at are protected, make note of that. That way we don't need to keep re-testing protection state later.
	self.old_pos_pointset = Pointset.create() -- For tracking original location of nodes if we do transformations on the Digtron
	self.nodes_dug = Pointset.create() -- For tracking adjacent nodes that will have been dug by digger heads in future
	self.contains_protected_node = false -- used to indicate if at least one node in this digtron array is protected from the player.
	self.controller = {x=pos.x, y=pos.y, z=pos.z} 	--Make a deep copy of the pos parameter just in case the calling code wants to play silly buggers with it

	table.insert(self.all, get_node_image(pos, minetest.get_node(pos))) -- We never visit the source node, so insert it into the all table a priori. Revisit this design decision if a controller node is created that contains fuel or inventory or whatever.

	self.extents_max_x = pos.x
	self.extents_min_x = pos.x
	self.extents_max_y = pos.y
	self.extents_min_y = pos.y
	self.extents_max_z = pos.z
	self.extents_min_z = pos.z

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
			--digtron array is next to unloaded nodes, too dangerous to do anything. Abort.
			self.ignore_touching = true
		end
		
		if minetest.get_item_group(node.name, "water") ~= 0 then
			self.water_touching = true
		elseif minetest.get_item_group(node.name, "lava") ~= 0 then
			self.lava_touching = true
			if digtron.config.lava_impassible then
				self.protected:set(testpos.x, testpos.y, testpos.z, true)
			end
		end

		local is_protected = false
		if minetest.is_protected(testpos, player:get_player_name()) and not minetest.check_player_privs(player, "protection_bypass") then
			self.protected:set(testpos.x, testpos.y, testpos.z, true)
			is_protected = true
		end
		
		local group_number = minetest.get_item_group(node.name, "digtron")
		if group_number > 0 then
			--found one. Add it to the digtrons output
			local node_image = get_node_image(testpos, node)
			
			table.insert(self.all, node_image)

			-- add a reference to this node's position to special node lists
			if group_number == 2 then
				self.inventories = self.inventories or {}
				table.insert(self.inventories, node_image)
			elseif group_number == 3 then
				self.diggers = self.diggers or {}
				table.insert(self.diggers, node_image)
			elseif group_number == 4 then
				self.builders = self.builders or {}
				table.insert(self.builders, node_image)
			elseif group_number == 5 then
				self.fuelstores = self.fuelstores or {}
				table.insert(self.fuelstores, node_image)
			elseif group_number == 6 then
				self.inventories = self.inventories or {}
				self.fuelstores = self.fuelstores or {}
				table.insert(self.inventories, node_image)
				table.insert(self.fuelstores, node_image)
			elseif group_number == 7 then -- technic batteries
				self.battery_holders = self.battery_holders or {}
				table.insert(self.battery_holders, node_image)
			elseif group_number == 8 then
				self.power_connectors = self.power_connectors or {}
				table.insert(self.power_connectors, node_image) -- technic power connectors
			elseif group_number == 9 and node_image.meta.fields["autoeject"] == "true" then
				self.auto_ejectors = self.auto_ejectors or {}
				table.insert(self.auto_ejectors, node_image)
			end
			
			if is_protected then
				self.contains_protected_node = true
			end
			
			-- update extents
			self.extents_max_x = math.max(self.extents_max_x, testpos.x)
			self.extents_min_x = math.min(self.extents_min_x, testpos.x)
			self.extents_max_y = math.max(self.extents_max_y, testpos.y)
			self.extents_min_y = math.min(self.extents_min_y, testpos.y)
			self.extents_max_z = math.max(self.extents_max_z, testpos.z)
			self.extents_min_z = math.min(self.extents_min_z, testpos.z)
			
			--queue up potential new test points adjacent to this digtron node
			to_test:set_if_not_in(tested, testpos.x + 1, testpos.y, testpos.z, true)
			to_test:set_if_not_in(tested, testpos.x - 1, testpos.y, testpos.z, true)
			to_test:set_if_not_in(tested, testpos.x, testpos.y + 1, testpos.z, true)
			to_test:set_if_not_in(tested, testpos.x, testpos.y - 1, testpos.z, true)
			to_test:set_if_not_in(tested, testpos.x, testpos.y, testpos.z + 1, true)
			to_test:set_if_not_in(tested, testpos.x, testpos.y, testpos.z - 1, true)
		elseif not minetest.registered_nodes[node.name] or minetest.registered_nodes[node.name].buildable_to ~= true then
			-- Tracks whether the digtron is hovering in mid-air. If any part of the digtron array touches something solid it gains traction.
			-- Allowing unknown nodes to provide traction, since they're not buildable_to either
			self.traction = self.traction + 1
		end
		
		testpos, _ = to_test:pop()
	end
	
	digtron.award_layout(self, player) -- hook for achievements mod
	
	to_test:clear()
	tested:clear()
	
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
-- operates directly on the pos vector
local rotate_pos = function(axis, direction, pos)
	if axis == "x" then
		if direction < 0 then
			local temp_z = pos.z
			pos.z = pos.y
			pos.y = -temp_z
		else
			local temp_z = pos.z
			pos.z = -pos.y
			pos.y = temp_z
		end
	elseif axis == "y" then
		if direction < 0 then
			local temp_x = pos.x
			pos.x = -pos.z
			pos.z = temp_x
		else
			local temp_x = pos.x
			pos.x = pos.z
			pos.z = -temp_x
		end
	else	
		if direction < 0 then
			local temp_x = pos.x
			pos.x = -pos.y
			pos.y = temp_x
		else
			local temp_x = pos.x
			pos.x = pos.y
			pos.y = -temp_x
		end
	end
	return pos
end

-- operates directly on the pos vector
local subtract_in_place = function(pos, subtract)
	pos.x = pos.x - subtract.x
	pos.y = pos.y - subtract.y
	pos.z = pos.z - subtract.z
	return pos
end
local add_in_place = function(pos, add)
	pos.x = pos.x + add.x
	pos.y = pos.y + add.y
	pos.z = pos.z + add.z
	return pos
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
	local pos = subtract_in_place(node_image.pos, origin)
	pos = rotate_pos(axis, direction, pos)
	-- Move back to original reference frame
	node_image.pos = add_in_place(pos, origin)
	
	return node_image	
end


local top = {
	[0]={axis="y", dir=-1},
	{axis="z", dir=1},
	{axis="z", dir=-1},
	{axis="x", dir=1},
	{axis="x", dir=-1},
	{axis="y", dir=1},
}
-- Rotates 90 degrees widdershins around the axis defined by facedir (which in this case is pointing out the front of the node, so it needs to be converted into an upward-pointing axis internally)
function DigtronLayout.rotate_layout_image(self, facedir)

	if self == nil or self.all == nil or self.controller == nil or self.old_pos_pointset == nil then
		-- this should not be possible, but if it is then abort.
		return false
	end

	-- To convert this into the direction the "top" of the axle node is pointing in:
	-- 0, 1, 2, 3 == (0,1,0)
	-- 4, 5, 6, 7 == (0,0,1)
	-- 8, 9, 10, 11 == (0,0,-1)
	-- 12, 13, 14, 15 == (1,0,0)
	-- 16, 17, 18, 19 == (-1,0,0)
	-- 20, 21, 22, 23== (0,-1,0)
	
	local params = top[math.floor(facedir/4)]
	
	for k, node_image in pairs(self.all) do
		rotate_node_image(node_image, self.controller, params.axis, params.dir, self.old_pos_pointset)
	end
	return self
end

-----------------------------------------------------------------------------------------------
-- Translation

function DigtronLayout.move_layout_image(self, dir)
	self.extents_max_x = self.extents_max_x + dir.x
	self.extents_min_x = self.extents_min_x + dir.x
	self.extents_max_y = self.extents_max_y + dir.y
	self.extents_min_y = self.extents_min_y + dir.y
	self.extents_max_z = self.extents_max_z + dir.z
	self.extents_min_z = self.extents_min_z + dir.z
	
	for k, node_image in pairs(self.all) do
		self.old_pos_pointset:set(node_image.pos.x, node_image.pos.y, node_image.pos.z, true)
		node_image.pos = add_in_place(node_image.pos, dir)
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

-- We need to call on_dignode and on_placenode for dug and placed nodes,
-- but that triggers falling nodes (sand and whatnot) and destroys Digtrons
-- if done during mid-write. So we need to defer the calls until after the
-- Digtron has been fully written.

-- using local counters and shared tables like this allows us to avoid some needless allocating and garbage-collecting of tables
local dug_nodes_count = 0
local dug_node_pos = {}
local dug_node = {}
local dug_node_meta = {}

local placed_nodes_count = 0
local placed_node_pos = {}
local placed_new_node = {}
local placed_old_node = {}

local node_callbacks = function(player)
	if dug_nodes_count > 0 then
		for i = 1, dug_nodes_count do
			local old_pos = dug_node_pos[i]
			local old_node = dug_node[i]
			local old_meta = dug_node_meta[i]
	
			for _, callback in ipairs(minetest.registered_on_dignodes) do
				-- Copy pos and node because callback can modify them
				local pos_copy = {x=old_pos.x, y=old_pos.y, z=old_pos.z}
				local oldnode_copy = {name=old_node.name, param1=old_node.param1, param2=old_node.param2}
				callback(pos_copy, oldnode_copy, digtron.fake_player)
			end
	
			local old_def = minetest.registered_nodes[old_node.name]
			if old_def ~= nil and old_def.after_dig_node ~= nil then
				old_def.after_dig_node(old_pos, old_node, old_meta, player)
			end
		end
	end

	if placed_nodes_count > 0 then
		for i = 1, placed_nodes_count do
			local new_pos = placed_node_pos[i]
			local new_node = placed_new_node[i]
			local old_node = placed_old_node[i]
	
			for _, callback in ipairs(minetest.registered_on_placenodes) do
				-- Copy pos and node because callback can modify them
				local pos_copy = {x=new_pos.x, y=new_pos.y, z=new_pos.z}
				local oldnode_copy = {name=old_node.name, param1=old_node.param1, param2=old_node.param2}
				local newnode_copy = {name=new_node.name, param1=new_node.param1, param2=new_node.param2}
				callback(pos_copy, newnode_copy, digtron.fake_player, oldnode_copy)
			end
	
			local new_def = minetest.registered_nodes[new_node.name]
			if new_def ~= nil and new_def.after_place_node ~= nil then
				new_def.after_place_node(new_pos, player)
			end
		end
	end
end

local set_node_with_retry = function(pos, node)
	local start_time = minetest.get_us_time()
	while not minetest.set_node(pos, node) do
		if minetest.get_us_time() - start_time > 1000000 then -- 1 second in useconds
			return false
		end
	end
	return true
end

local set_meta_with_retry = function(meta, meta_table)
	local start_time = minetest.get_us_time()
	while not meta:from_table(meta_table) do
		if minetest.get_us_time() - start_time > 1000000 then -- 1 second in useconds
			return false
		end
	end
	return true
end

local air_node = {name="air"}
function DigtronLayout.write_layout_image(self, player)
	-- destroy the old digtron
	local oldpos, _ = self.old_pos_pointset:pop()
	while oldpos ~= nil do
		local old_node = minetest.get_node(oldpos)
		local old_meta = minetest.get_meta(oldpos):to_table()

		if not set_node_with_retry(oldpos, air_node) then
			minetest.log("error", "DigtronLayout.write_layout_image failed to destroy old Digtron node, aborting write.")
			return false
		end

		dug_nodes_count = dug_nodes_count + 1
		dug_node_pos[dug_nodes_count] = oldpos
		dug_node[dug_nodes_count] = old_node
		dug_node_meta[dug_nodes_count] = old_meta
		oldpos, _ = self.old_pos_pointset:pop()
	end

	-- create the new one
	for k, node_image in pairs(self.all) do
		local new_pos = node_image.pos
		local new_node = node_image.node
		local old_node = minetest.get_node(new_pos)

		if not (set_node_with_retry(new_pos, new_node) and set_meta_with_retry(minetest.get_meta(new_pos), node_image.meta)) then
			minetest.log("error", "DigtronLayout.write_layout_image failed to write a Digtron node, aborting write.")
			return false
		end
		
		placed_nodes_count = placed_nodes_count + 1
		placed_node_pos[placed_nodes_count] = new_pos
		placed_new_node[placed_nodes_count] = new_node
		placed_old_node[placed_nodes_count] = old_node
	end
	
	-- fake_player will be passed to callbacks to prevent actual player from "taking the blame" for this action.
	-- For example, the hunger mod shouldn't be making the player hungry when he moves Digtron.
	digtron.fake_player:update(self.controller, player:get_player_name())
	-- note that the actual player is still passed to the per-node after_place_node and after_dig_node, should they exist.
	node_callbacks(player)
	dug_nodes_count = 0
	placed_nodes_count = 0
	return true
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
	local deserialized_layout = minetest.deserialize(layout_string)

	self.all = deserialized_layout.all
	self.controller = deserialized_layout.controller
	self.old_pos_pointset = Pointset.create() -- needed by the write_layout method, leave empty

	return self
end
