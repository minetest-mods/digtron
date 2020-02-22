local S = digtron.S

local get_manifest = function(pos)
	local manifest = {}
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	local template = inv:get_stack("template", 1)
	local stack_meta = template:get_meta()
	local digtron_id = stack_meta:get_string("digtron_id")
	if digtron_id ~= "" then
		local layout = digtron.get_layout(digtron_id)
		for hash, data in pairs(layout) do
			local item = data.node.name
			local item_def = minetest.registered_items[item]
			if item_def._digtron_disassembled_node then
				item = item_def._digtron_disassembled_node
				item_def = minetest.registered_items[item]
			end
			local desc = item_def.description
			local entry = manifest[desc]
			if entry == nil then
				entry = {item = item}
				manifest[desc] = entry
			elseif entry.item ~= item then
				minetest.log("error", "[Digtron] Duplicator found two digtron nodes that are defined with the same description: "
					.. item .. " and " .. entry.item .. ". File an issue with Digtron's maintainers.")
			end
			entry.requires = (entry.requires or 0) + 1
		end
	end

	local main_list = inv:get_list("main")
	for _, itemstack in ipairs(main_list) do
		if not itemstack:is_empty() then
			local desc = itemstack:get_definition().description
			local entry = manifest[desc]
			if entry == nil then
				entry = {item = item}
				manifest[desc] = entry
			end
			entry.contains = (entry.contains or 0) + itemstack:get_count()
		end
	end
	
	local ok = false
	if digtron_id ~= "" then
		ok = true
		for item, entry in pairs(manifest) do
			if entry.requires and (entry.contains == nil or entry.contains < entry.requires) then
				ok = false
				break
			end
		end
	end
	
	return manifest, ok, digtron_id
end

local cache = {}

