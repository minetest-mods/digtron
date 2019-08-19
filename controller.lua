-- internationalization boilerplate
local MP = minetest.get_modpath(minetest.get_current_modname())
local S, NS = dofile(MP.."/intllib.lua")

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

local get_controller_unconstructed_formspec = function(pos, player_name)
	local meta = minetest.get_meta(pos)
	return "size[9,9]"
		.. "container[0.5,0]"
		.. "button[0,0;1,1;construct;Construct]"
		.. "field[1.2,0.25;2,1;digtron_name;Digtron name;"..meta:get_string("infotext").."]"
		.. "field_close_on_enter[digtron_name;false]"
		.. "container_end[]"
end

local get_controller_constructed_formspec = function(pos, digtron_id, player_name)
	digtron.retrieve_inventory(digtron_id) -- ensures the detatched inventory exists and is populated
	return "size[9,9]"
		.. "container[0.5,0]"
		.. "button[0,0;1,1;deconstruct;Deconstruct]"
		.. "field[1.2,0.25;2,1;digtron_name;Digtron name;"..digtron.get_name(digtron_id).."]"
		.. "field_close_on_enter[digtron_name;false]"
		.. "container_end[]"
		.. "container[0.5,1]"
		.. "list[detached:" .. digtron_id .. ";main;0,0;8,2]" -- TODO: paging system for inventory
		.. "list[detached:" .. digtron_id .. ";fuel;0,2.5;8,2]" -- TODO: paging system for inventory
		.. "container_end[]"
		.. "container[0.5,5]list[current_player;main;0,0;8,1;]list[current_player;main;0,1.25;8,3;8]container_end[]"
		.. "listring[current_player;main]"
		.. "listring[detached:" .. digtron_id .. ";main]"
end

minetest.register_node("digtron:controller", {
	description = S("Digtron Control Module"),
	_doc_items_longdesc = nil,
    _doc_items_usagehelp = nil,
	groups = {cracky = 3, oddly_breakable_by_hand = 3, digtron = 1},
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
			digtron.remove_from_world(digtron_id, pos, player_name)
		else
			minetest.remove_node(pos)
		end
	end,
	
	--TODO: this didn't work when I blew up a digtron with TNT, investigate why
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
			local root_pos = minetest.get_pointed_thing_position(pointed_thing, true)
			digtron.build_to_world(digtron_id, root_pos, player_name)
		end
		-- 
		
		-- Default:
        return minetest.item_place(itemstack, placer, pointed_thing)
	end,
	
	after_place_node = function(pos, placer, itemstack, pointed_thing)
		local stack_meta = itemstack:get_meta()
		local title = stack_meta:get_string("description")
		local digtron_id = stack_meta:get_string("digtron_id")
		
		local meta = minetest.get_meta(pos)
			
		meta:set_string("infotext", title)
		meta:set_string("digtron_id", digtron_id)
		
		if digtron_id ~= "" then
			-- TODO create the other nodes belonging to this digtron
		end
	end,
	
	on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
		local meta = minetest.get_meta(pos)
		local digtron_id = meta:get_string("digtron_id")
		local player_name
		if clicker then player_name = clicker:get_player_name() end
		
		if digtron_id == "" then
			minetest.show_formspec(player_name,
				"digtron_controller_unconstructed:"..minetest.pos_to_string(pos)..":"..player_name,
				get_controller_unconstructed_formspec(pos, player_name))
		else
			-- initialized
			minetest.show_formspec(player_name,
				"digtron_controller_constructed:"..minetest.pos_to_string(pos)..":"..player_name..":"..digtron_id,
				get_controller_constructed_formspec(pos, digtron_id, player_name))
		end
	end,
	
	on_timer = function(pos, elapsed)
	end,
})

-- Dealing with an unconstructed Digtron controller
minetest.register_on_player_receive_fields(function(player, formname, fields)
	local formname_split = formname:split(":")
	if #formname_split ~= 3 or formname_split[1] ~= "digtron_controller_unconstructed" then
		return
	end
	local pos = minetest.string_to_pos(formname_split[2])
	if pos == nil then
		minetest.log("error", "[Digtron] Unable to parse position from formspec name " .. formname)
		return
	end
	local name = formname_split[3]
	if player:get_player_name() ~= name then
		return
	end

	if fields.construct then
		local digtron_id = digtron.construct(pos, name)
		if digtron_id then
			local meta = minetest.get_meta(pos)
			meta:set_string("digtron_id", digtron_id)
			minetest.show_formspec(name,
				"digtron_controller_constructed:"..minetest.pos_to_string(pos)..":"..name..":"..digtron_id,
				get_controller_constructed_formspec(pos, digtron_id, name))
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
	local formname_split = formname:split(":")
	if #formname_split ~= 4 or formname_split[1] ~= "digtron_controller_constructed" then
		return
	end
	local pos = minetest.string_to_pos(formname_split[2])
	if pos == nil then
		minetest.log("error", "[Digtron] Unable to parse position from formspec name " .. formname)
		return
	end
	local name = formname_split[3]
	if player:get_player_name() ~= name then
		return
	end
	local digtron_id = formname_split[4]
	
	if fields.deconstruct then
		minetest.chat_send_all("Deconstructing " .. digtron_id)
		
		local meta = minetest.get_meta(pos)
		local digtron_id = meta:get_string("digtron_id")
		if digtron_id == "" then
			minetest.log("error", "[Digtron] tried to deconstruct Digtron at pos "
				.. minetest.pos_to_string(pos) .. " but it had no digtron_id in the node's metadata")
		else
			digtron.deconstruct(digtron_id, pos, name)
			minetest.show_formspec(name,
				"digtron_controller_unconstructed:"..minetest.pos_to_string(pos)..":"..name,
				get_controller_unconstructed_formspec(pos, name))
		end		
	end
	
	--TODO: this isn't recording the field when using ESC to exit the formspec
	if fields.key_enter_field == "digtron_name" or fields.digtron_name then
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", fields.digtron_name)
		digtron.set_name(digtron_id, fields.digtron_name)
	end
	
end)
