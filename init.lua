digtron = {}

digtron.auto_controller_colorize = "#88000030"
digtron.pusher_controller_colorize = "#00880030"
digtron.soft_digger_colorize = "#88880030"

-- A global dictionary is used here so that other substitutions can be added easily by other mods, if necessary
digtron.builder_read_item_substitutions = {
	["default:torch_ceiling"] = "default:torch",
	["default:torch_wall"] = "default:torch",
	["default:dirt_with_grass"] = "default:dirt",
	["default:dirt_with_grass_footsteps"] = "default:dirt",
	["default:dirt_with_dry_grass"] = "default:dirt",
	["default:dirt_with_rainforest_litter"] = "default:dirt",
	["default:dirt_with_snow"] = "default:dirt",
	["default:furnace_active"] = "default:furnace",
	["farming:soil"] = "default:dirt",
	["farming:soil_wet"] = "default:dirt",
	["farming:desert_sand_soil"] = "default:desert_sand",
	["farming:desert_sand_soil_wet"] = "default:desert_sand",
}

dofile( minetest.get_modpath( "digtron" ) .. "/config.lua" )
dofile( minetest.get_modpath( "digtron" ) .. "/util.lua" )
dofile( minetest.get_modpath( "digtron" ) .. "/doc.lua" )
dofile( minetest.get_modpath( "digtron" ) .. "/awards.lua" )
dofile( minetest.get_modpath( "digtron" ) .. "/class_pointset.lua" )
dofile( minetest.get_modpath( "digtron" ) .. "/class_layout.lua" )
dofile( minetest.get_modpath( "digtron" ) .. "/entities.lua" )
dofile( minetest.get_modpath( "digtron" ) .. "/nodes/node_misc.lua" ) -- contains structure and light nodes
dofile( minetest.get_modpath( "digtron" ) .. "/nodes/node_storage.lua" ) -- contains inventory and fuel storage nodes
dofile( minetest.get_modpath( "digtron" ) .. "/nodes/node_diggers.lua" ) -- contains all diggers
dofile( minetest.get_modpath( "digtron" ) .. "/nodes/node_builders.lua" ) -- contains all builders (there's just one currently)
dofile( minetest.get_modpath( "digtron" ) .. "/nodes/node_controllers.lua" ) -- controllers
dofile( minetest.get_modpath( "digtron" ) .. "/nodes/node_axle.lua" ) -- Rotation controller
dofile( minetest.get_modpath( "digtron" ) .. "/nodes/node_crate.lua" ) -- Digtron portability support
dofile( minetest.get_modpath( "digtron" ) .. "/nodes/recipes.lua" )

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

-- internationalization boilerplate
local MP = minetest.get_modpath(minetest.get_current_modname())
local S, NS = dofile(MP.."/intllib.lua")

minetest.register_lbm({
	name = "digtron:builder_extrusion_upgrade",
	nodenames = {"digtron:builder"},
	action = function(pos, node)
		local meta = minetest.get_meta(pos)
		meta:set_int("extrusion", 1)
		meta:set_string("formspec",
			"size[8,5.2]" ..
			default.gui_bg ..
			default.gui_bg_img ..
			default.gui_slots ..
			"list[current_name;main;0.5,0;1,1;]" ..
			"label[0.5,0.8;" .. S("Block to build") .. "]" ..
			"field[2.3,0.8;1,0.1;extrusion;" .. S("Extrusion") .. ";${extrusion}]" ..
			"tooltip[extrusion;" .. S("Builder will extrude this many blocks in the direction it is facing.\nCan be set from 1 to @1.\nNote that Digtron won't build into unloaded map regions.", digtron.config.maximum_extrusion) .. "]" ..
			"field[3.3,0.8;1,0.1;period;" .. S("Periodicity") .. ";${period}]" ..
			"tooltip[period;" .. S("Builder will build once every n steps.\nThese steps are globally aligned, so all builders with the\nsame period and offset will build on the same location.") .. "]" ..
			"field[4.3,0.8;1,0.1;offset;" .. S("Offset") .. ";${offset}]" ..
			"tooltip[offset;" .. S("Offsets the start of periodicity counting by this amount.\nFor example, a builder with period 2 and offset 0 builds\nevery even-numbered block and one with period 2 and\noffset 1 builds every odd-numbered block.") .. "]" ..
			"button_exit[5.0,0.5;1,0.1;set;" .. S("Save &\nShow") .. "]" ..
			"tooltip[set;" .. S("Saves settings") .. "]" ..
			"field[6.3,0.8;1,0.1;build_facing;" .. S("Facing") .. ";${build_facing}]" ..
			"tooltip[build_facing;" .. S("Value from 0-23. Not all block types make use of this.\nUse the 'Read & Save' button to copy the facing of the block\ncurrently in the builder output location.") .. "]" ..
			"button_exit[7.0,0.5;1,0.1;read;" .. S("Read &\nSave") .. "]" ..
			"tooltip[read;" .. S("Reads the facing of the block currently in the build location,\nthen saves all settings.") .. "]" ..
			"list[current_player;main;0,1.3;8,1;]" ..
			default.get_hotbar_bg(0,1.3) ..
			"list[current_player;main;0,2.5;8,3;8]" ..
			"listring[current_player;main]" ..
			"listring[current_name;main]"
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