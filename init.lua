digtron = {}
digtron.doc = {}

digtron.config = {}

digtron.config.marker_crate_bad_duration = 5
digtron.config.marker_crate_good_duration = 5

local modpath = minetest.get_modpath(minetest.get_current_modname())

dofile(modpath.."/entities.lua")
dofile(modpath.."/functions.lua")
dofile(modpath.."/controller.lua")
dofile(modpath.."/nodes/node_misc.lua")
dofile(modpath.."/nodes/node_storage.lua")