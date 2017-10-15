-- internationalization boilerplate
local MP = minetest.get_modpath(minetest.get_current_modname())
local S, NS = dofile(MP.."/intllib.lua")

local pipeworks_path = minetest.get_modpath("pipeworks")

minetest.register_node("digtron:inventory_ejector", {
	description = S("Digtron Inventory Ejector"),
	_doc_items_longdesc = digtron.doc.inventory_ejector_longdesc,
    _doc_items_usagehelp = digtron.doc.inventory_ejector_usagehelp,
	groups = {cracky = 3,  oddly_breakable_by_hand=3, digtron = 1, tubedevice = 1},
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
		connect_sides = {back = 1}
	} end end)(),
	
	on_rightclick = function(pos, node, player)
		local dir = minetest.facedir_to_dir(node.param2)
		local destination_pos = vector.add(pos, dir)
		local destination_node_name = minetest.get_node(destination_pos).name
		local destination_node_def = minetest.registered_nodes[destination_node_name]
		local layout = DigtronLayout.create(pos, player)

		-- Build a list of all the items that builder nodes want to use.
		local filter_items = {}
		for _, node_image in pairs(layout.builders) do
			filter_items[node_image.meta.inventory.main[1]:get_name()] = true
		end
		
		-- Look through the inventories and find an item that's not on that list.
		local source_node = nil
		local source_index = nil
		local source_stack = nil
		for _, node_image in pairs(layout.inventories) do
			for index, item_stack in pairs(node_image.meta.inventory.main) do
				if item_stack:get_count() > 0 and not filter_items[item_stack:get_name()] then
					source_node = node_image
					source_index = index
					source_stack = item_stack
					break
				end
			end
			if source_node then break end
		end
		
		if source_node then
			local meta = minetest.get_meta(source_node.pos)
			local inv = meta:get_inventory()
			
			if pipeworks_path and minetest.get_node_group(destination_node_name, "tubedevice") > 0 then
				local from_pos = vector.add(pos, vector.multiply(dir, 0.5))
				local start_pos = pos--vector.add(pos, dir)
				inv:set_stack("main", source_index, nil)
				pipeworks.tube_inject_item(from_pos, start_pos, vector.multiply(dir, 1), source_stack, player:get_player_name())
				minetest.sound_play("steam_puff", {gain=0.5, pos=pos})
			elseif destination_node_def and not destination_node_def.walkable then
				minetest.add_item(destination_pos, source_stack)
				inv:set_stack("main", source_index, nil)
				minetest.sound_play("steam_puff", {gain=0.5, pos=pos})
			else
				minetest.sound_play("buzzer", {gain=0.5, pos=pos})
			end
		end		
	end,
	
	after_place_node = (function() if pipeworks_path then return pipeworks.after_place end end)(),
	after_dig_node = (function() if pipeworks_path then return pipeworks.after_dig end end)()
})
