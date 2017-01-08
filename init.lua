dofile( minetest.get_modpath( "digtron" ) .. "/util.lua" )
dofile( minetest.get_modpath( "digtron" ) .. "/pointset.lua" )
dofile( minetest.get_modpath( "digtron" ) .. "/entities.lua" )
dofile( minetest.get_modpath( "digtron" ) .. "/node_misc.lua" ) -- contains structure and light nodes
dofile( minetest.get_modpath( "digtron" ) .. "/node_storage.lua" ) -- contains inventory and fuel storage nodes
dofile( minetest.get_modpath( "digtron" ) .. "/node_diggers.lua" ) -- contains all diggers
dofile( minetest.get_modpath( "digtron" ) .. "/node_builders.lua" ) -- contains all builders (there's just one currently)
dofile( minetest.get_modpath( "digtron" ) .. "/node_controllers.lua" ) -- controllers
dofile( minetest.get_modpath( "digtron" ) .. "/node_axle.lua" ) -- Rotation controller
dofile( minetest.get_modpath( "digtron" ) .. "/recipes.lua" )

digtron.creative_mode = false -- this causes digtrons to operate without consuming fuel or building materials.
digtron.particle_effects = true -- Enables the spray of particles out the back of a digger head and puffs of smoke from the controller
digtron.lava_impassible = true -- when true, lava counts as protected nodes.
digtron.diggers_damage_creatures = true -- when true, diggers deal damage to creatures when they trigger.

digtron.cycle_time = 1 -- How many seconds a digtron waits between cycles. Auto-controllers can make this wait longer, but cannot make it shorter.
digtron.traction_factor = 3.0 -- How many digtron nodes can be moved for each adjacent solid node that the digtron has traction against

-- fuel costs. For comparison, in the default game:
-- one default tree block is 30 units
-- one coal lump is 40 units
-- one coal block is 370 units (apparently it's slightly more productive making your coal lumps into blocks before burning)
-- one book is 3 units

local dig_cost_adjustment_factor = 0.5 -- across-the-board multiplier to make overall fuel costs easier to modify

digtron.dig_cost_default = 1.0 * dig_cost_adjustment_factor -- how much fuel is required to dig a node if not in one of the following groups.
-- If a node is in more than one of the following groups, the group with the maximum cost for that node is used.
digtron.dig_cost_cracky = 2.0 * dig_cost_adjustment_factor -- eg, stone
digtron.dig_cost_crumbly = 1.0 * dig_cost_adjustment_factor -- eg, dirt, sand
digtron.dig_cost_choppy = 1.5 * dig_cost_adjustment_factor -- eg, wood

digtron.build_cost = 1.0 -- how much fuel is required to build a node

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