-- internationalization boilerplate
local MP = minetest.get_modpath(minetest.get_current_modname())
local S, NS = dofile(MP.."/intllib.lua")


-- Battery storage. Controller node draws electrical power from here.
-- Note that batttery boxes are digtron group 7.

local battery_holder_formspec = 
	"size[8,9.3]" ..
	default.gui_bg ..
	default.gui_bg_img ..
	default.gui_slots ..
	"label[0,0;" .. S("Batteries") .. "]" ..
	"list[current_name;batteries;0,0.6;8,4;]" ..
	"list[current_player;main;0,5.15;8,1;]" ..
	"list[current_player;main;0,6.38;8,3;8]" ..
	"listring[current_name;batteries]" ..
	"listring[current_player;main]" ..
	default.get_hotbar_bg(0,5.15)


minetest.register_node("digtron:battery_holder", {
	description = S("Digtron Battery Holder"),
	_doc_items_longdesc = digtron.doc.battery_holder_longdesc,
	_doc_items_usagehelp = digtron.doc.battery_holder_usagehelp,
	_digtron_formspec = battery_holder_formspec,
	groups = {cracky = 3,  oddly_breakable_by_hand = 3, digtron = 7, tubedevice = 1, tubedevice_receiver = 1},
	drop = "digtron:battery_holder",
	sounds = digtron.metal_sounds,
	paramtype2= "facedir",
	drawtype = "nodebox",
	paramtype = "light",
	is_ground_content = false,
	tiles = {
		"digtron_plate.png^digtron_crossbrace.png^digtron_battery.png",
		"digtron_plate.png^digtron_crossbrace.png^digtron_battery.png",
		"digtron_plate.png^digtron_crossbrace.png^digtron_battery.png^digtron_storage.png",
		"digtron_plate.png^digtron_crossbrace.png^digtron_battery.png^digtron_storage.png",
		"digtron_plate.png^digtron_crossbrace.png^digtron_battery.png^digtron_storage.png",
		"digtron_plate.png^digtron_crossbrace.png^digtron_battery.png^digtron_storage.png",
		},

	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("formspec", battery_holder_formspec)
		local inv = meta:get_inventory()
		inv:set_size("batteries", 8*4)
	end,
	
	-- Only allow RE batteries to be placed in the inventory
	allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		if listname == "batteries" then
			local node_name = stack:get_name()
                                                 
			-- Only allow RE batteries from technic mode
			if node_name == "technic:battery" then                            
				local meta = stack:get_metadata()
				local md = minetest.deserialize(meta)
				-- And specifically if they hold any charge
				-- Disregard empty batteries, the player should know better
				if md.charge > 0 then
					return stack:get_count()    
				else
					return 0
				end
                                                 
			else
				return 0
			end
		end
		return 0
	end,
                                                  
                                                 
	can_dig = function(pos,player)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		return inv:is_empty("batteries")
	end,
		
	-- Pipeworks compatibility
	-- Because who wouldn't send batteries through pipes if he could?
	-----------------------------------------------------------------

	tube = (function() if minetest.get_modpath("pipeworks") then return {
		insert_object = function(pos, node, stack, direction)
			if minetest.get_craft_result({method="batteries", width=1, items={stack}}).time ~= 0 then
				local meta = minetest.get_meta(pos)
				local inv = meta:get_inventory()
				return inv:add_item("batteries", stack)
			end
			return stack
		end,
		can_insert = function(pos, node, stack, direction)
			if minetest.get_craft_result({method="batteries", width=1, items={stack}}).time ~= 0 then
				local meta = minetest.get_meta(pos)
				local inv = meta:get_inventory()
				return inv:room_for_item("batteries", stack)
			end
			return false
		end,
		input_inventory = "batteries",
		connect_sides = {left = 1, right = 1, back = 1, front = 1, bottom = 1, top = 1}
	} end end)(),
	
	after_place_node = (function() if minetest.get_modpath("pipeworks") then return pipeworks.after_place end end)(),
	after_dig_node = (function() if minetest.get_modpath("pipeworks")then return pipeworks.after_dig end end)()
})




