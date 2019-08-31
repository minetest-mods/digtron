-- internationalization boilerplate
local MP = minetest.get_modpath(minetest.get_current_modname())
local S, NS = dofile(MP.."/intllib.lua")


-- Note: builders go in group 4

-- TODO make this global
local player_interacting_with_builder_pos = {}

local get_formspec = function(pos)
	local meta = minetest.get_meta(pos)
	
	local period = meta:get_int("period")
	if period < 1 then period = 1 end
	local offset = meta:get_int("offset")
	local extrusion = meta:get_int("extrusion")
	local facing = meta:get_int("facing")
	local item_name = meta:get_string("item")

	return "size[8,5.2]" ..
	"item_image[0,0;1,1;" .. item_name .. "]"..
	"listcolors[#00000069;#5A5A5A00;#141318;#30434C;#FFF]" ..
	"list[detached:digtron:builder_item;main;0,0;1,1;]" ..
	"field[1.3,0.8;1,0.1;extrusion;" .. S("Extrusion") .. ";" ..extrusion .. "]" ..
	"field_close_on_enter[extrusion;false]" ..
	"tooltip[extrusion;" .. S("Builder will extrude this many blocks in the direction it is facing.\nCan be set from 1 to @1.\nNote that Digtron won't build into unloaded map regions.", digtron.config.maximum_extrusion) .. "]" ..
	"field[2.3,0.8;1,0.1;period;" .. S("Periodicity") .. ";".. period .. "]" ..
	"field_close_on_enter[period;false]" ..
	"tooltip[period;" .. S("Builder will build once every n steps.\nThese steps are globally aligned, so all builders with the\nsame period and offset will build on the same location.") .. "]" ..
	"field[3.3,0.8;1,0.1;offset;" .. S("Offset") .. ";" .. offset .. "]" ..
	"field_close_on_enter[offset;false]" ..
	"tooltip[offset;" .. S("Offsets the start of periodicity counting by this amount.\nFor example, a builder with period 2 and offset 0 builds\nevery even-numbered block and one with period 2 and\noffset 1 builds every odd-numbered block.") .. "]" ..
	"button[4.0,0.5;1,0.1;set;" .. S("Save &\nShow") .. "]" ..
	"tooltip[set;" .. S("Saves settings, closes interface, and shows the locations this builder will build to in-world.") .. "]" ..
	"field[5.3,0.8;1,0.1;facing;" .. S("Facing") .. ";" .. facing .. "]" ..
	"field_close_on_enter[facing;false]" ..
	"tooltip[facing;" .. S("Value from 0-23. Not all block types make use of this.\nUse the 'Read & Save' button to copy the facing of the block\ncurrently in the builder output location.") .. "]" ..
	"button[6.0,0.5;1,0.1;read;" .. S("Read") .. "]" ..
	"tooltip[read;" .. S("Reads the facing of the block currently in the build location.") .. "]" ..
	"list[current_player;main;0,1.3;8,1;]" ..
	default.get_hotbar_bg(0,1.3) ..
	"list[current_player;main;0,2.5;8,3;8]" ..
	"listring[current_player;main]" ..
	"listring[detached:digtron:builder_item;main]"
end

----------------------------------------------------------------------
-- Detached inventory for setting the builder item

local is_item_allowed = function(item)
	-- Ignore unknown items
	if minetest.registered_items[item] == nil then return false end

	local stack_def = minetest.registered_nodes[item]
	if not stack_def and not digtron.whitelisted_on_place(item) then
		return false -- don't allow craft items unless their on_place is whitelisted.
	end
	
	return true
end


