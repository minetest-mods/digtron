-- internationalization boilerplate
local MP = minetest.get_modpath(minetest.get_current_modname())
local S, NS = dofile(MP.."/intllib.lua")

minetest.register_node("digtron:empty_crate", {
	description = S("Digtron Crate (Empty)"),
	_doc_items_longdesc = digtron.doc.empty_crate_longdesc,
    _doc_items_usagehelp = digtron.doc.empty_crate_usagehelp,
	groups = {cracky = 3, oddly_breakable_by_hand=3},
	drop = "digtron:empty_crate",
	sounds = default.node_sound_wood_defaults(),
	tiles = {"digtron_crate.png"},
	is_ground_content = false,
	drawtype = "nodebox",
	paramtype = "light",
	
	on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
		local layout = DigtronLayout.create(pos, clicker)
		if layout.contains_protected_node then
			local meta = minetest.get_meta(pos)
			minetest.sound_play("buzzer", {gain=0.5, pos=pos})
			meta:set_string("infotext", S("Digtron can't be packaged, it contains protected blocks"))
			-- no stealing other peoples' digtrons
			return
		end

		digtron.award_crate(layout, clicker:get_player_name())
		
		local layout_string = layout:serialize()
		
		-- destroy everything. Note that this includes the empty crate, which will be bundled up with the layout.
		for _, node_image in pairs(layout.all) do
			minetest.remove_node(node_image.pos)
		end
		
		-- Create the loaded crate node
		minetest.set_node(pos, {name="digtron:loaded_crate", param1=node.param1, param2=node.param2})
		minetest.sound_play("machine1", {gain=1.0, pos=pos})
		
		local meta = minetest.get_meta(pos)
		meta:set_string("crated_layout", layout_string)
		meta:set_string("title", S("Crated Digtron"))
		meta:set_string("infotext", S("Crated Digtron"))
	end,
})

local loaded_formspec

if minetest.get_modpath("doc") then
	loaded_formspec =
	"size[4.1,1.5]" ..
	default.gui_bg ..
	default.gui_bg_img ..
	default.gui_slots ..
	"field[0.3,0.5;4,0.5;title;" .. S("Digtron Name") .. ";${title}]" ..
	"button_exit[0.0,1.2;1,0.1;save;" .. S("Save\nTitle") .. "]" ..
	"tooltip[save;" .. S("Saves the title of this Digtron") .. "]" ..
	"button_exit[1.0,1.2;1,0.1;show;" .. S("Show\nBlocks") .. "]" ..
	"tooltip[show;" .. S("Shows which blocks the packed Digtron will occupy if unpacked") .. "]" ..
	"button_exit[2.0,1.2;1,0.1;unpack;" .. S("Unpack") .. "]" ..
	"tooltip[unpack;" .. S("Attempts to unpack the Digtron on this location") .. "]" ..
	"button_exit[3.0,1.2;1,0.1;help;" .. S("Help") .. "]" ..
	"tooltip[help;" .. S("Show documentation about this block") .. "]"
else
	loaded_formspec =
	"size[4,1.5]" ..
	default.gui_bg ..
	default.gui_bg_img ..
	default.gui_slots ..
	"field[0.3,0.5;4,0.5;title;" .. S("Digtron Name") .. ";${title}]" ..
	"button_exit[0.5,1.2;1,0.1;save;" .. S("Save\nTitle") .. "]" ..
	"tooltip[show;" .. S("Saves the title of this Digtron") .. "]" ..
	"button_exit[1.5,1.2;1,0.1;show;" .. S("Show\nBlocks") .. "]" ..
	"tooltip[save;" .. S("Shows which blocks the packed Digtron will occupy if unpacked") .. "]" ..
	"button_exit[2.5,1.2;1,0.1;unpack;" .. S("Unpack") .. "]" ..
	"tooltip[unpack;" .. S("Attempts to unpack the Digtron on this location") .. "]"
end

