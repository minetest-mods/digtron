-- internationalization boilerplate
local S = digtron.S
-- local MP = minetest.get_modpath(minetest.get_current_modname())
-- local S = dofile(MP.."/intllib.lua")

minetest.register_node("digtron:axle", {
	description = S("Digtron Rotation Axle"),
	_doc_items_longdesc = digtron.doc.axle_longdesc,
    _doc_items_usagehelp = digtron.doc.axle_usagehelp,
	groups = {cracky = 3, oddly_breakable_by_hand=3, digtron = 1},
	drop = "digtron:axle",
	sounds = digtron.metal_sounds,
	paramtype = "light",
	paramtype2= "facedir",
	is_ground_content = false,
	-- Aims in the +Z direction by default
	tiles = {
		"digtron_plate.png^digtron_axel_top.png",
		"digtron_plate.png^digtron_axel_top.png",
		"digtron_plate.png^digtron_axel_side.png",
		"digtron_plate.png^digtron_axel_side.png",
		"digtron_plate.png^digtron_axel_side.png",
		"digtron_plate.png^digtron_axel_side.png",
	},

	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			{-0.5, 0.3125, -0.3125, 0.5, 0.5, 0.3125}, -- Uppercap
			{-0.5, -0.5, -0.3125, 0.5, -0.3125, 0.3125}, -- Lowercap
			{-0.3125, 0.3125, -0.5, 0.3125, 0.5, -0.3125}, -- Uppercap_edge2
			{-0.3125, 0.3125, 0.3125, 0.3125, 0.5, 0.5}, -- Uppercap_edge1
			{-0.3125, -0.5, -0.5, 0.3125, -0.3125, -0.3125}, -- Lowercap_edge1
			{-0.3125, -0.5, 0.3125, 0.3125, -0.3125, 0.5}, -- Lowercap_edge2
			{-0.25, -0.3125, -0.25, 0.25, 0.3125, 0.25}, -- Axle
		}
	},



	on_rightclick = function(pos, node, clicker)
		local meta = minetest.get_meta(pos)

		-- new delay code without nodetimer (lost on crating)
		local now = minetest.get_gametime()
		local last_time = tonumber(meta:get_string("last_time")) or 0
		-- if meta:get_string("waiting") == "true" then
		if last_time + digtron.config.cycle_time*2 > now then
			-- Been too soon since last time the digtron rotated.

		        -- added for clarity
		        meta:set_string("infotext", S("repetition delay"))

			return
		end

		local image = digtron.DigtronLayout.create(pos, clicker)
		if image:rotate_layout_image(node.param2) == false then
			-- This should be impossible, but if self-validation fails abort.
			return
		end
		if image:can_write_layout_image() then
			if image:write_layout_image(clicker) then
				minetest.sound_play("whirr", {gain=1.0, pos=pos})
				meta = minetest.get_meta(pos)
				meta:set_string("waiting", "true")
				meta:set_string("infotext", nil)
				-- minetest.get_node_timer(pos):start(digtron.config.cycle_time*2)
				-- new delay code
				meta:set_string("last_time",tostring(minetest.get_gametime()))
			else
				meta:set_string("infotext", "unrecoverable write_layout_image error")
			end
		else
			minetest.sound_play("buzzer", {gain=1.0, pos=pos})
			meta:set_string("infotext", S("Digtron is obstructed."))
		end
	end,

	on_timer = function(pos)
		minetest.get_meta(pos):set_string("waiting", nil)
	end,
})