local def = {
		description = "Digger",
		_doc_items_longdesc = nil,
		_doc_items_usagehelp = nil,
		drawtype = "mesh",
		mesh = "digtron_digger.obj",
		tiles = {
			{ name = "digtron_plate.png^digtron_digger_yb_frame.png", backface_culling = true }, 
			{ name = "digtron_plate.png", backface_culling = true },
			{ name = "digtron_drill_head_animated.png", backface_culling = true, animation =
				{
				        type = "vertical_frames",
						aspect_w = 48,
						aspect_h = 12,
						length = 1.0,
				}
			},
			{ name = "digtron_plate.png^digtron_motor.png", backface_culling = true },
		},
		collision_box = {
			type = "fixed",
			fixed = {
				{-0.25, -0.25, 0.5, 0.25, 0.25, 0.8125}, -- Drill
				{-0.5, -0.5, 0, 0.5, 0.5, 0.5}, -- Block
				{-0.25, -0.25, -0.5, 0.25, 0.25, 0}, -- Drive
			},
		},
		selection_box = {
			type = "fixed",
			fixed = {
				{-0.25, -0.25, 0.5, 0.25, 0.25, 0.8125}, -- Drill
				{-0.5, -0.5, 0, 0.5, 0.5, 0.5}, -- Block
				{-0.25, -0.25, -0.5, 0.25, 0.25, 0}, -- Drive
			},
		},
		paramtype2 = "facedir",
		paramtype = "light",
		groups = {cracky = 3, oddly_breakable_by_hand = 3, digtron = 1},
		sounds = digtron.metal_sounds,
}

minetest.register_node("digtron:digger", def)