local inv = minetest.create_detached_inventory("digtron:builder_item", {
	allow_move = function(inv, from_list, from_index, to_list, to_index, count, player)
		return 0
	end,
	allow_put = function(inv, listname, index, stack, player)
		-- Always disallow put, but use this to read what the player *tried* adding and set the builder appropriately
		local item = stack:get_name()
		
		if not is_item_allowed(item) then
			return 0
		end

		local player_name = player:get_player_name()
		local pos = player_interacting_with_builder_pos[player_name]
		if pos == nil then
			return 0
		end
		
		local node = minetest.get_node(pos)
		if node.name ~= "digtron:builder" then
			minetest.log("warning", "[Digtron] builder detached inventory had player " .. player_name
				.. " attempt to set " .. item .. " at " .. minetest.pos_to_string(pos) ..
				" but the node at that location was a " .. node.name)
			return 0
		end
		
		local meta = minetest.get_meta(pos)
		local digtron_id = meta:get_string("digtron_id")
		if digtron_id ~= "" then
			minetest.log("warning", "[Digtron] builder detached inventory had player " .. player_name
				.. " attempt to set " .. item .. " at " .. minetest.pos_to_string(pos) ..
				" but the builder node at that location was already assembled into " .. digtron_id)
			return 0
		end
		
		-- If we're adding a wallmounted item and the build facing is greater than 5, reset it to 0
		if stack_def ~= nil and stack_def.paramtype2 == "wallmounted" and tonumber(meta:get_int("facing")) > 5 then
			meta:set_int("facing", 0)
		end
		
		meta:set_string("item", item)
		digtron.update_builder_item(pos)
		minetest.show_formspec(player_name, "digtron:builder", get_formspec(pos))

		return 0
	end,
	allow_take = function(inv, listname, index, stack, player)
		return 0
	end,
})
inv:set_size("main", 1)

local builder_on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
	local returnstack, success = digtron.on_rightclick(pos, node, clicker, itemstack, pointed_thing)
	if returnstack then
		return returnstack, success
	end

	if clicker == nil then return end
	local player_name = clicker:get_player_name()

	local meta = minetest.get_meta(pos)	
	
	local digtron_id = meta:get_string("digtron_id")
	if digtron_id ~= "" then
		minetest.sound_play({name = "digtron_error", gain = 0.1}, {to_player=player_name})
		minetest.chat_send_player(player_name, S("This Digtron is active, interact with it via the controller node."))
		return
	end
	
	player_interacting_with_builder_pos[player_name] = pos
	minetest.show_formspec(player_name,
		"digtron:builder",
		get_formspec(pos))
end

minetest.register_on_player_receive_fields(function(sender, formname, fields)
	if formname ~= "digtron:builder" then
		return
	end
	
	local player_name = sender:get_player_name()
	local pos = player_interacting_with_builder_pos[player_name]
	if pos == nil then
		minetest.log("error", "[Digtron] ".. player_name .. " tried interacting with a Digtron builder but"
			.. " no position was recorded.")
		return
	end
	
    local meta = minetest.get_meta(pos)
	
	local item = meta:get_string("item")
	
	local period = tonumber(fields.period)
	if period and period > 0 then
		meta:set_int("period", math.floor(period))
	else
		period = meta:get_int("period")
	end
	
	local offset = tonumber(fields.offset)
	if offset then
		meta:set_int("offset", math.floor(offset))
	else
		offset = meta:get_int("offset")
	end
	
	local facing = tonumber(fields.facing)
	if facing and facing >= 0 and facing < 24 then
		local target_item = ItemStack(item)
		if target_item:get_definition().paramtype2 == "wallmounted" then
			if facing < 6 then
				meta:set_int("facing", math.floor(facing))
				-- wallmounted facings only run from 0-5
			end
		else
			meta:set_int("facing", math.floor(facing))
		end
	else
		facing = meta:get_int("facing")
	end
	
	local extrusion = tonumber(fields.extrusion)
	if extrusion and extrusion > 0 and extrusion <= digtron.config.maximum_extrusion then
		meta:set_int("extrusion", math.floor(extrusion))
	else
		extrusion = meta:get_int("extrusion")
	end
	
	if fields.set then
		--digtron.show_offset_markers(pos, offset, period)
	end

	if fields.read then
		local builder_facing = minetest.get_node(pos).param2
		local buildpos = vector.add(minetest.facedir_to_dir(builder_facing), pos)
		local target_node = minetest.get_node(buildpos)
		local target_name = target_node.name
		if digtron.builder_read_item_substitutions[target_name] then
			target_name = digtron.builder_read_item_substitutions[target_name]
		end
		if target_name ~= "air" and is_item_allowed(target_name) then
			local meta = minetest.get_meta(pos)
			item = target_name
			meta:set_string("item", item)
			meta:set_int("facing", target_node.param2)
		end
	end
	
	if fields.help then
		minetest.after(0.5, doc.show_entry, sender:get_player_name(), "nodes", "digtron:builder", true)
	end
	
	local item_def = minetest.registered_items[item]
	local item_desc = "Nothing"
	if item_def then
		item_desc = item_def.description
	end
	
	meta:set_string("infotext", S("Builder for @1\nperiod @2, offset @3, extrusion @4", item_desc, period, offset, extrusion))
	digtron.update_builder_item(pos)
	minetest.show_formspec(player_name, "digtron:builder", get_formspec(pos))

end)


