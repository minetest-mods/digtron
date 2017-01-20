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
	_doc_items_longdesc = digtron.doc.controller_longdesc,
    _doc_items_usagehelp = digtron.doc.controller_usagehelp,
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
		"digtron_plate.png^digtron_control.png",
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
	
		local newpos, status, return_code = digtron.execute_dig_cycle(pos, clicker)
		
		meta = minetest.get_meta(newpos)
		if status ~= nil then
			meta:set_string("infotext", status)
		end
		
		-- Start the delay before digtron can run again.
		minetest.get_meta(newpos):set_string("waiting", "true")
		minetest.get_node_timer(newpos):start(digtron.cycle_time)
	end,
	
	on_timer = function(pos, elapsed)
		minetest.get_meta(pos):set_string("waiting", nil)
	end,
})

-- Auto-controller
---------------------------------------------------------------------------------------------------------------

local auto_formspec = "size[3.5,2]" ..
	default.gui_bg ..
	default.gui_bg_img ..
	default.gui_slots ..
	"field[0.5,0.8;1,0.1;cycles;Cycles;${cycles}]" ..
	"tooltip[cycles;When triggered, this controller will try to run for the given number of cycles. The cycle count will decrement as it runs, so if it gets halted by a problem you can fix the problem and restart.]" ..
	"button_exit[1.2,0.5;1,0.1;set;Set]" ..
	"tooltip[set;Saves the cycle setting without starting the controller running]" ..
	"button_exit[2.2,0.5;1,0.1;execute;Set &\nExecute]" ..
	"tooltip[execute;Begins executing the given number of cycles]" ..
	"field[0.5,2.0;1,0.1;slope;Slope;${slope}]" ..
	"tooltip[slope;For diagonal digging. After every X blocks the auto controller moves forward, the controller will add an additional cycle moving the digtron laterally in the direction of the arrows on the side of this controller. Set to 0 for no lateral digging.]" ..
	"field[1.5,2.0;1,0.1;offset;Offset;${offset}]" ..
	"tooltip[offset;Sets the offset of the lateral motion defined in the Slope field. Note: this offset is relative to the controller's location. The controller will move down when it reaches the indicated point.]" ..
	"field[2.5,2.0;1,0.1;period;Delay;${period}]" ..
	"tooltip[period;Number of seconds to wait between each cycle]"
	
-- Needed to make this global so that it could recurse into minetest.after
digtron.auto_cycle = function(pos)
	local node = minetest.get_node(pos)
	local controlling_coordinate = digtron.get_controlling_coordinate(pos, node.param2)
	local meta = minetest.get_meta(pos)
	local player = minetest.get_player_by_name(meta:get_string("triggering_player"))
	if player == nil or meta:get_string("waiting") == "true" then
		return
	end

	local cycle = meta:get_int("cycles")
	local slope = meta:get_int("slope")
	
	if meta:get_string("lateral_done") ~= "true" and slope ~= 0 and (pos[controlling_coordinate] + meta:get_int("offset")) % slope == 0 then
		--Do a downward dig cycle. Don't update the "cycles" count, these don't count towards that.
		local newpos, status, return_code = digtron.execute_downward_dig_cycle(pos, player)
		
		if vector.equals(pos, newpos) then
			status = status .. string.format("\nCycles remaining: %d\nHalted!", cycle)
			meta:set_string("infotext", status)
			if return_code == 1 then --return code 1 happens when there's unloaded nodes adjacent, just keep trying.
				minetest.after(meta:get_int("period"), digtron.auto_cycle, newpos)
			else
				meta:set_string("formspec", auto_formspec)
			end
		else
			meta = minetest.get_meta(newpos)
			minetest.after(meta:get_int("period"), digtron.auto_cycle, newpos)
			meta:set_string("infotext", status)
			meta:set_string("lateral_done", "true")
		end
		return
	end
	
	local newpos, status, return_code = digtron.execute_dig_cycle(pos, player)
	
	if vector.equals(pos, newpos) then
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
	cycle = meta:get_int("cycles") - 1
	meta:set_int("cycles", cycle)
	status = status .. string.format("\nCycles remaining: %d", cycle)
	meta:set_string("infotext", status)
	meta:set_string("lateral_done", nil)
	
	if cycle > 0 then
		minetest.after(meta:get_int("period"), digtron.auto_cycle, newpos)
	else
		meta:set_string("formspec", auto_formspec)
	end
end

