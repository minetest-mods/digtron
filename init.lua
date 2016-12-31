dofile( minetest.get_modpath( "digtron" ) .. "/util.lua" )
dofile( minetest.get_modpath( "digtron" ) .. "/pointset.lua" )

dofile( minetest.get_modpath( "digtron" ) .. "/node_misc.lua" ) -- contains inventory and structure nodes
dofile( minetest.get_modpath( "digtron" ) .. "/node_diggers.lua" ) -- contains all diggers
dofile( minetest.get_modpath( "digtron" ) .. "/node_builders.lua" ) -- contains all builders (there's just one currently)
dofile( minetest.get_modpath( "digtron" ) .. "/node_controllers.lua" ) -- controllers

dofile( minetest.get_modpath( "digtron" ) .."/recipes.lua" )

digtron.refractory = 1.0 -- How long a digtron waits between cycles.

-- digtron group numbers:
-- 1 - generic digtron node, nothing special is done with these. They're just dragged along.
-- 2 - inventory-holding digtron, has a "main" inventory that the digtron can add to and take from.
-- 3 - digger head, has an "execute_dig" method in its definition
-- 4 - builder head, has a "test_build" and "execute_build" method in its definition





