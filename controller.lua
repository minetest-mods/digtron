-- internationalization boilerplate
local MP = minetest.get_modpath(minetest.get_current_modname())
local S, NS = dofile(MP.."/intllib.lua")

local listname_to_title =
{
	["main"] = "Main Inventory",
	["fuel"] = "Fuel",
}

-- This allows us to know which digtron the player has a formspec open for without
-- sending the digtron_id over the network
local player_interacting_with_digtron_id = {}

local get_controller_assembled_formspec = function(digtron_id, player_name)
	local context = player_interacting_with_digtron_id[player_name]
	if context == nil or context.digtron_id ~= digtron_id then
		minetest.log("error", "[Digtron] get_controller_assembled_formspec was called for Digtron "
			..digtron_id .. " by " .. player_name .. " but there was no context recorded or the context was"
			.." for the wrong digtron. This shouldn't be possible.")
		return ""
	end
	
	local inv = digtron.retrieve_inventory(digtron_id) -- ensures the detatched inventory exists and is populated
	
	-- TODO: will probably want a centralized cache for most of this, right now there's tons of redundancy
	if context.tabs == nil then
		context.tabs = {}
		local lists = inv:get_lists()
		for listname, contents in pairs(lists) do
			table.insert(context.tabs, {
				tab_type = "inventory",
				listname = listname,
				size = #contents,
				current_page = 1})
		end
		context.current_tab = 1
	end

	local tabs = ""
	if next(context.tabs) ~= nil then
		tabs = "tabheader[0,0;tab_header;Controls"
		for _, tab in ipairs(context.tabs) do
			tabs = tabs .. "," .. listname_to_title[tab.listname] or tab.listname
		end
		tabs = tabs .. ";" .. context.current_tab .. "]"
	end
	
	local inv_tab = function(inv_list)
		return "size[8,9]"
			.. "position[0.025,0.1]"
			.. "anchor[0,0]"
			.. "container[0,0]"
			.. "list[detached:" .. digtron_id .. ";"..inv_list..";0,0;8,5]" -- TODO: paging system for inventory
			.. "container_end[]"
			.. "container[0,5]list[current_player;main;0,0;8,1;]list[current_player;main;0,1.25;8,3;8]container_end[]"
			.. "listring[current_player;main]"
			.. "listring[detached:" .. digtron_id .. ";"..inv_list.."]"
	end
	
	local controls = "size[4.2,5]"
		.. "position[0.025,0.1]"
		.. "anchor[0,0]"
		.. "container[0,0]"
		.. "button[0,0;1,1;disassemble;Disassemble]"
		.. "field[1.2,0.3;1.75,1;digtron_name;Digtron name;"
		.. minetest.formspec_escape(digtron.get_name(digtron_id)).."]"
		.. "field_close_on_enter[digtron_name;false]"
		.. "field[2.9,0.3;0.7,1;cycles;Cycles;1]" -- TODO persist, actually use
		.. "button[3.2,0;1,1;execute;Execute]"
		.. "container_end[]"
		
		.. "container[0,1]"
		.. "box[0,0;4,2;#DDDDDD]"
		.. "label[1.8,0.825;Move]"
		.. "button[1.1,0.1;1,1;move_up;Up]"
		.. "button[1.1,1.1;1,1;move_down;Down]"
		.. "button[2.1,0.1;1,1;move_forward;Forward]"
		.. "button[2.1,1.1;1,1;move_back;Back]"
		.. "button[0.1,0.6;1,1;move_left;Left]"
		.. "button[3.1,0.6;1,1;move_right;Right]"
		.. "container_end[]"

		.. "container[0.5,3.2]"
		.. "box[0,0;3,2;#DDDDDD]"
		.. "label[1.3,0.825;Rotate]"
		.. "button[0.1,0.1;1,1;rot_counterclockwise;Widdershins]"
		.. "button[2.1,0.1;1,1;rot_clockwise;Clockwise]"
		.. "button[1.1,0.1;1,1;rot_up;Pitch Up]"
		.. "button[1.1,1.1;1,1;rot_down;Pitch Down]"
		.. "button[0.1,1.1;1,1;rot_left;Yaw Left]"
		.. "button[2.1,1.1;1,1;rot_right;Yaw Right]"
		.. "container_end[]"
		
	if context.current_tab == 1 then
		return controls .. tabs
	else
		return inv_tab(context.tabs[context.current_tab - 1].listname) .. tabs
	end
