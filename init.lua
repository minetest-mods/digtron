digtron = {}
digtron.doc = {} -- TODO: move to doc file

digtron.mod_meta = minetest.get_mod_storage()

local modpath = minetest.get_modpath(minetest.get_current_modname())

dofile(modpath.."/config.lua")
dofile(modpath.."/entities.lua")
dofile(modpath.."/functions.lua")
dofile(modpath.."/controller.lua")
dofile(modpath.."/nodes/node_misc.lua")
dofile(modpath.."/nodes/node_storage.lua")
dofile(modpath.."/nodes/node_digger.lua")