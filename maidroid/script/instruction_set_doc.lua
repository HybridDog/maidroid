-- See also the pdisc mod's instruction list.

local instr = {
	{"getpos", "<s posname>", 'Gets the current position. (Stored in {x=vars[posname .. ".x"], y=[…]})'},
	{"getvelocity", "<s velname>", "Gets the maidroid's velocity."},
	{"getacceleration", "<s accname>", "Gets the maidroid's acceleration."},
	{"getyaw", "<v yaw>", "Gets the maidroid's yaw."},


	{"setyaw", "<n yaw>", "Sets the maidroid's yaw in radians."},

	{"setwalk", "[<n speed>]", "Starts walking n m/s to the current direction. If speed is omitted, the maidroid stops. maximum speed: 5"},
	{"dig", "<s posname>[, <v errormsg>]", "Digs a node, if posname is a variable, it is set to a bool indicating whether the dig succeeded. If false, errormsg tells the reason."},
	{"jump", "[<n heigth>]", "Makes the droid jump, if height is invalid (height ∈ ]0,2]), it's set to 1, if it's a variable, it's set to a bool indicating whether the jump succeeded."},
	{"beep", "", "Execute this every second while the droid walks backwards, pls."},
}

o = "Instructions:\n\n"
for i = 1,#instr do
	i = instr[i]
	o = o .. i[1] .. "  " .. i[2] .. "\n"
		.. "  " .. i[3] .. "\n\n" -- TODO: max 80 letters each line
end

print(o)
