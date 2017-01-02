minetest.register_entity("digtron:marker", {
	initial_properties = {
		visual = "cube",
		visual_size = {x=1.1, y=1.1},
		textures = {"digtron_marker_side.png","digtron_marker_side.png","digtron_marker.png","digtron_marker.png","digtron_marker_side.png","digtron_marker_side.png"},
		collisionbox = {-0.55, -0.55, -0.55, 0.55, 0.55, 0.55},
		physical = false,
	},

	on_activate = function(self, staticdata)
		minetest.after(5.0, 
			function(self) 
				self.object:remove()
			end,
			self)
	end,
	
	on_rightclick=function(self, clicker)
		self.object:remove()
	end,
	
	on_punch = function(self, hitter)
		self.object:remove()
	end,
})

minetest.register_entity("digtron:marker_vertical", {
	initial_properties = {
		visual = "cube",
		visual_size = {x=1.1, y=1.1},
		textures = {"digtron_marker.png","digtron_marker.png","digtron_marker_side.png^[transformR90","digtron_marker_side.png^[transformR90","digtron_marker_side.png^[transformR90","digtron_marker_side.png^[transformR90"},
		collisionbox = {-0.55, -0.55, -0.55, 0.55, 0.55, 0.55},
		physical = false,
	},

	on_activate = function(self, staticdata)
		minetest.after(5.0, 
			function(self) 
				self.object:remove()
			end,
			self)
	end,
	
	on_rightclick=function(self, clicker)
		self.object:remove()
	end,
	
	on_punch = function(self, hitter)
		self.object:remove()
	end,
})
