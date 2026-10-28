-- Tests, run with the mtt mod (https://github.com/BuckarooBanzay/mtt)

local pos1 = vector.new(-50, -10, -50)
local pos2 = vector.new(50, 50, 50)

mtt.emerge_area(pos1, pos2)

-- minimal player stand-in, the layout code only needs name and position
local function fake_player(pos)
	return {
		get_player_name = function() return "digtron_mtt" end,
		get_pos = function() return vector.copy(pos) end,
		set_pos = function() end,
	}
end

mtt.register("pointset", function(callback)
	local set = digtron.Pointset.create()
	assert(set:get(1, 2, 3) == nil)

	set:set(1, 2, 3, "a")
	set:set(-1, -2, -3, "b")
	assert(set:get(1, 2, 3) == "a")
	assert(set:get(-1, -2, -3) == "b")
	assert(set:get(3, 2, 1) == nil)

	set:clear()
	assert(set:get(1, 2, 3) == nil)

	callback()
end)

mtt.register("registered nodes", function(callback)
	for _, name in ipairs({
		"digtron:controller",
		"digtron:pusher",
		"digtron:auto_controller",
		"digtron:digger",
		"digtron:builder",
		"digtron:structure",
		"digtron:inventory",
		"digtron:fuelstore",
	}) do
		assert(core.registered_nodes[name], "node not registered: " .. name)
	end

	callback()
end)

mtt.register("layout detection", function(callback)
	local base = vector.new(0, 20, 0)
	core.get_voxel_manip(vector.subtract(base, 5), vector.add(base, 5))
	core.set_node(base, { name = "digtron:controller", param2 = 0 })
	core.set_node(vector.add(base, vector.new(1, 0, 0)), { name = "digtron:structure" })
	core.set_node(vector.add(base, vector.new(1, 1, 0)), { name = "digtron:structure" })
	-- not connected to the controller
	core.set_node(vector.add(base, vector.new(4, 0, 0)), { name = "digtron:structure" })

	local layout = digtron.DigtronLayout.create(base, fake_player(base))
	assert(#layout.all == 3, "expected 3 digtron nodes, got " .. #layout.all)
	assert(vector.equals(layout.extents_min, base))
	assert(vector.equals(layout.extents_max, vector.add(base, vector.new(1, 1, 0))))

	callback()
end)

mtt.register("pusher move cycle", function(callback)
	local base = vector.new(20, 20, 20)
	core.get_voxel_manip(vector.subtract(base, 5), vector.add(base, 5))
	for x = -3, 3 do
		for y = -3, 3 do
			for z = -3, 3 do
				core.set_node(vector.add(base, vector.new(x, y, z)), { name = "air" })
			end
		end
	end

	-- facedir 0 faces +Z
	core.set_node(base, { name = "digtron:pusher", param2 = 0 })
	core.set_node(vector.add(base, vector.new(1, 0, 0)), { name = "digtron:structure" })

	local newpos, _, code = digtron.execute_move_cycle(base, fake_player(vector.new(0, 100, 0)))
	assert(code == 0, "move cycle failed with code " .. tostring(code))
	assert(vector.equals(newpos, vector.add(base, vector.new(0, 0, 1))), "unexpected new position")

	assert(core.get_node(base).name == "air", "old controller not removed")
	assert(core.get_node(newpos).name == "digtron:pusher", "controller not moved")
	assert(core.get_node(vector.add(newpos, vector.new(1, 0, 0))).name == "digtron:structure", "structure not moved")
	assert(core.get_node(vector.add(base, vector.new(1, 0, 0))).name == "air", "old structure not removed")

	callback()
end)
