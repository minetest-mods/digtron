local cardinal_dirs = {
	{x = 0, y = 0,  z = 1},
	{x = 1, y = 0,  z = 0},
	{x = 0, y = 0,  z = -1},
	{x = -1, y = 0,  z = 0},
	{x = 0, y = -1, z = 0},
	{x = 0, y = 1,  z = 0},
}
-- Turn the cardinal directions into a set of integers you can add to a hash to step in that direction.
local cardinal_dirs_hash = {}
for i, dir in ipairs(cardinal_dirs) do
	cardinal_dirs_hash[i] = minetest.hash_node_position(dir) - minetest.hash_node_position({x = 0, y = 0, z = 0})
end

-- Mapping from facedir value to index in cardinal_dirs.
local facedir_to_dir_map = {
	[0] = 1, 2, 3, 4,
	5, 2, 6, 4,
	6, 2, 5, 4,
	1, 5, 3, 6,
	1, 6, 3, 5,
	1, 4, 3, 2,
}

local facedir_to_up_map = {
	[0] = 6, 6, 6, 6,
	3, 3, 3, 3,
	1, 1, 1, 1,
	4, 4, 4, 4,
	2, 2, 2, 2,
	5, 5, 5, 5,
}

local facedir_to_down_map = {
	[0] = 5, 5, 5, 5,
	1, 1, 1, 1,
	3, 3, 3, 3,
	2, 2, 2, 2,
	4, 4, 4, 4,
	6, 6, 6, 6,
}

local facedir_to_right_map = {
	[0] = 2, 3, 4, 1,
	2, 6, 4, 6,
	2, 5, 4, 6,
	5, 3, 6, 1,
	6, 3, 5, 1,
	4, 3, 2, 1,
}

local facedir_to_dir = function(facedir)
	return cardinal_dirs[facedir_to_dir_map[facedir % 32]]
end
local facedir_to_dir_hash = function(facedir)
	return cardinal_dirs_hash[facedir_to_dir_map[facedir % 32]]
end
local facedir_to_up = function(facedir)
	return cardinal_dirs[facedir_to_up_map[facedir % 32]]
end
local facedir_to_up_hash = function(facedir)
	return cardinal_dirs_hash[facedir_to_up_map[facedir % 32]]
end
local facedir_to_down = function(facedir)
	return cardinal_dirs[facedir_to_down_map[facedir % 32]]
end
local facedir_to_down_hash = function(facedir)
	return cardinal_dirs_hash[facedir_to_down_map[facedir % 32]]
end
local facedir_to_right = function(facedir)
	return cardinal_dirs[facedir_to_right_map[facedir % 32]]
end
local facedir_to_right_hash = function(facedir)
	return cardinal_dirs_hash[facedir_to_right_map[facedir % 32]]
end

-- Rotation

local negative_x = minetest.hash_node_position({x = -1, y = 0, z = 0})
local positive_x = minetest.hash_node_position({x = 1, y = 0, z = 0}) 
local negative_y = minetest.hash_node_position({x = 0, y = -1, z = 0})
local positive_y = minetest.hash_node_position({x = 0, y = 1, z = 0}) 
local negative_z = minetest.hash_node_position({x = 0, y = 0, z = -1})
local positive_z = minetest.hash_node_position({x = 0, y = 0, z = 1})

local facedir_rot = {
	[negative_x] = {[0] = 4, 5, 6, 7, 22, 23, 20, 21, 0, 1, 2, 3, 13, 14, 15, 12, 19, 16, 17, 18, 10, 11, 8, 9}, -- 270 degrees
	[positive_x] = {[0] = 8, 9, 10, 11, 0, 1, 2, 3, 22, 23, 20, 21, 15, 12, 13, 14, 17, 18, 19, 16, 6, 7, 4, 5}, -- 90 degrees
	[negative_y] = {[0] = 3, 0, 1, 2, 19, 16, 17, 18, 15, 12, 13, 14, 7, 4, 5, 6, 11, 8, 9, 10, 21, 22, 23, 20}, -- 270 degrees
	[positive_y] = {[0] = 1, 2, 3, 0, 13, 14, 15, 12, 17, 18, 19, 16, 9, 10, 11, 8, 5, 6, 7, 4, 23, 20, 21, 22}, -- 90 degrees
	[negative_z] = {[0] = 16, 17, 18, 19, 5, 6, 7, 4, 11, 8, 9, 10, 0, 1, 2, 3, 20, 21, 22, 23, 12, 13, 14, 15}, -- 270 degrees
	[positive_z] = {[0] = 12, 13, 14, 15, 7, 4, 5, 6, 9, 10, 11, 8, 20, 21, 22, 23, 0, 1, 2, 3, 16, 17, 18, 19}, -- 90 degrees
}