----------------------------- previous version below 

--[[


minetest.register_node("digtron:battery_holder", {
	description = S("Digtron Battery Holder"),
	_doc_items_longdesc = digtron.doc.batteryholder_longdesc,
	_doc_items_usagehelp = digtron.doc.batteryholder_usagehelp,
	groups = {cracky = 3,  oddly_breakable_by_hand=3, digtron = 7, tubedevice = 1, tubedevice_receiver = 1},
	drop = "digtron:battery_holder",
	sounds = digtron.metal_sounds,
	paramtype2= "facedir",
	drawtype = "nodebox",
	paramtype = "light",
	is_ground_content = false,
	tiles = {
		"digtron_plate.png^digtron_crossbrace.png^digtron_battery.png",
		"digtron_plate.png^digtron_crossbrace.png^digtron_battery.png",
		"digtron_plate.png^digtron_crossbrace.png^digtron_battery.png^digtron_storage.png",
		"digtron_plate.png^digtron_crossbrace.png^digtron_battery.png^digtron_storage.png",
		"digtron_plate.png^digtron_crossbrace.png^digtron_battery.png^digtron_storage.png",
		"digtron_plate.png^digtron_crossbrace.png^digtron_battery.png^digtron_storage.png",
		},

	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("formspec", 
			"size[8,9.3]" ..
			default.gui_bg ..
			default.gui_bg_img ..
			default.gui_slots ..
			"label[0,0;" .. S("Batteries") .. "]" ..
			"list[current_name;batteries;0,0.6;8,4;]" ..
			"list[current_player;main;0,5.15;8,1;]" ..
			"list[current_player;main;0,6.38;8,3;8]" ..
			"listring[current_name;batteries]" ..
			"listring[current_player;main]" ..
			default.get_hotbar_bg(0,5.15)
		)
		local inv = meta:get_inventory()
		inv:set_size("batteries", 8*4)
	end,
	
	-- Only allow RE batteries to be placed in the inventory
	allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		if listname == "batteries" then
			local node_name = stack:get_name()
                                                 
			-- Only allow RE batteries from technic mode
			if node_name == "technic:battery" then                            
				local meta = stack:get_metadata()
-- 				minetest.chat_send_all(minetest.serialize(meta))
				local md = minetest.deserialize(meta)
				minetest.chat_send_all("Battery has charge: "..md.charge)
				-- And specifically if they hold any charge
				if md.charge > 0 then
					return stack:get_count()    
				else
					return 0
				end
                                                 
			else
				return 0
			end
		end
		return 0
	end,
	
	can_dig = function(pos,player)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		return inv:is_empty("batteries")
	end,
	
                                                  
	-- Pipeworks compatibility
	----------------------------------------------------------------

	tube = (function() if minetest.get_modpath("pipeworks") then return {
		insert_object = function(pos, node, stack, direction)
			local node_name = stack:get_name()
			if node_name == "technic:battery" then      
				local meta = minetest.get_meta(pos)
				local inv = meta:get_inventory()
				return inv:add_item("batteries", stack)
			end
			return stack
		end,
		can_insert = function(pos, node, stack, direction)
			local node_name = stack:get_name()
			if node_name == "technic:battery" then      
				local meta = minetest.get_meta(pos)
				local inv = meta:get_inventory()
				return inv:room_for_item("batteries", stack)
			end
			return false
		end,
		input_inventory = "batteries",
		connect_sides = {left = 1, right = 1, back = 1, front = 1, bottom = 1, top = 1}
	} end end)(),
	
	after_place_node = (function() if minetest.get_modpath("pipeworks") then return pipeworks.after_place end end)(),
	after_dig_node = (function() if minetest.get_modpath("pipeworks")then return pipeworks.after_dig end end)()
})
]]
