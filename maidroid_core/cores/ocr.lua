------------------------------------------------------------
-- Copyright (c) 2016 tacigar. All rights reserved.
-- https://github.com/tacigar/maidroid
------------------------------------------------------------

-- This list ought to contain only the nodedef fields which are known by players
local known_nodedef_info = {"tiles", "use_texture_alpha", "post_effect_color",
	"walkable", "pointable", "climbable", "buildable_to", "light_source",
	"damage_per_second", "sounds", "groups", "sunlight_propagates"}

local function usleep(t, thread)
	if not pdisc.standard_befehlssatz.usleep({t}, thread) then
		error"Problem with pdisc instruction set."
	end
end

local function pos_from_varname(name, vars)
	if type(name) ~= "string" then
		return false, "string expected"
	end
	local cs = {"x", "y", "z"}
	local pos = {}
	for i = 1,#cs do
		i = cs[i]
		local v = tonumber(vars[name .. "." .. i])
		if not v then
			return false, "coordinate " .. i .. " not found"
		end
		pos[i] = v
	end
	return pos
end

local function table_tovars(name, t, vars)
	if type(name) ~= "string" then
		return false, "string expected"
	end
	for i,v in pairs(t) do
		vars[name .. "." .. i] = v
	end
	return true
end

local function update_animation(droid, ani)
	if not ani then
		droid.object:set_animation(maidroid.animation_frames[ani])
		return
	end
	if droid.vel.x == 0
	and droid.vel.z == 0 then
		droid.object:set_animation(maidroid.animation_frames.STAND)
	else
		droid.object:set_animation(maidroid.animation_frames.WALK)
	end
end

-- used for the place instruction
local under_offsets = {
	{0,-1,0},
	{0,0,-1}, {-1,0,0}, {1,0,0}, {0,0,1},
	{0,1,0}
}
local function get_pt_under(pos, dir)
	if dir then
		local p = vector.round(vector.add(pos, dir))
		local def = minetest.registered_nodes[minetest.get_node(p).name]
		return def and def.pointable and p
	end
	for i = 1,#under_offsets do
		local o = under_offsets[i]
		local p = {x = pos.x + o[1], y = pos.y + o[2], z = pos.z + o[3]}

		local node = minetest.get_node(p)
		local def = minetest.registered_nodes[node.name]
		if def
		and def.pointable then
			return p
		end
	end
end

local function get_pt_above(pos, dir)
	if dir then
		local p = vector.round(vector.add(pos, vector.multiply(dir, -1)))
		return p
	end
	local p = vector.new(pos)
	p.y = p.y + 1
	return p
end

local chat_last_sayer, chat_last_message = "", ""
minetest.register_on_chat_message(function(name, message)
	chat_last_sayer, chat_last_message = name, message
end)

