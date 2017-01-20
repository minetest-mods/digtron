if not minetest.get_modpath("awards") then
	digtron.award_item_dug = function (items, player, count) end
	digtron.award_layout = function (layout, player) end
	digtron.award_item_built = function(item_name, player) end
	return
end
---------------------------------------------------------------------------

digtron.award_item_dug = function (items_dropped, player)
	if table.getn(items_dropped) == 0 then
		return
	end

	local data = awards.players[player]
	
	for _, item in pairs(items_dropped) do
		awards.increment_item_counter(data, "digtron_dug", item)
		
		if minetest.get_item_group(item, "tree") > 0 then
			awards.tbv(data, "digtron_dug_groups")
			awards.tbv(data["digtron_dug_groups"], "tree")
			data["digtron_dug_groups"]["tree"] = data["digtron_dug_groups"]["tree"] + count
		end
		if minetest.get_item_group(item, "dirt") > 0 then
			awards.tbv(data, "digtron_dug_groups")
			awards.tbv(data["digtron_dug_groups"], "dirt")
			data["digtron_dug_groups"]["dirt"] = data["digtron_dug_groups"]["dirt"] + count
		end
		if minetest.get_item_group(item, "grass") > 0 then
			awards.tbv(data, "digtron_dug_groups")
			awards.tbv(data["digtron_dug_groups"], "grass")
			data["digtron_dug_groups"]["grass"] = data["digtron_dug_groups"]["grass"] + count
		end		
	end
	
	if awards.get_item_count(data, "digtron_dug", "default:mese_crystal") > 100 then
		awards.unlock(player, "digtron_100mese_dug")
	end
	if awards.get_item_count(data, "digtron_dug", "default:diamond") > 100 then
		awards.unlock(player, "digtron_100diamond_dug")
	end
	if awards.get_item_count(data, "digtron_dug", "default:coal_lump") > 1000 then
		awards.unlock(player, "digtron_1000coal_dug")
		if awards.get_item_count(data, "digtron_dug", "default:coal_lump") > 10000 then
			awards.unlock(player, "digtron_10000coal_dug")
		end
	end
	if awards.get_item_count(data, "digtron_dug", "default:iron_lump") > 1000 then
		awards.unlock(player, "digtron_1000iron_dug")
	end
	if awards.get_item_count(data, "digtron_dug", "default:copper_lump") > 1000 then
		awards.unlock(player, "digtron_1000copper_dug")
	end
	if awards.get_item_count(data, "digtron_dug", "default:gold_lump") > 100 then
		awards.unlock(player, "digtron_100gold_dug")
	end
	
	local total_count = awards.get_total_item_count(data, "digtron_dug")
	if total_count > 1000 then
		awards.unlock(player, "digtron_1000_dug")
		if total_count > 10000 then
			awards.unlock(player, "digtron_10000_dug")
			if total_count > 100000 then
				awards.unlock(player, "digtron_100000_dug")
				if total_count > 1000000 then
					awards.unlock(player, "digtron_1000000_dug")
				end
			end
		end
	end

	awards.tbv(data, "digtron_dug_groups")
	awards.tbv(data.digtron_dug_groups, "tree", 0)
	awards.tbv(data.digtron_dug_groups, "dirt", 0)
	awards.tbv(data.digtron_dug_groups, "grass", 0)
	if data["digtron_dug_groups"]["tree"] > 1000 then
		awards.unlock(player, "digtron_1000wood_dug")
		if data["digtron_dug_groups"]["tree"] > 10000 then
			awards.unlock(player, "digtron_10000wood_dug")
		end
	end
	if data["digtron_dug_groups"]["dirt"] > 1000 then
		awards.unlock(player, "digtron_1000dirt_dug")
	end
	if data["digtron_dug_groups"]["grass"] > 1000 then
		awards.unlock(player, "digtron_1000grass_dug")
	end
end

digtron.award_item_built = function(item_name, player)
	local data = awards.players[player]
	awards.increment_item_counter(data, "digtron_built", item_name)
	
	local total_count = awards.get_total_item_count(data, "digtron_built")
	if total_count > 1000 then
		awards.unlock(player, "digtron_1000_built")
		if total_count > 10000 then
			awards.unlock(player, "digtron_10000_built")
		end
	end
end

