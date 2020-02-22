local S = digtron.S

--Build up the formspec, somewhat complicated due to multiple mod options
local pipeworks_path = minetest.get_modpath("pipeworks")


local function eject_items(pos, node, player, eject_even_without_pipeworks, layout)
	local dir = minetest.facedir_to_dir(node.param2)
	local destination_pos = vector.add(pos, dir)
	local destination_node_name = minetest.get_node(destination_pos).name
	local destination_node_def = minetest.registered_nodes[destination_node_name]
	
	local insert_into_pipe = false

	-- Build a list of all the items that builder nodes want to use.
	local filter_items = {}
	if layout.builders ~= nil then
		for _, node_image in pairs(layout.builders) do
			filter_items[node_image.meta.inventory.main[1]:get_name()] = true
		end
	end
	
	-- Look through the inventories and find an item that's not on that list.
	local source_node = nil
	local source_index = nil
	local source_stack = nil
	for _, node_image in pairs(layout.inventories or {}) do
		if type(node_image.meta.inventory.main) ~= "table" then
			node_image.meta.inventory.main = {}
		end
		for index, item_stack in pairs(node_image.meta.inventory.main) do
			if item_stack:get_count() > 0 and not filter_items[item_stack:get_name()] then
				source_node = node_image
				source_index = index
				source_stack = item_stack
				node_image.meta.inventory.main[index] = nil
				break
			end
		end
		if source_node then break end
	end
	
	if source_node then
		local meta = minetest.get_meta(source_node.pos)
		local inv = meta:get_inventory()
		
		if insert_into_pipe then
			local from_pos = vector.add(pos, vector.multiply(dir, 0.5))
			local start_pos = pos
			inv:set_stack("main", source_index, nil)
			pipeworks.tube_inject_item(from_pos, start_pos, dir, source_stack, player:get_player_name())
			minetest.sound_play("steam_puff", {gain=0.5, pos=pos})
			return true
		end
	end

	-- couldn't find an item to eject
	return false
end


-- TODO: hoppers need enhancement to support this

---- Hopper compatibility
--if minetest.get_modpath("hopper") and hopper ~= nil and hopper.add_container ~= nil then
--	hopper:add_container({
--		{"top", "digtron:inventory", "main"},
--		{"bottom", "digtron:inventory", "main"},
--		{"side", "digtron:inventory", "main"},
--
--		{"top", "digtron:fuelstore", "fuel"},
--		{"bottom", "digtron:fuelstore", "fuel"},
--		{"side", "digtron:fuelstore", "fuel"},
--	
--		{"top", "digtron:combined_storage", "main"},
--		{"bottom", "digtron:combined_storage", "main"},
--		{"side", "digtron:combined_storage", "fuel"},
--	})
--end


local ejector_def = {
	description = S("Digtron Inventory Interface"),
	_doc_items_longdesc = digtron.doc.inventory_ejector_longdesc,
    _doc_items_usagehelp = digtron.doc.inventory_ejector_usagehelp,
	_digtron_formspec = ejector_formspec,
	groups = {cracky = 3,  oddly_breakable_by_hand=3, digtron = 9, tubedevice = 1},
	tiles = {"digtron_plate.png", "digtron_plate.png", "digtron_plate.png", "digtron_plate.png", "digtron_plate.png^digtron_output.png", "digtron_plate.png^digtron_output_back.png"},
	drawtype = "nodebox",
	sounds = digtron.metal_sounds,
	paramtype = "light",
	paramtype2 = "facedir",
	is_ground_content = false,
	node_box = {
		type = "fixed",
		fixed = {
			{-0.5, -0.5, -0.5, 0.5, 0.5, 0.1875}, -- NodeBox1
			{-0.3125, -0.3125, 0.1875, 0.3125, 0.3125, 0.3125}, -- NodeBox2
			{-0.1875, -0.1875, 0.3125, 0.1875, 0.1875, 0.5}, -- NodeBox3
		}
	},
	
	tube = (function() if pipeworks_path then return {
		insert_object = function(pos, node, stack, direction)
			local meta = minetest.get_meta(pos)
			local digtron_id = meta:get_string("digtron_id")
			local inv = digtron.retrieve_inventory(digtron_id)
			if inv == nil then
				-- TODO error message
				return
			end

--			return inv:add_item("main", stack)
		end,
		can_insert = function(pos, node, stack, direction)
			local meta = minetest.get_meta(pos)
			local digtron_id = meta:get_string("digtron_id")
			local inv = digtron.retrieve_inventory(digtron_id)
			if inv == nil then
				-- TODO error message
				return
			end

--			return inv:room_for_item("main", stack)
		end,
		input_inventory = "main",
		connect_sides = {back = 1}
	} end end)(),
	
	after_place_node = (function() if pipeworks_path then return pipeworks.after_place end end)(),
	after_dig_node = (function() if pipeworks_path then return pipeworks.after_dig end end)()
})

minetest.register_node("digtron:pipeworks_interface", ejector_def)