local maidroid_instruction_set = {
	-- popular (similars in lua_api) information gathering functions

	get_pos = function(params, thread)
		return table_tovars(params[1], thread.droid.object:get_pos(),
			thread.vars)
	end,

	get_velocity = function(params, thread)
		return table_tovars(params[1], thread.droid.vel, thread.vars)
	end,

	get_acceleration = function(params, thread)
		return table_tovars(params[1], thread.droid.object:get_acceleration(),
			thread.vars)
	end,

	get_yaw = function(_, thread)
		return true, thread.droid.object:getyaw()
	end,

	-- other info functions
	get_node = function(params, thread)
		-- get position
		local pos, msg = pos_from_varname(params[1], thread.vars)
		if not pos then
			return false, msg
		end

		local range = 100
		local mp = thread.droid.object:get_pos()
		if vector.distance(pos, mp) > range then
			return false, "node too far away"
		end

		return table_tovars(params[1], minetest.get_node(pos), thread.vars)
	end,

	get_nodedef = function(params, thread)
		local nodename = params[1]
		if type(nodename) ~= "string" then
			return false, "nodename is not a string"
		end
		local def = minetest.registered_nodes[nodename]
		if not def then
			return true, false
		end
		local localdef = {}
		for i = 1,#known_nodedef_info do
			localdef[known_nodedef_info[i]] = def[known_nodedef_info[i]]
		end
		return table_tovars(params[2], localdef, thread.vars)
	end,

	get_item_group = function(params)
		local name = params[1]
		local group = params[2]
		if type(name) ~= "string"
		or type(group) ~= "string" then
			return false, "two strings expected"
		end
		return true, minetest.get_item_group(name, group)
	end,

	-- popular actions for changing sth
	set_yaw = function(params, thread)
		if #params ~= 1 then
			return false, "wrong number of arguments"
		end
		local p = params[1]
		if type(p) ~= "number" then
			return false, "unsupported argument"
		end
		thread.droid.object:setyaw(p)
		return true
	end,

	-- other actions
	jump = function(params, thread)
		-- test if it can jump
		local droid = thread.droid
		if droid.vel.y ~= 0
		or droid.vel_prev.y ~= 0 then
			return true, false
		end

		-- get the strength of the jump
		local h = tonumber(params[1])
		if not h
		or h <= 0
		or h > 2 then
			h = 1
		end

		-- play sound
		local p = droid.object:get_pos()
		p.y = p.y - 1
		local node_under = minetest.get_node(p).name
		local def = minetest.registered_nodes[node_under]
		if def
		and def.sounds then
			local snd = def.sounds.footstep or def.sounds.dig
			if snd then
				p.y = p.y + .5
				minetest.sound_play(snd.name, {pos = p, gain = snd.gain})
			end
		end

		-- perform jump
		droid.vel.y = math.sqrt(-2 * h * droid.object:get_acceleration().y)
		droid.object:setvelocity(droid.vel)
		return true, true
	end,

	setwalk = function(params, thread)
		local speed = tonumber(params[1]) or 0
		speed = math.max(-.5, math.min(5, speed))
		local obj = thread.droid.object
		local yaw = obj:getyaw()
		local vel = thread.droid.vel
		vel.z = math.cos(yaw) * speed
		vel.x = -math.sin(yaw) * speed
		obj:setvelocity(vel)
		update_animation(thread.droid)
		return true
	end,

	dig = function(params, thread)
		-- the wielditem's on_use is ignored
		--~ -- look if wielditem has on_use
		--~ local wielditem = thread.droid:get_wielded_item()
		--~ local wielditem_def = minetest.registered_items[wielditem:get_name()]
		--~ if wielditem_def and wielditem_def.on_use then
			--~ local pointed_thing = {}
			--~ local pos = pos_from_varname(params[1], thread.vars)
			--~ if pos then
				--~ pointed_thing.type = "node"
				--~ pointed_thing.under = pos
				--~ -- get_look_direction is not used since it only uses yaw
				--~ pointed_thing.above = get_pt_above(pos,
						--~ vector.direction(thread.droid:get_pos(), pos))
			--~ else
				--~ pointed_thing.type = "nothing"
			--~ end
			--~ thread.droid.is_player_currently = true
			--~ wielditem = wielditem_def.on_use(wielditem, thread.droid, pointed_thing)
			--~ thread.droid.is_player_currently = false
			--~ thread.droid:set_wielded_item(wielditem)
			--~ return true, {false, "wielded item has on_use"}
		--~ end

		-- get position
		local pos, msg = pos_from_varname(params[1], thread.vars)
		if not pos then
			return false, msg
		end

		-- test if the node there can be dug
		local node = minetest.get_node(pos)
		local def = minetest.registered_nodes[node.name]
		if not def
		or not def.diggable -- diggable is also tested in the on_dig
		or not def.pointable then
			return true, {false, "node not diggable"}
		end

		-- test tool params (Code from simple_robots)
		local obj = thread.droid.object
		local mp = obj:get_pos()
		local dist = vector.distance(mp, pos)
		local dp_result
		local groups = def.groups
		local dp_pool = {}
		dp_pool[1] = minetest.get_dig_params(
			groups,
			ItemStack{name=":"}:get_tool_capabilities()
		)
		dp_pool[1].range = minetest.registered_items[""].range or 14
		-- currently 1 possible tool
		local wielded = thread.droid:get_wielded_item()
		dp_pool[2] = minetest.get_dig_params(
			groups,
			wielded:get_tool_capabilities()
		)
		dp_pool[2].range = minetest.registered_items[wielded:get_name()].range
			or 14
		local used_tool
		for i = 1,#dp_pool do
			-- fix, see game.cpp:3888 TODO
			dp_pool[i].time = math.max(dp_pool[i].time, 0.15)
		end
		for i = 1,#dp_pool do
			local v = dp_pool[i]
			if v.diggable then
				if dist <= v.range
				and (not dp_result
					or dp_result.time > v.time
				) then
					dp_result = v
					used_tool = i > 1 and i
				end
			end
		end
		if not dp_result then
			return true, {false, "insufficient tool capabilities"}
		end

		thread.droid.is_player_currently = true
		def.on_dig(pos, node, thread.droid)
		thread.droid.is_player_currently = false
		--~ local success = minetest.dig_node(pos)

		--~ if not success then
			--~ return true, false, "no success"
		--~ end

		-- toolwear is adjusted in on_dig, needs testing
		--~ if used_tool then
			--~ wielded:add_wear(dp_pool[used_tool].wear)
			--~ obj:set_wielded_item(wielded)
		--~ end

		-- play sound
		local sound = def.sounds and def.sounds.dug
		if sound then
			minetest.sound_play(sound.name, {pos=pos, gain=sound.gain})
		end

		-- wait the digging time while showing the MINE animation
		update_animation(thread.droid, "MINE")
		usleep(dp_result.time * 1000000, thread)
		update_animation(thread.droid)

		return true, {true, dp_result.time}
	end,

	place = function(params, thread)
		-- get pt.above
		local pos, msg = pos_from_varname(params[1], thread.vars)
		if not pos then
			return false, msg
		end

		-- get wield item
		local stack = thread.droid:get_wielded_item()

		-- get pt.under (get_look_direction is not used since it only uses yaw)
		local under = get_pt_under(pos, vector.direction(thread.droid:get_pos(), pos))
		if not under then
			return true, {false, "no node to place onto found"}
		end

		-- place it
		local pt = {
			above = pos,
			under = under,
			type = "node"
		}
		local stack_def = stack:get_definition()
		local newitem, succ = stack_def.on_place(stack, thread.droid.object, pt)
		if not succ then
			return true, {false, "could not place"}
		end

		-- play the place sound
		if stack_def.sounds
		and stack_def.sounds.place then
			minetest.sound_play(stack_def.sounds.place, {
				pos = pos,
				max_hear_distance = 10,
			})
		end

		-- set new item
		if newitem then
			thread.droid:set_wielded_item(newitem)
		end

		return true, true
	end,

	rightclick = function(params, thread)
		-- check if object shall rightclicked
		if type(params[1]) == "number" then
			local obj = minetest.object_refs[params[1]]
			if obj:is_player() then
				return true
			end
			local luaent = obj:get_luaentity()
			local def = minetest.registered_entities[luaent.name]
			if not def or not def.on_rightclick then
				return true
			end
			thread.droid.is_player_currently = true
			def.on_rightclick(luaent, thread.droid)
			thread.droid.is_player_currently = false
			return true
		end

		-- get pt.under
		local pos, msg = pos_from_varname(params[1], thread.vars)
		if not pos then
			return false, msg
		end

		-- get wield item
		local stack = thread.droid:get_wielded_item()

		-- get pt.above (get_look_direction is not used since it only uses yaw)
		local above = get_pt_above(pos, vector.direction(thread.droid:get_pos(), pos))

		-- place it
		local pt = {
			above = above,
			under = pos,
			type = "node"
		}
		local stack_def = stack:get_definition()
		local newitem, succ = stack_def.on_place(stack, thread.droid.object, pt)
		if not succ then
			return true, true
		end

		-- play the place sound
		if stack_def.sounds
		and stack_def.sounds.place then
			minetest.sound_play(stack_def.sounds.place, {
				pos = pos,
				max_hear_distance = 10,
			})
		end

		-- set new item
		if newitem then
			thread.droid:set_wielded_item(newitem)
		end

		return true, {false, "no on_rightclick"}
	end,

	leftclick = function(params, thread)
		local wielditem = thread.droid:get_wielded_item()
		local wielditem_def = minetest.registered_items[wielditem:get_name()]
		local pointed_thing = {}
		local pos = pos_from_varname(params[1], thread.vars)
		local obj = minetest.object_refs[params[1]]
		if pos then
			pointed_thing.type = "node"
			pointed_thing.under = pos
			-- get_look_direction is not used since it only uses yaw
			pointed_thing.above = get_pt_above(pos,
					vector.direction(thread.droid:get_pos(), pos))
		elseif obj then
			pointed_thing.type = "object"
			pointed_thing.ref = obj
		else
			pointed_thing.type = "nothing"
		end
		thread.droid.is_player_currently = true
		if wielditem_def and wielditem_def.on_use then
			wielditem = wielditem_def.on_use(wielditem, thread.droid, pointed_thing)
					or wielditem -- it could return nil
			wielditem = ItemStack(wielditem)
			thread.droid:set_wielded_item(wielditem)
		elseif pos then
			local node = minetest.get_node(pos)
			local node_def = minetest.registered_nodes[node.name]
			if node_def and node_def.on_punch then
				node_def.on_punch(pos, node, thread.droid, pointed_thing)
			end
		elseif obj then
			obj:punch(thread.droid, 0, wielditem:get_tool_capabilities(),
					vector.direction(thread.droid:get_pos(), pos))
		end
		thread.droid.is_player_currently = false
		return true
	end,

	secondary_use = function(params, thread)
		local wielditem = thread.droid:get_wielded_item()
		local wielditem_def = minetest.registered_items[wielditem:get_name()]
		if not (wielditem_def and wielditem_def.on_secondary_use) then
			return true
		end
		local pointed_thing = {type = "nothing"}
		thread.droid.is_player_currently = true
		wielditem_def.on_secondary_use(wielditem, thread.droid, pointed_thing)
		thread.droid.is_player_currently = false
		return true
	end,

	drop = function(params, thread)
		local wielditem = thread.droid:get_wielded_item()
		local wielditem_def = minetest.registered_items[wielditem:get_name()]
		if not (wielditem_def and wielditem_def.on_drop) then
			return true
		end
		local count = params[1]
		if count and type(count) == "number" and count > 0 then
			wielditem:set_count(math.min(count, wielditem:get_count()))
		end
		local pos = thread.droid:get_pos()
		thread.droid.is_player_currently = true
		local inv = thread.droid:get_inventory()
		inv:remove_item("wield_item", wielditem)
		wielditem = wielditem_def.on_drop(wielditem, thread.droid, pos)
		wielditem = ItemStack(wielditem)
		wielditem = inv:add_item("wield_item", wielditem)
		if not wielditem:is_empty() then
			wielditem = inv:add_item("main", wielditem)
			if not wielditem:is_empty() then
				minetest.item_drop(wielditem, thread.droid, pos)
			end
		end
		thread.droid.is_player_currently = false
		return true
	end,

	select_item = function(params, thread)
		if not params[1]
		or type(params[1]) ~= "number" then
			return false, "number expected"
		end
		local inv = thread.droid:get_inventory()
		if not (params[1] >= 1)  -- NaN checked
		or params[1] > inv:get_size"main" then
			return false, "invalid inventory index"
		end
		local stack = inv:get_stack("main", params[1])
		inv:set_stack("main", params[1], inv:get_stack("wield_item", 1))
		inv:set_stack("wield_item", 1, stack)
		return true
	end,

	beep = function(params, thread)
		local f = params[1]
		f = type(f) == "number" and f > 0 and f or 2000
		local p = f/2000 -- 2000 Hz is the frequency of maidroid_beep.ogg.
		p = math.min(math.max(p, 0.1), 2)
		minetest.sound_play("maidroid_beep", {
			pos = thread.droid.object:get_pos(),
			pitch = p,
		})
		return true
	end,

	listen_chat = function()
		return true, {chat_last_sayer, chat_last_message}
	end,
}

