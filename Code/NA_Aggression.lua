
local og_produce_output = ProductionDeviceComponent.ProduceOutput
function ProductionDeviceComponent:ProduceOutput(recipe, def, count, unit)
	Resource_aggression_check(self.unfinished_item_data.used_resources,self)
	og_produce_output(self, recipe, def, count, unit)
end

-- input a string or classdef, output the nesting species classdef (If we can find it)
function find_nest_class(input)
	local str_check = type(input) == 'string'
	local nest_spec_check, nest_entity_check
	if str_check then
		nest_spec_check = Presets.NestingSpeciesPreset.Default[input]
		nest_entity_check = g_Classes[input]
	else
		nest_spec_check = IsKindOf(input, "NestingSpecies")
		nest_entity_check = IsKindOf(input, "TerritorialNest")
	end
	if nest_entity_check then
		return nest_entity_check
	end
	if nest_spec_check then
		return g_Classes[nest_spec_check.nest_class]
	end
	return false
end

-- middle layer function so that on low difficulties the species take more to become aggresive
function Aggression_log_faction(input)
	local nesting_species = input
	--local nesting_species = find_nest_species(input)
	--if not nesting_species then return nil end
	DebugPrint("Logging an aggression event\n")
	DebugPrint(IsKindOf(nesting_species, "NestingSpeciesPreset"))
	DebugPrint(IsKindOf(nesting_species.id, "NestingSpeciesPreset"))
	local to_return = false
	local threshold = Faction_aggression_threshold or Max(0,6 - Get_difficulty_offset())
	local count = 0
	if Nest_Species_Savegame_Stats[nesting_species] and Nest_Species_Savegame_Stats[nesting_species][nesting_species .. '_aggro_events'] then
		count = Nest_Species_Savegame_Stats[nesting_species][nesting_species .. '_aggro_events']
	else
		DebugPrint("Nesting species did not have an entry in map vars for their aggro events! Alert mod author!")
		Nest_Species_Savegame_Stats[nesting_species] = {}
		Nest_Species_Savegame_Stats[nesting_species][nesting_species .. '_aggro_events'] = 0
	end
	count = count + 1
	if count >= threshold then
		to_return = true
		Nest_Species_Savegame_Stats[nesting_species][nesting_species .. '_aggro_events'] = 0
	else
		Nest_Species_Savegame_Stats[nesting_species][nesting_species .. '_aggro_events'] = count
	end
	DebugPrint("Did this event trigger an aggression up?\n")
	DebugPrint(to_return)
	DebugPrint("\n")
	return to_return
end