local get_formspec = function(pos)
	local hash = minetest.hash_node_position(pos)
	local cache_val = cache[hash]
	if cache_val == nil then
		cache_val = {}
		cache_val.manifest, cache_val.ok = get_manifest(pos)
		cache[hash] = cache_val
	end
	local manifest = cache_val.manifest
	local ok = cache_val.ok
	
	-- Build item table
	local manifest_formspec_head = "tablecolumns[color;text,tooltip=" .. S("Digtron component.")
		..";text,align=center,tooltip=" .. S("Amount of this component required to copy the template Digtron.")
		..";text,align=center,tooltip=" .. S("Amount of this component currently available.")
		.."]table[0,0;2.9,3;manifest;#FFFFFF,Item,Required,Available"
	local manifest_formspec_body = {}
	for desc, entry in pairs(manifest) do
		local color = "#FFFFFF"
		if entry.requires then
			if entry.contains == nil or entry.contains < entry.requires then
				color = "#FF0000"
			else
				color = "#00FF00"
			end
		end
		manifest_formspec_body[#manifest_formspec_body + 1] =
			","..color..","..desc..","..(entry.requires or "-")..","..(entry.contains or "-")
	end
	table.sort(manifest_formspec_body)
	local manifest_formspec_tail = ";]"
	local manifest_formspec = manifest_formspec_head .. table.concat(manifest_formspec_body) .. manifest_formspec_tail
	
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()

	-- Duplicate button
	local duplicate_button
	if ok and inv:is_empty("copy") then
		duplicate_button = "button[1,0;1,1;duplicate;"..S("Duplicate").."]tooltip[duplicate;"
			.. S("Puts a copy of the template Digtron into the output inventory slot.") .. "]"
	else
		duplicate_button = "button[1,0;1,1;no_duplicate;X]tooltip[no_duplicate;"
			.. S("Duplication cannot proceed at this time.") .. "]"
	end

	return "size[8,9.3]"
	
	.. "container[5,1.5]"
	.. manifest_formspec
	.. "container_end[]"
	
	.."label[0,0;" .. S("Digtron components") .. "]"
	.."list[current_name;main;0,0.6;5,4;]"
	.."tooltip[0,0;5,4.6;".. S("Digtron components in this inventory will be used to create the duplicate.") .."]"
	.."container[5,0]"
	.."list[current_name;template;0,0;1,1;]"
	.."tooltip[0,0;1,1.25;".. S("Place the Digtron you want to make a copy of here.") .."]"
	.."label[0.1,0.8;" .. S("Template") .. "]"
	..duplicate_button
	.."list[current_name;copy;2,0;1,1;]"
	.."tooltip[2,0;1,1.25;".. S("The duplicate Digtron is output here.") .."]"
	.."label[2.25,0.8;" .. S("Copy") .. "]"
	.."container_end[]"
	.."list[current_player;main;0,5.15;8,1;]"
	.."list[current_player;main;0,6.38;8,3;8]"
	.."listring[current_name;main]"
	.."listring[current_player;main]"
	..default.get_hotbar_bg(0,5.15)
end
	
minetest.register_node("digtron:duplicator", {
	description = S("Digtron Duplicator"),
	_doc_items_longdesc = digtron.doc.duplicator_longdesc,
    _doc_items_usagehelp = digtron.doc.duplicator_usagehelp,
	groups = {cracky = 3,  oddly_breakable_by_hand=3},
	sounds = digtron.metal_sounds,
	tiles = {"digtron_plate.png^(digtron_axel_side.png^[transformR90)",
		"digtron_plate.png^(digtron_axel_side.png^[transformR270)",
		"digtron_plate.png^digtron_axel_side.png",
		"digtron_plate.png^(digtron_axel_side.png^[transformR180)",
		"digtron_plate.png^digtron_builder.png",
		"digtron_plate.png",
	},
	paramtype = "light",
	paramtype2= "facedir",
	is_ground_content = false,	
	drawtype="nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			{-0.5, 0.3125, 0.3125, 0.5, 0.5, 0.5}, -- FrontFrame_top
			{-0.5, -0.5, 0.3125, 0.5, -0.3125, 0.5}, -- FrontFrame_bottom
			{0.3125, -0.3125, 0.3125, 0.5, 0.3125, 0.5}, -- FrontFrame_right
			{-0.5, -0.3125, 0.3125, -0.3125, 0.3125, 0.5}, -- FrontFrame_left
			{-0.0625, -0.3125, 0.3125, 0.0625, 0.3125, 0.375}, -- frontcross_vertical
			{-0.3125, -0.0625, 0.3125, 0.3125, 0.0625, 0.375}, -- frontcross_horizontal
			{-0.4375, -0.4375, -0.4375, 0.4375, 0.4375, 0.3125}, -- Body
			{-0.5, -0.3125, -0.5, -0.3125, 0.3125, -0.3125}, -- backframe_vertical
			{0.3125, -0.3125, -0.5, 0.5, 0.3125, -0.3125}, -- backframe_left
			{-0.5, 0.3125, -0.5, 0.5, 0.5, -0.3125}, -- backframe_top
			{-0.5, -0.5, -0.5, 0.5, -0.3125, -0.3125}, -- backframe_bottom
			{-0.0625, -0.0625, -0.5625, 0.0625, 0.0625, -0.4375}, -- back_probe
		},
	},
	selection_box = {
	    type = "regular"
	},
	
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("formspec", get_formspec(pos))
		local inv = meta:get_inventory()
		inv:set_size("main", 5*4)
		inv:set_size("template", 1)
		inv:set_size("copy", 1)
	end,
	
	on_destruct = function(pos)
		cache[minetest.hash_node_position(pos)] = nil
	end,
	
	can_dig = function(pos,player)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		return inv:is_empty("main") and inv:is_empty("template") and inv:is_empty("copy")
	end,
	
	allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		local stack_name = stack:get_name()
		if listname == "main" and (minetest.get_item_group(stack_name, "digtron") > 0 or stack_name == "digtron:controller_unassembled") then
			return stack:get_count()
		elseif listname == "template" and stack:get_name() == "digtron:controller" then
			return stack:get_count()
		end
		return 0
	end,
	
	allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
		if from_list == to_list then
			return count
		end
		return 0
	end,
	
	allow_metadata_inventory_take = function(pos, listname, index, stack, player)
		return stack:get_count()
	end,
	
	on_metadata_inventory_put = function(pos, listname, index, stack, player)
		local meta = minetest.get_meta(pos)
		cache[minetest.hash_node_position(pos)] = nil
		meta:set_string("formspec", get_formspec(pos))
	end,
	on_metadata_inventory_take = function(pos, listname, index, stack, player)
		local meta = minetest.get_meta(pos)
		cache[minetest.hash_node_position(pos)] = nil
		meta:set_string("formspec", get_formspec(pos))
	end,
	
	on_receive_fields = function(pos, formname, fields, sender)
		if fields.help then
			minetest.after(0.5, doc.show_entry, sender:get_player_name(), "nodes", "digtron:duplicator", true)
		end
		
		if fields.no_duplicate then			
			minetest.sound_play("digtron_error", {gain=0.5, to_player=sender:get_player_name()}) -- Insufficient inventory
		end
	
		if fields.duplicate then
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			
			if not inv:is_empty("copy") then
				minetest.log("error", "[Digtron] duplicator was sent a 'duplicate' command by " .. player_name
					.. "but there was an item in the output inventory already. This should be impossible.")
				minetest.sound_play("digtron_error", {gain=0.5, to_player=sender:get_player_name()})
				return
			end
		
			local manifest, ok, digtron_id = get_manifest(pos) -- don't trust formspec fields, that's hackable. Recalculate manifest.
			if not ok then
				local player_name = sender:get_player_name()
				minetest.log("error", "[Digtron] duplicator was sent a 'duplicate' command by " .. player_name
					.. "but get_manifest reported insufficent inputs. This should be impossible.")
				minetest.sound_play("digtron_error", {gain=0.5, to_player=player_name})
				return
			end
			
			-- deduct nodes from duplicator inventory
			for desc, entry in pairs(manifest) do
				if entry.requires then
					local count = entry.requires
					while count > 0 do
						-- We need to do this loop because we may be wanting to remove more items than
						-- a single stack of that item can hold.
						-- https://github.com/minetest/minetest/issues/8883
						local stack_to_remove = ItemStack({name=entry.item, count=count})
						stack_to_remove:set_count(math.min(count, stack_to_remove:get_stack_max()))
						local removed = inv:remove_item("main", stack_to_remove)
						count = count - removed:get_count()
					end
				end
			end
			
			local new_digtron = digtron.duplicate(digtron_id)
			inv:set_stack("copy", 1, new_digtron)
			
			minetest.sound_play("digtron_machine_assemble", {gain=1.0, pos=pos})
		end
	end,

})
