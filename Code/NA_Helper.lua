-------------------- MOD SETUP ---------------------
local hour_duration = const.HourDuration

MapVar("Global_nest_spawn_cd", 0)
MapVar("Nest_Notifications", 1)
MapVar("Nest_Species_Savegame_Stats", {})
MapVar("Faction_aggression_threshold", 0)
MapVar("Nest_tutorial", false)
MapVar("Nest_upgrade", false)
MapVar("Per_species_nest_max", 13)
MapVar("Max_nests_allowed", 20)
MapVar('Nest_scouting_quadrants', {})
MapVar('NA_Y_length', 0)
MapVar('NA_X_length', 0)
MapVar('NA_NestRoleZoom', 3)
MapVar('NA_NestRoleName', false)

function NA_Mod_Set(id)
	id = id or CurrentModId
	if CurrentModId ~= id or not CurrentModOptions then return end
	--ilu_set_map_vars() --
	local options = CurrentModOptions
	local nest_notif = options.nests_awaken_notifications
	local nest_level = 1
	--(nest_notif)
	if nest_notif == 'Full Popup' then
		nest_level = 2
	elseif nest_notif == 'Notifications Only' then
		nest_level = 1
	elseif nest_notif == 'Do not Alert me (<style TextNegative>Warning Dangerous</style>)' then
		nest_level = 0
	end
	Nest_Notifications = nest_level
	local per_species = options.max_nest
	Per_species_nest_max = per_species or 13
	Max_nests_allowed = options.max_global_nests or 15
	local visual_selection = options.NA_Visuals
	if visual_selection == 'Always on' then
		NA_NestRoleZoom = 3
	elseif visual_selection == 'Far (~80 meters)' then
		NA_NestRoleZoom = 2
	elseif visual_selection == 'Close (Same as Resource Piles) (~20 meters)' then
		NA_NestRoleZoom = 1
	elseif visual_selection == 'Always off' then
		NA_NestRoleZoom = 0
	end
	if options.NA_show_name then
		NA_NestRoleName = true
	else
		NA_NestRoleName = false
	end
end

function Setup_nest_mod()
	CreateGameTimeThread(function()
		WaitMsg("DlcsLoaded")
		local species = Presets.NestingSpeciesPreset.Default --nests = ClassDescendantsList("TerritorialNest")
		for _, v in ipairs(species) do
			if v.nest_class and not Nest_Species_Savegame_Stats[v.id] then
				local spawnflag = false
				if v.nest_class == 'ScissorhandsNest' or v.nest_class == 'ShriekerNest' then
					spawnflag = true
				elseif v.nest_class == 'ConsortiumNest' and IsDlcAvailable('Robots') then
					spawnflag = true
				end
				Nest_Species_Savegame_Stats[v.id] = {}
				Nest_Species_Savegame_Stats[v.id][v.id .. '_nest_spawn_cd'] = 0
				Nest_Species_Savegame_Stats[v.id][v.id .. '_evo_cd'] = 0
				Nest_Species_Savegame_Stats[v.id][v.id .. '_stored_aggr'] = 0
				Nest_Species_Savegame_Stats[v.id][v.id .. '_aggro_events'] = 0
				Nest_Species_Savegame_Stats[v.id]['spawnflag'] = spawnflag
			end
		end
		if Nest_scouting_quadrants == {} then
			CreateMapGrid()
		end
		Faction_aggression_threshold = Max(0, 6 - Get_difficulty_offset())
		Msg("UpdateNestRoleVisuals")
	end)
end

OnMsg.ApplyModOptions = NA_Mod_Set
OnMsg.GameStarted = Setup_nest_mod -- first start
OnMsg.LoadGame = Setup_nest_mod    -- savegame load


