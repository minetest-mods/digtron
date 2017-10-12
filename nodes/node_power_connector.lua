-- internationalization boilerplate
local MP = minetest.get_modpath(minetest.get_current_modname())
local S, NS = dofile(MP.."/intllib.lua")

local size = 3/16

local max_dig_cost = math.max(digtron.config.dig_cost_cracky, digtron.config.dig_cost_crumbly, digtron.config.dig_cost_choppy, digtron.config.dig_cost_default)

minetest.register_node("digtron:power_connector", {
	description = S("DPC"),
	_doc_items_longdesc = digtron.doc.power_connector_longdesc,
    _doc_items_usagehelp = digtron.doc.power_connector_usagehelp,
	groups = {cracky = 3,  oddly_breakable_by_hand=3, digtron = 8, technic_machine=1, technic_hv=1},
	tiles = {"digtron_plate.png"},
	connect_sides = {"bottom", "top", "left", "right", "front", "back"},
	drawtype = "nodebox",
	sounds = digtron.metal_sounds,
	paramtype = "light",
	paramtype2 = "facedir",
	is_ground_content = false,
--	node_box = {
--		type = "fixed",
--		fixed = {
--			{-0.5, 0.5, -0.5, 0.5, 0, 0.5}, -- NodeBox1
--			{-0.1875, 0, -0.1875, 0.1875, -0.5, 0.1875}, -- NodeBox2
--			{-0.3125, -0.0625, -0.3125, 0.3125, -0.1875, 0.3125}, -- NodeBox3
--			{-0.3125, -0.25, -0.3125, 0.3125, -0.375, 0.3125}, -- NodeBox4
--		}
--	},
	
	connects_to = {"group:technic_hv_cable"},
	node_box = {
		type = "connected",
		fixed          = {
			{-0.5, -0.5, -0.5, 0.5, 0, 0.5}, -- NodeBox1
			{-0.1875, 0, -0.1875, 0.1875, 0.5, 0.1875}, -- NodeBox2
			{-0.3125, 0.0625, -0.3125, 0.3125, 0.1875, 0.3125}, -- NodeBox3
			{-0.3125, 0.25, -0.3125, 0.3125, 0.375, 0.3125}, -- NodeBox4
		},
		connect_front  = {-size, -size, -0.5,  size,  size, size}, -- z-
		connect_back   = {-size, -size,  size, size,  size, 0.5 }, -- z+
		connect_left   = {-0.5,  -size, -size, size,  size, size}, -- x-
		connect_right  = {-size, -size, -size, 0.5,   size, size}, -- x+
	},
	
	technic_run = function(pos, node)
		local meta = minetest.get_meta(pos)
		local eu_input = meta:get_int("HV_EU_input")
		local demand = meta:get_int("HV_EU_demand")
		meta:set_string("infotext", S("Digtron Power @1/@2\nRight-click to update", eu_input, demand))
	end,
	
	on_rightclick = function(pos, node, player, itemstack, pointed_thing)
		local layout = DigtronLayout.create(pos, player)
		local max_cost = 0
		for _, node_image in pairs(layout.builders) do
			max_cost = max_cost + digtron.config.build_cost
		end 
		for _, node_image in pairs(layout.diggers) do
			max_cost = max_cost + max_dig_cost
		end
		local meta = minetest.get_meta(pos)
		meta:set_int("HV_EU_demand", max_cost * digtron.config.power_ratio)		
	end,

})


technic.register_machine("HV", "digtron:power_connector", technic.receiver)