minetest.register_node("digtron:auto_controller", {
	description = "Digtron Automatic Control Unit",
	_doc_items_longdesc = digtron.doc.auto_controller_longdesc,
    _doc_items_usagehelp = digtron.doc.auto_controller_usagehelp,
	groups = {cracky = 3, oddly_breakable_by_hand = 3, digtron = 1},
	drop = "digtron:auto_controller",
	sounds = digtron.metal_sounds,
	paramtype = "light",
	paramtype2= "facedir",
	is_ground_content = false,
	-- Aims in the +Z direction by default
	tiles = {
		"digtron_plate.png^[transformR90^digtron_auto_control_tint.png",
		"digtron_plate.png^[transformR270^digtron_auto_control_tint.png",
		"digtron_plate.png^digtron_axel_side.png^[transformR270^digtron_auto_control_tint.png",
		"digtron_plate.png^digtron_axel_side.png^[transformR270^digtron_auto_control_tint.png",
		"digtron_plate.png^digtron_auto_control_tint.png",
		"digtron_plate.png^digtron_control.png^digtron_auto_control_tint.png",
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
		meta:set_int("cycles", 0)
		meta:set_int("slope", 0)
	end,

	on_receive_fields = function(pos, formname, fields, sender)
        local meta = minetest.get_meta(pos)
		local offset = tonumber(fields.offset)
		local period = tonumber(fields.period)
		local slope = tonumber(fields.slope)
		local cycles = tonumber(fields.cycles)
		
		if period and period > 0 then
			meta:set_int("period", math.max(digtron.cycle_time, math.floor(period)))
		end

		if offset then
			meta:set_int("offset", offset)
		end
		
		if slope and slope >= 0 then
			meta:set_int("slope", slope)
		end
		
		if cycles and cycles >= 0 then
			meta:set_int("cycles", math.floor(cycles))
			if sender:is_player() and cycles > 0 then
				meta:set_string("triggering_player", sender:get_player_name())
				if fields.execute then
					meta:set_string("waiting", nil)
					meta:set_string("formspec", nil)
					digtron.auto_cycle(pos)
				end
			end
		end

		if fields.set and slope and slope > 0 then
			local node = minetest.get_node(pos)
			local controlling_coordinate = digtron.get_controlling_coordinate(pos, node.param2)
			
			local newpos = pos --digtron.find_new_pos(pos, minetest.get_node(pos).param2)
			local markerpos = {x=newpos.x, y=newpos.y, z=newpos.z}
			local x_pos = math.floor((newpos[controlling_coordinate]+offset)/slope)*slope - offset
			markerpos[controlling_coordinate] = x_pos
			minetest.add_entity(markerpos, "digtron:marker_vertical")
			if x_pos >= newpos[controlling_coordinate] then
				markerpos[controlling_coordinate] = x_pos - slope
				minetest.add_entity(markerpos, "digtron:marker_vertical")
			end
			if x_pos <= newpos[controlling_coordinate] then
				markerpos[controlling_coordinate] = x_pos + slope
				minetest.add_entity(markerpos, "digtron:marker_vertical")
			end
		end		
	end,	
	
	on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", meta:get_string("infotext") .. "\nInterrupted!")
		meta:set_string("waiting", "true")
		meta:set_string("formspec", auto_formspec)
	end,
	
	on_timer = function(pos, elapsed)
		minetest.get_meta(pos):set_string("waiting", nil)
	end,

})

---------------------------------------------------------------------------------------------------------------

-- A much simplified control unit that only moves the digtron, and doesn't trigger the diggers or builders.
-- Handy for shoving a digtron to the side if it's been built a bit off.
minetest.register_node("digtron:pusher", {
	description = "Digtron Pusher Unit",
	_doc_items_longdesc = digtron.doc.pusher_longdesc,
    _doc_items_usagehelp = digtron.doc.pusher_usagehelp,
	groups = {cracky = 3, oddly_breakable_by_hand=3, digtron = 1},
	drop = "digtron:pusher",
	sounds = digtron.metal_sounds,
	paramtype = "light",
	paramtype2= "facedir",
	is_ground_content = false,
	-- Aims in the +Z direction by default
	tiles = {
		"digtron_plate.png^[transformR90^digtron_pusher_tint.png",
		"digtron_plate.png^[transformR270^digtron_pusher_tint.png",
		"digtron_plate.png^digtron_pusher_tint.png",
		"digtron_plate.png^[transformR180^digtron_pusher_tint.png",
		"digtron_plate.png^digtron_pusher_tint.png",
		"digtron_plate.png^digtron_control.png^digtron_pusher_tint.png",
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

		local newpos, status_text, return_code = digtron.execute_move_cycle(pos, clicker)
		meta = minetest.get_meta(newpos)
		meta:set_string("infotext", status_text)
		
		-- Start the delay before digtron can run again.
		minetest.get_meta(newpos):set_string("waiting", "true")
		minetest.get_node_timer(newpos):start(digtron.cycle_time)
	end,
	
	on_timer = function(pos, elapsed)
		minetest.get_meta(pos):set_string("waiting", nil)
	end,

})