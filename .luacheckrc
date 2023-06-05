max_line_length = 180

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
	"default", "awards", "pipeworks", "hopper", "technic"
}

files = {
	["doc.lua"] = {
		max_line_length = 1000
	}
}