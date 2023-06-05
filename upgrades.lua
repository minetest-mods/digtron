-- re-applies the "_digtron_formspec" property from all digtron node defs to the digtron node's metadata.
minetest.register_lbm({
	name = "digtron:generic_formspec_sanitizer",
	nodenames = {"group:digtron"},
	action = function(pos, node)
		local node_def = minetest.registered_nodes[node.name]
		if node_def._digtron_formspec then
			local meta = minetest.get_meta(pos)
			meta:set_string("formspec", node_def._digtron_formspec(pos, meta))
		end
	end
})

minetest.register_lbm({
	name = "digtron:sand_digger_upgrade",
	nodenames = {"digtron:sand_digger"},
	action = function(pos, node)
		local meta = minetest.get_meta(pos)
		local offset = meta:get_string("offset")
		local period = meta:get_string("period")
		minetest.set_node(pos, {name = "digtron:soft_digger",
			param2 = node.param2})
		meta:set_string("offset", offset)
		meta:set_string("period", period)
	end
})

minetest.register_lbm({
	name = "digtron:fuelstore_upgrade",
	nodenames = {"digtron:fuelstore"},
	action = function(pos)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		local list = inv:get_list("main")
		inv:set_list("main", {})
		inv:set_list("fuel", list)
	end
})

minetest.register_lbm({
	name = "digtron:autocontroller_lateral_upgrade",
	nodenames = {"digtron:auto_controller"},
	action = function(pos)
		local meta = minetest.get_meta(pos)
		local cycles = meta:get_int("offset")
		meta:set_int("cycles", cycles)
		meta:set_int("offset", 0)
		meta:set_int("slope", 0)
	end
})

minetest.register_lbm({
	name = "digtron:builder_extrusion_upgrade",
	nodenames = {"digtron:builder"},
	action = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_int("extrusion", 1)
	end
})