--[[
This module implements Typed Lua tltype.
]]

--local tlutils = require "typedlua.tlutils"
--local seri = require "typedlua.seri"

local tltype = {}
local tltRelation = require "typedlua/tltRelation"

tltype.integer = true

-- literal types

--@ (boolean|number|string) -> auto
function tltype.Literal (vValue)
	return { tag = "TLiteral", [1] = vValue }
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
  return { tag = "TNil" }
end

-- Any : () -> (type)
function tltype.Any ()
  return { tag = "TAny" }
end

-- union types

-- Union : (type*) -> (type)
function tltype.Union (...)
	if select("#", ...) == 1 then
		return ...
	end
	local nTypeList = {...}
	local nUnionType = {tag = "TUnion"}
	for i, nType in ipairs(nTypeList) do
		local nRightList = nType
		if nType.tag ~= "TUnion" then
			nRightList = {nType}
		end
		for j, nRightType in ipairs(nRightList) do
			local nFullContain = false
			local nFullBelong = false
			for k, nLeftType in ipairs(nUnionType) do
				-- right in left, do nothing
				local nLeftContainRight = tltRelation.contain(nLeftType, nRightType)
				if nLeftContainRight == tltRelation.CONTAIN_FULL then
					nFullContain = true
				end
				-- left in right, replace left with right
				local nRightContainLeft = tltRelation.contain(nRightType, nLeftType)
				if nRightContainLeft == tltRelation.CONTAIN_FULL then
					nFullBelong = k
				end
				if nLeftContainRight == tltRelation.CONTAIN_PART
					and nRightContainLeft == tltRelation.CONTAIN_PART then
					print("union type in unimplement case")
				end
			end
			if not nFullContain then
				if nFullBelong then
					nUnionType[nFullBelong] = nRightType
				else
					nUnionType[#nUnionType + 1] = nRightType
				end
			end
		end
	end
	return nUnionType
end

-- UnionNil : (type, true?) -> (type)
function tltype.UnionNil (t, is_union_nil)
  if is_union_nil then
    return tltype.Union(t, tltype.Nil())
  else
    return t
  end
end

-- tuple types
function tltype.VarTuple(...)
	return { tag = "TTuple", sub_tag = "TVarTuple", ...  }
end

-- Tuple : ({number:type}, true?) -> (type)
function tltype.Tuple (...)
  return { tag = "TTuple", ... }
end

function tltype.tuple_index(vTuple, vIndex)
	if vTuple.sub_tag == "TVarTuple" then
		if #vTuple <= vIndex then
			return vTuple[vIndex]
		else
			return vTuple[#vTuple]
		end
	else
		return vTuple[vIndex]
	end
end

-- function types

-- Function : (type, type) -> (type)
function tltype.Function (t1, t2)
  return { tag = "TFunction", [1] = t1, [2] = t2 }
end

-- type variables

-- Variable : (string) -> (type)
function tltype.Variable (name)
  return { tag = "TVariable", [1] = name }
end

-- isVariable : (type) -> (boolean)
function tltype.isVariable (t)
  return t.tag == "TVariable"
end

-- global type variables

-- GlobalVariable : (string) -> (type)
function tltype.GlobalVariable (env, name, pos, typeerror, namespace)
  return { tag = "TGlobalVariable", [1] = name} --, [2] = env, [3] = pos, [4] = typeerror, [5] = namespace }
end

-- isVariable : (type) -> (boolean)
function tltype.isGlobalVariable (t)
  return t.tag == "TGlobalVariable"
end

function tltype.setGlobalVariable(t, env, pos, typeerror, namespace)
  t.tag = "TGlobalVariable"
  --[[
  t[2] = env
  t[3] = pos
  t[4] = typeerror
  t[5] = namespace]]
end

-- Primitive functions

function tltype.Prim (name)
  return { tag = "TPrim", [1] = name, [2] = tltype.primtypes[name] }
end

function tltype.isPrim (t)
  return t.tag == "TPrim"
end

function tltype.typeerror (env, tag, msg, pos)
  local function lineno (s, i)
    if i == 1 then return 1, 1 end
    local rest, num = s:sub(1,i):gsub("[^\n]*\n", "")
    local r = #rest
    return 1 + num, r ~= 0 and r or 1
  end

  local l, c = lineno(env.subject, pos)
  local error_msg = { tag = tag, filename = env.filename, msg = msg, l = l, c = c }
  for i, v in ipairs(env.messages) do
    if l < v.l or (l == v.l and c < v.c) then
      table.insert(env.messages, i, error_msg)
      return
    end
  end
  table.insert(env.messages, error_msg)
end

function tltype.error(env, node, msg)
  local error_msg = { tag = "error", filename = env.filename, msg = msg, l = node.l, c = node.c }
  for i, v in ipairs(env.messages) do
    if l < v.l or (l == v.l and c < v.c) then
      table.insert(env.messages, i, error_msg)
      return
    end
  end
  table.insert(env.messages, error_msg)
end

function tltype.first(vType)
	if vType.tag == "TTuple" then
		return vType[1]
	else
		return vType
	end
end

tltype.to_base_detail = tltRelation.to_base_detail

function tltype.general(vType)
	if vType.tag == "TLiteral" then
		return tltype.Base(tltype.to_base_detail(vType[1]))
	else
		return vType
	end
end

local formatterDict ={
	TGlobalVariable	= function(vType)
		return string.format("TGlobalVariable(%s)", vType[1])
	end,
	TUnion			= function(vUnionType)
		local nList = {}
		for i, vType in ipairs(vUnionType) do
			nList[#nList + 1] = tltype.tostring(vType)
		end
		return table.concat(nList, "|")
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
	TAutoLink		= function(vTuple)
		return "autostrTODO"
	end
}

function tltype.tostring (vType)
	local nFunc = formatterDict[vType.tag]
	return vType.tag.."`"..nFunc(vType).."`"
end

return tltype
