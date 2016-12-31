-- A simple special-purpose class, this is used for building up sets of three-dimensional points
-- I only added features to it as I needed them so may not be highly useful outside of this mod's context.

Pointset = {}
Pointset.__index = Pointset

function Pointset.create()
	local set = {}
	setmetatable(set,Pointset)
	set.points = {}
	return set
end

function Pointset:set(x, y, z, value)
	-- sets a value in the 3D array "points".
	if self.points[x] == nil then
		self.points[x] = {}
	end
	if self.points[x][y] == nil then
		self.points[x][y] = {}
	end
	self.points[x][y][z] = value	
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
	if self.points[x] == nil or self.points[x][y] == nil then
		return nil
	end
	return self.points[x][y][z]
end

function Pointset:pop()
	-- returns a point that's in the 3D array, and then removes it.
	local pos = {}
	local ytable
	local ztable
	local val

	local count = 0
	for _ in pairs(self.points) do count = count + 1 end
	if count == 0 then
		return nil
	end
	
	pos.x, ytable = next(self.points)
	pos.y, ztable = next(ytable)
	pos.z, val = next(ztable)

	self.points[pos.x][pos.y][pos.z] = nil
	
	count = 0
	for _ in pairs(self.points[pos.x][pos.y]) do count = count + 1 end
	if count == 0 then
		self.points[pos.x][pos.y] = nil
	end
	
	count = 0
	for _ in pairs(self.points[pos.x]) do count = count + 1 end
	if count == 0 then
		self.points[pos.x] = nil
	end
	
	return pos, val
end