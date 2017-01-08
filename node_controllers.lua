local controller_nodebox ={
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
}

-- Master controller. Most complicated part of the whole system. Determines which direction a digtron moves and triggers all of its component parts.
minetest.register_node("digtron:controller", {
	description = "Digtron Control Unit",
	groups = {cracky = 3, oddly_breakable_by_hand = 3, digtron = 1},
	drop = "digtron:controller",
	sounds = digtron.metal_sounds,
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
		"digtron_control.png",
	},
	
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = controller_nodebox,
	},
	
	on_construct = function(pos)
        local meta = minetest.get_meta(pos)
		meta:set_float("fuel_burning", 0.0)
		meta:set_string("infotext", "Heat remaining in controller furnace: 0")
	end,
	
	on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
		local meta = minetest.get_meta(pos)
		if meta:get_string("waiting") == "true" then
			-- Been too soon since last time the digtron did a cycle.
			return
		end
	
		local newpos, status, return_code = digtron.execute_cycle(pos, clicker)
		
		meta = minetest.get_meta(newpos)
		if status ~= nil then
			meta:set_string("infotext", status)
		end
		
		-- Start the delay before digtron can run again.
		minetest.get_meta(newpos):set_string("waiting", "true")
		minetest.after(digtron.cycle_time,
				function (pos)
					minetest.get_meta(pos):set_string("waiting", nil)
				end, newpos
			)
	end,
})

-- Auto-controller
---------------------------------------------------------------------------------------------------------------

local auto_formspec = "size[4.5,1]" ..
	default.gui_bg ..
	default.gui_bg_img ..
	default.gui_slots ..
	"field[0.5,0.8;1,0.1;offset;Cycles;${offset}]" ..
	"tooltip[offset;When triggered, this controller will try to run for the given number of cycles. The cycle count will decrement as it runs, so if it gets halted by a problem you can fix the problem and restart.]" ..
	"field[1.5,0.8;1,0.1;period;Period;${period}]" ..
	"tooltip[period;Number of seconds to wait between each cycle]" ..
	"button_exit[2.2,0.5;1,0.1;set;Set]" ..
	"tooltip[set;Saves the cycle setting without starting the controller running]" ..
	"button_exit[3.2,0.5;1,0.1;execute;Set &\nExecute]" ..
	"tooltip[execute;Begins executing the given number of cycles]"

-- Needed to make this global so that it could recurse into minetest.after
digtron.auto_cycle = function(pos)
	local meta = minetest.get_meta(pos)
	local player = minetest.get_player_by_name(meta:get_string("triggering_player"))
	if player == nil or meta:get_string("waiting") == "true" then
		return
	end
	
	local newpos, status, return_code = digtron.execute_cycle(pos, player)
	
	local cycle = 0
	if vector.equals(pos, newpos) then
		cycle = meta:get_int("offset")
		status = status .. string.format("\nCycles remaining: %d\nHalted!", cycle)
		meta:set_string("infotext", status)
		if return_code == 1 then --return code 1 happens when there's unloaded nodes adjacent, just keep trying.
			minetest.after(meta:get_int("period"), digtron.auto_cycle, newpos)
		else
			meta:set_string("formspec", auto_formspec)
		end
		return
	end
	
	meta = minetest.get_meta(newpos)
	cycle = meta:get_int("offset") - 1
	meta:set_int("offset", cycle)
	status = status .. string.format("\nCycles remaining: %d", cycle)
	meta:set_string("infotext", status)
	
	if cycle > 0 then
		minetest.after(meta:get_int("period"), digtron.auto_cycle, newpos)
	else
		meta:set_string("formspec", auto_formspec)
	end
end

minetest.register_node("digtron:auto_controller", {
	description = "Digtron Automatic Control Unit",
	groups = {cracky = 3, oddly_breakable_by_hand = 3, digtron = 1},
	drop = "digtron:auto_controller",
	sounds = digtron.metal_sounds,
	paramtype = "light",
	paramtype2= "facedir",
	is_ground_content = false,
	-- Aims in the +Z direction by default
	tiles = {
		"digtron_plate.png^[transformR90^[colorize:#88000030",
		"digtron_plate.png^[transformR270^[colorize:#88000030",
		"digtron_plate.png^[colorize:#88000030",
		"digtron_plate.png^[transformR180^[colorize:#88000030",
		"digtron_plate.png^[colorize:#88000030",
		"digtron_control.png^[colorize:#88000030",
	},
	
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = controller_nodebox,
	},
	
	on_construct = function(pos)
        local meta = minetest.get_meta(pos)
		meta:set_float("fuel_burning", 0.0)
		meta:set_string("infotext", "Heat remaining in controller furnace: 0")
		meta:set_string("formspec", auto_formspec)
		-- Reusing offset and period to keep the digtron node-moving code simple, and the names still fit well
		meta:set_int("period", digtron.cycle_time)
		meta:set_int("offset", 0)
	end,

	on_receive_fields = function(pos, formname, fields, sender)
        local meta = minetest.get_meta(pos)
		local offset = tonumber(fields.offset)
		local period = tonumber(fields.period)
		
		if period and period > 0 then
			meta:set_int("period", math.max(digtron.cycle_time, math.floor(period)))
		end
		
		if offset and offset >= 0 then
			meta:set_int("offset", math.floor(offset))
			if sender:is_player() and offset > 0 then
				meta:set_string("triggering_player", sender:get_player_name())
				if fields.execute then
					meta:set_string("waiting", nil)
					meta:set_string("formspec", nil)
					digtron.auto_cycle(pos)			
				end
			end
		end
	end,	
	
	on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", meta:get_string("infotext") .. "\nInterrupted!")
		meta:set_string("waiting", "true")
		meta:set_string("formspec", auto_formspec)
	end,
})

