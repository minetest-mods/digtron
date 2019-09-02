digtron = {}
digtron.doc = {} -- TODO: move to doc file

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

-- Sometimes we want builder heads to call an item's "on_place" method, other times we
-- don't want them to. There's no way to tell which situation is best programmatically
-- so we have to rely on whitelists to be on the safe side.
--first exact matches are tested, and the value given in this global table is returned
digtron.builder_on_place_items = {
	["default:torch"] = true,
}
-- Then a string prefix is checked, returning this value. Useful for enabling on_placed on a mod-wide basis.
digtron.builder_on_place_prefixes = {
	["farming:"] = true,
	["farming_plus:"] = true,
	["crops:"] = true, 
}
-- Finally, items belonging to group "digtron_on_place" will have their on_place methods called.



digtron.mod_meta = minetest.get_mod_storage()

local modpath = minetest.get_modpath(minetest.get_current_modname())
dofile(modpath.."/config.lua")

dofile(modpath.."/class_fakeplayer.lua")
digtron.fake_player = DigtronFakePlayer.create({x=0,y=0,z=0}, "fake_player") -- since we only need one fake player at a time and it doesn't retain useful state, create a global one and just update it as needed.
dofile(modpath.."/util_item_place_node.lua")

dofile(modpath.."/geometry.lua")
dofile(modpath.."/entities.lua")
dofile(modpath.."/functions.lua")
dofile(modpath.."/controller.lua")
dofile(modpath.."/nodes/node_misc.lua")
dofile(modpath.."/nodes/node_storage.lua")
dofile(modpath.."/nodes/node_digger.lua")
dofile(modpath.."/nodes/node_builder.lua")
dofile(modpath.."/nodes/node_duplicator.lua")
dofile(modpath.."/nodes/recipes.lua")


-- digtron group numbers:
-- 1 - generic digtron node, nothing special is done with these. They're just dragged along.
-- 2 - inventory-holding digtron, has a "main" inventory that the digtron can add to and take from.
-- 4 - builder head
-- 5 - fuel-holding digtron, has a "fuel" invetory that the control node can draw fuel items from. Separate from general inventory, nothing gets put here automatically.
-- 6 - holds both fuel and main inventories
-- 7 - holds batteries (RE Battery from technic) to provide clean renewable power
-- 8 - connects to adjacent HV technic cable
-- 9 - connects to pipeworks
-- 10 digger
-- 11 dual-headed digger
-- 12 soft digger
-- 13 dual-headed soft digger