digtron.award_layout = function (layout, player)
	if layout == nil or player == nil or player == "" then
		return
	end

	if layout.water_touching then
		awards.unlock(player, "digtron_water")
	end
	if layout.lava_touching then
		awards.unlock(player, "digtron_lava")
	end
	if table.getn(layout.all) > 9 then
		awards.unlock(player, "digtron_size10")
		if table.getn(layout.all) > 99 then
			awards.unlock(player, "digtron_size100")
		end
	end
	if table.getn(layout.diggers) > 24 then
		awards.unlock(player, "digtron_digger25")
	end
	if table.getn(layout.builders) > 24 then
		awards.unlock(player, "digtron_builder25")
	end
	
	if layout.controller.y > 100 then
		awards.unlock(player, "digtron_height100")
		if layout.controller.y > 1000 then
			awards.unlock(player, "digtron_height1000")
		end
	elseif layout.controller.y < -100 then
		awards.unlock(player, "digtron_depth100")
		if layout.controller.y < -1000 then
			awards.unlock(player, "digtron_depth1000")
			if layout.controller.y < -2000 then
				awards.unlock(player, "digtron_depth2000")
				if layout.controller.y < -4000 then
					awards.unlock(player, "digtron_depth4000")
					if layout.controller.y < -8000 then
						awards.unlock(player, "digtron_depth8000")
						if layout.controller.y < -16000 then
							awards.unlock(player, "digtron_depth16000")
							if layout.controller.y < -30000 then
								awards.unlock(player, "digtron_depth30000")
							end
						end
					end
				end
			end
		end
	end
end

awards.register_achievement("digtron_water",{
	title = "Deep Blue Digtron",
	description = "Encountered water while operating a Digtron.",
	background = "awards_bg_mining.png",
	icon = "default_water.png^digtron_digger_yb_frame.png",
})

awards.register_achievement("digtron_lava",{
	title = "Digtrons of Fire",
	description = "Encountered lava while operating a Digtron.",
	background = "awards_bg_mining.png",
	icon = "default_lava.png^digtron_digger_yb_frame.png",
})

awards.register_achievement("digtron_size10",{
	title = "Bigtron",
	description = "Operated a Digtron with 10 or more component blocks.",
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^digtron_crate.png",
})

awards.register_achievement("digtron_size100",{
	title = "Really Bigtron",
	description = "Operated a Digtron with 100 or more component blocks.",
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^digtron_crate.png", -- TODO: Visually distinguish this from Bigtron
})

awards.register_achievement("digtron_builder25",{
	title = "Buildtron",
	description = "Operated a Digtron with 25 or more builder modules.",
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^digtron_builder.png^digtron_crate.png",
})

awards.register_achievement("digtron_digger25",{
	title = "Digging Leviathan",
	description = "Operated a Digtron with 25 or more digger heads.",
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^digtron_motor.png^digtron_crate.png",
})

awards.register_achievement("digtron_height1000",{
	title = "Digtron In The Sky",
	description = "Operate a Digtron above 1000m elevation",
	background = "awards_bg_mining.png",
	icon = "default_river_water.png^default_snow_side.png^[transformR180^digtron_digger_yb_frame.png",
})

awards.register_achievement("digtron_height100",{
	title = "Digtron High",
	description = "Operated a Digtron above 100m elevation",
	background = "awards_bg_mining.png",
	icon = "default_river_water.png^default_snow_side.png^digtron_digger_yb_frame.png",
})

awards.register_achievement("digtron_depth100",{
	title = "Scratching the Surface",
	description = "Operated a Digtron 100m underground",
	background = "awards_bg_mining.png",
	icon = "default_cobble.png^digtron_digger_yb_frame.png^awards_level1.png",
})

awards.register_achievement("digtron_depth1000",{
	title = "Digging Deeper",
	description = "Operated a Digtron 1,000m underground",
	background = "awards_bg_mining.png",
	icon = "default_cobble.png^[colorize:#0002^digtron_digger_yb_frame.png^awards_level2.png",
})

awards.register_achievement("digtron_depth2000",{
	title = "More Than a Mile",
	description = "Operated a Digtron 2,000m underground",
	background = "awards_bg_mining.png",
	icon = "default_cobble.png^[colorize:#0004^digtron_digger_yb_frame.png^awards_level3.png",
})

awards.register_achievement("digtron_depth4000",{
	title = "Digging Below Plausibility",
	description = "The deepest mine in the world is only 3.9 km deep, you operated a Digtron below 4km",
	background = "awards_bg_mining.png",
	icon = "default_cobble.png^[colorize:#0006^digtron_digger_yb_frame.png^awards_level4.png",
})

awards.register_achievement("digtron_depth8000",{
	title = "Double Depth",
	description = "Operated a Digtron 8,000m underground",
	background = "awards_bg_mining.png",
	icon = "default_cobble.png^[colorize:#0008^digtron_digger_yb_frame.png^awards_level5.png",
})

