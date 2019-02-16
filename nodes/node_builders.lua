-- internationalization boilerplate
local MP = minetest.get_modpath(minetest.get_current_modname())
local S, NS = dofile(MP.."/intllib.lua")

-- Note: builders go in group 4 and have both test_build and execute_build methods.

local node_inventory_table = {type="node"} -- a reusable parameter for get_inventory calls, set the pos parameter before using.

local displace_due_to_help_button = 1.0
if minetest.get_modpath("doc") then
	displace_due_to_help_button = 0.0
end

local builder_formspec_string =
	"size[8,5.2]" ..
	default.gui_bg ..
	default.gui_bg_img ..
	default.gui_slots ..
	"list[current_name;main;".. tostring(displace_due_to_help_button/2) ..",0;1,1;]" ..
	"label[" .. tostring(displace_due_to_help_button/2).. ",0.8;" .. S("Block to build") .. "]" ..
	"field[" .. tostring(displace_due_to_help_button + 1.3) ..",0.8;1,0.1;extrusion;" .. S("Extrusion") .. ";${extrusion}]" ..
	"tooltip[extrusion;" .. S("Builder will extrude this many blocks in the direction it is facing.\nCan be set from 1 to @1.\nNote that Digtron won't build into unloaded map regions.", digtron.config.maximum_extrusion) .. "]" ..
	"field[" .. tostring(displace_due_to_help_button + 2.3) ..",0.8;1,0.1;period;" .. S("Periodicity") .. ";${period}]" ..
	"tooltip[period;" .. S("Builder will build once every n steps.\nThese steps are globally aligned, so all builders with the\nsame period and offset will build on the same location.") .. "]" ..
	"field[" .. tostring(displace_due_to_help_button + 3.3) ..",0.8;1,0.1;offset;" .. S("Offset") .. ";${offset}]" ..
	"tooltip[offset;" .. S("Offsets the start of periodicity counting by this amount.\nFor example, a builder with period 2 and offset 0 builds\nevery even-numbered block and one with period 2 and\noffset 1 builds every odd-numbered block.") .. "]" ..
	"button_exit[" .. tostring(displace_due_to_help_button + 4.0) ..",0.5;1,0.1;set;" .. S("Save &\nShow") .. "]" ..
	"tooltip[set;" .. S("Saves settings") .. "]" ..
	"field[" .. tostring(displace_due_to_help_button + 5.3) .. ",0.8;1,0.1;build_facing;" .. S("Facing") .. ";${build_facing}]" ..
	"tooltip[build_facing;" .. S("Value from 0-23. Not all block types make use of this.\nUse the 'Read & Save' button to copy the facing of the block\ncurrently in the builder output location.") .. "]" ..
	"button_exit[" .. tostring(displace_due_to_help_button + 6.0) ..",0.5;1,0.1;read;" .. S("Read &\nSave") .. "]" ..
	"tooltip[read;" .. S("Reads the facing of the block currently in the build location,\nthen saves all settings.") .. "]" ..
	"list[current_player;main;0,1.3;8,1;]" ..
	default.get_hotbar_bg(0,1.3) ..
	"list[current_player;main;0,2.5;8,3;8]" ..
	"listring[current_player;main]" ..
	"listring[current_name;main]"

if minetest.get_modpath("doc") then
	builder_formspec_string = builder_formspec_string ..
		"button_exit[7.0,0.5;1,0.1;help;" .. S("Help") .. "]" ..
		"tooltip[help;" .. S("Show documentation about this block") .. "]"
end
	
local builder_formspec = function(pos, meta)
	local nodemeta = "nodemeta:"..pos.x .. "," .. pos.y .. "," ..pos.z
	return builder_formspec_string
		:gsub("${extrusion}", meta:get_int("extrusion"), 1)
		:gsub("${period}", meta:get_int("period"), 1)
		:gsub("${offset}", meta:get_int("offset"), 1)
		:gsub("${build_facing}", meta:get_int("build_facing"), 1)
		:gsub("current_name", "nodemeta:"..pos.x .. "," .. pos.y .. "," ..pos.z, 2)
end

local builder_on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
	local item_def = itemstack:get_definition()
	if item_def.type == "node" and minetest.get_item_group(itemstack:get_name(), "digtron") > 0 then
		local returnstack, success = minetest.item_place_node(itemstack, clicker, pointed_thing)
		if success and item_def.sounds and item_def.sounds.place and item_def.sounds.place.name then
			minetest.sound_play(item_def.sounds.place, {pos = pos})
		end
		return returnstack, success
	end
	local meta = minetest.get_meta(pos)	
	minetest.show_formspec(clicker:get_player_name(),
		"digtron:builder"..minetest.pos_to_string(pos),
		builder_formspec(pos, meta))
end