-- note we are switching cases, and no MapVar in use should start with a lowercase character
function SavegameFixups.NA_MapVarCleanup()
	local flag = false
	if MapVarValues["global_nest_spawn_cd"] ~= 0 then
		Global_nest_spawn_cd = MapVarValues["global_nest_spawn_cd"]
		MapVarValues["Global_nest_spawn_cd"] = 0
		flag = true
	end
	if MapVarValues["Nest_Notifications"] ~= 1 then
		Nest_Notifications = MapVarValues["Nest_Notifications"]
		MapVarValues["Nest_Notifications"] = 1
		flag = true
	end
	if MapVarValues['per_species_nest_max'] ~= 13 then
		Per_species_nest_max = MapVarValues['per_species_nest_max']
		MapVarValues['Per_species_nest_max'] = 13
		flag = true
	end
	if MapVarValues["faction_aggression_threshold"] ~= 0 then
		Faction_aggression_threshold = MapVarValues["faction_aggression_threshold"]
		MapVarValues["Faction_aggression_threshold"] = 0
		flag = true
	end
	if MapVarValues["nest_tutorial"] ~= false then
		Nest_tutorial = MapVarValues["nest_tutorial"]
		MapVarValues["Nest_tutorial"] = 1
		flag = true
	end
	if MapVarValues["Nest_Notifications"] ~= 1 then
		Nest_Notifications = MapVarValues["Nest_Notifications"]
		MapVarValues["Nest_Notifications"] = 1
		flag = true
	end
	if MapVarValues["Max_nests_allowed"] ~= 1 then
		Nest_Notifications = MapVarValues["Nest_Notifications"]
		MapVarValues["Nest_Notifications"] = 1
		flag = true
	end
	local species = Presets.NestingSpeciesPreset.Default --nests = ClassDescendantsList("TerritorialNest")
	for _, v in ipairs(species) do
		if v.nest_class then
			if not Nest_Species_Savegame_Stats[v.id] then
				Nest_Species_Savegame_Stats[v.id] = {}
				Nest_Species_Savegame_Stats[v.id][v.id .. '_nest_spawn_cd'] = 0
				Nest_Species_Savegame_Stats[v.id][v.id .. '_evo_cd'] = 0
				Nest_Species_Savegame_Stats[v.id][v.id .. '_stored_aggr'] = 0
				Nest_Species_Savegame_Stats[v.id][v.id .. '_aggro_events'] = 0
			end
			if MapVarValues[v.id .. '_nest_spawn_cd'] ~= 0 then
				Nest_Species_Savegame_Stats[v.id][v.id .. '_nest_spawn_cd'] = MapVarValues[v.id .. '_nest_spawn_cd']
				-- we are not resetting this MapVar because we will never use this MapVar
				flag = true
			end
			if MapVarValues[v.id .. '_evo_cd'] ~= 0 then
				Nest_Species_Savegame_Stats[v.id][v.id .. '_evo_cd'] = MapVarValues[v.id .. '_evo_cd']
				-- we are not resetting this MapVar because we will never use this MapVar
				flag = true
			end
			if MapVarValues[v.id .. '_stored_aggr'] ~= 0 then
				Nest_Species_Savegame_Stats[v.id][v.id .. '_stored_aggr'] = MapVarValues[v.id .. '_stored_aggr']
				-- we are not resetting this MapVar because we will never use this MapVar
				flag = true
			end
			if MapVarValues[v.id .. '_aggro_events'] ~= 0 then
				Nest_Species_Savegame_Stats[v.id][v.id .. '_aggro_events'] = MapVarValues[v.id .. '_aggro_events']
				-- we are not resetting this MapVar because we will never use this MapVar
				flag = true
			end
		end
	end
	if flag then
		Bkob_Log("NA had to clean up some vars!")
	end
end

--------------- SAVEGAME FIXUPS ---------------
-- brute force method.... not ideal
function SavegameFixups.NA_Disaster_clean()
	if GameState.SolarEclipse then
		DisasterPresets['SolarEclipse']:StopDisaster()
	end
end

function SavegameFixups.NA_Disaster_clean()
	if GameState.SolarEclipse then
		DisasterPresets['SolarEclipse']:StopDisaster()
	end