-- Note to future me, the wierd_res_table is:
-- { res = amount, res2 = amount2, .... }
-- So we cannot loop through it, just check if any res that a nest species cares about is in the table
function Resource_aggression_check(unfinished_table, bench)
	local aggroed = {}
	if not unfinished_table then return end
	DebugPrint("input")
	DebugPrint(unfinished_table)
	DebugPrint("A recipe completed\n")
	-- res table already scaled because it is in the UI editor
	local res_table = get_nest_res_table()
	if #res_table == 0 then
		Build_species_pivot_table()
		res_table = get_nest_res_table()
	end
	local recipe_res = table.keys(unfinished_table)
	DebugPrint("recipe_res")
	DebugPrint(recipe_res)
	--local scale = const.ResourceScale -- 1000 base
	for _,res in ipairs(recipe_res) do
		DebugPrint("Checking res: "..res)
		if res_table[res] then
			DebugPrint("it is a res that nests care about")
			-- already scaled because this is from the recipe
			local consumed = unfinished_table[res]
			for _,v in ipairs(res_table[res]) do
				local roll = AsyncRand(100)
				local aggression_roll = roll > DivRound(consumed * 100, v.chance)
				if consumed >= v.chance or aggression_roll then
					DebugPrint("Aggression triggered for species: "..v.species)
					Aggression_up(v.species,bench)
					aggroed[#aggroed + 1] = v.species
				end
			end
		end
	end
	-- return which species got aggression up calls
	return aggroed
end

local function can_spawn_nest(input)
	local nest_species = find_nest_species(input)
	if not nest_species then return nil end
	local species_id = nest_species.id
	local nest_class_def = find_nest_class(input)
	if not nest_class_def then return nil end
	local nest_classname = nest_class_def.class
	DebugPrint("Checking if can spawn nest for species: "..species_id)
	DebugPrint("Checking how many nests of this clas exist on map: "..nest_classname)
	local count_total = MapCount("map", nest_classname)

	-- In cases where the player needs to do something before spawning is enabled.
	if not Nest_Species_Savegame_Stats[species_id]['spawnflag'] then return false end

	-- Do nothing if too many nests exist
	if count_total >= Per_species_nest_max then
		return false
	end

	--local new_spawn_time = GameTime() + MoonInstance.AttackCooldownMin
	if GameTime() < Global_nest_spawn_cd then
		-- cannot spawn due to global cd
		return false
	elseif Nest_Species_Savegame_Stats[species_id] and Nest_Species_Savegame_Stats[species_id][species_id .. '_nest_spawn_cd'] and GameTime() < Nest_Species_Savegame_Stats[species_id][species_id .. '_nest_spawn_cd'] then
		-- cannot spawn due to species specific cd
		return false
	else
		-- marking this species and the global cd is done in a helper function called mark_spawned_nest, which is called in the same function that spawns the nest, so we can be sure that if a nest is spawned, the cds are marked
		return true
	end
end

local function can_give_evo(input)
	local nest_species = find_nest_species(input)
	if not nest_species then return nil end
	local species_id = nest_species.id
	if MapCount(true, nest_species.nest_class) <= 0 then
		return false
	end
	local new_evo_time = GameTime() + DivRound(MoonInstance.AttackCooldownMin, 2)
	local species_evo_var = species_id .. '_evo_cd'
	if not Nest_Species_Savegame_Stats[species_id] or not Nest_Species_Savegame_Stats[species_id][species_evo_var] then
		Nest_Species_Savegame_Stats[species_id] = Nest_Species_Savegame_Stats[species_id] or {}
		Nest_Species_Savegame_Stats[species_id][species_evo_var] = new_evo_time
		DebugPrint("Nesting species did not have an entry in map vars for their evo events! Alert mod author!")
		return true
	elseif Nest_Species_Savegame_Stats[species_id] and Nest_Species_Savegame_Stats[species_id][species_evo_var] then
		if GameTime() < Nest_Species_Savegame_Stats[species_id][species_evo_var] then
			-- cannot evo due to species specific cd
			return false
		else
			Nest_Species_Savegame_Stats[species_id][species_evo_var] = new_evo_time
			return true
		end
	else
		return false
	end
end

function Aggression_up(input,location)
	local nest_species = find_nest_species(input)
	if not nest_species then
		nest_species = find_nest_species(Get_nest_species_by_region())
	end
	if not nest_species then
		DebugPrint("Aggression_up: could not resolve a nesting species; skipping\n")
		return
	end
	DebugPrint("Aggression up called\n")
	DebugPrint("Checking if species is valid")
	-- 1 Find our how many nests of the type on map
	-- 2 Find out % of said nests are not asleep
	--- 2a If 0 nests on map, need (difficulty offset - 8)
	-- 3 If % < 600%, wake up 1 nest
	-- 4 If % > 60%, spawn new nest
	--(species)
	DebugPrint("Checking the aggression log!")
	local species_name = nest_species.id
	local species_nest_name = nest_species.nest_class
	if not Aggression_log_faction(species_name) then return end
	DebugPrint("past the aggression check!")
	local count_total = MapCount("map", species_nest_name)
	local count_awake = MapCount("map", species_nest_name, function(this_nest)
		if this_nest.state == 'sleepy' then
			return true
		end
	end)
	local choice = {}
	choice[#choice + 1] = { event = 'bank', weight = 100 }
	if can_spawn_nest(species_name) then
		choice[#choice + 1] = { event = 'spawn', weight = 250 }
	end
	if count_total > 0 then
		choice[#choice + 1] = { event = 'consume', weight = 150 }
		if can_give_evo(species_name) then
			choice[#choice + 1] = { event = 'evo', weight = 200 }
		end
		if  DivRound(count_awake * 100, count_total) < 75 then
			choice[#choice + 1] = { event = 'wakeup', weight = 150 }
		end
	end
	DebugPrint("Possible response options:")
	DebugPrint(choice)
	local option, _, __ = table.weighted_rand(choice, 'weight')
	option = option.event
	DebugPrint("option picked:")
	DebugPrint(option)
	local weakest_nest
	if option == 'evo' or option == 'consume' then
		local nests = MapGet("map", species_nest_name, function(this_nest)
			if this_nest.state == 'asleep' then
				return true
			end
		end)
		local lowest_evo = 10
		for _,v in ipairs(nests or empty_table) do
			local tier = EE_get_tier(v.elder_class)   -- lazy-inits EE's tier pivot; nil if species unmapped
			if tier and tier < lowest_evo then
				weakest_nest = v
				lowest_evo = tier
			end
		end
		if not weakest_nest then return end
		DebugPrint("Weakest nest needed, here it is:")
		DebugPrint(weakest_nest)
	end
	if option == 'spawn' then
		local sb = nest_species.spawner_storybit
		ForceActivateStoryBit(sb)
	elseif option == 'evo' then
		weakest_nest.attacks_done = weakest_nest.attacks_done + 1
		if weakest_nest.attacks_to_evo == weakest_nest.attacks_done then
			weakest_nest:change_nest_herd(true)
		end
	elseif option == 'wakeup' then
		local nest_picked
		if location then
			nest_picked = MapFindNearest(location, "map", species_nest_name, function(this_nest)
				return this_nest.state == 'asleep'
			end)
		else
			nest_picked = MapGetFirst("map", species_nest_name, function(this_nest)
				return this_nest.state == 'asleep'
			end)
		end
		if nest_picked then
			nest_picked:scout_nearest_quad()
		end
		--nest_picked:SwitchState("sleepy")
	elseif option == 'bank' then
		local species_banked_aggr = species_name..'_banked_aggr'
		if Nest_Species_Savegame_Stats[species_name] and Nest_Species_Savegame_Stats[species_name][species_banked_aggr] then
			Nest_Species_Savegame_Stats[species_name][species_banked_aggr] = Nest_Species_Savegame_Stats[species_name][species_banked_aggr] + 5
		else
			DebugPrint("Nesting species does not have an entry in map vars for their banked aggro! Alert mod author!")
			Nest_Species_Savegame_Stats[species_name] = Nest_Species_Savegame_Stats[species_name] or {}
			Nest_Species_Savegame_Stats[species_name][species_banked_aggr] = 5
		end
	elseif option == 'consume' then
		for i=1, Max(1, Get_difficulty_offset()) do
			weakest_nest:consume_closest_node()
		end
	end
end

function Aggression_down(input)
	local nest_species = find_nest_species(input)
	if not nest_species then
		nest_species = find_nest_species(Get_nest_species_by_region())
	end
	if not nest_species then
		DebugPrint("Aggression_down: could not resolve a nesting species; skipping\n")
		return
	end
	local species_nest_name = nest_species.nest_class
	DebugPrint("Aggression down called\n")
	-- Will deactivate a nest if possible, eventually will lower attack chance/faction
	local nest
	nest = MapGetFirst("map", species_nest_name, function(this_nest)
		if this_nest.state == 'sleepy' then
			return true
		end
	end)
	if nest then
		nest:SwitchState("asleep")
	end
end