end

-- Controlling a fully armed and operational Digtron
minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "digtron:controller_assembled" then
		return
	end
	local player_name = player:get_player_name()
	local context = player_interacting_with_digtron_id[player_name]
	if context == nil then
		minetest.chat_send_all("no context")
		return
	end
	local digtron_id = context.digtron_id
	if digtron_id == nil then
		minetest.chat_send_all("no id")
		return
	end
	
	local pos = digtron.get_pos(digtron_id)
	if pos == nil then
		minetest.chat_send_all("no pos")
		return
	end
	local node = minetest.get_node(pos)
	if node.name ~= "digtron:controller" then
		minetest.chat_send_all("not controller " .. node.name .. " " .. minetest.pos_to_string(pos))
		-- this happened somehow in testing, Digtron needs to be able to recover from this situation.
		-- TODO catch this on_rightclick and try remapping the layout to the new position.
		return
	end

	local refresh = false
	if fields.tab_header then
		local new_tab = tonumber(fields.tab_header)
		if new_tab <= #(context.tabs) + 1 then
			context.current_tab = new_tab
			refresh = true
		else
			--TODO error message
		end
	end

	if fields.disassemble then
		local pos = digtron.disassemble(digtron_id, player_name)
		minetest.close_formspec(player_name, formname)
	end
	
	local facedir = node.param2
	-- Translation
	if fields.move_forward then
		digtron.move(digtron_id, vector.add(pos, digtron.facedir_to_dir(facedir)), player_name)
	elseif fields.move_back then
		digtron.move(digtron_id, vector.add(pos, vector.multiply(digtron.facedir_to_dir(facedir), -1)), player_name)
	elseif fields.move_up then
		digtron.move(digtron_id, vector.add(pos, digtron.facedir_to_up(facedir)), player_name)
	elseif fields.move_down then
		digtron.move(digtron_id, vector.add(pos, vector.multiply(digtron.facedir_to_up(facedir), -1)), player_name)
	elseif fields.move_left then
		digtron.move(digtron_id, vector.add(pos, vector.multiply(digtron.facedir_to_right(facedir), -1)), player_name)
	elseif fields.move_right then
		digtron.move(digtron_id, vector.add(pos, digtron.facedir_to_right(facedir)), player_name)
	-- Rotation	
	elseif fields.rot_counterclockwise then
		digtron.rotate(digtron_id, vector.multiply(digtron.facedir_to_dir(facedir), -1), player_name)
	elseif fields.rot_clockwise then
		digtron.rotate(digtron_id, digtron.facedir_to_dir(facedir), player_name)
	elseif fields.rot_up then
		digtron.rotate(digtron_id, digtron.facedir_to_right(facedir), player_name)
	elseif fields.rot_down then
		digtron.rotate(digtron_id, vector.multiply(digtron.facedir_to_right(facedir), -1), player_name)
	elseif fields.rot_left then
		digtron.rotate(digtron_id, vector.multiply(digtron.facedir_to_up(facedir), -1), player_name)
	elseif fields.rot_right then
		digtron.rotate(digtron_id, digtron.facedir_to_up(facedir), player_name)
	end

	if fields.execute then
		digtron.execute_cycle(digtron_id, player_name)
	end
	
	--TODO: this isn't recording the field when using ESC to exit the formspec
	if fields.key_enter_field == "digtron_name" or fields.digtron_name then
		local pos = digtron.get_pos(digtron_id)
		if pos then
			local meta = minetest.get_meta(pos)
			meta:set_string("infotext", fields.digtron_name)
			digtron.set_name(digtron_id, fields.digtron_name)
		end
	end
	
	if refresh then
		minetest.show_formspec(player_name,
			"digtron:controller_assembled",
			get_controller_assembled_formspec(digtron_id, player_name))
	end	
end)

