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

local digtron_modpath = minetest.get_modpath( "digtron" )

dofile( digtron_modpath .. "/config.lua" )
dofile( digtron_modpath .. "/util.lua" )
dofile( digtron_modpath .. "/doc.lua" )
dofile( digtron_modpath .. "/awards.lua" )
dofile( digtron_modpath .. "/class_pointset.lua" )
dofile( digtron_modpath .. "/class_layout.lua" )
dofile( digtron_modpath .. "/entities.lua" )
dofile( digtron_modpath .. "/nodes/node_misc.lua" ) -- contains structure and light nodes
dofile( digtron_modpath .. "/nodes/node_storage.lua" ) -- contains inventory and fuel storage nodes
dofile( digtron_modpath .. "/nodes/node_diggers.lua" ) -- contains all diggers
dofile( digtron_modpath .. "/nodes/node_builders.lua" ) -- contains all builders (there's just one currently)
dofile( digtron_modpath .. "/nodes/node_controllers.lua" ) -- controllers
dofile( digtron_modpath .. "/nodes/node_axle.lua" ) -- Rotation controller
dofile( digtron_modpath .. "/nodes/node_crate.lua" ) -- Digtron portability support
dofile( digtron_modpath .. "/nodes/recipes.lua" )

dofile( digtron_modpath .. "/upgrades.lua" ) -- various LBMs for upgrading older versions of Digtron.

-- digtron group numbers:
-- 1 - generic digtron node, nothing special is done with these. They're just dragged along.
-- 2 - inventory-holding digtron, has a "main" inventory that the digtron can add to and take from.
-- 3 - digger head, has an "execute_dig" method in its definition
-- 4 - builder head, has a "test_build" and "execute_build" method in its definition
-- 5 - fuel-holding digtron, has a "fuel" invetory that the control node can draw fuel items from. Separate from general inventory, nothing gets put here automatically.
-- 6 - holds both fuel and main inventories

-- This code was added for use with FaceDeer's fork of the [catacomb] mod. Paramat's version doesn't support customized protected nodes, which causes
-- it to "eat" Digtrons sometimes.
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