-- Builds objects in the targeted node.
minetest.register_node("digtron:builder", {
	description = S("Digtron Builder Module"),
	_doc_items_longdesc = digtron.doc.builder_longdesc,
    _doc_items_usagehelp = digtron.doc.builder_usagehelp,
	groups = {cracky = 3,  oddly_breakable_by_hand=3, digtron = 4},
	drop = "digtron:builder",
	sounds = default.node_sound_metal_defaults(),
	paramtype = "light",
	paramtype2= "facedir",
	is_ground_content = false,
	tiles = {
		"digtron_plate.png^[transformR90",
		"digtron_plate.png^[transformR270",
		"digtron_plate.png",
		"digtron_plate.png^[transformR180",
		"digtron_plate.png^digtron_builder.png",
		"digtron_plate.png",
	},
	
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			{-0.25, 0.3125, 0.3125, 0.25, 0.5, 0.5}, -- FrontFrame_top
			{-0.25, -0.5, 0.3125, 0.25, -0.3125, 0.5}, -- FrontFrame_bottom
			{0.3125, -0.25, 0.3125, 0.5, 0.25, 0.5}, -- FrontFrame_right
			{-0.5, -0.25, 0.3125, -0.3125, 0.25, 0.5}, -- FrontFrame_left
			{-0.5, 0.25, -0.5, -0.25, 0.5, 0.5}, -- edge_topright
			{-0.5, -0.5, -0.5, -0.25, -0.25, 0.5}, -- edge_bottomright
			{0.25, 0.25, -0.5, 0.5, 0.5, 0.5}, -- edge_topleft
			{0.25, -0.5, -0.5, 0.5, -0.25, 0.5}, -- edge_bottomleft
			{-0.25, 0.4375, -0.5, 0.25, 0.5, -0.4375}, -- backframe_top
			{-0.25, -0.5, -0.5, 0.25, -0.4375, -0.4375}, -- backframe_bottom
			{-0.5, -0.25, -0.5, -0.4375, 0.25, -0.4375}, -- backframe_left
			{0.4375, -0.25, -0.5, 0.5, 0.25, -0.4375}, -- Backframe_right
			{-0.0625, -0.3125, 0.3125, 0.0625, 0.3125, 0.375}, -- frontcross_vertical
			{-0.3125, -0.0625, 0.3125, 0.3125, 0.0625, 0.375}, -- frontcross_horizontal
		}
	},
	
	on_construct = function(pos)
        local meta = minetest.get_meta(pos)
		meta:set_int("period", 1)
		meta:set_int("offset", 0)
		meta:set_int("facing", 0)
		meta:set_int("extrusion", 1)
    end,
	
	on_rightclick = builder_on_rightclick,
	
	on_destruct = function(pos)
		local node = minetest.get_node(pos)
		local target_pos = vector.add(pos, minetest.facedir_to_dir(node.param2))
		digtron.remove_builder_item(target_pos)
	end,
	
	after_place_node = function(pos)
		digtron.update_builder_item(pos)
	end,
	
	can_dig = digtron.can_dig,
	on_blast = digtron.on_blast,
})