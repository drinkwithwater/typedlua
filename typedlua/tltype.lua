--[[
This module implements Typed Lua tltype.
]]

local tlutils = require "typedlua.tlutils"
local seri = require "typedlua.seri"
if not table.unpack then table.unpack = unpack end

local tltype = {}

tltype.integer = false

-- literal types

-- Literal : (boolean|number|string) -> (type)
function tltype.Literal (l)
  return { tag = "TLiteral", [1] = l }
end

-- False : () -> (type)
function tltype.False ()
  return tltype.Literal(false)
end

-- True : () -> (type)
function tltype.True ()
  return tltype.Literal(true)
end

-- Num : (number) -> (type)
function tltype.Num (n)
  return tltype.Literal(n)
end

-- Str : (string) -> (type)
function tltype.Str (s)
  return tltype.Literal(s)
end

-- isLiteral : (type) -> (boolean)
function tltype.isLiteral (t)
  return t.tag == "TLiteral"
end

-- isFalse : (type) -> (boolean)
function tltype.isFalse (t)
  return tltype.isLiteral(t) and t[1] == false
end

-- isTrue : (type) -> (boolean)
function tltype.isTrue (t)
  return tltype.isLiteral(t) and t[1] == true
end

-- isNum : (type) -> (boolean)
function tltype.isNum (t)
  return tltype.isLiteral(t) and type(t[1]) == "number"
end

-- isFloat : (type) -> (boolean)
function tltype.isFloat (t)
  if _VERSION == "Lua 5.3" then
    return tltype.isLiteral(t) and math.type(t[1]) == "float"
  else
    return false
  end
end

-- isInt : (type) -> (boolean)
function tltype.isInt (t)
  if _VERSION == "Lua 5.3" then
    return tltype.isLiteral(t) and math.type(t[1]) == "integer"
  else
    return false
  end
end

-- isStr : (type) -> (boolean)
function tltype.isStr (t)
  return tltype.isLiteral(t) and type(t[1]) == "string"
end

function tltype.isProj (t)
  return t.tag == "TProj"
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

-- isBase : (type) -> (boolean)
function tltype.isBase (t)
  return t.tag == "TBase"
end

-- isBoolean : (type) -> (boolean)
function tltype.isBoolean (t)
  return tltype.isBase(t) and t[1] == "boolean"
end

-- isNumber : (type) -> (boolean)
function tltype.isNumber (t)
  return tltype.isBase(t) and t[1] == "number"
end

-- isString : (type) -> (boolean)
function tltype.isString (t)
  return tltype.isBase(t) and t[1] == "string"
end

-- isInteger : (type) -> (boolean)
function tltype.isInteger (t)
  return tltype.isBase(t) and t[1] == "integer"
end

-- nil type

-- Nil : () -> (type)
function tltype.Nil ()
  return { tag = "TNil" }
end

-- isNil : (type) -> (boolean)
function tltype.isNil (t)
  return t.tag == "TNil"
end

-- value type

-- Value : () -> (type)
function tltype.Value ()
  return { tag = "TValue" }
end

-- isValue : (type) -> (boolean)
function tltype.isValue (t)
  return t.tag == "TValue"
end

-- dynamic type

-- Any : () -> (type)
function tltype.Any ()
  return { tag = "TAny" }
end

-- isAny : (type) -> (boolean)
function tltype.isAny (t)
  return t.tag == "TAny"
end

-- self type

-- Self : () -> (type)
function tltype.Self ()
  return { tag = "TSelf" }
end

-- isSelf : (type) -> (boolean)
function tltype.isSelf (t)
  return t.tag == "TSelf"
end

-- union types

-- Union : (type*) -> (type)
function tltype.Union (...)
  local l1 = {...}
  -- remove unions of unions
  local l2 = {}
  for i = 1, #l1 do
    if tltype.isUnion(l1[i]) or tltype.isUnionlist(l1[i]) then
      for j = 1, #l1[i] do
        table.insert(l2, l1[i][j])
      end
    else
      table.insert(l2, l1[i])
    end
  end
  if #l2 == 1 then -- short circuit
    return l2[1]
  end
  -- remove duplicates
  local l3 = {}
  for i = 1, #l2 do
    local enter = true
    for j = i + 1, #l2 do
      if tltype.subtype(l2[i], l2[j]) and tltype.subtype(l2[j], l2[i]) then
        enter = false
        break
      end
    end
    if enter then table.insert(l3, l2[i]) end
  end
  if #l3 == 1 then -- short circuit
    return l3[1]
  end
  -- simplify union
  local t = { tag = "TUnion" }
  for i = 1, #l3 do
    local enter = true
    for j = 1, #l3 do
      if i ~= j and not tltype.isAny(l3[i]) and tltype.consistent_subtype(l3[i], l3[j]) then
        enter = false
        break
      end
    end
    if enter then table.insert(t, l3[i]) end
  end
  if #t == 0 then
    return tltype.Void()
  elseif #t == 1 then
    return t[1]
  else
    if tltype.isTuple(t[1]) then
      t.tag = "TUnionlist"
    end
    return t
  end
