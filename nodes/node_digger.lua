-- internationalization boilerplate
local MP = minetest.get_modpath(minetest.get_current_modname())
local S, NS = dofile(MP.."/intllib.lua")

local player_interacting_with_digtron_pos = {}

local get_formspec = function(pos, player_name)
	local meta = minetest.get_meta(pos)
	
	local period = meta:get_int("period")
	if period < 1 then period = 1 end
	local offset = meta:get_int("offset")
	
	return
	"size[5,3]" ..
	default.gui_bg ..
	default.gui_bg_img ..
	default.gui_slots ..
	"field[0.5,0.8;1,0.1;period;" .. S("Periodicity") .. ";" .. period .. "]" ..
	"field_close_on_enter[period;false]" ..
	"tooltip[period;" .. S("Digger will dig once every n steps.\nThese steps are globally aligned, all diggers with\nthe same period and offset will dig on the same location.") .. "]" ..
	"field[1.5,0.8;1,0.1;offset;" .. S("Offset") .. ";" .. offset .. "]" ..
	"field_close_on_enter[offset;false]" ..
	"tooltip[offset;" .. S("Offsets the start of periodicity counting by this amount.\nFor example, a digger with period 2 and offset 0 digs\nevery even-numbered block and one with period 2 and\noffset 1 digs every odd-numbered block.") .. "]" ..
	"button[2.2,0.5;1,0.1;set;" .. S("Save &\nShow") .. "]" ..
	"tooltip[set;" .. S("Saves settings") .. "]"
end

local update_infotext = function(meta)
	local period = meta:get_int("period")
	if period < 1 then period = 1 end
	local offset = meta:get_int("offset")

	meta:set_string("infotext", S("Digger period @1 offset @2", period, offset))
end

minetest.register_node("digtron:digger", {
	description = S("Digtron Digger"),
	_doc_items_longdesc = nil,
	_doc_items_usagehelp = nil,
	_digtron_disassembled_node = "digtron:digger_static",
	drops = "digtron:digger_static",
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
	groups = {cracky = 3, oddly_breakable_by_hand = 3, digtron = 3},
	is_ground_content = false,
	sounds = default.node_sound_metal_defaults(),
	can_dig = digtron.can_dig,
	on_blast = digtron.on_blast,
})

minetest.register_node("digtron:digger_static",{
	description = S("Digtron Digger"),
	_doc_items_longdesc = nil,
	_doc_items_usagehelp = nil,
	_digtron_assembled_node = "digtron:digger",
	drawtype = "mesh",
	mesh = "digtron_digger_static.obj",
	tiles = {
		{ name = "digtron_plate.png^digtron_digger_yb_frame.png", backface_culling = true }, 
		{ name = "digtron_plate.png", backface_culling = true },
		{ name = "digtron_drill_head_animated.png", backface_culling = true },
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
	groups = {cracky = 3, oddly_breakable_by_hand = 3, digtron = 3},
	is_ground_content = false,
	sounds = default.node_sound_metal_defaults(),
	can_dig = digtron.can_dig,
	on_blast = digtron.on_blast,
	
	on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
		if clicker == nil then return end
		local player_name = clicker:get_player_name()
		player_interacting_with_digtron_pos[player_name] = pos
		minetest.show_formspec(player_name, "digtron:digger", get_formspec(pos, player_name))
	end,
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "digtron:digger" then
		return
	end
	local player_name = player:get_player_name()
	local pos = player_interacting_with_digtron_pos[player_name]
	if pos == nil then return end
	local meta = minetest.get_meta(pos)	
	
	--TODO: this isn't recording the field when using ESC to exit the formspec
	if fields.key_enter_field == "offset" or fields.offset then
		local val = tonumber(fields.offset)
		if val ~= nil and val >= 0 then
			meta:set_int("offset", val)
		end
	end
	if fields.key_enter_field == "period" or fields.period then
		local val = tonumber(fields.period)
		if val ~= nil and val >= 1 then
			meta:set_int("period", val)
		end
	end
	
	update_infotext(meta)
end)
