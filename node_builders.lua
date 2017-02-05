-- internationalization boilerplate
local MP = minetest.get_modpath(minetest.get_current_modname())
local S, NS = dofile(MP.."/intllib.lua")

-- Note: builders go in group 4 and have both test_build and execute_build methods.

local builder_formspec =
	"size[8,5.2]" ..
	default.gui_bg ..
	default.gui_bg_img ..
	default.gui_slots ..
	"list[current_name;main;0.5,0;1,1;]" ..
	"label[0.5,0.8;" .. S("Block to build") .. "]" ..
	"field[2.3,0.8;1,0.1;period;" .. S("Periodicity") .. ";${period}]" ..
	"tooltip[period;" .. S("Builder will build once every n steps.\nThese steps are globally aligned, so all builders with the\nsame period and offset will build on the same location.") .. "]" ..
	"field[3.3,0.8;1,0.1;offset;" .. S("Offset") .. ";${offset}]" ..
	"tooltip[offset;" .. S("Offsets the start of periodicity counting by this amount.\nFor example, a builder with period 2 and offset 0 builds\nevery even-numbered block and one with period 2 and\noffset 1 builds every odd-numbered block.") .. "]" ..
	"button_exit[4.0,0.5;1,0.1;set;" .. S("Save &\nShow") .. "]" ..
	"tooltip[set;" .. S("Saves settings") .. "]" ..
	"field[5.3,0.8;1,0.1;build_facing;" .. S("Facing") .. ";${build_facing}]" ..
	"tooltip[build_facing;" .. S("Value from 0-23. Not all block types make use of this.\nUse the 'Read & Save' button to copy the facing of the block\ncurrently in the builder output location.") .. "]" ..
	"button_exit[6.0,0.5;1,0.1;read;" .. S("Read &\nSave") .. "]" ..
	"tooltip[read;" .. S("Reads the facing of the block currently in the build location,\nthen saves all settings.") .. "]" ..
	"list[current_player;main;0,1.3;8,1;]" ..
	default.get_hotbar_bg(0,1.3) ..
	"list[current_player;main;0,2.5;8,3;8]" ..
	"listring[current_player;main]" ..
	"listring[current_name;main]"

if minetest.get_modpath("doc") then
	builder_formspec = builder_formspec ..
	"button_exit[7.0,0.5;1,0.1;help;" .. S("Help") .. "]" ..
	"tooltip[help;" .. S("Show documentation about this block") .. "]"