minetest.register_on_player_receive_fields(function(sender, formname, fields)

	if formname:sub(1, 15) ~= "digtron:builder" then
		return
	end
	local pos = minetest.string_to_pos(formname:sub(16, -1))

    local meta = minetest.get_meta(pos)
	local period = tonumber(fields.period)
	local offset = tonumber(fields.offset)
	local build_facing = tonumber(fields.build_facing)
	local extrusion = tonumber(fields.extrusion)
	
	if period and period > 0 then
		meta:set_int("period", math.floor(tonumber(fields.period)))
	else
		period = meta:get_int("period")
	end
	if offset then
		meta:set_int("offset", math.floor(tonumber(fields.offset)))
	else
		offset = meta:get_int("offset")
	end
	if build_facing and build_facing >= 0 and build_facing < 24 then
		local inv = meta:get_inventory()
		local target_item = inv:get_stack("main",1)
		if target_item:get_definition().paramtype2 == "wallmounted" then
			if build_facing < 6 then
				meta:set_int("build_facing", math.floor(build_facing))
				-- wallmounted facings only run from 0-5
			end
		else
			meta:set_int("build_facing", math.floor(build_facing))
		end
	end
	if extrusion and extrusion > 0 and extrusion <= digtron.config.maximum_extrusion then
		meta:set_int("extrusion", math.floor(tonumber(fields.extrusion)))
	else
		extrusion = meta:get_int("extrusion")
	end
	
	if fields.set then
		digtron.show_offset_markers(pos, offset, period)

	elseif fields.read then
		local facing = minetest.get_node(pos).param2
		local buildpos = digtron.find_new_pos(pos, facing)
		local target_node = minetest.get_node(buildpos)
		if target_node.name ~= "air" and minetest.get_item_group(target_node.name, "digtron") == 0 then
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			local target_name = digtron.builder_read_item_substitutions[target_node.name] or target_node.name
			inv:set_stack("main", 1, target_name)
			meta:set_int("build_facing", target_node.param2)
		end
	end
	
	if fields.help and minetest.get_modpath("doc") then --check for mod in case someone disabled it after this digger was built
		minetest.after(0.5, doc.show_entry, sender:get_player_name(), "nodes", "digtron:builder", true)
	end

	digtron.update_builder_item(pos)
end)