awards.register_achievement("digtron_depth16000",{
	title = "Halfway to the Core",
	description = "Operated a Digtron 16,000m underground",
	background = "awards_bg_mining.png",
	icon = "default_cobble.png^[colorize:#000A^digtron_digger_yb_frame.png^awards_level6.png",
})

awards.register_achievement("digtron_depth30000",{
	title = "Nowhere To Go But Up",
	description = "Operated a Digtron 30,000m underground",
	background = "awards_bg_mining.png",
	icon = "default_cobble.png^[colorize:#000C^digtron_digger_yb_frame.png^awards_level7.png",
})

awards.register_achievement("digtron_100mese_dug",{
	title = "Mese Master",
	description = "Mine 100 Mese crystals with a Digtron",
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^default_mese_crystal.png^digtron_digger_yb_frame.png",
})

awards.register_achievement("digtron_100diamond_dug",{
	title = "Diamonds Vs. Diamonds",
	description = "Mine 100 diamonds with a Digtron",
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^default_diamond.png^digtron_digger_yb_frame.png",
})

awards.register_achievement("digtron_1000dirt_dug",{
	title = "Strip Mining",
	description = "Excavate 1000 units of dirt with a Digtron",
	background = "awards_bg_mining.png",
	icon = "default_dirt.png^digtron_digger_yb_frame.png",
})

awards.register_achievement("digtron_1000_dug",{
	title = "Digtron Miner",
	description = "Excavate 1000 blocks using Digtrons",
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^default_tool_bronzepick.png^digtron_digger_yb_frame.png",
})

awards.register_achievement("digtron_10000_dug",{
	title = "Digtron Expert Miner",
	description = "Excavate 10,000 blocks using Digtrons",
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^default_tool_steelpick.png^digtron_digger_yb_frame.png",
})

awards.register_achievement("digtron_100000_dug",{
	title = "Digtron Master Miner",
	description = "Excavate 100,000 blocks using Digtrons",
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^default_tool_diamondpick.png^digtron_digger_yb_frame.png",
})

awards.register_achievement("digtron_1000000_dug",{
	title = "DIGTRON MEGAMINER",
	description = "Excavate over a million blocks using Digtrons!",
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^default_tool_mesepick.png^digtron_digger_yb_frame.png",
})

awards.register_achievement("digtron_1000wood_dug",{
	title = "Clear Cutting",
	description = "Chop down 1000 units of tree with a Digtron",
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^default_sapling.png^digtron_digger_yb_frame.png",
})

awards.register_achievement("digtron_10000wood_dug",{
	title = "Digtron Deforestation",
	description = "Chop down 10,000 units of tree with a Digtron",
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^default_sapling.png^digtron_digger_yb_frame.png",
})

awards.register_achievement("digtron_1000grass_dug",{
	title = "Lawnmower",
	description = "Harvest 1000 units of grass with a Digtron",
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^default_grass_5.png^digtron_digger_yb_frame.png",
})

awards.register_achievement("digtron_1000iron_dug",{
	title = "Iron Digtron",
	description = "Excavate 1000 units of iron ore with a Digtron",
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^default_steel_ingot.png^digtron_digger_yb_frame.png",
})

awards.register_achievement("digtron_1000copper_dug",{
	title = "Copper Digtron",
	description = "Excavate 1000 units of copper ore with a Digtron",
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^default_copper_ingot.png^digtron_digger_yb_frame.png",
})

awards.register_achievement("digtron_1000coal_dug",{
	title = "Coal Digtron",
	description = "Excavate 1,000 units if coal with a Digtron",
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^default_coal_lump.png^digtron_digger_yb_frame.png",
})

awards.register_achievement("digtron_10000coal_dug",{
	title = "Bagger 288",
	description = "Excavate 10,000 units of coal with a Digtron",
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^default_coal_block.png^digtron_digger_yb_frame.png",
})

awards.register_achievement("digtron_100gold_dug",{
	title = "Digtron 49er",
	description = "Excavate 100 units of gold with a Digtron",
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^default_gold_ingot.png^digtron_digger_yb_frame.png",
})

awards.register_achievement("digtron_1000_built",{
	title = "Constructive Digging",
	description = "Build 1,000 blocks with a Digtron",
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^digtron_builder.png",
})

awards.register_achievement("digtron_10000_built",{
	title = "Highly Constructive Digging",
	description = "Build 10,000 blocks with a Digtron",
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^digtron_axel_side.png^[transformR90^digtron_builder.png",
})