end

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
        meta:set_string("formspec", builder_formspec)
		meta:set_int("period", 1) 
		meta:set_int("offset", 0) 
		meta:set_int("build_facing", 0)
				
		local inv = meta:get_inventory()
		inv:set_size("main", 1)
    end,
	
	on_receive_fields = function(pos, formname, fields, sender)
        local meta = minetest.get_meta(pos)
		local period = tonumber(fields.period)
		local offset = tonumber(fields.offset)
		local build_facing = tonumber(fields.build_facing)
		if  period and period > 0 then
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
			-- TODO: wallmounted facings only run from 0-5, a player could theoretically put a wallmounted item into the builder and then manually set the build facing to an invalid number
			-- Should prevent that somehow. But not tonight.
			meta:set_int("build_facing", math.floor(build_facing))
		end
		
		if fields.set then
			local buildpos = digtron.find_new_pos(pos, minetest.get_node(pos).param2)
			local x_pos = math.floor((buildpos.x+offset)/period)*period - offset
			minetest.add_entity({x=x_pos, y=buildpos.y, z=buildpos.z}, "digtron:marker")
			if x_pos >= buildpos.x then
				minetest.add_entity({x=x_pos - period, y=buildpos.y, z=buildpos.z}, "digtron:marker")
			end
			if x_pos <= buildpos.x then
				minetest.add_entity({x=x_pos + period, y=buildpos.y, z=buildpos.z}, "digtron:marker")
			end

			local y_pos = math.floor((buildpos.y+offset)/period)*period - offset
			minetest.add_entity({x=buildpos.x, y=y_pos, z=buildpos.z}, "digtron:marker_vertical")
			if y_pos >= buildpos.y then
				minetest.add_entity({x=buildpos.x, y=y_pos - period, z=buildpos.z}, "digtron:marker_vertical")
			end
			if y_pos <= buildpos.y then
				minetest.add_entity({x=buildpos.x, y=y_pos + period, z=buildpos.z}, "digtron:marker_vertical")
			end

			local z_pos = math.floor((buildpos.z+offset)/period)*period - offset
			minetest.add_entity({x=buildpos.x, y=buildpos.y, z=z_pos}, "digtron:marker"):setyaw(1.5708)
			if z_pos >= buildpos.z then
				minetest.add_entity({x=buildpos.x, y=buildpos.y, z=z_pos - period}, "digtron:marker"):setyaw(1.5708)
			end
			if z_pos <= buildpos.z then
				minetest.add_entity({x=buildpos.x, y=buildpos.y, z=z_pos + period}, "digtron:marker"):setyaw(1.5708)
			end

		elseif fields.read then
			local meta = minetest.get_meta(pos)
			local facing = minetest.get_node(pos).param2
			local buildpos = digtron.find_new_pos(pos, facing)
			meta:set_int("build_facing", minetest.get_node(buildpos).param2)
		end
		
		if fields.help and minetest.get_modpath("doc") then --check for mod in case someone disabled it after this digger was built
			doc.show_entry(sender:get_player_name(), "nodes", "digtron:builder")
		end

		digtron.update_builder_item(pos)
	end,
	
	on_destruct = function(pos)
		digtron.remove_builder_item(pos)
	end,
	
	after_place_node = function(pos)
		digtron.update_builder_item(pos)
	end,

	allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		if minetest.get_item_group(stack:get_name(), "digtron") ~= 0 then
			return 0 -- don't allow builders to be set to build Digtron nodes, they'll just clog the output.
		end	
		local inv = minetest.get_inventory({type="node", pos=pos})
		inv:set_stack(listname, index, stack:take_item(1))
		return 0
	end,
	
	allow_metadata_inventory_take = function(pos, listname, index, stack, player)
		local inv = minetest.get_inventory({type="node", pos=pos})
		inv:set_stack(listname, index, ItemStack(""))
		return 0
	end,
	
	-- "builder at pos, imagine that you're in test_pos. If you're willing and able to build from there, take the item you need from inventory.
	-- return the item you took and the inventory location you took it from so it can be put back after all the other builders have been tested.
	-- If you couldn't get the item from inventory, return an error code so we can abort the cycle.
	-- If you're not supposed to build at all, or the location is obstructed, return 0 to let us know you're okay and we shouldn't abort."
	
	--return code and accompanying value:
	-- 0, nil								-- not supposed to build, no error
	-- 1, {itemstack, source inventory pos} -- can build, took an item from inventory
	-- 2, itemstack 						-- was supposed to build, but couldn't get the item from inventory
	-- 3, nil								-- builder configuration error
	test_build = function(pos, test_pos, inventory_positions, protected_nodes, nodes_dug, controlling_coordinate, controller_pos)
		local meta = minetest.get_meta(pos)
		local facing = minetest.get_node(pos).param2
		local buildpos = digtron.find_new_pos(test_pos, facing)
		
		if (buildpos[controlling_coordinate] + meta:get_int("offset")) % meta:get_int("period") ~= 0 then
			--It's not the builder's turn to build right now.
			return 0, nil
		end
		
		if not digtron.can_move_to(buildpos, protected_nodes, nodes_dug) then
			--using "can_move_to" instead of "can_build_to" test case in case the builder is pointed "backward", and will thus
			--be building into the space that it's currently in and will be vacating after moving, or in case the builder is aimed
			--sideways and a fellow digtron node was ahead of it (will also be moving out of the way).
			
			--If the player has built his digtron stupid (eg has another digtron node in the place the builder wants to build) this
			--assumption is wrong, but I can't hold the player's hand through *every* possible bad design decision. Worst case,
			--the digtron will think its inventory can't handle the next build step and abort the build when it actually could have
			--managed one more cycle. That's not a bad outcome for a digtron array that was built stupidly to begin with.
			--The player should be thanking me for all the error-checking I *do* do, really.
			--Ungrateful wretch.
			return 0, nil
		end
		
		local inv = minetest.get_inventory({type="node", pos=pos})
		local item_stack = inv:get_stack("main", 1)
		if not item_stack:is_empty() then
			local source_location = digtron.take_from_inventory(item_stack:get_name(), inventory_positions)
			if source_location ~= nil then
				return 1, {item=item_stack, location=source_location}
			end
			return 2, item_stack -- error code for "needed an item but couldn't get it from inventory"
		else
			return 3, nil -- error code for "this builder's item slot is unset"
		end
	end,
	
	execute_build = function(pos, player, inventory_positions, protected_nodes, nodes_dug, controlling_coordinate, controller_pos)
		local meta = minetest.get_meta(pos)
		local build_facing = meta:get_int("build_facing")
		local facing = minetest.get_node(pos).param2
		local buildpos = digtron.find_new_pos(pos, facing)
		local oldnode = minetest.get_node(buildpos)
		
		if (buildpos[controlling_coordinate] + meta:get_int("offset")) % meta:get_int("period") ~= 0 then
			return nil
		end
		
		if digtron.can_build_to(buildpos, protected_nodes, nodes_dug) then
			local inv = minetest.get_inventory({type="node", pos=pos})
			local item_stack = inv:get_stack("main", 1)
			if not item_stack:is_empty() then
			
				if digtron.creative_mode then
					local returned_stack, success = digtron.item_place_node(item_stack, player, buildpos, tonumber(build_facing))
					if success == true then
						minetest.log("action", string.format(S("%s uses Digtron to build %s at (%d, %d, %d), displacing %s"), player:get_player_name(), item_stack:get_name(), buildpos.x, buildpos.y, buildpos.z, oldnode.name))
						nodes_dug:set(buildpos.x, buildpos.y, buildpos.z, false)
						return true
					end
					return nil
				end
			
				local sourcepos = digtron.take_from_inventory(item_stack:get_name(), inventory_positions)
				if sourcepos == nil then
					-- item not in inventory! Need to sound the angry buzzer to let the player know, so return false.
					return false
				end
				local returned_stack, success = digtron.item_place_node(item_stack, player, buildpos, tonumber(build_facing))
				if success == true then
					minetest.log("action", string.format(S("%s uses Digtron to build %s at (%d, %d, %d), displacing %s"), player:get_player_name(), item_stack:get_name(), buildpos.x, buildpos.y, buildpos.z, oldnode.name))
					--flag this node as *not* to be dug.
					nodes_dug:set(buildpos.x, buildpos.y, buildpos.z, false)
					digtron.award_item_built(item_stack:get_name(), player:get_player_name())
					return true
				else
					--failed to build, target node probably obstructed. Put the item back in inventory.
					digtron.place_in_specific_inventory(item_stack, sourcepos, inventory_positions, controller_pos)
					return nil
				end
			end
		end
	end,
})