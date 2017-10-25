-- internationalization boilerplate
local MP = minetest.get_modpath(minetest.get_current_modname())
local S, NS = dofile(MP.."/intllib.lua")

minetest.register_craftitem("digtron:digtron_core", {
	description = S("Digtron Core"),
	inventory_image = "digtron_core.png",
	_doc_items_longdesc = digtron.doc.core_longdesc,
    _doc_items_usagehelp = digtron.doc.core_usagehelp,
})

minetest.register_craft({
	output = "digtron:digtron_core",
	recipe = {
			{"","default:steel_ingot",""},
			{"default:steel_ingot","default:mese_crystal_fragment","default:steel_ingot"},
			{"","default:steel_ingot",""}
			}
})

minetest.register_craft({
	output = "digtron:controller",
	recipe = {
			{"","default:mese_crystal",""},
			{"default:mese_crystal","digtron:digtron_core","default:mese_crystal"},
			{"","default:mese_crystal",""}
			}
})

minetest.register_craft({
	output = "digtron:auto_controller",
	recipe = {
			{"default:mese_crystal","default:mese_crystal","default:mese_crystal"},
			{"default:mese_crystal","digtron:digtron_core","default:mese_crystal"},
			{"default:mese_crystal","default:mese_crystal","default:mese_crystal"}
			}
})

minetest.register_craft({
	output = "digtron:builder",
	recipe = {
			{"","default:mese_crystal_fragment",""},
			{"default:mese_crystal_fragment","digtron:digtron_core","default:mese_crystal_fragment"},
			{"","default:mese_crystal_fragment",""}
			}
})

minetest.register_craft({
	output = "digtron:light",
	recipe = {
			{"","default:torch",""},
			{"","digtron:digtron_core",""},
			{"","",""}
			}
})

minetest.register_craft({
	output = "digtron:digger",
	recipe = {
			{"","default:diamond",""},
			{"default:diamond","digtron:digtron_core","default:diamond"},
			{"","default:diamond",""}
			}
})

minetest.register_craft({
	output = "digtron:soft_digger",
	recipe = {
			{"","default:steel_ingot",""},
			{"default:steel_ingot","digtron:digtron_core","default:steel_ingot"},
			{"","default:steel_ingot",""}
			}
})

minetest.register_craft({
	output = "digtron:inventory",
	recipe = {
			{"","default:chest",""},
			{"","digtron:digtron_core",""},
			{"","",""}
			}
})

minetest.register_craft({
	output = "digtron:fuelstore",
	recipe = {
			{"","default:furnace",""},
			{"","digtron:digtron_core",""},
			{"","",""}
			}
})

if minetest.get_modpath("technic") then
	-- no need for this recipe if technic is not installed, avoid cluttering crafting guides
	minetest.register_craft({
		output = "digtron:battery_holder",
		recipe = {
				{"","default:chest",""},
				{"","digtron:digtron_core",""},
				{"","default:steel_ingot",""}
				}
	})
	
	minetest.register_craft({
		output = "digtron:power_connector",
		recipe = {
				{"","technic:hv_cable",""},
				{"technic:hv_cable","digtron:digtron_core","technic:hv_cable"},
				{"","technic:hv_cable",""}
				}
	})
end

minetest.register_craft({
	output = "digtron:combined_storage",
	recipe = {
			{"","default:furnace",""},
			{"","digtron:digtron_core",""},
			{"","default:chest",""}
			}
})

minetest.register_craft({
	output = "digtron:pusher",
	recipe = {
			{"","default:coal_lump",""},
			{"default:coal_lump","digtron:digtron_core","default:coal_lump"},
			{"","default:coal_lump",""}
			}
})

minetest.register_craft({
	output = "digtron:axle",
	recipe = {
			{"default:coal_lump","default:coal_lump","default:coal_lump"},
			{"default:coal_lump","digtron:digtron_core","default:coal_lump"},
			{"default:coal_lump","default:coal_lump","default:coal_lump"}
			}
})

minetest.register_craft({
	output = "digtron:empty_crate",
	recipe = {
			{"","default:chest",""},
			{"","digtron:digtron_core",""},
			{"","default:mese_crystal",""}
			}
})

