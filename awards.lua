if not minetest.get_modpath("awards") then
	digtron.award_item_dug = function() end
	digtron.award_layout = function() end
	digtron.award_item_built = function() end
	digtron.award_crate = function() end
	return
end

---------------------------------------------------------------------------

-- internationalization boilerplate
local S = digtron.S
-- local MP = minetest.get_modpath(minetest.get_current_modname())
-- local S = dofile(MP.."/intllib.lua")

awards.register_trigger("digtron_dig", {
	type = "counted_key",
	progress = "@1/@2 excavated",
	auto_description = {"Excavate 1 @2 using a Digtron.", "Excavate @1 @2 using a Digtron."},
	auto_description_total = {"Excavate @1 block using a Digtron.", "Excavate @1 blocks using a Digtron."},
	get_key = function(_, def)
		return minetest.registered_aliases[def.trigger.node] or def.trigger.node
	end,
	key_is_item = true,
})

digtron.award_item_dug = function(items_dropped, player)
	if #items_dropped == 0 or not player then
		return
	end
	for _, item in pairs(items_dropped) do
		awards.notify_digtron_dig(player, item)
	end
end

awards.register_trigger("digtron_build", {
	type = "counted_key",
	progress = "@1/@2 built",
	auto_description = {"Build 1 @2 using a Digtron.", "Build @1 @2 using a Digtron."},
	auto_description_total = {"Build @1 block using a Digtron.", "Build @1 blocks using a Digtron."},
	get_key = function(_, def)
		return minetest.registered_aliases[def.trigger.node] or def.trigger.node
	end,
	key_is_item = true,
})

digtron.award_item_built = function(item_name, player)
	if not player then
		return
	end
	awards.notify_digtron_build(player, item_name)
end

digtron.award_layout = function(layout, player)
	if layout == nil or not player then
		return
	end

	local name = player:get_player_name()

	if layout.water_touching then
		awards.unlock(name, "digtron_water")
	end
	if layout.lava_touching then
		awards.unlock(name, "digtron_lava")
	end
	if table.getn(layout.all) > 9 then
		awards.unlock(name, "digtron_size10")
		if table.getn(layout.all) > 99 then
			awards.unlock(name, "digtron_size100")
		end
	end
	if layout.diggers ~= nil and table.getn(layout.diggers) > 24 then
		awards.unlock(name, "digtron_digger25")
	end
	if layout.builders ~= nil and table.getn(layout.builders) > 24 then
		awards.unlock(name, "digtron_builder25")
	end

	if layout.controller.y > 100 then
		awards.unlock(name, "digtron_height100")
		if layout.controller.y > 1000 then
			awards.unlock(name, "digtron_height1000")
		end
	elseif layout.controller.y < -100 then
		awards.unlock(name, "digtron_depth100")
		if layout.controller.y < -1000 then
			awards.unlock(name, "digtron_depth1000")
			if layout.controller.y < -2000 then
				awards.unlock(name, "digtron_depth2000")
				if layout.controller.y < -4000 then
					awards.unlock(name, "digtron_depth4000")
					if layout.controller.y < -8000 then
						awards.unlock(name, "digtron_depth8000")
						if layout.controller.y < -16000 then
							awards.unlock(name, "digtron_depth16000")
							if layout.controller.y < -30000 then
								awards.unlock(name, "digtron_depth30000")
							end
						end
					end
				end
			end
		end
	end
end

digtron.award_crate = function(layout, name)
	if layout == nil or not name or name == "" then
		return
	end

	-- Note that we're testing >10 rather than >9 because this layout includes the crate node
	if table.getn(layout.all) > 10 then
		awards.unlock(name, "digtron_crate10")
		if table.getn(layout.all) > 100 then
			awards.unlock(name, "digtron_crate100")
		end
	end
end

awards.register_award("digtron_water",{
	title = S("Deep Blue Digtron"),
	description = S("Encounter water while operating a Digtron."),
	background = "awards_bg_mining.png",
	icon = "default_water.png^digtron_digger_yb_frame.png",
})

awards.register_award("digtron_lava",{
	title = S("Digtrons of Fire"),
	description = S("Encounter lava while operating a Digtron."),
	background = "awards_bg_mining.png",
	icon = "default_lava.png^digtron_digger_yb_frame.png",
})

awards.register_award("digtron_size10",{
	title = S("Bigtron"),
	description = S("Operate a Digtron with 10 or more component blocks."),
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^digtron_crate.png",
})

awards.register_award("digtron_size100",{
	title = S("Really Bigtron"),
	description = S("Operate a Digtron with 100 or more component blocks."),
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^digtron_crate.png", -- TODO: Visually distinguish this from Bigtron
})

