-- internationalization boilerplate
local MP = minetest.get_modpath(minetest.get_current_modname())
local S, NS = dofile(MP.."/intllib.lua")

local size = 3/16

local max_dig_cost = math.max(digtron.config.dig_cost_cracky, digtron.config.dig_cost_crumbly, digtron.config.dig_cost_choppy, digtron.config.dig_cost_default)

local get_formspec_string = function(current_val, current_max)
	return "size[4.5,0.6]" ..
		default.gui_bg ..
		default.gui_bg_img ..
		default.gui_slots ..
		"field[0.2,0.3;1,1;value;;".. current_val .. "]" ..
		"button[1,0;1,1;maximize;" .. S("Maximize\nPower") .."]" ..
		"label[2,0;"..S("Maximum Power\nRequired: @1", current_max) .."]"..
		"button[3.5,0;1,1;refresh;" .. S("Refresh\nMax") .."]"
end

local connector_groups = {cracky = 3, oddly_breakable_by_hand=3, digtron = 8, technic_machine=1, technic_hv=1}
if not minetest.get_modpath("technic") then
	-- Technic is not installed, hide this away.
	connector_groups.not_in_creative_inventory = 1
end

minetest.register_node("digtron:power_connector", {
	description = S("Digtron HV Power Connector"),
	_doc_items_longdesc = digtron.doc.power_connector_longdesc,
    _doc_items_usagehelp = digtron.doc.power_connector_usagehelp,
	groups = connector_groups,
	tiles = {"digtron_plate.png^digtron_power_connector_top.png^digtron_digger_yb_frame.png", "digtron_plate.png^digtron_digger_yb_frame.png",
		"digtron_plate.png^digtron_digger_yb_frame.png^digtron_power_connector_side.png", "digtron_plate.png^digtron_digger_yb_frame.png^digtron_power_connector_side.png",
		"digtron_plate.png^digtron_digger_yb_frame.png^digtron_power_connector_side.png", "digtron_plate.png^digtron_digger_yb_frame.png^digtron_power_connector_side.png",
		},
	connect_sides = {"bottom", "top", "left", "right", "front", "back"},
	drawtype = "nodebox",
	sounds = digtron.metal_sounds,
	paramtype = "light",
	paramtype2 = "facedir",
	is_ground_content = false,
	
	connects_to = {"group:technic_hv_cable"},
	node_box = {
		type = "connected",
		fixed          = {
			{-0.5, -0.5, -0.5, 0.5, 0, 0.5}, -- Main body
			{-0.1875, 0, -0.1875, 0.1875, 0.5, 0.1875}, -- post
			{-0.3125, 0.0625, -0.3125, 0.3125, 0.1875, 0.3125}, -- vane
			{-0.3125, 0.25, -0.3125, 0.3125, 0.375, 0.3125}, -- vane
		},
		connect_front  = {-size, -size, -0.5,  size,  size, size}, -- z-
		connect_back   = {-size, -size,  size, size,  size, 0.5 }, -- z+
		connect_left   = {-0.5,  -size, -size, size,  size, size}, -- x-
		connect_right  = {-size, -size, -size, 0.5,   size, size}, -- x+
	},
	
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("formspec", get_formspec_string(0,0))
	end,

	technic_run = function(pos, node)
		local meta = minetest.get_meta(pos)
		local eu_input = meta:get_int("HV_EU_input")
		local demand = meta:get_int("HV_EU_demand")
		meta:set_string("infotext", S("Digtron Power @1/@2", eu_input, demand))
	end,
	
	on_receive_fields = function(pos, formname, fields, sender)
		local layout = DigtronLayout.create(pos, sender)
		local max_cost = 0
		if layout.builders ~= nil then
			for _, node_image in pairs(layout.builders) do
				max_cost = max_cost + (digtron.config.build_cost * (node_image.meta.fields.extrusion or 1))
			end 
		end
		if layout.diggers ~= nil then
			for _, node_image in pairs(layout.diggers) do
				max_cost = max_cost + max_dig_cost
			end
		end
		local current_max = max_cost * digtron.config.power_ratio
	
		local meta = minetest.get_meta(pos)
		
		if fields.maximize then
			meta:set_int("HV_EU_demand", current_max)
		elseif fields.value ~= nil then
			local number = tonumber(fields.value) or 0
			local number = math.min(math.max(number, 0), current_max)
			meta:set_int("HV_EU_demand", number)
		end
	
		meta:set_string("formspec", get_formspec_string(meta:get_int("HV_EU_demand"), current_max))	
	end,
})

if minetest.get_modpath("technic") then
	technic.register_machine("HV", "digtron:power_connector", technic.receiver)
end