minetest.register_craft({
	output = "digtron:empty_locked_crate",
	type = "shapeless",
	recipe = {"default:steel_ingot", "digtron:empty_crate"},
})

minetest.register_craft({
	output = "digtron:empty_crate",
	type = "shapeless",
	recipe = {"digtron:empty_locked_crate"},
})

minetest.register_craft({
	output = "digtron:duplicator",
	recipe = {
			{"default:mese_crystal","default:mese_crystal","default:mese_crystal"},
			{"default:chest","digtron:digtron_core","default:chest"},
			{"default:mese_crystal","default:mese_crystal","default:mese_crystal"}
			}
})

minetest.register_craft({
	output = "digtron:inventory_ejector",
	recipe = {
			{"default:steel_ingot","default:steel_ingot","default:steel_ingot"},
			{"","digtron:digtron_core",""},
			{"","default:steel_ingot",""}
			}
})

-- Structural

minetest.register_craft({
	output = "digtron:structure",
	recipe = {
			{"group:stick","","group:stick"},
			{"","digtron:digtron_core",""},
			{"group:stick","","group:stick"}
			}
})

minetest.register_craft({
	output = "digtron:panel",
	recipe = {
			{"","",""},
			{"","digtron:digtron_core",""},
			{"","default:steel_ingot",""}
			}
})

minetest.register_craft({
	output = "digtron:edge_panel",
	recipe = {
			{"","",""},
			{"","digtron:digtron_core","default:steel_ingot"},
			{"","default:steel_ingot",""}
			}
})

minetest.register_craft({
	output = "digtron:corner_panel",
	recipe = {
			{"","",""},
			{"","digtron:digtron_core","default:steel_ingot"},
			{"","default:steel_ingot","default:steel_ingot"}
			}
})

-- For swapping digger types
minetest.register_craft({
	output = "digtron:digger",
	recipe = {
			{"digtron:intermittent_digger"},
			}
})
minetest.register_craft({
	output = "digtron:intermittent_digger",
	recipe = {
			{"digtron:digger"},
			}
})
minetest.register_craft({
	output = "digtron:soft_digger",
	recipe = {
			{"digtron:intermittent_soft_digger"},
			}
})
minetest.register_craft({
	output = "digtron:intermittent_soft_digger",
	recipe = {
			{"digtron:soft_digger"},
			}
})

minetest.register_craft({
	output = "digtron:dual_soft_digger",
	type = "shapeless",
	recipe = {"digtron:soft_digger", "digtron:soft_digger"},
})
minetest.register_craft({
	output = "digtron:dual_digger",
	type = "shapeless",
	recipe = {"digtron:digger", "digtron:digger"},
})
minetest.register_craft({
	output = "digtron:soft_digger 2",
	recipe = {
			{"digtron:dual_soft_digger"},
			}
})
minetest.register_craft({
	output = "digtron:digger 2",
	recipe = {
			{"digtron:dual_digger"},
			}
})

-- And some recycling reactions to get digtron cores out of the "cheap" parts:

minetest.register_craft({
	output = "digtron:digtron_core",
	recipe = {
			{"digtron:structure"},
			}
})
minetest.register_craft({
	output = "digtron:digtron_core",
	recipe = {
			{"digtron:panel"},
			}
})
minetest.register_craft({
	output = "digtron:digtron_core",
	recipe = {
			{"digtron:corner_panel"},
			}
})
minetest.register_craft({
	output = "digtron:digtron_core",
	recipe = {
			{"digtron:edge_panel"},
			}
})

minetest.register_craft({
	output = "digtron:digtron_core",
	recipe = {
			{"digtron:inventory"},
			}
})

minetest.register_craft({
	output = "digtron:digtron_core",
	recipe = {
			{"digtron:fuelstore"},
			}
})

minetest.register_craft({
	output = "digtron:digtron_core",
	recipe = {
			{"digtron:combined_storage"},
			}
})

minetest.register_craft({
	output = "digtron:digtron_core",
	recipe = {
			{"digtron:light"},
			}
})

minetest.register_craft({
	output = "digtron:digtron_core",
	recipe = {
			{"digtron:pusher"},
			}
})

minetest.register_craft({
	output = "digtron:digtron_core",
	recipe = {
			{"digtron:axle"},
			}
})