local wallmounted_rot = {
	[negative_x] = {[0] = 4, 5, 2, 3, 1, 0}, -- 270 degrees
	[positive_x] = {[0] = 5, 4, 2, 3, 0, 1}, -- 90 degrees
	[negative_y] = {[0] = 0, 1, 4, 5, 3, 2}, -- 270 degrees
	[positive_y] = {[0] = 0, 1, 5, 4, 2, 3}, -- 90 degrees
	[negative_z] = {[0] = 3, 2, 0, 1, 4, 5}, -- 270 degrees
	[positive_z] = {[0] = 2, 3, 1, 0, 4, 5}, -- 90 degrees
}

local rotate_facedir = function(axis_hash, facedir)
	return facedir_rot[axis_hash][facedir]
end
local rotate_wallmounted = function(axis_hash, facedir)
	return wallmounted_rot[axis_hash][facedir]
end

--90 degrees CW about x-axis: (x, y, z) -> (x, -z, y)
--90 degrees CCW about x-axis: (x, y, z) -> (x, z, -y)
--90 degrees CW about y-axis: (x, y, z) -> (-z, y, x)
--90 degrees CCW about y-axis: (x, y, z) -> (z, y, -x)
--90 degrees CW about z-axis: (x, y, z) -> (y, -x, z)
--90 degrees CCW about z-axis: (x, y, z) -> (-y, x, z)
-- operates directly on the pos vector
-- Rotates it around origin
local rotate_pos = function(axis_hash, pos)
	if axis_hash == negative_x and not (pos.y == 0 and pos.z == 0) then
		local temp_z = pos.z
		pos.z = pos.y
		pos.y = -temp_z
	elseif axis_hash == positive_x and not (pos.y == 0 and pos.z == 0) then
		local temp_z = pos.z
		pos.z = -pos.y
		pos.y = temp_z
	elseif axis_hash == negative_y and not (pos.x == 0 and pos.z == 0) then
		local temp_x = pos.x
		pos.x = -pos.z
		pos.z = temp_x
	elseif axis_hash == positive_y and not (pos.x == 0 and pos.z == 0) then
		local temp_x = pos.x
		pos.x = pos.z
		pos.z = -temp_x
	elseif axis_hash == negative_z and not (pos.x == 0 and pos.y == 0) then
		local temp_x = pos.x
		pos.x = -pos.y
		pos.y = temp_x
	elseif axis_hash == positive_z and not (pos.x == 0 and pos.y == 0) then
		local temp_x = pos.x
		pos.x = pos.y
		pos.y = -temp_x
	end
	return pos
end

digtron.cardinal_dirs = cardinal_dirs -- used by builder entities as well
digtron.cardinal_dirs_hash = cardinal_dirs_hash
digtron.facedir_to_dir_map = facedir_to_dir_map -- used by get_controlling_coordinate

digtron.facedir_to_dir = facedir_to_dir
digtron.facedir_to_dir_hash = facedir_to_dir_hash
digtron.facedir_to_up = facedir_to_up
digtron.facedir_to_up_hash = facedir_to_up_hash
digtron.facedir_to_down = facedir_to_down
digtron.facedir_to_down_hash = facedir_to_down_hash
digtron.facedir_to_right = facedir_to_right
digtron.facedir_to_right_hash = facedir_to_right_hash

digtron.rotate_pos = rotate_pos
digtron.rotate_wallmounted = rotate_wallmounted
digtron.rotate_facedir = rotate_facedir