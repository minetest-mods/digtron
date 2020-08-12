-- internationalization boilerplate
local MP = minetest.get_modpath(minetest.get_current_modname())
local S, NS = dofile(MP.."/intllib.lua")

--Build up the formspec, somewhat complicated due to multiple mod options
local pipeworks_path = minetest.get_modpath("pipeworks")
local doc_path = minetest.get_modpath("doc")
local formspec_width = 1.5

local ejector_formspec_string = 
	default.gui_bg ..
	default.gui_bg_img ..
	default.gui_slots

if doc_path then
	ejector_formspec_string = ejector_formspec_string ..
		"button_exit[".. 0.2 + formspec_width ..",0.5;1,0.1;help;" .. S("Help") .. "]" ..
		"tooltip[help;" .. S("Show documentation about this block") .. "]"
	formspec_width = formspec_width + 1.5
end

local ejector_formspec_string = "size[".. formspec_width .. ",1]" .. ejector_formspec_string

local ejector_formspec = function(pos, meta)
	local return_string = ejector_formspec_string
	if pipeworks_path then
		return_string = return_string .. "checkbox[0,0.5;nonpipe;"..S("Eject into world")..";"..meta:get_string("nonpipe").."]" ..
			"tooltip[nonpipe;" .. S("When checked, will eject items even if there's no pipe to accept it") .. "]"
	end
	return return_string .. "checkbox[0,0;autoeject;"..S("Automatic")..";"..meta:get_string("autoeject").."]" ..
		"tooltip[autoeject;" .. S("When checked, will eject items automatically with every Digtron cycle.\nItem ejectors can always be operated manually by punching them.") .. "]"
end

local function eject_items(pos, node, player, eject_even_without_pipeworks, layout)
	local dir = minetest.facedir_to_dir(node.param2)
	local destination_pos = vector.add(pos, dir)
	local destination_node_name = minetest.get_node(destination_pos).name
	local destination_node_def = minetest.registered_nodes[destination_node_name]
	
	if not pipeworks_path then eject_even_without_pipeworks = true end -- if pipeworks is not installed, always eject into world (there's no other option)
	
	local insert_into_pipe = false
	local eject_into_world = false
	if pipeworks_path and minetest.get_item_group(destination_node_name, "tubedevice") > 0 then
		insert_into_pipe = true
	elseif eject_even_without_pipeworks then
		if destination_node_def and not destination_node_def.walkable then
			eject_into_world = true
		else
			minetest.sound_play("buzzer", {gain=0.5, pos=pos})
			return false
		end
	else
		return false
	end	

	if layout == nil then
		layout = DigtronLayout.create(pos, player)
	end

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
			pipeworks.tube_inject_item(from_pos, start_pos, vector.multiply(dir, 1), source_stack, player:get_player_name())
			minetest.sound_play("steam_puff", {gain=0.5, pos=pos})
			return true
		elseif eject_into_world then
			minetest.add_item(destination_pos, source_stack)
			inv:set_stack("main", source_index, nil)
			minetest.sound_play("steam_puff", {gain=0.5, pos=pos})
			return true
		end
	end

	-- couldn't find an item to eject
	return false
end

minetest.register_node("digtron:inventory_ejector", {
	description = S("Digtron Inventory Ejector"),
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
	
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("autoeject", "true")
		meta:set_string("formspec", ejector_formspec(pos, meta))
	end,
	
	tube = (function() if pipeworks_path then return {
		connect_sides = {back = 1}
	} end end)(),
	
	on_punch = function(pos, node, player)
		eject_items(pos, node, player, true)
	end,
	
	execute_eject = function(pos, node, player, layout)
		local meta = minetest.get_meta(pos)
		eject_items(pos, node, player, meta:get_string("nonpipe") == "true", layout)
	end,
	
	on_receive_fields = function(pos, formname, fields, sender)
		local meta = minetest.get_meta(pos)
		
		if fields.help and minetest.get_modpath("doc") then --check for mod in case someone disabled it after this digger was built
			local node_name = minetest.get_node(pos).name
			minetest.after(0.5, doc.show_entry, sender:get_player_name(), "nodes", node_name, true)
		end
		
		if fields.nonpipe then
			meta:set_string("nonpipe", fields.nonpipe)
		end
		
		if fields.autoeject then
			meta:set_string("autoeject", fields.autoeject)
		end
		
		meta:set_string("formspec", ejector_formspec(pos, meta))
		
	end,
	
	after_place_node = (function() if pipeworks_path then return pipeworks.after_place end end)(),
	after_dig_node = (function() if pipeworks_path then return pipeworks.after_dig end end)()
})
