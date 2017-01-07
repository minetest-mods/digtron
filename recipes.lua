minetest.register_craftitem("digtron:digtron_core", {
	description = "Digtron Core",
	inventory_image = "digtron_core.png"
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

-- Structural

minetest.register_craft({
	output = "digtron:structure",
	recipe = {
			{"default:stick","","default:stick"},
			{"","digtron:digtron_core",""},
			{"default:stick","","default:stick"}
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