end

-- isUnion : (type, type?) -> (boolean)
function tltype.isUnion (t1, t2)
  if not t2 then
    return t1.tag == "TUnion"
  else
    if t1.tag == "TUnion" then
      for _, v in ipairs(t1) do
        if tltype.subtype(t2, v) and tltype.subtype(v, t2) then
          return true
        end
      end
      return false
    else
      return false
    end
  end
end

-- filterUnion : (type, type) -> (type)
function tltype.filterUnion (u, t)
  if tltype.isUnion(u) then
    local l = {}
    for _, v in ipairs(u) do
      if not (tltype.subtype(t, v) and tltype.subtype(v, t)) then
        table.insert(l, v)
      end
    end
    return tltype.Union(table.unpack(l))
  else
    return u
  end
end

-- UnionNil : (type, true?) -> (type)
function tltype.UnionNil (t, is_union_nil)
  if is_union_nil then
    return tltype.Union(t, tltype.Nil())
  else
    return t
  end
end

-- vararg types

-- Vararg : (type) -> (type)
function tltype.Vararg (t)
  return { tag = "TVararg", [1] = t, name = t.name and t.name .. "*" }
end

-- isVararg : (type) -> (boolean)
function tltype.isVararg (t)
  return t.tag == "TVararg"
end

-- tuple types

