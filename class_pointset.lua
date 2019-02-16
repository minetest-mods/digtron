-- A simple special-purpose class, this is used for building up sets of three-dimensional points for fast reference

Pointset = {}
Pointset.__index = Pointset

-- from builtin\game\misc.lua, modified to take values directly to avoid creating an intermediate vector
local hash_node_position_values = function(x, y, z)
	return (z + 32768) * 65536 * 65536
		 + (y + 32768) * 65536
		 +  x + 32768
end

function Pointset.create()
	local set = {}
	setmetatable(set,Pointset)
	set.points = {}
	return set
end

function Pointset:clear()
	local points = self.points
	for k, v in pairs(points) do
		points[k] = nil
	end
end

function Pointset:set(x, y, z, value)
	-- sets a value in the 3D array "points".
	self.points[hash_node_position_values(x,y,z)] = value
end

function Pointset:set_if_not_in(excluded, x, y, z, value)
	-- If a value is not already set for this point in the 3D array "excluded", set it in "points"
	if excluded:get(x, y, z) ~= nil then
		return
	end
	self:set(x, y, z, value)
end

function Pointset:get(x, y, z)
	-- return a value from the 3D array "points"
	return self.points[hash_node_position_values(x,y,z)]
end

function Pointset:set_pos(pos, value)
	self:set(pos.x, pos.y, pos.z, value)
end

function Pointset:set_pos_if_not_in(excluded, pos, value)
	self:set_if_not_in(excluded, pos.x, pos.y, pos.z, value)
end

function Pointset:get_pos(pos)
	return self:get(pos.x, pos.y, pos.z)
end

function Pointset:pop()
	-- returns a point that's in the 3D array, and then removes it.
	local hash, value = next(self.points)
	if hash == nil then return nil end
	local pos = minetest.get_position_from_hash(hash)
	self.points[hash] = nil	
	return pos, value
end

function Pointset:get_pos_list(value)
	-- Returns a list of all points with the given value in standard Minetest vector format. If no value is provided, returns all points
	local outlist = {}
	for hash, pointsval in pairs(self.points) do
		if value == nil or pointsval == value then
			table.insert(outlist,  minetest.get_position_from_hash(hash))
		end
	end
	return outlist
end
			
	