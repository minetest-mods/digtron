local CONFIG_FILE_PREFIX = "digtron_"

digtron.config = {}

local print_settingtypes = false

local function setting(stype, name, default, description)
	local value
	if stype == "bool" then
		value = minetest.settings:get_bool(CONFIG_FILE_PREFIX..name)
	elseif stype == "string" then
		value = minetest.settings:get(CONFIG_FILE_PREFIX..name)
	elseif stype == "int" or stype == "float" then
		value = tonumber(minetest.settings:get(CONFIG_FILE_PREFIX..name))
	end
	if value == nil then
		value = default
	end
	digtron.config[name] = value

	if print_settingtypes then
		minetest.debug(CONFIG_FILE_PREFIX..name.." ("..description..") "..stype.." "..tostring(default))
	end
end

setting("bool", "uses_resources", true, "Digtron uses resources when active")
setting("bool", "lava_impassible", true, "Lava counts as a protected node")
setting("bool", "damage_creatures", true, "Diggers damage creatures") -- TODO: legacy setting, remove eventually
setting("int", "damage_hp", 8, "Damage diggers do")
setting("int", "size_limit", 1000, "Digtron size limit in nodes per moving digtron")

if digtron.config.damage_creatures == false then digtron.config.damage_hp = 0 end -- TODO: remove when damage_creatures is removed

-- Enables the spray of particles out the back of a digger head and puffs of smoke from the controller
local particle_effects = minetest.settings:get_bool("enable_particles")
digtron.config.particle_effects = particle_effects or particle_effects == nil -- default true


setting("int", "maximum_extrusion", 25, "Maximum builder extrusion distance")
setting("float", "cycle_time", 1.0, "Minimum Digtron cycle time")
setting("float", "traction_factor", 3.0, "Traction factor")

-- fuel costs. For comparison, in the default game:
-- one default tree block is 30 units
-- one coal lump is 40 units
-- one coal block is 370 units (apparently it's slightly more productive making your coal lumps into blocks before burning)
-- one book is 3 units

-- how much fuel is required to dig a node if not in one of the following groups.
setting("float", "dig_cost_default", 3.0, "Default dig cost")
-- eg, stone
setting("float", "dig_cost_cracky", 1.0, "Cracky dig cost")
-- eg, dirt, sand
setting("float", "dig_cost_crumbly", 0.5, "Crumbly dig cost")
-- eg, wood
setting("float", "dig_cost_choppy", 0.75, "Choppy dig cost")
-- how much fuel is required to build a node
setting("float", "build_cost", 1.0, "Build cost")

-- How much charge (an RE battery holds 10000 EU) is equivalent to 1 unit of heat produced by burning coal
-- With 100, the battery is 2.5 better than a coal lump, yet 3.7 less powerful than a coal block
-- Being rechargeable should pay off for this "average" performance.
setting("int", "power_ratio", 100, "The electrical charge to 1 coal heat unit conversion ratio")


setting("float", "marker_crate_good_duration", 3.0, "Duration that 'good' crate markers last")
setting("float", "marker_crate_bad_duration", 9.0, "Duration that 'bad' crate markers last")

setting("bool", "emerge_unloaded_mapblocks", true, "When Digtron encounters unloaded map blocks, emerge them.")
