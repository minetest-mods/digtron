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

local get_controller_constructed_formspec = function(pos, digtron_id, player_name)
	return "size[9,9]button[1,1;1,1;deconstruct;Deconstruct]"
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
		if meta:get("digtron_id") ~= nil then
			return
		else
			return minetest.node_dig(pos, node, digger)
		end
	end,
	
	on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
		local meta = minetest.get_meta(pos)
		local digtron_id = meta:get("digtron_id")
		local player_name = clicker:get_player_name()
		if digtron_id ~= "" then
			minetest.show_formspec(player_name,
				"digtron_controller_unconstructed:"..minetest.pos_to_string(pos)..":"..player_name,
				get_controller_unconstructed_formspec(pos, player_name))
		else
			-- initialized
			minetest.show_formspec(player_name,
				"digtron_controller_constructed:"..minetest.pos_to_string(pos)..":"..player_name..":"..digtron_id,
				get_controller_construted_formspec(pos, digtron_id, player_name))
		end
	end,
	
	on_timer = function(pos, elapsed)
	end,
})

local cardinal_directions = {
	{x=1,y=0,z=0},
	{x=-1,y=0,z=0},
	{x=0,y=1,z=0},
	{x=0,y=-1,z=0},
	{x=0,y=0,z=1},
	{x=0,y=0,z=-1},
}
local origin_hash = minetest.hash_node_position({x=0,y=0,z=0})

local get_all_adjacent_digtron_nodes
get_all_adjacent_digtron_nodes = function(pos, digtron_nodes, not_digtron)
	for _, dir in ipairs(cardinal_directions) do
		local test_pos = vector.add(pos, dir)
		local test_hash = minetest.hash_node_position(test_pos)
		if not (digtron_nodes[test_hash] or not_digtron[test_hash]) then -- don't test twice
			local test_node = minetest.get_node(test_pos)
			local group_value = minetest.get_item_group(test_node.name, "digtron")
			if group_value > 0 then
				digtron_nodes[test_hash] = test_node
				get_all_adjacent_digtron_nodes(test_pos, digtron_nodes, not_digtron) -- recurse
			else
				not_digtron[test_hash] = test_node
			end
		end		
	end
end


digtron.construct = function(pos, player_name)
	local node = minetest.get_node(pos)
	if node.name ~= "digtron:controller" then
		-- Called on an incorrect node
		minetest.log("error", "[Digtron] digtron.construct called with pos " .. minetest.pos_to_string(pos) .. " but the node at this location was " .. node.name)
		return nil
	end
	local meta = minetest.get_meta(pos)
	if meta:get("digtron_id") ~= nil then
		-- Already constructed. TODO: validate that the digtron_id actually exists as well
		minetest.log("error", "[Digtron] digtron.construct called with pos " .. minetest.pos_to_string(pos) .. " but the controller at this location was already part of a constructed Digtron.")
		return nil
	end
	local root_hash = minetest.hash_node_position(pos)
	local digtron_nodes = {[root_hash] = node}
	local not_digtron = {}
	get_all_adjacent_digtron_nodes(pos, digtron_nodes, not_digtron)
	for hash, node in pairs(digtron_nodes) do
		local relative_hash = hash - root_hash + origin_hash
		minetest.chat_send_all("constructing " .. minetest.pos_to_string(minetest.get_position_from_hash(relative_hash)))
		local digtron_meta
		if hash == root_hash then
			digtron_meta = meta -- we're processing the controller, we already have a reference to its meta
		else
			digtron_meta = minetest.get_meta(minetest.get_position_from_hash(hash))
		end
		
		local meta_table = digtron_meta:to_table()
		meta_table.node = node
		-- Process inventories specially
		-- Builder inventory gets turned into an itemname in a special key in the builder's meta
		-- fuel and main get added to corresponding detached inventory lists
		-- then wipe them from the meta_table. They'll be re-added in digtron.deconstruct.
		--meta_table.inventory = nil
		node.param1 = nil -- we don't care about param1, wipe it to save space
		minetest.chat_send_all(dump(meta_table))
	end
	
	
end


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
			minetest.show_formspec(name,
				"digtron_controller_constructed:"..minetest.pos_to_string(pos)..":"..name..":"..digtron_id,
				get_controller_construted_formspec(pos, digtron_id, name))
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
	local digtron_id = formname_splot[4]
	
	if fields.deconstruct then
		minetest.chat_send_all("Deconstructing " .. digtron_id)
	end
	
end)