end

function SavegameFixups.Nest_cap_clean()
	Align_global_nest_cap()
end

function Align_global_nest_cap()
	local nests = MapGet(true, "TerritorialNest")
	local cap = Max_nests_allowed
	if not cap then
		cap = 19
	end
	DebugPrint("Checking if I need to delete nests!")
	DebugPrint(#nests - cap)
	if #nests > (cap) then
		DebugPrint("Still need to delete!")
		local types = ClassDescendantsList('TerritorialNest')
		local min = DivRound(cap, #types) - 1
		local needed_delete = #nests - cap
		local saved = {}
		local count = 0
		for _, nest in ipairs(nests) do
			DebugPrint("looking at this nest: ")
			DebugPrint(count)
			count = count + 1
			if saved[nest.class] and saved[nest.class] > min and needed_delete > 0 then
				DebugPrint("Deleting this nest!")
				-- delete
				local members = nest.nest_members
				for i = #members, 1, -1 do
					members[i]:SetNest(false)
				end
				for i = #members, 1, -1 do
					members[i]:CheatDelete()
				end
				nest:CheatDelete()
				needed_delete = needed_delete - 1
			elseif not saved[nest.class] then
				DebugPrint("Saving this nest!")
				saved[nest.class] = 1
				DebugPrint("This many saved of this class: ")
				DebugPrint(nest.class)
				DebugPrint(saved[nest.class])
			else
				DebugPrint("Saving this nest!")
				saved[nest.class] = saved[nest.class] + 1
				DebugPrint("This many saved of this class: ")
				DebugPrint(nest.class)
				DebugPrint(saved[nest.class])
			end
		end
	end
end

------------------------------ HELPER FUNCTIONS ------------------------------
function Bkob_Log_NA(hard_string, var)
	DebugPrint(hard_string)
	if var then
		DebugPrint(var)
	end
	DebugPrint("\n")
	if EE_debug == 'all' then
		print(hard_string)
		print(var)
	end
end

-- input a preset id, nest class name, preset, or nest object; output the NestingSpeciesPreset (or false)
function find_nest_species(input)
	-- Always resolve to the NestingSpeciesPreset object (or false), regardless of whether
	-- the caller passed a preset id, a nest class name, the preset itself, or a nest object.
	if type(input) == 'string' then
		local by_id = Presets.NestingSpeciesPreset.Default[input] -- preset id, e.g. "nesting_consortium"
		if by_id then return by_id end
		if g_Classes[input] then                            -- nest class name, e.g. "ConsortiumNest"
			local species_id = get_species_from_nest(input)
			if species_id then return Presets.NestingSpeciesPreset.Default[species_id] end
		end
		return false
	end
	if IsKindOf(input, "NestingSpeciesPreset") then return input end
	if IsKindOf(input, "TerritorialNest") then
		local species_id = get_species_from_nest(input.class)
		if species_id then return Presets.NestingSpeciesPreset.Default[species_id] end
	end
	return false
end

function Get_difficulty_offset()
	local difficulty_offset = 2
	local difficulty = GetGameDifficulty()
	if difficulty == 'Easy' then
		difficulty_offset = 1
	elseif difficulty == 'Medium' then
		difficulty_offset = 2
	elseif difficulty == 'Hard' then
		difficulty_offset = 3
	elseif difficulty == 'VeryHard' then
		difficulty_offset = 4
	elseif difficulty == 'Insane' then
		difficulty_offset = 5
	elseif difficulty == 'PXImpossible' then
		difficulty_offset = 6
	else
		difficulty_offset = 7
	end
	return difficulty_offset
end

--assuming a string of the nest class
function get_species_from_nest(nest_class)
	local found = false
	for _, v in ipairs(ClassDescendantsList('TerritorialNest')) do
		if v == nest_class then
			found = true
		end
	end
	if not found then return end
	local entries = #Presets.NestingSpeciesPreset.Default
	for i = 1, entries do
		local species = Presets.NestingSpeciesPreset.Default[i]
		if species and species.unit_species then
			if species.nest_class == nest_class then
				return species.id
			end
		end
	end
end

function Get_nest_species_by_region(region)
	region = region or Region.id
	DebugPrint("Getting nest class id by region\n")
	if region == 'Desertum' then
		return get_species_from_nest('ShriekerNest')
	elseif region == 'Sobrius' then
		return get_species_from_nest("ShriekerNest")
	elseif region == 'Saltu' then
		return get_species_from_nest('ScissorhandsNest')
	else
		return get_species_from_nest('ShriekerNest')
	end
end

function Get_nest_entity_by_region(region)
	region = region or Region.id
	DebugPrint("Getting nest class id by region\n")
	if region == 'Desertum' then
		return ('ShriekerNest')
	elseif region == 'Sobrius' then
		return get_species_from_nest("ShriekerNest")
	elseif region == 'Saltu' then
		return get_species_from_nest('ScissorhandsNest')
	else
		return get_species_from_nest('ShriekerNest')
	end
end

function Is_DLC_Present()
	DebugPrint("Checking if DLC loaded\n")
	return TradingShips['SmallCargoShip']
end

function mark_spawned_nest(nest_type)
	Global_nest_spawn_cd = GameTime() + MoonInstance.AttackCooldownMin
	local species_name = get_species_from_nest(nest_type)
	print(species_name)
	local species_def = Presets.NestingSpeciesPreset.Default[species_name]
	print(species_def)
	local species_id = species_def.id
	print(species_id)
	if Nest_Species_Savegame_Stats[species_id] and Nest_Species_Savegame_Stats[species_id][species_id .. '_nest_spawn_cd'] then
		Nest_Species_Savegame_Stats[species_id][species_id .. '_nest_spawn_cd'] = GameTime() +
			(MoonInstance.AttackCooldownMin * 3)
	else
		DebugPrint("Nesting species does not have an entry in map vars for their nest spawn cd! Alert mod author!")
	end
end

function NA_log_nest_evolved(nest)
	local notif_level = Nest_Notifications or 1
	if notif_level == 2 then
		ForceActivateStoryBit('nests_evolving', self, true)
	elseif notif_level == 1 then
		AddGameNotification("nests_evolving", nil, nil, { nest })
	end
end

function NA_tutorial()
	if Nest_tutorial then return end
	Presets.TutorialHint.Default['nests_awaken_tutorial']:ShowNotification()
	Nest_tutorial = true
end

function Get_center_of_survivors()
	local surv = GetValidSurvivorsOnMap()
	local sum_x = 0
	local sum_y = 0
	local count = 0
	local x = 0
	local y = 0
	for _, v in ipairs(surv) do
		x, y, _ = v:GetVisualPosXYZ()
		sum_x = sum_x + x
		sum_y = sum_y + y
		count = count + 1
	end
	if count == 0 then
		-- no valid survivors (rare; e.g. a wipe) -> fall back to map centre to avoid a /0 crash
		return GetMapBox():Center()
	end
	local center = point(DivRound(sum_x, count), DivRound(sum_y, count))
	return center
end

function NA_QA(full_log)
	Setup_nest_mod()
	Build_species_pivot_table()
	build_pivot_tables()
	EE_Instantiate()
	full_log = full_log or false
	EE_debug = full_log
	print("Testing regions default nests")
	print(Get_nest_entity_by_region('Desertum') == 'nesting_shriekers')
	print(Get_nest_entity_by_region('Sobrius') == 'nesting_shriekers')
	print(Get_nest_entity_by_region('Saltu') == 'nesting_scissorhands')
	--assert(Get_nest_by_region('Desertum')=='nesting_shriekers')
	--assert(Get_nest_by_region('Sobrius')=='nesting_shriekers')
	--assert(Get_nest_by_region('Saltu')=='nesting_scissorhands')
	Bkob_Log("Testing Nest spawner storybits!")
	local all_nest_species = Presets.NestingSpeciesPreset.Default
	-- this ensures there is one of each nest on the map for continued testing
	local og_EP = EventProgress
	for _, v in ipairs(all_nest_species) do
		if not v.nest_class then goto continue end
		if v.nest_class then
			ForceActivateStoryBit(v.spawner_storybit, nil, "immediate", nil, true)
		end
		CreateRealTimeThread(function(nestclass)
			print("Testing nest: " .. nestclass)
			Sleep(5000)
			local nest_on_map = MapGetFirst(true, nestclass)
			local EP_nums = { 100, 800, 1200, 5000, 15000, 30000, 75000, 140000, 300000 }
			local def = g_Classes[nestclass]
			local attack_at = GameTime() + (2 * hour_duration)
			local attacked = false
			local deleted = false
			local og_hatch = def.hatchling_class
			local og_adult = def.adult_class
			local og_elder = def.elder_class
			local elder_chain = Find_evo_chain(og_elder)
			local reset = function(nest)
				nest.hatchling_class = og_hatch
				nest.adult_class = og_adult
				nest.elder_class = og_elder
			end
			nest_on_map:expand()
			for i = 1, 10 do
				nest_on_map:consume_closest_node()
			end
			nest_on_map:SwitchState("sleepy")
			print("State should be sleepy: " .. nest_on_map.state)
			nest_on_map:SwitchState("awake")
			print("State should be awake: " .. nest_on_map.state)
			nest_on_map:SwitchState("asleep")
			print("State should be asleep: " .. nest_on_map.state)
			for _, int in ipairs(EP_nums) do
				print("Testing with EP: ")
				print(int)
				EventProgress = int
				local correct_elder = elder_chain:get_correct_evo(int)
				nest_on_map:change_nest_herd()
				local possible = #correct_elder
				table.insert_unique(correct_elder, nest_on_map.elder_class)
				if possible ~= #correct_elder then
					print("Something went wrong evolving!")
				end
				Sleep(6000)
				nest_on_map:attack()
				reset(nest_on_map)
			end
		end, v.nest_class)
		::continue::
	end
	print("Testing resources!")
	local res_table = get_nest_res_table()
	for _, res in ipairs(table.keys(res_table)) do
		print(res)
		for _, species_entry in ipairs(res_table[res]) do
			print("This should aggro: " .. species_entry.species)
			local to_send = {}
			to_send[res] = species_entry.chance
			print(to_send)
			for i = 1, 20 do
				Resource_aggression_check(to_send)
			end
		end
	end
	EventProgress = og_EP
end

function Get_species_nests()
	local ret = {}
	for i = 1, #Presets.NestingSpeciesPreset.Default do
		local nest_def = Presets.NestingSpeciesPreset.Default[i]
		if nest_def and nest_def.nest_class then
			ret[#ret + 1] = nest_def.nest_class
		end
	end
	return ret
end

function UnitInvader:GetNestClass()
	local species = self:Get_Nesting_Species()
	return Presets.NestingSpeciesPreset.Default[species].nest_class
end

function UnitInvader:Get_Nesting_Species()
	for i = 1, #Presets.NestingSpeciesPreset.Default do
		if Presets.NestingSpeciesPreset.Default[i] then
			local nestS = Presets.NestingSpeciesPreset.Default[i]
			if self.SpeciesGroup == nestS.unit_species then return nestS.id end
		end
	end
	return false
end

--[[
quadrants = {1={},2={}}
......
quadrants[1] = {
	shriekers={
			last_scout=y2d1,
			map_objs={
				1=scissorhand_nest_2,
				2=scissorhand_nest_3,
				3=consortium_nest_100
			},
			other_species={
			-- Used to determine what other species are attackable inside of this quadrant
				scissorhands={
					1=scissorhands_nest_2,
					2=scissorhands_nest_3
				},
				consortium={
					1=consortium_nest_100
				}
			}
	},
	scissorhands={repeat.....
	}
}
--]]
function CreateMapGrid()
	local minx, miny, maxx, maxy = GetPlayBox():xyxy()
	NA_X_length = MulDivRound(maxx - minx, 1, 5)
	NA_Y_length = MulDivRound(maxy - miny, 1, 5)

	local species = Presets.NestingSpeciesPreset.Default
	for _, v in ipairs(species) do
		if v.nest_class then
			for quadrant = 1, 25 do
				if not Nest_scouting_quadrants[quadrant] then
					Nest_scouting_quadrants[quadrant] = {}
				end
				if not Nest_scouting_quadrants[quadrant][v.id] then
					Nest_scouting_quadrants[quadrant][v.id] = {
						last_scout = 0,
						player_detected = false,
						map_objs = {},
						other_species = {},
					}
				end
			end
		end
	end
	return Nest_scouting_quadrants
end

function DebugQuadrant(no)
	print("Quadrant: " .. no)
	local this_quad = Nest_scouting_quadrants[no]
	for _, species in ipairs(table.keys(this_quad)) do
		if this_quad[species]['last_scout'] ~= 0 then
			print("Has been explored by species: " .. species)
			print("On day: " .. this_quad[species]['last_scout'])
			print("And had recorded " .. #this_quad[species]['map_objs'] .. "  of other species")
			print("Other species detected: ")
			print(table.keys(this_quad[species]['other_species']))
		else
			print("Has not been explored by species: " .. species)
		end
	end
end

function DebugGetQuadrantSummary(quad)
	quad = quad or 0
	if quad < 1 then
		for q = 1, 25 do
			DebugQuadrant(q)
		end
	else
		DebugQuadrant(quad)
	end
end

--- Quadrant Functions
function Get_box_from_quadrant(quadrant_number)
	if not NA_Y_length or not NA_X_length then
		CreateMapGrid()
	end
	if not quadrant_number then return end
	--print("Making box for quadrant: ",quadrant_number,'\n')
	local start_x, _, _, start_y = GetPlayBox():xyxy()
	--print('\nX start',start_x,'Y start',start_y,'\n')
	local quad_obj = Uncollapse_quad(quadrant_number)
	local box_y_end = start_y - ((quad_obj.y - 1) * NA_Y_length)
	local box_y_start = box_y_end - NA_Y_length
	--print("y quad: ",quad_obj.y,'\n')
	--print("starts at ",box_y_start," and stops at ",box_y_end,'\n')
	local box_x_start = start_x + ((quad_obj.x - 1) * NA_X_length)
	local box_x_end = box_x_start + NA_X_length
	--print("x quad: ",quad_obj.x,'\n')
	--print("starts at ",box_x_start," and stops at ",box_x_end,'\n')
	return box(box_x_start, box_y_start, 0, box_x_end, box_y_end, 0)
end

function Cheat_find_all_in_quadrant(quad_no, classname)
	classname = classname or 'TerritorialNest'
	local box = Get_box_from_quadrant(quad_no)
	if not box then
		--print('something went wrong getting the box!')
		return {}
	end
	return MapGet(box, classname)
end

function compare_quad_maths(entity)
	CreateMapGrid()
	print("Unit is at ", entity:GetPosXYZ())
	print('\n')
	local quad_no = Get_quadrant_from_obj(entity, true)
	local quad_box = Get_box_from_quadrant(quad_no)
	print("Quad box is: \n")
	print(quad_box)
	print("Entity is at this position:")
	print(entity:GetPosXYZ())
	print("Is this entity inside the quadrants box that it reports to be in?")
	print(is_inside_of(quad_box, entity))
end

function Player_presence_in_quadrant(quad_no)
	local box = Get_box_from_quadrant(quad_no)
	if not box then return false end
	local players_stuff = MapCount(box, function(thing)
		return IsValid(thing) and thing.player
	end)
	print("There are ", players_stuff, ' in this quadrant!\n')
	return players_stuff > 0
end

-- This is expected to be a map object
function Get_quadrant_from_obj(entity, int_flag)
	if NA_X_length == 0 or NA_Y_length == 0 then
		CreateMapGrid()
	end
	local minx, miny, maxx, maxy = GetPlayBox():xyxy()
	--print("\nStarting to count x coords at ",minx,'\n')
	--print("Starting to count y coords at ",maxy,'but going down!\n')
	int_flag = int_flag or false
	local x, y, z = entity:GetPosXYZ()
	local quad_x
	local quad_y
	--print("Unit is at this x position: ",x,'\n')
	local x_rel = x - minx
	local y_rel = y - miny
	--print("Which is ",MulDivRound(x_rel*100,1,maxx-minx),'% across the map in x!\n')
	--print("Unit is at this y position: ",y,'\n')
	--print("Which is ",MulDivRound(y_rel*100,1,maxy-miny),'% across the map in y!\n')
	for i = 1, 5, 1 do
		if not quad_y then
			local lowest_y = maxy - (i * NA_Y_length)
			local highest_y = maxy - ((i - 1) * NA_Y_length)
			print("Checking this y quadrant, ", i, '\n')
			print('Which starts at y: ', lowest_y, ' and ends at ', highest_y, '\n')
			if y < highest_y and y > lowest_y then
				print("Which is more than this quadrant border: ", y, '\n')
				quad_y = i
			end
		end
	end
	if not quad_y then
		--print("This unit is currently out of bounds!",'\n')
	end

	local quad_x
	for q = 1, 5, 1 do
		if not quad_x then
			--print("Checking this x quadrant, ",q,'\n')
			--print('Which starts at x: ',minx + ((q-1) * NA_X_length), ' and ends at ',minx + (q * NA_X_length),'\n')
			local check = minx + (q * NA_X_length)
			if x < check then
				--print("Which is more than this quadrant border: ",x,' < ',check,'\n')
				quad_x = q
			end
		end
	end
	if not quad_x then
		--print("This unit is currently out of bounds!",'\n')
	end
	if int_flag then
		local times_5 = quad_y - 1
		print("Returning quadrant no: ", times_5 * 5 + quad_x, '\n')
		return times_5 * 5 + quad_x
	else
		print("Returning quadrant obj: ", { x = quad_x, y = quad_y }, '\n')
		return { x = quad_x, y = quad_y }
	end
end

function Collapse_quad(quad_obj)
	local times_5 = quad_obj.y - 1
	local quad_no = (times_5 * 5) + quad_obj.x
	return quad_no
end

function Uncollapse_quad(quad_no)
	local y = MulDivTrunc(quad_no - 1, 1, 5)
	local x = quad_no - (y * 5)
	y = y + 1
	return { x = x, y = y }
end

function Get_adjacent_quads(quad_int)
	local quads = {}
	if quad_int - 1 > 0 then
		quads[#quads + 1] = quad_int - 1
	end
	if quad_int + 1 <= 25 and quad_int % 5 ~= 0 then
		quads[#quads + 1] = quad_int + 1
	end
	if quad_int + 5 <= 25 then
		quads[#quads + 1] = quad_int + 5
	end
	if quad_int - 5 > 0 then
		quads[#quads + 1] = quad_int - 5
	end
	return quads
end

function Reset_quadrant(quad_no, species)
	Nest_scouting_quadrants[quad_no][species].last_scout = GameTime()
	Nest_scouting_quadrants[quad_no][species].player_detected = false
	Nest_scouting_quadrants[quad_no][species].map_objs = {}
	Nest_scouting_quadrants[quad_no][species].other_species = {}
end

-- Removed this function from debug mode to test scouting / overrides needed for behaviors
function UnitInvader:DbgPrintInvaderBehaviours()
	if not self.invader_behaviours then
		print("never had invader behaviours")
		return
	end
	if IsValidThread(self.invader_behaviours_thread) then
		print("invader behaviours are running")
	else
		print("invader behaviours aren't running")
	end
	local previous = {}
	local current, current_until
	local now = GameTime()
	if self.forced_aggression_until then
		local str = "aggressive"
		local against = {}
		for _, group in ipairs(self.forced_aggression_groups) do
			table.insert(against, "(grp)" .. group)
		end
		for _, label in ipairs(self.forced_aggression_labels) do
			table.insert(against, "(lbl)" .. label)
		end
		for _, class in ipairs(self.forced_aggression_classes) do
			table.insert(against, "(cls)" .. class)
		end
		if next(against) then
			str = str .. " against " .. table.concat(against, ", ")
		end
		if now < self.forced_aggression_until then
			current = str
			current_until = self.forced_aggression_until
		else
			table.insert(previous, "aggressive")
		end
	elseif self.food_binge_until then
		if now < self.food_binge_until then
			current = "food binge"
			current_until = self.food_binge_until
		else
			table.insert(previous, "food binge")
		end
	elseif self.time_to_despawn then
		if now < self.time_to_despawn then
			current = "despawn"
			current_until = self.time_to_despawn
		else
			table.insert(previous, "despawn")
		end
	elseif self.pathing then
		print("new behavior detected!")
		current = "passive pathing"
		current_until = self.path_until
		-- inject new checks above this stay_awake_until, as this is the catchall from teh base bevahior bool
	elseif self.combat_passive_until then
		if now < self.combat_passive_until then
			current = "passive"
			current_until = self.combat_passive_until
		else
			table.insert(previous, "passive")
		end
	elseif self.stay_awake_until and
		self.combat_rage_until == self.stay_awake_until
	then
		if now < self.stay_awake_until then
			current = "berserk"
			current_until = self.combat_rage_until
		else
			table.insert(previous, "berserk")
		end
	else
		current = "(possibly) idle"
		current_until = max_int
	end
	if next(previous) then
		print("previous behaviours (in no particular order):")
		for i, str in ipairs(previous) do
			previous[i] = " - " .. str
		end
	end
	if current then
		local until_str = (current_until == max_int) and "forever" or
			("for " .. tostring(current_until / (const.HourDuration * 1.0)) .. " more hours")
		print("current behaviour:", current, until_str)
	end
	if next(self.invader_behaviours) then
		print("future behaviours:")
		for i, behavior in ipairs(self.invader_behaviours) do
			print("-", _InternalTranslate(behavior.EditorView, behavior))
		end
	end
end

function TestConnectivityRandomTile(center)
	DbgClear()

	center = center or SelectedObj or GameStartPos

	local nests = MapGet("map", "TerritorialNest")
	local function filter_far_from_nest(x, y)
		-- check for distance to shrieker nests
		for _, nest in ipairs(nests or empty_table) do
			if nest:IsCloser2D(x, y, nest.territorial_range) then
				return false
			end
		end
		return true
	end
	local x, y
	local seed = InteractionRand(nil, "LandHuman")
	local max_dist, min_dist = const.Gameplay.SurvivorSpawnNearBaseMaxRadius,
		const.Gameplay.SurvivorSpawnNearBaseMinRadius
	local origin = terrain.FindAreaPassable(center, 4086, 64 * guim, Human.pfclass)

	local stA = GetPreciseTicks(1000000)
	local pos = ConnectivityRandomTile(seed, origin, center, max_dist, min_dist, Human.pfclass, 4096,
		filter_far_from_nest)
	local timeA = GetPreciseTicks(1000000) - stA

	DbgAddVector(origin, 15 * guim, red)
	DbgAddVector(center, 10 * guim, blue)
	DbgAddCircle(center, min_dist, blue)
	DbgAddCircle(center, max_dist, yellow)
	if pos then
		DbgAddVector(pos, 10 * guim, green)
		DbgAddSegment(origin, pos)
	end

	print("pos", pos, "time", timeA / 1000.0)
end