awards.register_award("digtron_builder25",{
	title = S("Buildtron"),
	description = S("Operate a Digtron with 25 or more builder modules."),
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^digtron_builder.png^digtron_crate.png",
})

awards.register_award("digtron_digger25",{
	title = S("Digging Leviathan"),
	description = S("Operate a Digtron with 25 or more digger heads."),
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^digtron_motor.png^digtron_crate.png",
})

awards.register_award("digtron_height1000",{
	title = S("Digtron In The Sky"),
	description = S("Operate a Digtron above 1000m elevation."),
	background = "awards_bg_mining.png",
	icon = "default_river_water.png^default_snow_side.png^[transformR180^digtron_digger_yb_frame.png",
})

awards.register_award("digtron_height100",{
	title = S("Digtron High"),
	description = S("Operate a Digtron above 100m elevation."),
	background = "awards_bg_mining.png",
	icon = "default_river_water.png^default_snow_side.png^digtron_digger_yb_frame.png",
})

awards.register_award("digtron_depth100",{
	title = S("Scratching the Surface"),
	description = S("Operate a Digtron 100m underground."),
	background = "awards_bg_mining.png",
	icon = "default_cobble.png^digtron_digger_yb_frame.png^awards_level1.png",
})

awards.register_award("digtron_depth1000",{
	title = S("Digging Deeper"),
	description = S("Operate a Digtron 1,000m underground."),
	background = "awards_bg_mining.png",
	icon = "default_cobble.png^[colorize:#0002^digtron_digger_yb_frame.png^awards_level2.png",
})

awards.register_award("digtron_depth2000",{
	title = S("More Than a Mile"),
	description = S("Operate a Digtron 2,000m underground."),
	background = "awards_bg_mining.png",
	icon = "default_cobble.png^[colorize:#0004^digtron_digger_yb_frame.png^awards_level3.png",
})

awards.register_award("digtron_depth4000",{
	title = S("Digging Below Plausibility"),
	description = S("Operate a Digtron 4,000m underground."),
	background = "awards_bg_mining.png",
	icon = "default_cobble.png^[colorize:#0006^digtron_digger_yb_frame.png^awards_level4.png",
})

awards.register_award("digtron_depth8000",{
	title = S("Double Depth"),
	description = S("Operate a Digtron 8,000m underground."),
	background = "awards_bg_mining.png",
	icon = "default_cobble.png^[colorize:#0008^digtron_digger_yb_frame.png^awards_level5.png",
})

awards.register_award("digtron_depth16000",{
	title = S("Halfway to the Core"),
	description = S("The deepest mine in the world is only ~15 km deep, you operated a Digtron below 16km."),
	background = "awards_bg_mining.png",
	icon = "default_cobble.png^[colorize:#000A^digtron_digger_yb_frame.png^awards_level6.png",
})

awards.register_award("digtron_depth30000",{
	title = S("Nowhere To Go But Up"),
	description = S("Operate a Digtron 30,000m underground."),
	background = "awards_bg_mining.png",
	icon = "default_cobble.png^[colorize:#000C^digtron_digger_yb_frame.png^awards_level7.png",
})

awards.register_award("digtron_100mese_dug",{
	title = S("Mese Master"),
	description = S("Mine 100 Mese crystals with a Digtron."),
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^default_mese_crystal.png^digtron_digger_yb_frame.png",
	trigger = {
		type = "digtron_dig",
		node = "default:mese_crystal",
		target = 100,
	}
})

awards.register_award("digtron_100diamond_dug",{
	title = S("Diamond Vs. Diamond"),
	description = S("Mine 100 diamonds with a Digtron."),
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^default_diamond.png^digtron_digger_yb_frame.png",
	trigger = {
		type = "digtron_dig",
		node = "default:diamond",
		target = 100,
	}
})

awards.register_award("digtron_1000dirt_dug",{
	title = S("Strip Mining"),
	description = S("Excavate 1000 units of dirt with a Digtron."),
	background = "awards_bg_mining.png",
	icon = "default_dirt.png^digtron_digger_yb_frame.png",
	trigger = {
		type = "digtron_dig",
		node = "default:dirt",
		target = 1000,
	}
})

awards.register_award("digtron_1000_dug",{
	title = S("Digtron Miner"),
	description = S("Excavate 1000 blocks using a Digtron."),
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^default_tool_bronzepick.png^digtron_digger_yb_frame.png",
	trigger = {
		type = "digtron_dig",
		target = 1000,
	}
})

