-- internationalization boilerplate
local MP = minetest.get_modpath(minetest.get_current_modname())
local S, NS = dofile(MP.."/intllib.lua")

-- A do-nothing "structural" node, to ensure all digtron nodes that are supposed to be connected to each other can be connected to each other.
minetest.register_node("digtron:structure", {
	description = S("Digtron Structure"),
	_doc_items_longdesc = digtron.doc.structure_longdesc,
    _doc_items_usagehelp = digtron.doc.structure_usagehelp,
	groups = {cracky = 3,  oddly_breakable_by_hand=3, digtron = 1},
	tiles = {"digtron_plate.png"},
	drawtype = "nodebox",
	sounds = default.node_sound_metal_defaults(),
	climbable = true,
	walkable = false,
	paramtype = "light",
	is_ground_content = false,
	node_box = {
		type = "fixed",
		fixed = {
			{0.3125, 0.3125, -0.5, 0.5, 0.5, 0.5},
			{0.3125, -0.5, -0.5, 0.5, -0.3125, 0.5},
			{-0.5, 0.3125, -0.5, -0.3125, 0.5, 0.5},
			{-0.5, -0.5, -0.5, -0.3125, -0.3125, 0.5},
			{-0.3125, 0.3125, 0.3125, 0.3125, 0.5, 0.5},
			{-0.3125, -0.5, 0.3125, 0.3125, -0.3125, 0.5},
			{-0.5, -0.3125, 0.3125, -0.3125, 0.3125, 0.5},
			{0.3125, -0.3125, 0.3125, 0.5, 0.3125, 0.5},
			{-0.5, -0.3125, -0.5, -0.3125, 0.3125, -0.3125},
			{0.3125, -0.3125, -0.5, 0.5, 0.3125, -0.3125},
			{-0.3125, 0.3125, -0.5, 0.3125, 0.5, -0.3125},
			{-0.3125, -0.5, -0.5, 0.3125, -0.3125, -0.3125},
		}
	},
	can_dig = digtron.can_dig,
	on_blast = digtron.on_blast,
})

-- A modest light source that will move with the digtron, handy for working in a tunnel you aren't bothering to install permanent lights in.
minetest.register_node("digtron:light", {
	description = S("Digtron Light"),
	_doc_items_longdesc = digtron.doc.light_longdesc,
    _doc_items_usagehelp = digtron.doc.light_usagehelp,
	groups = {cracky = 3,  oddly_breakable_by_hand=3, digtron = 1},
	tiles = {"digtron_plate.png^digtron_light.png"},
	drawtype = "nodebox",
	paramtype = "light",
	is_ground_content = false,
	light_source = 10,
	sounds = default.node_sound_glass_defaults(),
	paramtype2 = "wallmounted",
	node_box = {
		type = "wallmounted",
		wall_top = {-0.25, 0.3125, -0.25, 0.25, 0.5, 0.25},
		wall_bottom = {-0.25, -0.5, -0.25, 0.25, -0.3125, 0.25},
		wall_side = {-0.5, -0.25, -0.25, -0.1875, 0.25, 0.25},
	},
	can_dig = digtron.can_dig,
	on_blast = digtron.on_blast,
})

-- A simple structural panel
minetest.register_node("digtron:panel", {
	description = S("Digtron Panel"),
	_doc_items_longdesc = digtron.doc.panel_longdesc,
    _doc_items_usagehelp = digtron.doc.panel_usagehelp,
	groups = {cracky = 3,  oddly_breakable_by_hand=3, digtron = 1},
	tiles = {"digtron_plate.png"},
	drawtype = "nodebox",
	paramtype = "light",
	is_ground_content = false,
	sounds = default.node_sound_metal_defaults(),
	paramtype2 = "facedir",
	node_box = {
		type = "fixed",
		fixed = {-0.5, -0.5, -0.5, 0.5, -0.375, 0.5},
	},
	collision_box = {
		type = "fixed",
		fixed = {-0.5, -0.5, -0.5, 0.5, -0.4375, 0.5},
	},
	can_dig = digtron.can_dig,
	on_blast = digtron.on_blast,
})

-- A simple structural panel
minetest.register_node("digtron:edge_panel", {
	description = S("Digtron Edge Panel"),
	_doc_items_longdesc = digtron.doc.edge_panel_longdesc,
    _doc_items_usagehelp = digtron.doc.edge_panel_usagehelp,
	groups = {cracky = 3,  oddly_breakable_by_hand=3, digtron = 1},
	tiles = {"digtron_plate.png"},
	drawtype = "nodebox",
	paramtype = "light",
	is_ground_content = false,
	sounds = default.node_sound_metal_defaults(),
	paramtype2 = "facedir",
	node_box = {
		type = "fixed",
		fixed = {
			{-0.5, -0.5, 0.375, 0.5, 0.5, 0.5},
			{-0.5, -0.5, -0.5, 0.5, -0.375, 0.375}
		},
	},
	collision_box = {
		type = "fixed",
		fixed = {
			{-0.5, -0.5, 0.4375, 0.5, 0.5, 0.5},
			{-0.5, -0.5, -0.5, 0.5, -0.4375, 0.4375}
		},
	},
	can_dig = digtron.can_dig,
	on_blast = digtron.on_blast,
})

minetest.register_node("digtron:corner_panel", {
	description = S("Digtron Corner Panel"),
	_doc_items_longdesc = digtron.doc.corner_panel_longdesc,
    _doc_items_usagehelp = digtron.doc.corner_panel_usagehelp,
	groups = {cracky = 3,  oddly_breakable_by_hand=3, digtron = 1},
	tiles = {"digtron_plate.png"},
	drawtype = "nodebox",
	paramtype = "light",
	is_ground_content = false,
	sounds = default.node_sound_metal_defaults(),
	paramtype2 = "facedir",
	node_box = {
		type = "fixed",
		fixed = {
			{-0.5, -0.5, 0.375, 0.5, 0.5, 0.5},
			{-0.5, -0.5, -0.5, 0.5, -0.375, 0.375},
			{-0.5, -0.375, -0.5, -0.375, 0.5, 0.375},
		},
	},
	collision_box = {
		type = "fixed",
		fixed = {
			{-0.5, -0.5, 0.4375, 0.5, 0.5, 0.5},
			{-0.5, -0.5, -0.5, 0.5, -0.4375, 0.4375},
			{-0.5, -0.4375, -0.5, -0.4375, 0.5, 0.4375},
		},
	},
	can_dig = digtron.can_dig,
	on_blast = digtron.on_blast,
})