-- some aliases
maidroid_instruction_set.getpos = maidroid_instruction_set.get_pos
maidroid_instruction_set.getvelocity = maidroid_instruction_set.get_velocity
maidroid_instruction_set.getacceleration  = maidroid_instruction_set.get_acceleration
maidroid_instruction_set.getyaw  = maidroid_instruction_set.get_yaw
maidroid_instruction_set.setyaw  = maidroid_instruction_set.set_yaw
maidroid_instruction_set.punch = maidroid_instruction_set.leftclick
maidroid_instruction_set.use = maidroid_instruction_set.leftclick


local function mylog(log)
	-- This happens to the maidroids messages
	minetest.chat_send_all("maidroid says " .. log)
end

-- the program is loaded from a "default:book_written" with title "main"
-- if it's not present, following program is used in lieu:
local dummycode = [[
beep
print $No book with title "main" found.
]]

local function get_code(self)
	local list = self:get_inventory():get_list"main"
	for i = 1,#list do
		local stack = list[i]
		if stack:get_name() == "default:book_written" then
			local data = stack:get_meta():to_table().fields
			if data
			and data.title == "main" then
				return data.text
			end
		end
	end
end

local function on_start(self)
	self.object:setacceleration{x = 0, y = -10, z = 0}
	self.object:setvelocity{x = 0, y = 0, z = 0}
	self.vel = {x = 0, y = 0, z = 0}
	self.vel_prev = self.vel

	local parsed_code = pdisc.parse(get_code(self) or dummycode)
	self.thread = pdisc.create_thread(function(thread)
		thread.flush = function(self)
			mylog(self.log)
			self.log = ""
			return true
		end
		table.insert(thread.is, 1, maidroid_instruction_set)
		thread.droid = self
	end, parsed_code)
	self.thread:suscitate()
