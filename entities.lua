-- The default minetest.add_entity crashes with an exception if you try adding an entity in an unloaded area
-- this wrapper catches that exception and just ignores it.
safe_add_entity = function(pos, name)
	local success, ret = pcall(minetest.add_entity, pos, name)
	if success then return ret else return nil end
end

-------------------------------------------------------------------------------------------------
-- For displaying where things get built under which periodicities

minetest.register_entity("digtron:marker", {
	initial_properties = {
		visual = "cube",
		visual_size = {x=1.05, y=1.05},
		textures = {"digtron_marker_side.png","digtron_marker_side.png","digtron_marker.png","digtron_marker.png","digtron_marker_side.png","digtron_marker_side.png"},
		collisionbox = {-0.525, -0.525, -0.525, 0.525, 0.525, 0.525},
		physical = false,
	},

	on_activate = function(self, staticdata)
		minetest.after(5.0, 
			function(self) 
				self.object:remove()
			end,
			self)
	end,
	
	on_rightclick=function(self, clicker)
		self.object:remove()
	end,
	
	on_punch = function(self, hitter)
		self.object:remove()
	end,
})

local vertical = {x=1.5708, y=0, z=0}
-- TODO: update to new method of finding buildpos?
-- TODO: add item indicator entity as well
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
	local entity = safe_add_entity({x=buildpos.x, y=y_pos, z=buildpos.z}, "digtron:marker")
	if entity ~= nil then entity:set_rotation(vertical) end
	if y_pos >= buildpos.y then
		local entity = safe_add_entity({x=buildpos.x, y=y_pos - period, z=buildpos.z}, "digtron:marker")
		if entity ~= nil then entity:set_rotation(vertical) end
	end
	if y_pos <= buildpos.y then
		local entity = safe_add_entity({x=buildpos.x, y=y_pos + period, z=buildpos.z}, "digtron:marker")
		if entity ~= nil then entity:set_rotation(vertical) end
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

-----------------------------------------------------------------------------------------------
-- For displaying whether nodes are part of a digtron or are obstructed

digtron.show_buildable_nodes = function(succeeded, failed)
	if succeeded then
		for _, pos in ipairs(succeeded) do
			safe_add_entity(pos, "digtron:marker_crate_good")
		end
	end
	if failed then
		for _, pos in ipairs(failed) do
			safe_add_entity(pos, "digtron:marker_crate_bad")
		end
	end
end


minetest.register_entity("digtron:marker_crate_good", {
	initial_properties = {
		visual = "cube",
		visual_size = {x=1.05, y=1.05},
		textures = {"digtron_crate.png", "digtron_crate.png", "digtron_crate.png", "digtron_crate.png", "digtron_crate.png", "digtron_crate.png"},
		collisionbox = {-0.525, -0.525, -0.525, 0.525, 0.525, 0.525},
		physical = false,
		glow = minetest.LIGHT_MAX,
	},

	on_activate = function(self, staticdata)
		minetest.after(digtron.config.marker_crate_good_duration, 
			function(self) 
				self.object:remove()
			end,
			self)
	end,
	
	on_rightclick=function(self, clicker)
		self.object:remove()
	end,
	
	on_punch = function(self, hitter)
		self.object:remove()
	end,
})

minetest.register_entity("digtron:marker_crate_bad", {
	initial_properties = {
		visual = "cube",
		visual_size = {x=1.05, y=1.05},
		textures = {"digtron_no_entry.png", "digtron_no_entry.png", "digtron_no_entry.png", "digtron_no_entry.png", "digtron_no_entry.png", "digtron_no_entry.png"},
		collisionbox = {-0.525, -0.525, -0.525, 0.525, 0.525, 0.525},
		physical = false,
		glow = minetest.LIGHT_MAX,
	},

	on_activate = function(self, staticdata)
		minetest.after(digtron.config.marker_crate_bad_duration, 
			function(self) 
				self.object:remove()
			end,
			self)
	end,
	
	on_rightclick=function(self, clicker)
		self.object:remove()
	end,
	
	on_punch = function(self, hitter)
		self.object:remove()
	end,
})

-----------------------------------------------------------------------------------------------------------------
-- Builder items

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
	local node = minetest.get_node(pos)
	if minetest.get_node_group(node.name, "digtron") ~= 4 then
		return
	end	
	local target_pos = vector.add(pos, minetest.facedir_to_dir(node.param2))
	digtron.remove_builder_item(target_pos)
	local meta = minetest.get_meta(pos)
	local item = meta:get_string("item")
	if item ~= "" then
		digtron.create_builder_item = item
		minetest.add_entity(target_pos,"digtron:builder_item")
	end
end

minetest.register_entity("digtron:builder_item", {

	initial_properties = {
		hp_max = 1,
		is_visible = true,
		visual = "wielditem",
		visual_size = {x=0.3333, y=0.3333},
		collisionbox = {0,0,0,0,0,0},
		physical = false,
		textures = {""},
		automatic_rotate = math.pi * 0.25,
	},
	
	on_activate = function(self, staticdata)
		local props = self.object:get_properties()
		if staticdata ~= nil and staticdata ~= "" then
			local pos = self.object:getpos()
			local adjacent_builder = false
			for _, dir in ipairs(digtron.cardinal_dirs) do
				local target_pos = vector.add(pos, dir)
				local node = minetest.get_node(target_pos)
				if minetest.get_node_group(node.name, "digtron") == 4 then
					-- Not checking whether the adjacent builder is aimed right,
					-- has the right builder_item, etc. This is just a failsafe
					-- to clean up entities that somehow got left behind when a
					-- Digtron moved, not that important really
					adjacent_builder = true
					break
				end
			end
			if not adjacent_builder then
				self.object:remove()
				return
			end
			
			props.textures = {staticdata}
			self.object:set_properties(props)
		elseif digtron.create_builder_item ~= nil then
			props.textures = {digtron.create_builder_item}
			self.object:set_properties(props)
			digtron.create_builder_item = nil
		else
			self.object:remove()
		end		
	end,
	
	get_staticdata = function(self)
		local props = self.object:get_properties()
		if props ~= nil and props.textures ~= nil and props.textures[1] ~= nil then
			return props.textures[1]
		end
		return ""
	end,
})