awards.register_award("digtron_10000_dug",{
	title = S("Digtron Expert Miner"),
	description = S("Excavate 10,000 blocks using a Digtron."),
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^default_tool_steelpick.png^digtron_digger_yb_frame.png",
	trigger = {
		type = "digtron_dig",
		target = 10000,
	}
})

awards.register_award("digtron_100000_dug",{
	title = S("Digtron Master Miner"),
	description = S("Excavate 100,000 blocks using a Digtron."),
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^default_tool_diamondpick.png^digtron_digger_yb_frame.png",
	trigger = {
		type = "digtron_dig",
		target = 100000,
	}
})

awards.register_award("digtron_1000000_dug",{
	title = S("DIGTRON MEGAMINER"),
	description = S("Excavate over a million blocks using a Digtron!"),
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^default_tool_mesepick.png^digtron_digger_yb_frame.png",
	trigger = {
		type = "digtron_dig",
		target = 1000000,
	}
})

awards.register_award("digtron_1000wood_dug",{
	title = S("Clear Cutting"),
	description = S("Chop down 1000 units of tree with a Digtron."),
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^default_sapling.png^digtron_digger_yb_frame.png",
	trigger = {
		type = "digtron_dig",
		node = "group:tree",
		target = 1000,
	}
})

awards.register_award("digtron_10000wood_dug",{
	title = S("Digtron Deforestation"),
	description = S("Chop down 10,000 units of tree with a Digtron."),
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^default_sapling.png^digtron_digger_yb_frame.png",
	trigger = {
		type = "digtron_dig",
		node = "group:tree",
		target = 10000,
	}
})

awards.register_award("digtron_1000grass_dug",{
	title = S("Lawnmower"),
	description = S("Harvest 1000 units of grass with a Digtron."),
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^default_grass_5.png^digtron_digger_yb_frame.png",
	trigger = {
		type = "digtron_dig",
		node = "group:grass",
		target = 1000,
	}
})

awards.register_award("digtron_1000iron_dug",{
	title = S("Iron Digtron"),
	description = S("Excavate 1000 units of iron ore with a Digtron."),
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^default_steel_ingot.png^digtron_digger_yb_frame.png",
	trigger = {
		type = "digtron_dig",
		node = "default:iron_lump",
		target = 1000,
	}
})

awards.register_award("digtron_1000copper_dug",{
	title = S("Copper Digtron"),
	description = S("Excavate 1000 units of copper ore with a Digtron."),
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^default_copper_ingot.png^digtron_digger_yb_frame.png",
	trigger = {
		type = "digtron_dig",
		node = "default:copper_lump",
		target = 1000,
	}
})

awards.register_award("digtron_1000coal_dug",{
	title = S("Coal Digtron"),
	description = S("Excavate 1,000 units of coal with a Digtron."),
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^default_coal_lump.png^digtron_digger_yb_frame.png",
	trigger = {
		type = "digtron_dig",
		node = "default:coal_lump",
		target = 1000,
	}
})

awards.register_award("digtron_10000coal_dug",{
	title = S("Bagger 288"),
	description = S("Excavate 10,000 units of coal with a Digtron."),
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^default_coal_block.png^digtron_digger_yb_frame.png",
	trigger = {
		type = "digtron_dig",
		node = "default:coal_lump",
		target = 10000,
	}
})

awards.register_award("digtron_100gold_dug",{
	title = S("Digtron 49er"),
	description = S("Excavate 100 units of gold with a Digtron."),
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^default_gold_ingot.png^digtron_digger_yb_frame.png",
	trigger = {
		type = "digtron_dig",
		node = "default:gold_lump",
		target = 100,
	}
})

awards.register_award("digtron_1000_built",{
	title = S("Constructive Digging"),
	description = S("Build 1,000 blocks with a Digtron."),
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^digtron_builder.png",
	trigger = {
		type = "digtron_build",
		target = 1000,
	}
})

awards.register_award("digtron_10000_built",{
	title = S("Highly Constructive Digging"),
	description = S("Build 10,000 blocks with a Digtron."),
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^digtron_axel_side.png^[transformR90^digtron_builder.png",
	trigger = {
		type = "digtron_build",
		target = 10000,
	}
})

awards.register_award("digtron_crate10",{
	title = S("Digtron Packrat"),
	description = S("Stored 10 or more Digtron blocks in one crate."),
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^digtron_crate.png", -- TODO: Visually distinguish this from Bigtron
})

awards.register_award("digtron_crate100",{
	title = S("Digtron Hoarder"),
	description = S("Stored 100 or more Digtron blocks in one crate."),
	background = "awards_bg_mining.png",
	icon = "digtron_plate.png^digtron_crate.png", -- TODO: Visually distinguish this from Bigtron
})
