-- internationalization boilerplate
local MP = minetest.get_modpath(minetest.get_current_modname())
local S, NS = dofile(MP.."/intllib.lua")

local inventory_formspec_string = 
	"size[9,9.3]" ..
	default.gui_bg ..
	default.gui_bg_img ..
	default.gui_slots ..
	"label[0,0;" .. S("Digtron components") .. "]" ..
	"list[current_name;main;0,0.6;8,4;]" ..
	"list[current_player;main;0,5.15;8,1;]" ..
	"list[current_player;main;0,6.38;8,3;8]" ..
	"listring[current_name;main]" ..
	"listring[current_player;main]" ..
	default.get_hotbar_bg(0,5.15)..
	"button_exit[8,3.5;1,1;duplicate;"..S("Duplicate").."]" ..
	"tooltip[duplicate;" .. S("Puts a copy of the adjacent Digtron into an empty crate\nlocated at the output side of the duplicator,\nusing components from the duplicator's inventory.") .. "]"

if minetest.get_modpath("doc") then
	inventory_formspec_string = inventory_formspec_string ..
		"button_exit[8,4.5;1,1;help;"..S("Help").."]" ..
		"tooltip[help;" .. S("Show documentation about this block") .. "]"
end
	
minetest.register_node("digtron:duplicator", {
	description = S("Digtron Duplicator"),
	_doc_items_longdesc = digtron.doc.duplicator_longdesc,
    _doc_items_usagehelp = digtron.doc.duplicator_usagehelp,
	groups = {cracky = 3,  oddly_breakable_by_hand=3},
	sounds = digtron.metal_sounds,
	tiles = {"digtron_plate.png^(digtron_axel_side.png^[transformR90)",
		"digtron_plate.png^(digtron_axel_side.png^[transformR270)",
		"digtron_plate.png^digtron_axel_side.png",
		"digtron_plate.png^(digtron_axel_side.png^[transformR180)",
		"digtron_plate.png^digtron_builder.png",
		"digtron_plate.png",
	},
	paramtype = "light",
	paramtype2= "facedir",
	is_ground_content = false,	
	drawtype="nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			{-0.5, 0.3125, 0.3125, 0.5, 0.5, 0.5}, -- FrontFrame_top
			{-0.5, -0.5, 0.3125, 0.5, -0.3125, 0.5}, -- FrontFrame_bottom
			{0.3125, -0.3125, 0.3125, 0.5, 0.3125, 0.5}, -- FrontFrame_right
			{-0.5, -0.3125, 0.3125, -0.3125, 0.3125, 0.5}, -- FrontFrame_left
			{-0.0625, -0.3125, 0.3125, 0.0625, 0.3125, 0.375}, -- frontcross_vertical
			{-0.3125, -0.0625, 0.3125, 0.3125, 0.0625, 0.375}, -- frontcross_horizontal
			{-0.4375, -0.4375, -0.4375, 0.4375, 0.4375, 0.3125}, -- Body
			{-0.5, -0.3125, -0.5, -0.3125, 0.3125, -0.3125}, -- backframe_vertical
			{0.3125, -0.3125, -0.5, 0.5, 0.3125, -0.3125}, -- backframe_left
			{-0.5, 0.3125, -0.5, 0.5, 0.5, -0.3125}, -- backframe_top
			{-0.5, -0.5, -0.5, 0.5, -0.3125, -0.3125}, -- backframe_bottom
			{-0.0625, -0.0625, -0.5625, 0.0625, 0.0625, -0.4375}, -- back_probe
		},
	},
	selection_box = {
	    type = "regular"
	},
	
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("formspec", inventory_formspec_string)
		local inv = meta:get_inventory()
		inv:set_size("main", 8*4)
	end,
	
	can_dig = function(pos,player)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		return inv:is_empty("main")
	end,
	
	allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		if minetest.get_item_group(stack:get_name(), "digtron") > 0 then
			return stack:get_count()
		else
			return 0
		end
	end,
	
	on_receive_fields = function(pos, formname, fields, sender)
		if fields.help then
			minetest.after(0.5, doc.show_entry, sender:get_player_name(), "nodes", "digtron:duplicator", true)
		end
	
		if fields.duplicate then
			local node = minetest.get_node(pos)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			local target_pos = vector.add(pos, minetest.facedir_to_dir(node.param2))
			local target_node = minetest.get_node(target_pos)

			if target_node.name ~= "digtron:empty_crate" then
				minetest.sound_play("buzzer", {gain=0.5, pos=pos})
				meta:set_string("infotext", S("Needs an empty crate in output position to store duplicate"))
				return
			end
			
			local layout = DigtronLayout.create(pos, sender)
			
			if layout.contains_protected_node then
				minetest.sound_play("buzzer", {gain=0.5, pos=pos})
				meta:set_string("infotext", S("Digtron can't be duplicated, it contains protected blocks"))
				return
			end
			
			if #layout.all == 1 then
				minetest.sound_play("buzzer", {gain=0.5, pos=pos})
				meta:set_string("infotext", S("No Digtron components adjacent to duplicate"))
				return
			end
			
			layout.all[1] = {node={name="digtron:empty_crate"}, meta={fields = {}, inventory = {}}, pos={x=pos.x, y=pos.y, z=pos.z}} -- replace the duplicator's image with the empty crate image
			
			-- count required nodes, skipping node 1 since it's the crate and we already know it's present in-world
			local required_count = {}
			for i = 2, #layout.all do
				local nodename = layout.all[i].node.name
				required_count[nodename] = (required_count[nodename] or 0) + 1
			end
						
			-- check that there's enough in the duplicator's inventory
			local unsatisfied = {}
			for name, count in pairs(required_count) do
				if not inv:contains_item("main", ItemStack({name=name, count=count})) then
					table.insert(unsatisfied, tostring(count) .. " " .. minetest.registered_nodes[name].description)
				end
			end			
			if #unsatisfied > 0 then
				minetest.sound_play("dingding", {gain=1.0, pos=pos}) -- Insufficient inventory
				meta:set_string("infotext", S("Duplicator requires:\n@1", table.concat(unsatisfied, "\n")))
				return
			end
			
			meta:set_string("infotext", "") -- clear infotext, we're good to go.
		
			-- deduct nodes from duplicator inventory
			for name, count in pairs(required_count) do
				inv:remove_item("main", ItemStack({name=name, count=count}))
			end

			-- clear inventories of image's nodes		
			if layout.inventories ~= nil then
				for _, node_image in pairs(layout.inventories) do
					local main_inventory = node_image.meta.inventory.main
					if type(main_inventory) ~= "table" then
						main_inventory = {}
					end
					for index, _ in pairs(main_inventory) do
						main_inventory[index] = ItemStack(nil)
					end
				end
			end
			if layout.fuelstores ~= nil then
				for _, node_image in pairs(layout.fuelstores) do
					local fuel_inventory = node_image.meta.inventory.fuel
					for index, _ in pairs(fuel_inventory) do
						fuel_inventory[index] = ItemStack(nil)
					end
				end
			end
			if layout.battery_holders ~= nil then
				for _, node_image in pairs(layout.battery_holders) do
					local battery_inventory = node_image.meta.inventory.batteries
					for index, _ in pairs(battery_inventory) do
						battery_inventory[index] = ItemStack(nil)
					end
				end
			end

			-- replace empty crate with loaded crate and write image to its metadata
			local layout_string = layout:serialize()
			
			minetest.set_node(target_pos, {name="digtron:loaded_crate", param1=node.param1, param2=node.param2})
			local target_meta = minetest.get_meta(target_pos)
			target_meta:set_string("crated_layout", layout_string)
			
			local titlestring = S("Crated @1-block Digtron", tostring(#layout.all-1))
			target_meta:set_string("title", titlestring)
			target_meta:set_string("infotext", titlestring)
			minetest.sound_play("machine1", {gain=1.0, pos=pos})
		end
	end,

})
