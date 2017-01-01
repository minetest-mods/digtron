-- Note: diggers go in group 3 and have an execute_dig method.

local digger_nodebox = {
	{-0.5, -0.5, 0, 0.5, 0.5, 0.4375}, -- Block
	{-0.4375, -0.3125, 0.4375, 0.4375, 0.3125, 0.5}, -- Cutter1
	{-0.3125, -0.4375, 0.4375, 0.3125, 0.4375, 0.5}, -- Cutter2
	{-0.5, -0.125, -0.125, 0.5, 0.125, 0}, -- BackFrame1
	{-0.125, -0.5, -0.125, 0.125, 0.5, 0}, -- BackFrame2
	{-0.25, -0.25, -0.5, 0.25, 0.25, 0}, -- Drive
}

-- Digs out nodes that are "in front" of the digger head.
minetest.register_node("digtron:digger", {
	description = "Digger Head",
	groups = {cracky = 3, stone = 1, digtron = 3},
	drop = 'digtron:digger',
	paramtype = "light",
	paramtype2= 'facedir',
	
	drawtype="nodebox",
	node_box = {
		type = "fixed",
		fixed = digger_nodebox,
	},
	
	-- Aims in the +Z direction by default
	tiles = {
		"digtron_plate.png^[transformR90",
		"digtron_plate.png^[transformR270",
		"digtron_plate.png",
		"digtron_plate.png^[transformR180",
		{
			name = "digtron_digger.png",
			animation = {
				type = "vertical_frames",
				aspect_w = 16,
				aspect_h = 16,
				length = 1.0,
			},
		},
		"digtron_motor.png",
	},
	
	on_construct = function(pos)
        local meta = minetest.env:get_meta(pos)
        meta:set_string("formspec",
			"size[3.5,1]" ..
			default.gui_bg ..
			default.gui_bg_img ..
			default.gui_slots ..
			"field[0.5,0.8;1,0.1;period;Periodicity;${period}]" ..
			"tooltip[period;Digger will dig once every n steps. These steps are globally aligned, all diggers with the same period and offset will dig on the same location.]" ..
			"field[1.5,0.8;1,0.1;offset;Offset;${offset}]" ..
			"tooltip[offset;Offsets the start of periodicity counting by this amount. For example, a digger with period 2 and offset 0 digs every even-numbered node and one with period 2 and offset 1 digs every odd-numbered node.]" ..
			"button_exit[2.2,0.5;1,0.1;set;Save]" ..
			"tooltip[set;Saves settings]"
		)
		meta:set_string("period", 1) 
		meta:set_string("offset", 0) 
				
		local inv = meta:get_inventory()
		inv:set_size("main", 1)
    end,
	
	on_receive_fields = function(pos, formname, fields, sender)
        local meta = minetest.get_meta(pos)
		local period = tonumber(fields.period)
		local offset = tonumber(fields.offset)
		if  period and period > 0 then
			meta:set_string("period", math.floor(tonumber(fields.period)))
		end
		if offset then
			meta:set_string("offset", math.floor(tonumber(fields.offset)))
		end
	end,

	execute_dig = function(pos, protected_nodes, nodes_dug, controlling_coordinate)
		local facing = minetest.get_node(pos).param2
		local digpos = digtron.find_new_pos(pos, facing)

		if protected_nodes:get(digpos.x, digpos.y, digpos.z) then
			return nil
		end
		
		local meta = minetest.get_meta(pos)
		if (digpos[controlling_coordinate] + meta:get_string("offset")) % meta:get_string("period") ~= 0 then
			return nil
		end
		
		return digtron.mark_diggable(digpos, nodes_dug)
	end,
})

-- A special-purpose digger to deal with stuff like sand and gravel in the ceiling. It always digs (no periodicity or offset), but it only digs falling_block nodes
minetest.register_node("digtron:soft_digger", {
	description = "Soft Material Digger Head",
	groups = {cracky = 3, stone = 1, digtron = 3},
	drop = 'digtron:soft_digger',
	paramtype = "light",
	paramtype2= 'facedir',
	
	drawtype="nodebox",
	node_box = {
		type = "fixed",
		fixed = digger_nodebox,
	},
	
	-- Aims in the +Z direction by default
	tiles = {
		"digtron_plate.png^[transformR90^[colorize:#88880030",
		"digtron_plate.png^[transformR270^[colorize:#88880030",
		"digtron_plate.png^[colorize:#88880030",
		"digtron_plate.png^[transformR180^[colorize:#88880030",
		{
			name = "digtron_digger.png^[colorize:#88880030",
			animation = {
				type = "vertical_frames",
				aspect_w = 16,
				aspect_h = 16,
				length = 1.0,
			},
		},
		"digtron_motor.png^[colorize:#88880030",
	},
	
	can_dig = function(pos,player)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		return inv:is_empty("main") and inv:is_empty("inv")
	end,
	
	execute_dig = function(pos, protected_nodes, nodes_dug, controlling_coordinate)
		local facing = minetest.get_node(pos).param2
		local digpos = digtron.find_new_pos(pos, facing)
		
		if protected_nodes:get(digpos.x, digpos.y, digpos.z) then
			return nil
		end
		
		local target_node = minetest.get_node(digpos)
		if  minetest.get_item_group(target_node.name, "crumbly") ~= 0 or
			minetest.get_item_group(target_node.name, "choppy") ~= 0 or
			minetest.get_item_group(target_node.name, "snappy") ~= 0 or
			minetest.get_item_group(target_node.name, "oddly_breakable_by_hand") ~= 0 or
			minetest.get_item_group(target_node.name, "fleshy") ~= 0 then
			return digtron.mark_diggable(digpos, nodes_dug)
		end
		
		return nil
	end,
})