-- Doesn't deep-copy
local combine_defs = function(base_def, override_content)
	local out = {}
	for key, value in pairs(base_def) do
		out[key] = value
	end
	for key, value in pairs(override_content) do
		out[key] = value
	end
	return out
end

local base_def = {
	description = S("Digtron Control Module"),
	_doc_items_longdesc = nil,
    _doc_items_usagehelp = nil,
	-- Note: this is not in the "digtron" group because we do not want it to be incorporated
	-- into digtrons by mere adjacency; it must be the root node and only one root node is allowed.
	groups = {cracky = 3, oddly_breakable_by_hand = 3},
	paramtype = "light",
	paramtype2= "facedir",
	is_ground_content = false,
	-- Aims in the +Z direction by default
	tiles = {
		"digtron_plate.png^[transformR90",
		"digtron_plate.png^[transformR270",
		"digtron_plate.png",
		"digtron_plate.png^[transformR180",
		"digtron_plate.png",
		"digtron_plate.png^digtron_control.png",
	},
	drawtype = "nodebox",
		node_box = {
		type = "fixed",
		fixed = {
			{-0.3125, -0.3125, -0.3125, 0.3125, 0.3125, 0.3125}, -- Core
			{-0.1875, 0.3125, -0.1875, 0.1875, 0.5, 0.1875}, -- +y_connector
			{-0.1875, -0.5, -0.1875, 0.1875, -0.3125, 0.1875}, -- -y_Connector
			{0.3125, -0.1875, -0.1875, 0.5, 0.1875, 0.1875}, -- +x_connector
			{-0.5, -0.1875, -0.1875, -0.3125, 0.1875, 0.1875}, -- -x_connector
			{-0.1875, -0.1875, 0.3125, 0.1875, 0.1875, 0.5}, -- +z_connector
			{-0.5, 0.125, -0.5, -0.125, 0.5, -0.3125}, -- back_connector_3
			{0.125, 0.125, -0.5, 0.5, 0.5, -0.3125}, -- back_connector_1
			{0.125, -0.5, -0.5, 0.5, -0.125, -0.3125}, -- back_connector_2
			{-0.5, -0.5, -0.5, -0.125, -0.125, -0.3125}, -- back_connector_4
		},
	},
	sounds = default.node_sound_metal_defaults(),
	on_blast = digtron.on_blast,
}

minetest.register_node("digtron:controller_unassembled", combine_defs(base_def, {
	_digtron_assembled_node = "digtron:controller",

	on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
		local returnstack, success = digtron.on_rightclick(pos, node, clicker, itemstack, pointed_thing)
		if returnstack then
			return returnstack, success
		end

		if clicker == nil then return end
		
		local player_name = clicker:get_player_name()
		local digtron_id = digtron.assemble(pos, player_name)
		if digtron_id then
			local meta = minetest.get_meta(pos)
			meta:set_string("digtron_id", digtron_id)
			meta:mark_as_private("digtron_id")
			player_interacting_with_digtron_id[player_name] = {digtron_id = digtron_id}
			minetest.show_formspec(player_name,
				"digtron:controller_assembled",
				get_controller_assembled_formspec(digtron_id, player_name))
		end
	end
}))

