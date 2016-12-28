------------------------------------------------------------
-- Copyright (c) 2016 tacigar. All rights reserved.
-- https://github.com/tacigar/maidroid
------------------------------------------------------------

local maidroid_instruction_set = {
	getpos = function(_, thread)
		local pos = thread.droid.object:getpos()
		return true, {pos.x, pos.y, pos.z}
	end,

	beep = function(_, thread)
		minetest.sound_play("maidroid_beep", {pos = thread.droid.object:getpos()})
		return true
	end,

	getyaw = function(_, thread)
		return true, thread.droid.object:getyaw()
	end,

	setyaw = function(params, thread)
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
}


local function mylog(log)
	-- This happens to the maidroids messages
	minetest.chat_send_all("maidroid says " .. log)
end

-- the program should come from default written book into disk
local parsed_code = pdisc.parse[[
mov yaw_rot,pi
mul yaw_rot,0.6
add pi,pi; this is not read only

loop_start:
	get_us_time beep; var and cmd name can both be same
	beep
	sleep 0.5

	getyaw yaw
	add yaw,yaw_rot; rotate the droid a bit
	mod yaw,pi; pi is 2π
	setyaw yaw

	get_us_time timediff
	neg beep
	add timediff,beep

	neg timediff
	add timediff,1
	sleep timediff; should continue 1s after previous beep
jmp loop_start
]]

local function on_start(self)
--~ print"start"
	self.object:setacceleration{x = 0, y = -10, z = 0}
	self.object:setvelocity{x = 0, y = 0, z = 0}

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
	if thread.stopped then
		thread:try_rebirth()
	end
end

local function on_resume(self)
self.object:remove()
--~ print"resume"
	self.thread:continue()
end

local function on_stop(self)
--~ print"stop"
	self.thread:exit()

	self.object:setvelocity{x = 0, y = 0, z = 0}
end

-- register a definition of a new core.
maidroid.register_core("maidroid_core:custom", {
	description      = "programmed maidroid core",
	inventory_image  = "maidroid_core_basic.png",
	on_start         = on_start,
	on_stop          = on_stop,
	on_resume        = on_resume,
	on_pause         = on_stop,
	on_step          = on_step,
})