end

local function on_step(self)
	local thread = self.thread
	if not thread then
		on_start(self)
		return
	end
	if not thread.stopped then
		-- Done or error now
		return
	end

	-- allow at max 1 ms executing
	local t_end = minetest.get_us_time() + 1000
	while minetest.get_us_time() < t_end do
		self.vel_prev = self.vel
		self.vel = self.object:get_velocity()

		if not thread:try_rebirth() -- ← sleeping
		or not thread.stopped then -- ← aborted
			return
		end
	end
end

local function on_resume(self)
	if self.thread.stopped then
		self.thread:continue()
	end
end

local function on_pause(self)
	self.thread:flush()
end

local function on_stop(self)
	self.thread:exit()
	self.thread = nil

	self.object:setvelocity{x = 0, y = 0, z = 0}
end

-- register a definition of a new core.
maidroid.register_core("maidroid_core:ocr", {
	description      = "OCR programmable maidroid core",
	inventory_image  = "maidroid_core_ocr.png",
	on_start         = on_start,
	on_stop          = on_stop,
	on_resume        = on_resume,
	on_pause         = on_pause,
	on_step          = on_step,
})


--[[
TODO:
* add functions for inventory
* add cheat instruction for server admins (set_node, …)
* instructions for communicating
* lots of testing
* implement farming core and the others in a book (maybe controversial)
]]
