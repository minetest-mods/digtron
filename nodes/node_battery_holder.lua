-- internationalization boilerplate
local S = digtron.S
-- local MP = minetest.get_modpath(minetest.get_current_modname())
-- local S = dofile(MP.."/intllib.lua")


-- Battery storage. Controller node draws electrical power from here.
-- Note that batttery boxes are digtron group 7.

local battery_holder_formspec_string = "size[8,9.3]" ..
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

local battery_holder_formspec = function()
	return battery_holder_formspec_string
end

local holder_groups = {cracky = 3,  oddly_breakable_by_hand = 3, digtron = 7, tubedevice = 1, tubedevice_receiver = 1}
if not minetest.get_modpath("technic") then
	-- if technic isn't installed there's no point in offering battery holders.
	-- leave them registered, though, in case technic is being removed from an existing server.
	holder_groups.not_in_creative_inventory = 1
end

minetest.register_node("digtron:battery_holder", {
	description = S("Digtron Battery Holder"),
	_doc_items_longdesc = digtron.doc.battery_holder_longdesc,
	_doc_items_usagehelp = digtron.doc.battery_holder_usagehelp,
	_digtron_formspec = battery_holder_formspec,
	groups = holder_groups,
	drop = "digtron:battery_holder",
	sounds = digtron.metal_sounds,
	paramtype2= "facedir",
	drawtype = "nodebox",
	node_box = {
        type = "fixed",
        fixed = {
            {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
        },
    },
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
		meta:set_string("formspec", battery_holder_formspec(pos, meta))
		local inv = meta:get_inventory()
		inv:set_size("batteries", 8*4)
	end,

	-- Allow all items with energy storage to be placed in the inventory
	allow_metadata_inventory_put = function(_, listname, _, stack)
		if listname == "batteries" then
			local node_name = stack:get_name()

			-- Allow all items with energy storage from technic mod
			if technic.power_tools[node_name] ~= nil then
				local meta = stack:get_metadata()
				local md = minetest.deserialize(meta)
				-- And specifically if they hold any charge
				-- Disregard empty batteries, the player should know better
				if md and md.charge > 0 then
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


	can_dig = function(pos)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		return inv:is_empty("batteries")
	end,

	-- Pipeworks compatibility
	-- Because who wouldn't send batteries through pipes if he could?
	-----------------------------------------------------------------

	tube = (function() if minetest.get_modpath("pipeworks") then return {
		insert_object = function(pos, _, stack)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			return inv:add_item("batteries", stack)
		end,
		can_insert = function(pos, _, stack)
			local meta = stack:get_metadata()
			local md = minetest.deserialize(meta)
			-- And specifically if they hold any charge
			-- Disregard empty batteries, the player should know better
			if md and md.charge > 0 then
				meta = minetest.get_meta(pos)
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