---------------------------------------------------------------------------------------------------------------

-- A much simplified control unit that only moves the digtron, and doesn't trigger the diggers or builders.
-- Handy for shoving a digtron to the side if it's been built a bit off.
minetest.register_node("digtron:pusher", {
	description = "Digtron Pusher Unit",
	groups = {cracky = 3, oddly_breakable_by_hand=3, digtron = 1},
	drop = "digtron:pusher",
	sounds = digtron.metal_sounds,
	paramtype = "light",
	paramtype2= "facedir",
	is_ground_content = false,
	-- Aims in the +Z direction by default
	tiles = {
		"digtron_plate.png^[transformR90^[colorize:#00880030",
		"digtron_plate.png^[transformR270^[colorize:#00880030",
		"digtron_plate.png^[colorize:#00880030",
		"digtron_plate.png^[transformR180^[colorize:#00880030",
		"digtron_plate.png^[colorize:#00880030",
		"digtron_control.png^[colorize:#00880030",
	},
	
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = controller_nodebox,
	},
	
	on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)	
		local meta = minetest.get_meta(pos)
		if meta:get_string("waiting") == "true" then
			-- Been too soon since last time the digtron did a cycle.
			return
		end

		local layout = digtron.get_all_digtron_neighbours(pos, clicker)
		if layout.all == nil then
			-- get_all_digtron_neighbours returns nil if the digtron array touches unloaded nodes, too dangerous to do anything in that situation. Abort.
			minetest.sound_play("buzzer", {gain=0.5, pos=pos})
			meta:set_string("infotext", "Digtron is adjacent to unloaded nodes.")
			return
		end
		
		if layout.traction * digtron.traction_factor < table.getn(layout.all) then
			-- digtrons can't fly
			minetest.sound_play("squeal", {gain=1.0, pos=pos})
			meta:set_string("infotext", string.format("Digtron has %d nodes but only enough traction to move %d nodes.", table.getn(layout.all), layout.traction * digtron.traction_factor))
			return
		end

		local facing = minetest.get_node(pos).param2
		local controlling_coordinate = digtron.get_controlling_coordinate(pos, facing)
		
		local nodes_dug = Pointset.create() -- empty set, we're not digging anything

		-- test if any digtrons are obstructed by non-digtron nodes that haven't been marked
		-- as having been dug.
		local can_move = true
		for _, location in pairs(layout.all) do
			local newpos = digtron.find_new_pos(location, facing)
			if not digtron.can_move_to(newpos, layout.protected, nodes_dug) then
				can_move = false
			end
		end
		
		if not can_move then
			-- mark this node as waiting, will clear this flag in digtron.cycle_time seconds
			meta:set_string("waiting", "true")
			minetest.after(digtron.cycle_time,
				function (pos)
					minetest.get_meta(pos):set_string("waiting", nil)
				end, pos
			)
			minetest.sound_play("squeal", {gain=1.0, pos=pos})
			minetest.sound_play("buzzer", {gain=0.5, pos=pos})
			meta:set_string("infotext", "Digtron is obstructed.")
			return --Abort
		end

		meta:set_string("infotext", nil)
		minetest.sound_play("truck", {gain=1.0, pos=pos})
	
		-- if the player is standing within the array or next to it, move him too.
		local player_pos = clicker:getpos()
		local move_player = false
		if player_pos.x >= layout.extents.min_x - 1 and player_pos.x <= layout.extents.max_x + 1 and
		   player_pos.y >= layout.extents.min_y - 1 and player_pos.y <= layout.extents.max_y + 1 and
		   player_pos.z >= layout.extents.min_z - 1 and player_pos.z <= layout.extents.max_z + 1 then
			move_player = true
		end
			
		--move the array
		digtron.move_digtron(facing, layout.all, layout.extents, nodes_dug)
		local oldpos = {x=pos.x, y=pos.y, z=pos.z}
		pos = digtron.find_new_pos(pos, facing)
		if move_player then
			clicker:moveto(digtron.find_new_pos(player_pos, facing), true)
		end
		
		-- Start the delay before digtron can run again. Do this after moving the array or pos will be wrong.
		minetest.get_meta(pos):set_string("waiting", "true")
		minetest.after(digtron.cycle_time,
			function (pos)
				minetest.get_meta(pos):set_string("waiting", nil)
			end, pos
		)
	end,
})