minetest.register_node("digtron:controller", combine_defs(base_def, {

	tiles = {
		"digtron_plate.png^[transformR90",
		"digtron_plate.png^[transformR270",
		"digtron_plate.png",
		"digtron_plate.png^[transformR180",
		"digtron_plate.png",
		"digtron_plate.png^digtron_control.png^digtron_intermittent.png",
	},
	_digtron_disassembled_node = "digtron:controller_unassembled",
	groups = {cracky = 3, oddly_breakable_by_hand = 3, not_in_creative_inventory = 1},
	
	on_dig = function(pos, node, digger)
		local player_name
		if digger then
			player_name = digger:get_player_name()
		end
		local meta = minetest.get_meta(pos)
		local digtron_id = meta:get_string("digtron_id")
		
		local stack = ItemStack({name=node.name, count=1, wear=0})
		local stack_meta = stack:get_meta()
		stack_meta:set_string("digtron_id", digtron_id)
		stack_meta:set_string("description", meta:get_string("infotext"))
		local inv = digger:get_inventory()
		local stack = inv:add_item("main", stack)
		if stack:get_count() > 0 then
			minetest.add_item(pos, stack)
		end		
		-- TODO call on_dignodes callback
		if digtron_id ~= "" then
			local removed = digtron.remove_from_world(digtron_id, player_name)
			for _, removed_pos in ipairs(removed) do
				minetest.check_for_falling(removed_pos)
			end
		else
			minetest.remove_node(pos)
		end
	end,
	
	preserve_metadata = function(pos, oldnode, oldmeta, drops)
		for _, dropped in ipairs(drops) do
			if dropped:get_name() == "digtron:controller" then
				local stack_meta = dropped:get_meta()
				stack_meta:set_string("digtron_id", oldmeta:get_string("digtron_id"))
				stack_meta:set_string("description", oldmeta:get_string("infotext"))
				return
			end
		end
	end,
	
	on_place = function(itemstack, placer, pointed_thing)
        -- Shall place item and return the leftover itemstack.
        -- The placer may be any ObjectRef or nil.
		local player_name
		if placer then player_name = placer:get_player_name() end
		
		local stack_meta = itemstack:get_meta()
		local digtron_id = stack_meta:get_string("digtron_id")
		if digtron_id ~= "" then
			local target_pos
			local below_node = minetest.get_node(pointed_thing.under)
			local below_def = minetest.registered_nodes[below_node.name]
			if below_def.buildable_to then
				target_pos = pointed_thing.under
			else
				target_pos = pointed_thing.above
			end
			-- TODO rotate layout based on player orientation
			
			-- move up so that the lowest y-coordinate on the Digtron is
			-- at the y-coordinate of the place clicked on and test again.
			local bbox = digtron.get_bounding_box(digtron_id)
			target_pos.y = target_pos.y + math.abs(bbox.minp.y)

			if target_pos then
				local success, succeeded, failed = digtron.is_buildable_to(digtron_id, nil, target_pos, player_name)
				if success then
					local built_positions = digtron.build_to_world(digtron_id, nil, target_pos, player_name)
					for _, built_pos in ipairs(built_positions) do
						minetest.check_for_falling(built_pos)
					end

					minetest.sound_play("digtron_machine_assemble", {gain = 0.5, pos=target_pos})
					-- Note: DO NOT RESPECT CREATIVE MODE here.
					-- If we allow multiple copies of a Digtron running around with the same digtron_id,
					-- human sacrifice, dogs and cats living together, mass hysteria
					return ItemStack("")
				else
					-- if that fails, show ghost of Digtron and fail to place.
					digtron.show_buildable_nodes(succeeded, failed)
					minetest.sound_play("digtron_buzzer", {gain = 0.5, pos=target_pos})
				end
			end
			return itemstack
		else
			-- Should be impossible to have a controller without an ID, but if it happens place an unassembled node
			itemstack:set_name("digtron:controller_unassembled")
			return minetest.item_place(itemstack, placer, pointed_thing)
		end
	end,
	
	after_place_node = function(pos, placer, itemstack, pointed_thing)
		local stack_meta = itemstack:get_meta()
		local title = stack_meta:get_string("description")
		local digtron_id = stack_meta:get_string("digtron_id")
		
		local meta = minetest.get_meta(pos)
			
		meta:set_string("infotext", title)
		meta:set_string("digtron_id", digtron_id)
		meta:mark_as_private("digtron_id")
	end,
	
	on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
		local returnstack, success = digtron.on_rightclick(pos, node, clicker, itemstack, pointed_thing)
		if returnstack then
			return returnstack, success
		end

		if clicker == nil then return end
		
		local meta = minetest.get_meta(pos)
		local digtron_id = meta:get_string("digtron_id")
		
		if digtron_id == "" then
			-- TODO: error message, fix digtron
		else
			local player_name = clicker:get_player_name()
			player_interacting_with_digtron_id[player_name] = {digtron_id = digtron_id}
			minetest.show_formspec(player_name,
				"digtron:controller_assembled",
				get_controller_assembled_formspec(digtron_id, player_name))
		end
	end,
}))