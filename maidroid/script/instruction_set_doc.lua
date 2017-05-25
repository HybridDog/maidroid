-- See also the pdisc mod's instruction list.

local instr = {
	{"getpos", "<s posname>", 'Gets the current position. (Stored in {x=vars[posname .. ".x"], y=[…]})'},
	{"getvelocity", "<s velname>", "Gets the maidroid's velocity."},
	{"getacceleration", "<s accname>", "Gets the maidroid's acceleration."},
	{"getyaw", "<v yaw>", "Gets the maidroid's yaw."},

	{"get_node", "<s posname>", 'Gets the node at posname, name, param2 etc. are stored in vars[posname .. ".name" etc.]. The maximum range depends on the tool.'},
	{"get_nodedef", "<vs nodename>, <vs deftblname>", "Copies some fields of nodename's node definition, e.g. ${deftblname}.walkable := minetest.registered_nodes[nodename].walkable. If the node is unknown, nodename is set to false. For a list of supported fields, look at maidroid_core/cores/ocr.lua."},
	{"get_item_group", "<vs name>, <s group>", "Sets name to the minetest.get_item_group(name, group)."},

	{"setyaw", "<n yaw>", "Sets the maidroid's yaw in radians."},

	{"jump", "[<n heigth>]", "Makes the droid jump, if height is invalid (height ∈ ]0,2]), it's set to 1, if it's a variable, it's set to a bool indicating whether the jump succeeded."},
	{"setwalk", "[<n speed>]", "Starts walking n m/s to the current direction. If speed is omitted, the maidroid stops. maximum speed: 5"},
	{"dig", "<s posname>[, <v errormsg>]", "Digs a node, if posname is a variable, it is set to a bool indicating whether digging succeeded. If false, errormsg tells the reason."},
	{"place", "<s posname>[, <v errormsg>]", "Places a node, if posname is a variable, it is set to a bool indicating whether placing succeeded. If false, errormsg tells the reason."},
	{"select_item", "<index>", "Swaps the currently wielded item with the item at place <index> in the main inventory."},
	{"beep", "", "Execute this every second while the droid walks backwards, pls."},
}

o = "Instructions:\n\n"
for i = 1,#instr do
	i = instr[i]
	o = o .. i[1] .. "  " .. i[2] .. "\n"
		.. "  " .. i[3] .. "\n\n" -- TODO: max 80 letters each line
end

print(o)
