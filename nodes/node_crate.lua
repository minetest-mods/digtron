-- internationalization boilerplate
local MP = minetest.get_modpath(minetest.get_current_modname())
local S, NS = dofile(MP.."/intllib.lua")

local modpath_awards = minetest.get_modpath("awards")


local player_permitted = function(pos, player)
	if player then
		if minetest.check_player_privs(player, "protection_bypass") then
			return true
		end
	else
		return false
	end

	local meta = minetest.get_meta(pos)
	local owner = meta:get_string("owner")

	if not owner or owner == "" or owner == player:get_player_name() then
		return true
	end
end

local store_digtron = function(pos, clicker, loaded_node_name, protected)
	local layout = DigtronLayout.create(pos, clicker)
	local protection_prefix = ""
	local protection_suffix = ""
	if protected then
		protection_prefix = S("Digtron Crate") .. "\n" .. S("Owned by @1", clicker:get_player_name() or "")
		protection_suffix = S("Owned by @1", clicker:get_player_name() or "")
	end
	
	if layout.contains_protected_node then
		local meta = minetest.get_meta(pos)
		minetest.sound_play("buzzer", {gain=0.5, pos=pos})
		meta:set_string("infotext", protection_prefix .. "\n" .. S("Digtron can't be packaged, it contains protected blocks"))
		-- no stealing other peoples' digtrons
		return
	end
	
	if #layout.all == 1 then
		local meta = minetest.get_meta(pos)
		minetest.sound_play("buzzer", {gain=0.5, pos=pos})
		meta:set_string("infotext", protection_prefix .. "\n" .. S("No Digtron components adjacent to package"))
		return
	end

	digtron.award_crate(layout, clicker:get_player_name())
	
	local layout_string = layout:serialize()
	
	-- destroy everything. Note that this includes the empty crate, which will be bundled up with the layout.
	for _, node_image in pairs(layout.all) do
		local old_pos = node_image.pos
		local old_node = node_image.node
		minetest.remove_node(old_pos)
		
		if modpath_awards then
			-- We're about to tell the awards mod that we're digging a node, but we
			-- don't want it to count toward any actual awards. Pre-decrement.
			local data = awards.player(clicker:get_player_name())
			awards.increment_item_counter(data, "dig", old_node.name, -1)
		end
		
		for _, callback in ipairs(minetest.registered_on_dignodes) do
			-- Copy pos and node because callback can modify them
			local pos_copy = {x=old_pos.x, y=old_pos.y, z=old_pos.z}
			local oldnode_copy = {name=old_node.name, param1=old_node.param1, param2=old_node.param2}
			callback(pos_copy, oldnode_copy, clicker)
		end			
	end
	
	-- Create the loaded crate node
	minetest.set_node(pos, {name=loaded_node_name})
	minetest.sound_play("machine1", {gain=1.0, pos=pos})
	
	local meta = minetest.get_meta(pos)
	meta:set_string("crated_layout", layout_string)

	if protected then
		-- only set owner if protected
		meta:set_string("owner", clicker:get_player_name() or "")
	end

	local titlestring = S("Crated @1-block Digtron", tostring(#layout.all-1))
	meta:set_string("title", titlestring )
	meta:set_string("infotext", titlestring .. "\n" .. protection_suffix)
end

minetest.register_node("digtron:empty_crate", {
	description = S("Digtron Crate (Empty)"),
	_doc_items_longdesc = digtron.doc.empty_crate_longdesc,
    _doc_items_usagehelp = digtron.doc.empty_crate_usagehelp,
	groups = {cracky = 3, oddly_breakable_by_hand=3},
	sounds = default.node_sound_wood_defaults(),
	tiles = {"digtron_crate.png"},
	is_ground_content = false,
	drawtype = "nodebox",
	node_box = {
        type = "fixed",
        fixed = {
            {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
        },
    },
	paramtype = "light",
	
	can_dig = function(pos, player)
		return player and not minetest.is_protected(pos, player:get_player_name())
	end,

	on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
		store_digtron(pos, clicker, "digtron:loaded_crate")
	end
})

minetest.register_node("digtron:empty_locked_crate", {
	description = S("Digtron Locked Crate (Empty)"),
	_doc_items_longdesc = digtron.doc.empty_locked_crate_longdesc,
    _doc_items_usagehelp = digtron.doc.empty_locked_crate_usagehelp,
	groups = {cracky = 3, oddly_breakable_by_hand=3},
	sounds = default.node_sound_wood_defaults(),
	tiles = {"digtron_crate.png","digtron_crate.png","digtron_crate.png^digtron_lock.png","digtron_crate.png^digtron_lock.png","digtron_crate.png^digtron_lock.png","digtron_crate.png^digtron_lock.png"},
	is_ground_content = false,
	drawtype = "nodebox",
	node_box = {
        type = "fixed",
        fixed = {
            {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
        },
    },
	paramtype = "light",
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("owner", "")
		meta:set_string("infotext", "")
	end,
	after_place_node = function(pos, placer)
		local meta = minetest.get_meta(pos)
		meta:set_string("owner", placer:get_player_name() or "")
		meta:set_string("infotext", S("Digtron Crate") .. "\n" .. S("Owned by @1", placer:get_player_name() or ""))
	end,
	can_dig = function(pos,player)
		return player and not minetest.is_protected(pos, player:get_player_name()) and player_permitted(pos, player)
	end,
	on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
		if player_permitted(pos,clicker) then
			store_digtron(pos, clicker, "digtron:loaded_locked_crate", true)
		end
	end,
})

local modpath_doc = minetest.get_modpath("doc")
local loaded_formspec_string
if modpath_doc then
	loaded_formspec_string =
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
	loaded_formspec_string =
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

local loaded_formspec = function(pos, meta)
	return loaded_formspec_string
end

local loaded_on_recieve = function(pos, fields, sender, protected)
	local meta = minetest.get_meta(pos)

	if fields.unpack or fields.save or fields.show or fields.key_enter then
		meta:set_string("title", minetest.formspec_escape(fields.title))
	end
	local title = meta:get_string("title")
	local infotext
	
	if protected then
		infotext = title .. "\n" .. S("Owned by @1", sender:get_player_name())
	else
		infotext = title
	end
	meta:set_string("infotext", infotext)
	
	if fields.help and minetest.get_modpath("doc") then --check for mod in case someone disabled it after this digger was built
		minetest.after(0.5, doc.show_entry, sender:get_player_name(), "nodes", "digtron:loaded_crate", true)
	end

	if not (fields.unpack or fields.show) then
		return
	end
	
	local layout_string = meta:get_string("crated_layout")
	local layout = DigtronLayout.deserialize(layout_string)

	if layout == nil then
		meta:set_string("infotext", infotext .. "\n" .. S("Unable to read layout from crate metadata, regrettably this Digtron may be corrupted."))
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
		meta:set_string("infotext", infotext .. "\n" .. S("Unable to deploy Digtron due to protected blocks in target area"))
		minetest.sound_play("buzzer", {gain=0.5, pos=pos})
		return
	end
	
	if obstructed_node then
		meta:set_string("infotext", infotext .. "\n" .. S("Unable to deploy Digtron due to obstruction in target area"))
		minetest.sound_play("buzzer", {gain=0.5, pos=pos})
		return
	end
	
	-- build digtron. Since the empty crate was included in the layout, that will overwrite this loaded crate and destroy it.
	minetest.sound_play("machine2", {gain=1.0, pos=pos})
	layout:write_layout_image(sender)
end

local loaded_on_dig = function(pos, player, loaded_node_name)
	local meta = minetest.get_meta(pos)
	
	local stack = ItemStack({name=loaded_node_name, count=1, wear=0})
	local stack_meta = stack:get_meta()
	stack_meta:set_string("crated_layout", meta:get_string("crated_layout"))
	stack_meta:set_string("description", meta:get_string("title"))
	local inv = player:get_inventory()
	local stack = inv:add_item("main", stack)
	if stack:get_count() > 0 then
		minetest.add_item(pos, stack)
	end		
	-- call on_dignodes callback
	minetest.remove_node(pos)
end

local loaded_after_place = function(pos, itemstack)

	-- Older versions of Digtron used this deprecated method for saving layout data on items.
	-- Maintain backward compatibility here.
	local deprecated_metadata = itemstack:get_metadata()
	if deprecated_metadata ~= "" then
		deprecated_metadata = minetest.deserialize(deprecated_metadata)
		local meta = minetest.get_meta(pos)
		meta:set_string("crated_layout", deprecated_metadata.layout)
		meta:set_string("title", deprecated_metadata.title)
		meta:set_string("infotext", deprecated_metadata.title)
		return
	end

	local stack_meta = itemstack:get_meta()
	local layout = stack_meta:get_string("crated_layout")
	local title = stack_meta:get_string("description")
	if layout ~= "" then
		local meta = minetest.get_meta(pos)
			
		meta:set_string("crated_layout", layout)
		meta:set_string("title", title)
		meta:set_string("infotext", title)
		--meta:set_string("formspec", loaded_formspec(pos, meta)) -- not needed, on_construct handles this
	end
end

minetest.register_node("digtron:loaded_crate", {
	description = S("Digtron Crate (Loaded)"),
	_doc_items_longdesc = digtron.doc.loaded_crate_longdesc,
    _doc_items_usagehelp = digtron.doc.loaded_crate_usagehelp,
	_digtron_formspec = loaded_formspec,
	groups = {cracky = 3, oddly_breakable_by_hand=3, not_in_creative_inventory=1, digtron_protected=1},
	stack_max = 1,
	sounds = default.node_sound_wood_defaults(),
	tiles = {"digtron_plate.png^digtron_crate.png"},
	is_ground_content = false,
	
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("formspec", loaded_formspec(pos, meta))
	end,
	
	on_receive_fields = function(pos, formname, fields, sender)
		return loaded_on_recieve(pos, fields, sender)
	end,

	on_dig = function(pos, node, player)
		if player and not minetest.is_protected(pos, player:get_player_name()) then
			return loaded_on_dig(pos, player, "digtron:loaded_crate")
		end
	end,
	
	after_place_node = function(pos, placer, itemstack, pointed_thing)
		loaded_after_place(pos, itemstack)
	end,
})

minetest.register_node("digtron:loaded_locked_crate", {
	description = S("Digtron Locked Crate (Loaded)"),
	_doc_items_longdesc = digtron.doc.loaded_locked_crate_longdesc,
    _doc_items_usagehelp = digtron.doc.loaded_locked_crate_usagehelp,
	groups = {cracky = 3, oddly_breakable_by_hand=3, not_in_creative_inventory=1, digtron_protected=1},
	stack_max = 1,
	sounds = default.node_sound_wood_defaults(),
	tiles = {"digtron_plate.png^digtron_crate.png","digtron_plate.png^digtron_crate.png","digtron_plate.png^digtron_crate.png^digtron_lock.png","digtron_plate.png^digtron_crate.png^digtron_lock.png","digtron_plate.png^digtron_crate.png^digtron_lock.png","digtron_plate.png^digtron_crate.png^digtron_lock.png"},
	is_ground_content = false,
	
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("owner", "")
	end,
	
	on_dig = function(pos, node, player)
		if player and not minetest.is_protected(pos, player:get_player_name()) and player_permitted(pos,player) then
			return loaded_on_dig(pos, player, "digtron:loaded_locked_crate")
		else
			return false
		end
	end,
	
	after_place_node = function(pos, placer, itemstack, pointed_thing)
		local meta = minetest.get_meta(pos)
		meta:set_string("owner", placer:get_player_name() or "")
		loaded_after_place(pos, itemstack)
		meta:set_string("infotext", meta:get_string("infotext") .. "\n" .. S("Owned by @1", meta:get_string("owner")))
	end,
	
	on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
		if player_permitted(pos,clicker) then
			local meta = minetest.get_meta(pos)
			minetest.show_formspec(
				clicker:get_player_name(),
				"digtron:loaded_locked_crate"..minetest.pos_to_string(pos),
				loaded_formspec_string:gsub("${title}", meta:get_string("title"), 1))
		end
	end,	
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname:sub(1, 27) == "digtron:loaded_locked_crate" then
		local pos = minetest.string_to_pos(formname:sub(28, -1))
		loaded_on_recieve(pos, fields, player, true)
		return true
	end
end)