-- Tuple : ({number:type}, true?) -> (type)
function tltype.Tuple (l, is_vararg)
  if is_vararg then
    l[#l] = tltype.Vararg(l[#l])
  end
  return { tag = "TTuple", table.unpack(l) }
end

-- void type

-- Void : () -> (type)
function tltype.Void ()
  return { tag = "TVoid" }
end

-- isVoid : (type) -> (boolean)
function tltype.isVoid (t)
  return t.tag == "TVoid"
end

-- inputTuple : (type?, boolean) -> (type)
function tltype.inputTuple (t, strict)
  if not strict then
    if not t then
      return tltype.Tuple({ tltype.Value() }, true)
    else
      if not tltype.isVararg(t[#t]) then
        table.insert(t, tltype.Vararg(tltype.Value()))
      end
      return t
    end
  else
    if not t then
      return tltype.Tuple({ tltype.Nil() }, true)
    else
      if not tltype.isVararg(t[#t]) then
        table.insert(t, tltype.Vararg(tltype.Nil()))
      end
      return t
    end
  end
end

-- outputTuple : (type?, boolean) -> (type)
function tltype.outputTuple (t)
  if not t then
    return tltype.Tuple({ tltype.Nil() }, true)
  else
    if not tltype.isVararg(t[#t]) then
      table.insert(t, tltype.Vararg(tltype.Nil()))
    end
    return t
  end
end

-- retType : (type, boolean) -> (type)
function tltype.retType (t)
  return tltype.outputTuple(tltype.Tuple({ t }))
end

-- isTuple : (type) -> (boolean)
function tltype.isTuple (t)
  return t.tag == "TTuple"
end

-- union of tuple types

-- Unionlist : (type*) -> (type)
function tltype.Unionlist (...)
  local t = tltype.Union(...)
  if tltype.isUnion(t) then t.tag = "TUnionlist" end
  return t
end

-- isUnionlist : (type) -> (boolean)
function tltype.isUnionlist (t)
  return t.tag == "TUnionlist"
end

function tltype.Proj(label, idx)
  return { tag = "TProj", label, idx }
end

-- UnionlistNil : (type, boolean?) -> (type)
function tltype.UnionlistNil (t, is_union_nil)
  if type(is_union_nil) == "boolean" then
    local u = tltype.Tuple({ tltype.Nil(), tltype.String() })
    return tltype.Unionlist(t, tltype.outputTuple(u))
  else
    return t
  end
end

-- function types

-- Function : (type, type, true?) -> (type)
function tltype.Function (t1, t2, is_method)
  if is_method then
    table.insert(t1, 1, tltype.Self())
  end
  return { tag = "TFunction", [1] = t1, [2] = t2 }
end

function tltype.isFunction (t)
  return t.tag == "TFunction"
end

function tltype.isMethod (t)
  if tltype.isFunction(t) then
    for _, v in ipairs(t[1]) do
      if tltype.isSelf(v) then return true end
    end
    return false
  else
    return false
  end
end

-- table types

-- Field : (boolean, type, type) -> (field)
function tltype.Field (is_const, t1, t2)
  return { tag = "TField", const = is_const, [1] = t1, [2] = t2 }
end

-- isField : (field) -> (boolean)
function tltype.isField (f)
  return f.tag == "TField" and not f.const
end

-- isConstField : (field) -> (boolean)
function tltype.isConstField (f)
  return f.tag == "TField" and f.const
end

-- ArrayField : (boolean, type) -> (field)
function tltype.ArrayField (i, t)
  return tltype.Field(false, tltype.Integer(i), t)
end

--[[
interface Table
	tag:string
	open:boolean?
	unique:boolean?
	name:string?

	--!cz
	file:string?

	Field
	record_dict:{string:integer}
	hash_list:{integer:integer}
end
]]

-- Table : (field*) -> (type)
function tltype.Table (...)
  local nTableType = { tag = "TTable", record_dict={}, hash_list={}, ... }
  local nRecordDict = nTableType.record_dict
  local nHashList = nTableType.hash_list
  for i, nField in ipairs(nTableType) do
	  local nFieldKey = nField[1]
	  if tltype.isLiteral(nFieldKey) then
		  assert(not nRecordDict[nFieldKey[1]], "TLiteral key use twice")
		  nRecordDict[nFieldKey[1]] = i
	  else
		  nHashList[#nHashList + 1] = i
	  end
  end
  return nTableType
end

-- isTable : (type) -> (boolean)
function tltype.isTable (t)
  return t.tag == "TTable"
end

-- fieldlist : ({ident}, type) -> (field*)
function tltype.fieldlist (idlist, t)
  local l = {}
  for _, v in ipairs(idlist) do
    table.insert(l, tltype.Field(v.const, tltype.Literal(v[1]), t))
  end
  return table.unpack(l)
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

function tltype.general (t)
	error("TODO, tltype.general")
end

function tltype.first (t)
	error("TODO, tltype.first")
end

-- tostring : (type) -> (string)
function tltype.tostring (t, n)
	error("TODO, tltype.tostring")
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

local tlrelation = nil
function tltype.subtype(vLeft, vRight)
	local nRelation = tlrelation or (require "typedlua/tlrelation")
	return nRelation.sub(vLeft, vRight)
end

function tltype.consistent_subtype(vLeft, vRight)
	local nRelation = tlrelation or (require "typedlua/tlrelation")
	return nRelation.sub(vLeft, vRight)
end

-- Built-in functions

--[[
local tanyany = tltype.Table(tltype.Field(false, tltype.Any(), tltype.Any()))

tltype.primtypes = {
  ["type"] = tltype.Function(tltype.inputTuple(tltype.Tuple{tltype.Value()}), tltype.outputTuple(tltype.Tuple{tltype.String()})),
  ["math_type"] = tltype.Function(tltype.inputTuple(tltype.Tuple{tltype.Value()}), tltype.outputTuple(tltype.Tuple{tltype.Union(tltype.String(),tltype.Nil())})),
  ["assert"] = tltype.Function(tltype.inputTuple(tltype.Tuple{tltype.Value(), tltype.Vararg(tltype.Value())}), tltype.outputTuple(tltype.Tuple{tltype.Vararg(tltype.Value())})),
  ["error"] = tltype.Function(tltype.inputTuple(tltype.Tuple{tltype.Value(), tltype.Union(tltype.Integer(), tltype.Nil())}), tltype.Void()),
  ["require"] = tltype.Function(tltype.inputTuple(tltype.Tuple{tltype.String()}), tltype.outputTuple(tltype.Tuple{tltype.Value()})),
  ["setmetatable"] = tltype.Function(tltype.inputTuple(tltype.Tuple{tanyany, tltype.Union(tanyany, tltype.Nil())}), tltype.outputTuple(tltype.Tuple{tanyany}))
}
]]

return tltype
