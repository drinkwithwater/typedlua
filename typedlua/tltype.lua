--[[
This module implements Typed Lua tltype.
]]

--local tlutils = require "typedlua.tlutils"
--local seri = require "typedlua.seri"

local tltype = {}
local tltRelation = require "typedlua/tltRelation"

-- TODO maybe no integer for 5.2 or 5.1
tltype.integer = true

-- literal types

--@ (boolean|number|string) -> auto
function tltype.Literal (vValue)
	return {
		tag = "TLiteral",
		[1] = vValue
	}
end

-- base types

-- Base : ("boolean"|"number"|"string") -> (type)
function tltype.Base (s)
  return { tag = "TBase", [1] = s }
end

-- Boolean : () -> (type)
function tltype.Boolean ()
  return tltype.Base("boolean")
end

-- Number : () -> (type)
function tltype.Number ()
  return tltype.Base("number")
end

-- String : () -> (type)
function tltype.String ()
  return tltype.Base("string")
end

-- Integer : (boolean?) -> (type)
function tltype.Integer ()
	if _VERSION == "Lua 5.3" then
		return tltype.Base("integer")
	else
		return tltype.Base("number")
	end
  -- if i then return tltype.Base("integer") else return tltype.Base("number") end
end

-- Nil : () -> (type)
function tltype.Nil ()
	  return { tag = "TNil", sub_tag = "TExplictNil" }
end

function tltype.ImplictNil()
	  return { tag = "TNil", sub_tag = "TImplictNil"}
end

-- Any : () -> (type)
function tltype.Any ()
  return { tag = "TAny" }
end

-- tuple types
function tltype.VarTuple(...)
	assert(select("#", ...) >= 1, "VarTuple's length can't be 0")
	return { tag = "TTuple", sub_tag = "TVarTuple", ...  }
end

-- Tuple : ({number:type}, true?) -> (type)
function tltype.Tuple (...)
  return { tag = "TTuple", ... }
end

function tltype.tuple_index(vTuple, vIndex)
	assert(vTuple.tag == "TTuple")
	if vIndex <= #vTuple then
		return vTuple[vIndex]
	else
		if vTuple.sub_tag == "TVarTuple" then
			return vTuple[#vTuple]
		else
			return tltype.Nil()
		end
	end
end

function tltype.tuple_sub(vTuple, vIndex)
	assert(vTuple.tag == "TTuple", "tuple_sub for unexcept type "..tostring(vTuple.tag))
	if vTuple.sub_tag == "TVarTuple" then
		if vIndex <= #vTuple then
			return tltype.VarTuple(select(vIndex, table.unpack(vTuple)))
		else
			return tltype.VarTuple(vTuple[#vTuple])
		end
	else
		return tltype.Tuple(select(vIndex, table.unpack(vTuple)))
	end
end

function tltype.tuple_reforge(vInputTypeList)
	local nTupleType = tltype.Tuple()
	local nLength = #vInputTypeList
	-- #vInputTypeList = 0 return ()
	if nLength <= 0 then
		return nTupleType
	end
	local nLastType = vInputTypeList[nLength]
	-- 1...n-1 merge and return
	for i = 1, nLength - 1 do
		nTupleType[i] = tltype.first(vInputTypeList[i])
	end

	if nLastType.tag == "TTuple" then
		-- if type1,type2,...,type3,tuple return {type1,type2,...,type3,table.unpack(tuple)}
		for i=1, #nLastType do
			nTupleType[nLength + i - 1] = nLastType[i]
		end

		if nLastType.sub_tag == "TVarTuple" then
			nTupleType.sub_tag = "TVarTuple"
		end
	else
		-- if type1,type2,...,type3,type4 return {type1,type2,...,type3,type4}
		nTupleType[nLength] = nLastType
	end

	return nTupleType
end

-- function types
function tltype.AnyFunction()
	return {tag = "TFunction", sub_tag = "TAnyFunction"}
end

function tltype.FunctionConstructor(vInputTuple, vOutputTuple)
	return {tag = "TFunction", sub_tag = "TUnknownFunction", [1] = vInputTuple, [2] = vOutputTuple}
end

-- Function : (type, type) -> (type)
function tltype.StaticFunction (vInputTuple, vOutputTuple)
  return { tag = "TFunction", sub_tag = "TStaticFunction", [1] = vInputTuple, [2] = vOutputTuple }
end

function tltype.NativeFunction(vNativeFunction)
	return {tag = "TFunction", sub_tag = "TNativeFunction", caller = vNativeFunction}
end

-- type define

-- define: (string) -> (type)
function tltype.Define(vName, vType)
  return { tag = "TDefineType", name=vName, vType}
end

function tltype.DefineRefer(vName)
	return { tag = "TDefineRefer", name=vName}
end

function tltype.first(vType)
	if vType.tag == "TTuple" then
		return vType[1] or tltype.Nil()
	else
		return vType
	end
end

-- other functions

tltype.to_base_detail = tltRelation.to_base_detail

function tltype.general(vType)
	if vType.tag == "TLiteral" then
		return tltype.Base(tltype.to_base_detail(vType[1]))
	else
		return vType
	end
end

local formatterDict ={
	TUnionType		= function(vUnionType)
		local nList = {}
		for i, vType in ipairs(vUnionType) do
			nList[#nList + 1] = tltype.tostring(vType)
		end
		return table.concat(nList, "|")
	end,
	TUnionDeduce	= function(vUnionState)
		return "UnionDeduceTODO"
	end,
	TAny			= function(vType)
		return "any"
	end,

	TLiteral		= function(vType)
		return string.format("%q", vType[1])
	end,
	TBase			= function(vType)
		return vType[1]
	end,
	TNil			= function(vType)
		return "nil"
	end,
	TTable			= function(vType)
		return vType.sub_tag or vType.tag
	end,
	TFunction		= function(vType)
		return tltype.tostring(vType[1]).."->"..tltype.tostring(vType[2])
	end,
	TTuple			= function(vTuple)
		local nList = {}
		for i, vType in ipairs(vTuple) do
			nList[#nList + 1] = tltype.tostring(vType)
		end
		return "("..table.concat(nList, ",")..")"
	end,
	TDefineType		= function(vType)
		return "definetype"
	end,
	TAutoType		= function(vType)
		return vType.sub_tag
	end,
	TDefineRefer		= function(vType)
		return vType.name
	end,
	TAutoLink		= function(vTuple)
		return "autostrTODO"
	end
}

function tltype.tostring (vType)
	local nFunc = assert(formatterDict[vType.tag], "type formatter not found"..vType.tag)
	return vType.tag.."`"..nFunc(vType).."`"
end

return tltype
