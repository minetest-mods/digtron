digtron = {}

digtron.auto_controller_colorize = "#88000030"
digtron.pusher_controller_colorize = "#00880030"
digtron.soft_digger_colorize = "#88880030"

dofile( minetest.get_modpath( "digtron" ) .. "/util.lua" )
dofile( minetest.get_modpath( "digtron" ) .. "/doc.lua" )
dofile( minetest.get_modpath( "digtron" ) .. "/awards.lua" )
dofile( minetest.get_modpath( "digtron" ) .. "/class_pointset.lua" )
dofile( minetest.get_modpath( "digtron" ) .. "/class_layout.lua" )
dofile( minetest.get_modpath( "digtron" ) .. "/entities.lua" )
dofile( minetest.get_modpath( "digtron" ) .. "/node_misc.lua" ) -- contains structure and light nodes
dofile( minetest.get_modpath( "digtron" ) .. "/node_storage.lua" ) -- contains inventory and fuel storage nodes
dofile( minetest.get_modpath( "digtron" ) .. "/node_diggers.lua" ) -- contains all diggers
dofile( minetest.get_modpath( "digtron" ) .. "/node_builders.lua" ) -- contains all builders (there's just one currently)
dofile( minetest.get_modpath( "digtron" ) .. "/node_controllers.lua" ) -- controllers
dofile( minetest.get_modpath( "digtron" ) .. "/node_axle.lua" ) -- Rotation controller
dofile( minetest.get_modpath( "digtron" ) .. "/node_crate.lua" ) -- Digtron portability support
dofile( minetest.get_modpath( "digtron" ) .. "/recipes.lua" )

-- Enables the spray of particles out the back of a digger head and puffs of smoke from the controller
local particle_effects = minetest.setting_getbool("enable_particles")

-- this causes digtrons to operate without consuming fuel or building materials.
local digtron_uses_resources = minetest.setting_getbool("digtron_uses_resources")
if digtron_uses_resources == nil then digtron_uses_resources = true end

-- when true, lava counts as protected nodes.
local lava_impassible = minetest.setting_getbool("digtron_lava_impassible")

-- when true, diggers deal damage to creatures when they trigger.
local damage_creatures = minetest.setting_getbool("digtron_damage_creatures")

digtron.creative_mode = not digtron_uses_resources -- default false
digtron.particle_effects = particle_effects or particle_effects == nil -- default true
digtron.lava_impassible = lava_impassible or lava_impassible == nil -- default true
digtron.diggers_damage_creatures = damage_creatures or damage_creatures == nil -- default true

-- How many seconds a digtron waits between cycles. Auto-controllers can make this wait longer, but cannot make it shorter.
local digtron_cycle_time = tonumber(minetest.setting_get("digtron_cycle_time"))
if digtron_cycle_time == nil or digtron_cycle_time < 0 then
	digtron.cycle_time = 1.0
else
	digtron.cycle_time = digtron_cycle_time
end

-- How many digtron nodes can be moved for each adjacent solid node that the digtron has traction against
local digtron_traction_factor = tonumber(minetest.setting_get("digtron_traction_factor"))
if digtron_traction_factor == nil or digtron_traction_factor < 0 then
	digtron.traction_factor = 3.0
else
	digtron.traction_factor = digtron_traction_factor
end

-- fuel costs. For comparison, in the default game:
-- one default tree block is 30 units
-- one coal lump is 40 units
-- one coal block is 370 units (apparently it's slightly more productive making your coal lumps into blocks before burning)
-- one book is 3 units

-- how much fuel is required to dig a node if not in one of the following groups.
local digtron_dig_cost_default = tonumber(minetest.setting_get("digtron_dig_cost_default"))
if digtron_dig_cost_default == nil or digtron_dig_cost_default < 0 then
	digtron.dig_cost_default = 0.5
else
	digtron.dig_cost_default = digtron_dig_cost_default
end
-- eg, stone
local digtron_dig_cost_cracky = tonumber(minetest.setting_get("digtron_dig_cost_cracky"))
if digtron_dig_cost_cracky == nil or digtron_dig_cost_cracky < 0 then
	digtron.dig_cost_cracky = 1.0
else
	digtron.dig_cost_cracky = digtron_dig_cost_cracky
end
-- eg, dirt, sand
local digtron_dig_cost_crumbly = tonumber(minetest.setting_get("digtron_dig_cost_crumbly"))
if digtron_dig_cost_crumbly == nil or digtron_dig_cost_crumbly < 0 then
	digtron.dig_cost_crumbly = 0.5
else
	digtron.dig_cost_crumbly = digtron_dig_cost_crumbly
end
-- eg, wood
local digtron_dig_cost_choppy = tonumber(minetest.setting_get("digtron_dig_cost_choppy"))
if digtron_dig_cost_choppy == nil or digtron_dig_cost_choppy < 0 then
	digtron.dig_cost_choppy = 0.75
else
	digtron.dig_cost_choppy = digtron_dig_cost_choppy
end
-- how much fuel is required to build a node
local digtron_build_cost = tonumber(minetest.setting_get("digtron_build_cost"))
if digtron_build_cost == nil or digtron_build_cost < 0 then
	digtron.build_cost = 1.0
else
	digtron.build_cost = digtron_build_cost
end

-- digtron group numbers:
-- 1 - generic digtron node, nothing special is done with these. They're just dragged along.
-- 2 - inventory-holding digtron, has a "main" inventory that the digtron can add to and take from.
-- 3 - digger head, has an "execute_dig" method in its definition
-- 4 - builder head, has a "test_build" and "execute_build" method in its definition
-- 5 - fuel-holding digtron, has a "fuel" invetory that the control node can draw fuel items from. Separate from general inventory, nothing gets put here automatically.
-- 6 - holds both fuel and main inventories

minetest.register_lbm({
	name = "digtron:sand_digger_upgrade",
	nodenames = {"digtron:sand_digger"},
	action = function(pos, node)
		local meta = minetest.get_meta(pos)
		local offset = meta:get_string("offset")
		local period = meta:get_string("period")
		minetest.set_node(pos, {name = "digtron:soft_digger",
			param2 = node.param2})
		meta:set_string("offset", offset)
		meta:set_string("period", period)
	end
})

minetest.register_lbm({
	name = "digtron:fuelstore_upgrade",
	nodenames = {"digtron:fuelstore"},
	action = function(pos, node)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		local list = inv:get_list("main")
		inv:set_list("main", {})
		inv:set_list("fuel", list)		
		meta:set_string("formspec",
			"size[8,9.3]" ..
			default.gui_bg ..
			default.gui_bg_img ..
			default.gui_slots ..
			"label[0,0;Fuel items]" ..
			"list[current_name;fuel;0,0.6;8,4;]" ..
			"list[current_player;main;0,5.15;8,1;]" ..
			"list[current_player;main;0,6.38;8,3;8]" ..
			"listring[current_name;fuel]" ..
			"listring[current_player;main]" ..
			default.get_hotbar_bg(0,5.15)
		)		
	end
})

minetest.register_lbm({
	name = "digtron:autocontroller_lateral_upgrade",
	nodenames = {"digtron:auto_controller"},
	action = function(pos, node)
		local meta = minetest.get_meta(pos)
		local cycles = meta:get_int("offset")
		meta:set_int("cycles", cycles)
		meta:set_int("offset", 0)
		meta:set_int("slope", 0)
		meta:set_string("formspec",
			"size[3.5,2]" ..
			default.gui_bg ..
			default.gui_bg_img ..
			default.gui_slots ..
			"field[0.5,0.8;1,0.1;cycles;Cycles;${cycles}]" ..
			"tooltip[cycles;When triggered, this controller will try to run for the given number of cycles.\nThe cycle count will decrement as it runs, so if it gets halted by a problem\nyou can fix the problem and restart.]" ..
			"button_exit[1.2,0.5;1,0.1;set;Set]" ..
			"tooltip[set;Saves the cycle setting without starting the controller running]" ..
			"button_exit[2.2,0.5;1,0.1;execute;Set &\nExecute]" ..
			"tooltip[execute;Begins executing the given number of cycles]" ..
			"field[0.5,2.0;1,0.1;slope;Slope;${slope}]" ..
			"tooltip[slope;For diagonal digging. After every X nodes the auto controller moves forward,\nthe controller will add an additional cycle moving the digtron laterally in the\ndirection of the arrows on the side of this controller.\nSet to 0 for no lateral digging.]" ..
			"field[1.5,2.0;1,0.1;offset;Offset;${offset}]" ..
			"tooltip[offset;Sets the offset of the lateral motion defined in the Slope field.\nNote: this offset is relative to the controller's location.\nThe controller will move down when it reaches the indicated point.]" ..
			"field[2.5,2.0;1,0.1;period;Delay;${period}]" ..
			"tooltip[period;Number of seconds to wait between each cycle]"
		)		
	end
})

if minetest.get_modpath("catacomb") and catacomb ~= nil and catacomb.chamber_protected_nodes ~= nil and catacomb.passage_protected_nodes ~= nil then
	local digtron_nodes = {
		minetest.get_content_id("digtron:inventory"),
		minetest.get_content_id("digtron:fuelstore"),
		minetest.get_content_id("digtron:combined_storage"),
		minetest.get_content_id("digtron:axle"),
		minetest.get_content_id("digtron:builder"),
		minetest.get_content_id("digtron:controller"),
		minetest.get_content_id("digtron:auto_controller"),
		minetest.get_content_id("digtron:pusher"),
		minetest.get_content_id("digtron:loaded_crate"),
		minetest.get_content_id("digtron:digger"),
		minetest.get_content_id("digtron:intermittent_digger"),
		minetest.get_content_id("digtron:soft_digger"),
		minetest.get_content_id("digtron:intermittent_soft_digger"),
		minetest.get_content_id("digtron:dual_digger"),
		minetest.get_content_id("digtron:dual_soft_digger"),
		minetest.get_content_id("digtron:structure"),
		minetest.get_content_id("digtron:light"),
		minetest.get_content_id("digtron:panel"),
		minetest.get_content_id("digtron:edge_panel"),
		minetest.get_content_id("digtron:corner_panel"),
	}
	for _, node_id in pairs(digtron_nodes) do
		catacomb.chamber_protected_nodes[node_id] = true
		catacomb.passage_protected_nodes[node_id] = true
	end
end