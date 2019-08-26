digtron = {}
digtron.doc = {} -- TODO: move to doc file

digtron.mod_meta = minetest.get_mod_storage()

local modpath = minetest.get_modpath(minetest.get_current_modname())


dofile(modpath .. "/class_fakeplayer.lua")
digtron.fake_player = DigtronFakePlayer.create({x=0,y=0,z=0}, "fake_player") -- since we only need one fake player at a time and it doesn't retain useful state, create a global one and just update it as needed.

dofile(modpath.."/config.lua")
dofile(modpath.."/entities.lua")
dofile(modpath.."/functions.lua")
dofile(modpath.."/controller.lua")
dofile(modpath.."/nodes/node_misc.lua")
dofile(modpath.."/nodes/node_storage.lua")
dofile(modpath.."/nodes/node_digger.lua")
dofile(modpath.."/nodes/node_builder.lua")