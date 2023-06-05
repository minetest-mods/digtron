max_line_length = 200

globals = {
	"digtron",
	"catacomb"
}

read_globals = {
	-- Stdlib
	string = {fields = {"split"}},
	table = {fields = {"copy", "getn"}},
	"VoxelManip",

	-- Minetest
	"minetest",
	"vector", "ItemStack",
	"dump", "VoxelArea",

	-- Deps
	"default", "awards", "pipeworks", "hopper", "technic", "doc", "intllib"
}

files = {
	["doc.lua"] = {
		max_line_length = 1000
	}
}