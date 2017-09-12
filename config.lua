-- Enables the spray of particles out the back of a digger head and puffs of smoke from the controller
local particle_effects = minetest.settings:get_bool("enable_particles")

-- this causes digtrons to operate without consuming fuel or building materials.
local digtron_uses_resources = minetest.settings:get_bool("digtron_uses_resources")
if digtron_uses_resources == nil then digtron_uses_resources = true end

-- when true, lava counts as protected nodes.
local lava_impassible = minetest.settings:get_bool("digtron_lava_impassible")

-- when true, diggers deal damage to creatures when they trigger.
local damage_creatures = minetest.settings:get_bool("digtron_damage_creatures")

digtron.creative_mode = not digtron_uses_resources -- default false
digtron.particle_effects = particle_effects or particle_effects == nil -- default true
digtron.lava_impassible = lava_impassible or lava_impassible == nil -- default true
digtron.diggers_damage_creatures = damage_creatures or damage_creatures == nil -- default true

-- maximum distance a builder head can extrude blocks
local maximum_extrusion = tonumber(minetest.settings:get("digtron_maximum_extrusion"))
if maximum_extrusion == nil or maximum_extrusion < 1 or maximum_extrusion > 100 then
	digtron.maximum_extrusion = 25
else
	digtron.maximum_extrusion = maximum_extrusion
end

-- How many seconds a digtron waits between cycles. Auto-controllers can make this wait longer, but cannot make it shorter.
local digtron_cycle_time = tonumber(minetest.settings:get("digtron_cycle_time"))
if digtron_cycle_time == nil or digtron_cycle_time < 0 then
	digtron.cycle_time = 1.0
else
	digtron.cycle_time = digtron_cycle_time
end

-- How many digtron nodes can be moved for each adjacent solid node that the digtron has traction against
local digtron_traction_factor = tonumber(minetest.settings:get("digtron_traction_factor"))
if digtron_traction_factor == nil or digtron_traction_factor < 0 then
	digtron.traction_factor = 3.0
else
	digtron.traction_factor = digtron_traction_factor
end

-- fuel costs. For comparison, in the default game:
-- one default tree block is 30 units
-- one coal lump is 40 units
-- one coal block is 370 units (apparently it's slightly more productive making your coal lumps into blocks before burning)
-- one book is 3 units

-- how much fuel is required to dig a node if not in one of the following groups.
local digtron_dig_cost_default = tonumber(minetest.settings:get("digtron_dig_cost_default"))
if digtron_dig_cost_default == nil or digtron_dig_cost_default < 0 then
	digtron.dig_cost_default = 0.5
else
	digtron.dig_cost_default = digtron_dig_cost_default
end
-- eg, stone
local digtron_dig_cost_cracky = tonumber(minetest.settings:get("digtron_dig_cost_cracky"))
if digtron_dig_cost_cracky == nil or digtron_dig_cost_cracky < 0 then
	digtron.dig_cost_cracky = 1.0
else
	digtron.dig_cost_cracky = digtron_dig_cost_cracky
end
-- eg, dirt, sand
local digtron_dig_cost_crumbly = tonumber(minetest.settings:get("digtron_dig_cost_crumbly"))
if digtron_dig_cost_crumbly == nil or digtron_dig_cost_crumbly < 0 then
	digtron.dig_cost_crumbly = 0.5
else
	digtron.dig_cost_crumbly = digtron_dig_cost_crumbly
end
-- eg, wood
local digtron_dig_cost_choppy = tonumber(minetest.settings:get("digtron_dig_cost_choppy"))
if digtron_dig_cost_choppy == nil or digtron_dig_cost_choppy < 0 then
	digtron.dig_cost_choppy = 0.75
else
	digtron.dig_cost_choppy = digtron_dig_cost_choppy
end
-- how much fuel is required to build a node
local digtron_build_cost = tonumber(minetest.settings:get("digtron_build_cost"))
if digtron_build_cost == nil or digtron_build_cost < 0 then
	digtron.build_cost = 1.0
else
	digtron.build_cost = digtron_build_cost
end