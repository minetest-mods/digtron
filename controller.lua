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
	return "size[8,8]button[1,1;1,1;construct;Construct]"
end

local get_controller_constructed_formspec = function(pos, digtron_id_name, player_name)
	digtron.retrieve_inventory(digtron_id_name)

	return "size[9,9]button[1,0;1,1;deconstruct;Deconstruct]"
		.. "list[detached:" .. digtron_id_name .. ";main;1,1;8,2]" -- TODO: paging system for inventory
		.. "list[detached:" .. digtron_id_name .. ";fuel;1,3.5;8,2]" -- TODO: paging system for inventory
		.."container[1,5]list[current_player;main;0,0;8,1;]list[current_player;main;0,1.25;8,3;8]container_end[]"
		.."listring[current_player;main]"
		.."listring[detached:" .. digtron_id_name .. ";main]"
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
		local meta = minetest.get_meta(pos)
		if meta:get_string("digtron_id") ~= "" then
			return -- TODO: special handling here!
		else
			return minetest.node_dig(pos, node, digger)
		end
	end,
	
	on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
		local meta = minetest.get_meta(pos)
		local digtron_id = meta:get_string("digtron_id")
		local player_name = clicker:get_player_name()
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
	
end)
