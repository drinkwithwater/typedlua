local tltype = require "typedlua/tltype"
local tltable = require "typedlua/tltable"
local tltAuto = require "typedlua/tltAuto"
local tltOper = require "typedlua/tltOper"


local tltNative = {}

tltNative.inext = tltype.NativeFunction(function(visitor, vTuple)
end)

tltNative._G = {
	xpcall = tltype.NativeFunction(function(visitor, vTuple)
		-- call input
		local nCallerType = tltype.tuple_index(vTuple, 1)
		local nMsgHandler = tltype.tuple_index(vTuple, 2)
		tltOper.assert_type(visitor, nMsgHandler, AnyFunction)
		local nArgTuple = tltype.tuple_sub(vTuple, 3)


		-- get output
		local nOutputTuple = tltOper._call(visitor, nCallerType, nArgTuple)
		-- TODO "output | (false, string)"
		return tltype.tuple_reforge({Boolean, nOutputTuple})
	end),
	pcall = tltype.NativeFunction(function(visitor, vTuple)
	end),
	next = tltype.NativeFunction(function(visitor, vTuple)
	end),
	pairs = tltype.NativeFunction(function(visitor, vTuple)
	end),
	ipairs = tltype.NativeFunction(function(visitor, vTuple)
	end),

	setmetatable = tltype.NativeFunction(function()
	end),
	getmetatable = tltype.NativeFunction(function()
	end),

	print = tltype.NativeFunction(function()
	end),

	tonumber = tltype.NativeFunction(function()
	end),
	tostring = tltype.NativeFunction(function()
	end),

	rawequal = tltype.NativeFunction(function()
	end),
	rawlen = tltype.NativeFunction(function() end),
	rawget = tltype.NativeFunction(function() end),
	rawset = tltype.NativeFunction(function() end),

	assert = tltype.NativeFunction(function() end),
	error = tltype.NativeFunction(function() end),

	require = tltype.NativeFunction(function() end),
	dofile = tltype.NativeFunction(function() end),
	loadfile = tltype.NativeFunction(function() end),
	load = tltype.NativeFunction(function() end),

	select = tltype.NativeFunction(function() end),
	type = tltype.NativeFunction(function() end),
	collectgarbage = tltype.NativeFunction(function() end),
}

return tltNative
