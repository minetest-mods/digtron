digtron = {}
digtron.doc = {} -- TODO: move to doc file


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