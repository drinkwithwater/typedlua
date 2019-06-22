local tltype = require "typedlua/tltype"
local tltable = require "typedlua/tltable"
local tltAuto = require "typedlua/tltAuto"
local tltOper = require "typedlua/tltOper"

local Function = tltype.StaticFunction
local Tuple = tltype.Tuple
local VarTuple = tltype.VarTuple
local Union = tltype.Union

local Any = tltype.Any()
local String = tltype.String()
local Number = tltype.Number()
local Integer = tltype.Integer()
local Nil = tltype.Nil()
local Boolean = tltype.Boolean()

local AnyTable = tltable.AnyTable() -- TODO
local AnyBase = Union(String, Number, Boolean) -- TODO
local AnyFunction = tltype.AnyFunction()
local AnyNext = tltype.StaticFunction(Tuple(Any, Any), Tuple(Any, Any))

print("native function TODO.....")

local tltNative = {}

tltNative.inext = tltype.NativeFunction(function(visitor, vTuple)
	local nTableType = tltype.tuple_index(vTuple, 1)
	local nIndexType = tltype.tuple_index(vTuple, 2)
	print("TODO check next's arg")
	nTableType = visitor:link_refer_type(nTableType)
	if nTableType.tag == "TTable" then
		return tltable.inext_return(nTableType)
	elseif nTableType.tag == "TDefineType" or nTableType.tag == "TAutoType" then
		return tltable.inext_return(nTableType[1])
	elseif nTableType.tag == "TAny" then
		return tltype.Tuple(Integer, Any)
	else
		visitor:log_error("next iter on non-table non-any type")
		return tltype.Tuple(Integer, Any)
	end
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
		-- call input
		local nCallerType = tltype.tuple_index(vTuple, 1)
		local nArgTuple = tltype.tuple_sub(vTuple, 2)
		-- get output
		local nOutputTuple = tltOper._call(visitor, nCallerType, nArgTuple)
		-- TODO "output | (false, string)"
		return tltype.tuple_reforge({Boolean, nOutputTuple})
	end),
	next = tltype.NativeFunction(function(visitor, vTuple)
		local nTableType = tltype.tuple_index(vTuple, 1)
		local nIndexType = tltype.tuple_index(vTuple, 2)
		print("TODO check next's arg")
		if nTableType.tag == "TTable" then
			return tltable.next_return(nTableType)
		else
			if nTableType.tag ~= "TAny" then
				visitor:log_error("next iter on non-table non-any type")
			end
			return tltype.Tuple(Any, Any)
		end
	end),
	pairs = tltype.NativeFunction(function(visitor, vTuple)
		if #vTuple > 1 then
			visitor:log_warning("pairs need only one arg")
		elseif #vTuple == 0 then
			visitor:log_error("pairs need one arg")
			return tltype.VarTuple(Any)
		end
		local nTableType = tltype.first(vTuple)
		tltOper.assert_type(visitor, nTableType, AnyTable)
		-- TODO 1 union all field
		-- TODO 2 get table's meta pairs
		return tltype.Tuple(tltNative._G.next, nTableType, Nil)
	end),
	ipairs = tltype.NativeFunction(function(visitor, vTuple)
		if #vTuple > 1 then
			visitor:log_warning("pairs need only one arg")
		elseif #vTuple == 0 then
			visitor:log_error("pairs need one arg")
			return tltype.VarTuple(Any)
		end
		local nTableType = tltype.first(vTuple)
		tltOper.assert_type(visitor, nTableType, AnyTable)
		-- TODO 1 union all integer field
		-- TODO 2 get table's meta ipairs
		print("TODO for ipairs")
		return tltype.Tuple(tltNative.inext, nTableType, tltype.Literal(0))
	end),

	setmetatable = Function(Tuple(AnyTable, AnyTable), Tuple(Any)), -- TODO, interface
	getmetatable = AnyFunction,

	print = Function(Tuple(Any), Tuple(Nil)),

	tonumber = Function(Tuple(Any), Tuple(Union(Number, Nil))),
	tostring = Function(Tuple(Any), Tuple(String)),

	rawequal = Function(Tuple(Any, Any), Tuple(Boolean)),
	rawlen = Function(Tuple(Union(AnyTable, String)), Tuple(Number)),
	rawget = Function(Tuple(AnyTable, Any), Tuple(Any)), -- TODO
	rawset = Function(Tuple(AnyTable, Any), Tuple(Any)), -- TODO

	assert = Function(Tuple(Any)), -- TODO
	error = Function(Tuple(Union(Number, String))),

	require = Function(Tuple(String), Tuple(Any)), -- TODO
	dofile = Function(Tuple(String)), -- TODO
	loadfile = Function(Tuple(String)), -- TODO
	load = Function(Tuple(String)),

	select = Function(Tuple(Number, Any)), -- TODO
	type = Function(Tuple(Any), Tuple(String)),
	collectgarbage = Function(Tuple(Any)), -- TODO
}

return tltNative