-- Builds objects in the targeted node. This is a complicated beastie.
minetest.register_node("digtron:builder", {
	description = S("Digtron Builder Module"),
	_doc_items_longdesc = digtron.doc.builder_longdesc,
    _doc_items_usagehelp = digtron.doc.builder_usagehelp,
	groups = {cracky = 3,  oddly_breakable_by_hand=3, digtron = 4},
	drop = "digtron:builder",
	sounds = digtron.metal_sounds,
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
		meta:set_int("build_facing", 0)
		meta:set_int("extrusion", 1)
				
		local inv = meta:get_inventory()
		inv:set_size("main", 1)
    end,
	
	on_rightclick = builder_on_rightclick,
	
	on_destruct = function(pos)
		digtron.remove_builder_item(pos)
	end,
	
	after_place_node = function(pos)
		digtron.update_builder_item(pos)
	end,

	allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		local stack_name = stack:get_name()
	
		if minetest.get_item_group(stack_name, "digtron") ~= 0 then
			return 0 -- don't allow builders to be set to build Digtron nodes, they'll just clog the output.
		end	
		
		local stack_def = minetest.registered_nodes[stack_name]
		if not stack_def and not digtron.whitelisted_on_place(stack_name) then
			return 0 -- don't allow craft items unless their on_place is whitelisted.
		end
		
		node_inventory_table.pos = pos
		local inv = minetest.get_inventory(node_inventory_table)
		inv:set_stack(listname, index, stack:take_item(1))
		
		-- If we're adding a wallmounted item and the build facing is greater than 5, reset it to 0
		local meta = minetest.get_meta(pos)
		if stack_def ~= nil and stack_def.paramtype2 == "wallmounted" and tonumber(meta:get_int("build_facing")) > 5 then
			meta:set_int("build_facing", 0)
		end
		
		return 0
	end,
	
	allow_metadata_inventory_take = function(pos, listname, index, stack, player)
		node_inventory_table.pos = pos
		local inv = minetest.get_inventory(node_inventory_table)
		inv:set_stack(listname, index, ItemStack(""))
		return 0
	end,
	
	-- "builder at pos, imagine that you're in test_pos. If you're willing and able to build from there, take the item you need from inventory.
	-- return the item you took and the inventory location you took it from so it can be put back after all the other builders have been tested.
	-- If you couldn't get the item from inventory, return an error code so we can abort the cycle.
	-- If you're not supposed to build at all, or the location is obstructed, return 0 to let us know you're okay and we shouldn't abort."
	
	--return code and accompanying value:
	-- 0, {}								-- not supposed to build, no error
	-- 1, {{itemstack, source inventory pos}, ...} -- can build, took items from inventory
	-- 2, {{itemstack, source inventory pos}, ...}, itemstack	-- was supposed to build, but couldn't get the item from inventory
	-- 3, {}								-- builder configuration error
	test_build = function(pos, test_pos, inventory_positions, protected_nodes, nodes_dug, controlling_coordinate, controller_pos)
		local meta = minetest.get_meta(pos)
		local facing = minetest.get_node(pos).param2
		local buildpos = digtron.find_new_pos(test_pos, facing)
		
		if (buildpos[controlling_coordinate] + meta:get_int("offset")) % meta:get_int("period") ~= 0 then
			--It's not the builder's turn to build right now.
			return 0, {}
		end
		
		local extrusion_count = 0
		local extrusion_target = meta:get_int("extrusion")
		if extrusion_target == nil or extrusion_target < 1 or extrusion_target > 100 then
			extrusion_target = 1 -- failsafe
		end
		
		local return_items = {}
		
		node_inventory_table.pos = pos
		local inv = minetest.get_inventory(node_inventory_table)
		local item_stack = inv:get_stack("main", 1)

		if item_stack:is_empty() then
			return 3, {} -- error code for "this builder's item slot is unset"
		end
		
		while extrusion_count < extrusion_target do
			if not digtron.can_move_to(buildpos, protected_nodes, nodes_dug) then
				--using "can_move_to" instead of "can_build_to" test case in case the builder is pointed "backward", and will thus
				--be building into the space that it's currently in and will be vacating after moving, or in case the builder is aimed
				--sideways and a fellow digtron node was ahead of it (will also be moving out of the way).
				
				--If the player has built his digtron stupid (eg has another digtron node in the place the builder wants to build) this
				--assumption is wrong, but I can't hold the player's hand through *every* possible bad design decision. Worst case,
				--the digtron will think its inventory can't handle the next build step and abort the build when it actually could have
				--managed one more cycle. That's not a bad outcome for a digtron array that was built stupidly to begin with.
				return 1, return_items
			end
			
			local source_location = digtron.take_from_inventory(item_stack:get_name(), inventory_positions)
			if source_location ~= nil then
				table.insert(return_items, {item=item_stack, location=source_location})
			else
				return 2, return_items, item_stack -- error code for "needed an item but couldn't get it from inventory"
			end
			extrusion_count = extrusion_count + 1
			buildpos = digtron.find_new_pos(buildpos, facing)
		end
		
		return 1, return_items
	end,
	
	execute_build = function(pos, player, inventory_positions, protected_nodes, nodes_dug, controlling_coordinate, controller_pos)
		local meta = minetest.get_meta(pos)
		local build_facing = tonumber(meta:get_int("build_facing"))
		local facing = minetest.get_node(pos).param2
		local buildpos = digtron.find_new_pos(pos, facing)
		
		if (buildpos[controlling_coordinate] + meta:get_int("offset")) % meta:get_int("period") ~= 0 then
			return 0
		end
		
		local extrusion_count = 0
		local extrusion_target = meta:get_int("extrusion")
		if extrusion_target == nil or extrusion_target < 1 or extrusion_target > 100 then
			extrusion_target = 1 -- failsafe
		end
		local built_count = 0
		
		node_inventory_table.pos = pos
		local inv = minetest.get_inventory(node_inventory_table)
		local item_stack = inv:get_stack("main", 1)
		if item_stack:is_empty() then
			return built_count
		end
		
		while extrusion_count < extrusion_target do
			if not digtron.can_build_to(buildpos, protected_nodes, nodes_dug) then
				return built_count
			end

			local oldnode = minetest.get_node(buildpos)

			if not digtron.config.uses_resources then
				local returned_stack, success = digtron.item_place_node(item_stack, player, buildpos, build_facing)
				if success == true then
					minetest.log("action", string.format("%s uses Digtron to build %s at (%d, %d, %d), displacing %s", player:get_player_name(), item_stack:get_name(), buildpos.x, buildpos.y, buildpos.z, oldnode.name))
					nodes_dug:set(buildpos.x, buildpos.y, buildpos.z, false)
					built_count = built_count + 1
				else
					return built_count
				end
			end
		
			local sourcepos = digtron.take_from_inventory(item_stack:get_name(), inventory_positions)
			if sourcepos == nil then
				-- item not in inventory! Need to sound the angry buzzer to let the player know, so return a negative number.
				return (built_count + 1) * -1
			end
			local returned_stack, success = digtron.item_place_node(ItemStack(item_stack), player, buildpos, build_facing)
			if success == true then
				minetest.log("action", string.format("%s uses Digtron to build %s at (%d, %d, %d), displacing %s", player:get_player_name(), item_stack:get_name(), buildpos.x, buildpos.y, buildpos.z, oldnode.name))
				--flag this node as *not* to be dug.
				nodes_dug:set(buildpos.x, buildpos.y, buildpos.z, false)
				digtron.award_item_built(item_stack:get_name(), player)
				built_count = built_count + 1
			else
				--failed to build, target node probably obstructed. Put the item back in inventory.
				--Should probably never reach this since we're guarding against can_build_to, above, but this makes things safe if we somehow do.
				digtron.place_in_specific_inventory(item_stack, sourcepos, inventory_positions, controller_pos)
				return built_count
			end

			extrusion_count = extrusion_count + 1
			buildpos = digtron.find_new_pos(buildpos, facing)
		end
		return built_count
	end,
})