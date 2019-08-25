-- internationalization boilerplate
local MP = minetest.get_modpath(minetest.get_current_modname())
local S, NS = dofile(MP.."/intllib.lua")

-- This allows us to know which digtron the player has a formspec open for without
-- sending the digtron_id over the network
local player_interacting_with_digtron_id = {}
local player_interacting_with_digtron_pos = {}

local controller_nodebox = {
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
}

local get_controller_unassembled_formspec = function(pos, player_name)
	local meta = minetest.get_meta(pos)
	return "size[9,9]"
		.. "container[0.5,0]"
		.. "button[0,0;1,1;assemble;Assemble]"
		.. "field[1.2,0.25;2,1;digtron_name;Digtron name;"..meta:get_string("infotext").."]"
		.. "field_close_on_enter[digtron_name;false]"
		.. "container_end[]"
end

local get_controller_assembled_formspec = function(pos, digtron_id, player_name)
	digtron.retrieve_inventory(digtron_id) -- ensures the detatched inventory exists and is populated
	return "size[9,9]"
		.. "container[0.5,0]"
		.. "button[0,0;1,1;disassemble;Disassemble]"
		.. "field[1.2,0.25;2,1;digtron_name;Digtron name;"..digtron.get_name(digtron_id).."]"
		.. "field_close_on_enter[digtron_name;false]"
		.. "button[3,0;1,1;move_forward;Move forward]"
		.. "button[4,0;1,1;test_dig;Test dig]"
		.. "container_end[]"
		.. "container[0.5,1]"
		.. "list[detached:" .. digtron_id .. ";main;0,0;8,2]" -- TODO: paging system for inventory, guard against non-existent listname
		.. "list[detached:" .. digtron_id .. ";fuel;0,2.5;8,2]" -- TODO: paging system for inventory, guard against non-existent listname
		.. "container_end[]"
		.. "container[0.5,5]list[current_player;main;0,0;8,1;]list[current_player;main;0,1.25;8,3;8]container_end[]"
		.. "listring[current_player;main]"
		.. "listring[detached:" .. digtron_id .. ";main]"
end

minetest.register_node("digtron:controller", {
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
	node_box = controller_nodebox,
	sounds = default.node_sound_metal_defaults(),
	
--	on_construct = function(pos)
--	end,
	
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
		-- call on_dignodes callback
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
			-- Test if Digtron will fit the surroundings
			-- if not, try moving it up so that the lowest y-coordinate on the Digtron is
			-- at the y-coordinate of the place clicked on and test again.
			-- if that fails, show ghost of Digtron and fail to place.
			
			local target_pos
			local below_node = minetest.get_node(pointed_thing.under)
			local below_def = minetest.registered_nodes[below_node.name]
			if below_def.buildable_to then
				target_pos = pointed_thing.under
			else
				target_pos = pointed_thing.above
			end

			if target_pos then
				local success, succeeded, failed = digtron.is_buildable_to(digtron_id, target_pos, player_name)
				if success then
					digtron.build_to_world(digtron_id, target_pos, player_name)
					minetest.sound_play("digtron_machine_assemble", {gain = 0.5, pos=target_pos})
					-- Note: DO NOT RESPECT CREATIVE MODE here.
					-- If we allow multiple copies of a Digtron running around with the same digtron_id,
					-- human sacrifice, dogs and cats living together, mass hysteria
					return ItemStack("")
				else
					digtron.show_buildable_nodes(succeeded, failed)
					minetest.sound_play("digtron_buzzer", {gain = 0.5, pos=target_pos})
				end
			end
			return itemstack
		else
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
		if clicker == nil then return end
		local meta = minetest.get_meta(pos)
		local digtron_id = meta:get_string("digtron_id")
		local player_name = clicker:get_player_name()
		
		if digtron_id == "" then
			player_interacting_with_digtron_pos[player_name] = pos
			minetest.show_formspec(player_name,
				"digtron:controller_unassembled",
				get_controller_unassembled_formspec(pos, player_name))
		else
			-- initialized
			player_interacting_with_digtron_id[player_name] = digtron_id
			minetest.show_formspec(player_name,
				"digtron:controller_assembled",
				get_controller_assembled_formspec(pos, digtron_id, player_name))
		end
	end,
	
	on_timer = function(pos, elapsed)
	end,
	
	on_blast = digtron.on_blast,
})

-- Dealing with an unassembled Digtron controller
minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "digtron:controller_unassembled" then
		return
	end
	local name = player:get_player_name()
	local pos = player_interacting_with_digtron_pos[name]
	
	if pos == nil then return end

	if fields.assemble then
		local digtron_id = digtron.assemble(pos, name)
		if digtron_id then
			local meta = minetest.get_meta(pos)
			meta:set_string("digtron_id", digtron_id)
			meta:mark_as_private("digtron_id")
			player_interacting_with_digtron_id[name] = digtron_id
			minetest.show_formspec(name,
				"digtron:controller_assembled",
				get_controller_assembled_formspec(pos, digtron_id, name))
		end
	end
	
	--TODO: this isn't recording the field when using ESC to exit the formspec
	if fields.key_enter_field == "digtron_name" or fields.digtron_name then
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", fields.digtron_name)
	end
end)

-- Controlling a fully armed and operational Digtron
minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "digtron:controller_assembled" then
		return
	end
	local player_name = player:get_player_name()
	local digtron_id = player_interacting_with_digtron_id[player_name]
	if digtron_id == nil then return end
	
	if fields.disassemble then
		local pos = digtron.disassemble(digtron_id, player_name)
		if pos then
			player_interacting_with_digtron_pos[player_name] = pos
			minetest.show_formspec(player_name,
				"digtron:controller_unassembled",
					get_controller_unassembled_formspec(pos, player_name))
		end		
	end
	
	if fields.move_forward then
		local pos = digtron.get_pos(digtron_id)
		if pos then
			local node = minetest.get_node(pos)
			if node.name == "digtron:controller" then
				local dir = minetest.facedir_to_dir(node.param2)
				local dest_pos = vector.add(dir, pos)
				digtron.move(digtron_id, dest_pos, player_name)
			end
		end		
	end
	
	if fields.test_dig then
		local products, nodes_to_dig, cost = digtron.predict_dig(digtron_id, player_name)
		minetest.chat_send_all("products: " .. dump(products))
		minetest.chat_send_all("positions: " .. dump(nodes_to_dig))
		minetest.chat_send_all("cost: " .. cost)
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
	
end)