minetest.register_node("digtron:loaded_crate", {
	description = S("Digtron Crate (Loaded)"),
	_doc_items_longdesc = digtron.doc.loaded_crate_longdesc,
    _doc_items_usagehelp = digtron.doc.loaded_crate_usagehelp,
	groups = {cracky = 3, oddly_breakable_by_hand=3, not_in_creative_inventory=1, digtron_protected=1},
	stack_max = 1,
	sounds = default.node_sound_wood_defaults(),
	tiles = {"digtron_plate.png^digtron_crate.png"},
	is_ground_content = false,
	
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("formspec", loaded_formspec)
	end,
	
	on_receive_fields = function(pos, formname, fields, sender)
		local meta = minetest.get_meta(pos)
		
		if fields.unpack or fields.save or fields.show then
			meta:set_string("title", fields.title)
			meta:set_string("infotext", fields.title)
		end
		
		if fields.help and minetest.get_modpath("doc") then --check for mod in case someone disabled it after this digger was built
			doc.show_entry(sender:get_player_name(), "nodes", "digtron:loaded_crate")
		end

		if not (fields.unpack or fields.show) then
			return
		end
		
		local layout_string = meta:get_string("crated_layout")
		local layout = DigtronLayout.deserialize(layout_string)

		if layout == nil then
			meta:set_string("infotext", meta:get_string("title") .. "\n" .. S("Unable to read layout from crate metadata, regrettably this Digtron may be corrupted or lost."))
			minetest.sound_play("buzzer", {gain=0.5, pos=pos})			
			-- Something went horribly wrong
			return
		end
		
		local protected_node = false
		local obstructed_node = false
		
		local pos_diff = vector.subtract(pos, layout.controller)
		layout.controller = pos
		for _, node_image in pairs(layout.all) do
			node_image.pos = vector.add(pos_diff, node_image.pos)
			if not vector.equals(pos, node_image.pos) then
				if minetest.is_protected(node_image.pos, sender:get_player_name()) and not minetest.check_player_privs(sender, "protection_bypass") then
					protected_node = true
					minetest.add_entity(node_image.pos, "digtron:marker_crate_bad")
				elseif not minetest.registered_nodes[minetest.get_node(node_image.pos).name].buildable_to then
					obstructed_node = true
					minetest.add_entity(node_image.pos, "digtron:marker_crate_bad")
				else
					minetest.add_entity(node_image.pos, "digtron:marker_crate_good")
				end
			end
		end
		
		if not fields.unpack then
			return
		end
		
		if protected_node then
			meta:set_string("infotext", meta:get_string("title") .. "\n" .. S("Unable to deploy Digtron due to protected blocks in target area"))
			minetest.sound_play("buzzer", {gain=0.5, pos=pos})
			return
		end
		
		if obstructed_node then
			meta:set_string("infotext", meta:get_string("title") .. "\n" .. S("Unable to deploy Digtron due to obstruction in target area"))
			minetest.sound_play("buzzer", {gain=0.5, pos=pos})
			return
		end
		
		-- build digtron. Since the empty crate was included in the layout, that will overwrite this loaded crate and destroy it.
		minetest.sound_play("machine2", {gain=1.0, pos=pos})
		layout:write_layout_image(sender)
	end,
		
	on_dig = function(pos, node, player)
	
		local meta = minetest.get_meta(pos)
		local to_serialize = {title=meta:get_string("title"), layout=meta:get_string("crated_layout")}
		
		local stack = ItemStack({name="digtron:loaded_crate", count=1, wear=0, metadata=minetest.serialize(to_serialize)})
		local inv = player:get_inventory()
		local stack = inv:add_item("main", stack)
		if stack:get_count() > 0 then
			minetest.add_item(pos, stack)
		end		
		-- call on_dignodes callback
		minetest.remove_node(pos)
	end,
	
	on_place = function(itemstack, placer, pointed_thing)
		local pos = minetest.get_pointed_thing_position(pointed_thing, true)
		local deserialized = minetest.deserialize(itemstack:get_metadata())
		if pos and deserialized then
			minetest.set_node(pos, {name="digtron:loaded_crate"})
			local meta = minetest.get_meta(pos)
			
			meta:set_string("crated_layout", deserialized.layout)
			meta:set_string("title", deserialized.title)
			meta:set_string("infotext", deserialized.title)
			meta:set_string("formspec", loaded_formspec)
			
			itemstack:take_item(1)
			return itemstack
		end
		-- after-place callbacks
	end,
})