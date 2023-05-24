-- unused_args = false
-- allow_defined_top = true
-- ignore = {"512"}

globals = {
	"digtron"
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
	"default"
}
