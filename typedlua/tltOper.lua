
local tltype = require "typedlua/tltype"
local tltRelation = require "typedlua/tltRelation"
local tltable = require "typedlua/tltable"
local tlutils = require "typedlua/tlutils"
local tltOper = {}

function tltOper.assert_type(visitor, vType, vMustType)
	if not tltRelation.contain(vMustType, vType) then
		visitor:log_error(tltype.tostring(vType), "can't belong to", tltype.tostring(vMustType))
		return false
	else
		return true
	end
end

function tltOper._return(visitor, vFunctionNode, vTupleType)
	local nFunctionType = visitor:link_refer_type(vFunctionNode.type)
	if nFunctionType.sub_tag == "TFunctionAuto" then
		-- auto set type
		print("TODO return for multi value")
		nFunctionType[1][2] = vTupleType
	else
		print("TODO check type")
		-- check type
	end
end

function tltOper._reforge_tuple(visitor, vExpListNode)
	local nInputTypeList = {}
	for i, nNode in ipairs(vExpListNode) do
		nInputTypeList[i] = assert(nNode.type)
	end
	return tltype.tuple_reforge(nInputTypeList)
end

function tltOper._relink_tuple(visitor, vArgTuple)
	local nNewTuple
	if vArgTuple.sub_tag == "TVarTuple" then
		nNewTuple = tltype.VarTuple(table.unpack(vArgTuple))
	else
		nNewTuple = tltype.Tuple(table.unpack(vArgTuple))
	end

	for i, nType in ipairs(nNewTuple) do
		nNewTuple[i] = visitor:link_refer_type(nType)
	end
	return nNewTuple
end

function tltOper._call(visitor, vCallerType, vArgTuple)
	local nFunctionType = visitor:link_refer_type(vCallerType)
	local nInputTuple = tltOper._relink_tuple(visitor, vArgTuple)
	if nFunctionType.tag == "TFunction" then
		print("TODO tltOper._call check and cast args")
		if nFunctionType.sub_tag == "TNativeFunction" then
			return nFunctionType.caller(visitor, nInputTuple)
		elseif nFunctionType.sub_tag == "TStaticFunction" then
			return nFunctionType[2]
		elseif nFunctionType.sub_tag == "TAnyFunction" then
			return tltype.VarTuple(tltype.Any())
		else
			visitor:log_error("function sub_tag exception", nFunctionType.sub_tag)
		end
	elseif nFunctionType.tag == "TDefineType" then
		print("define typeTODO")
	elseif nFunctionType.tag == "TAutoType" then
		return visitor:oper_auto_call(vCallerType, nInputTuple)
	elseif nFunctionType.tag == "TAny" then
		visitor:log_wany("call any")
		return tltype.VarTuple(tltype.Any())
	else
		visitor:log_error(tltype.tostring(nFunctionType), "is not function type")
		return tltype.Tuple(tltype.Nil())
	end
end

function tltOper.pindex_field(visitor, vPrefixType, vKeyType)
	local nTypeTag = vPrefixType.tag

	if nTypeTag == "TTable" then
		return true, tltable.index_field(vPrefixType, vKeyType)
	elseif nTypeTag == "TAny" then
		return true, tltable.Field(tltype.Any(), tltype.Any())
	elseif nTypeTag == "TBase" then
		return false, "TODO may index for string"

	elseif nTypeTag == "TDefineRefer" or nTypeTag == "TAutoLink" then
		vPrefixType = visitor:link_refer_type(vPrefixType)
		return tltOper.pindex_field(visitor, vPrefixType[1], vKeyType)
	elseif nTypeTag == "TDefineType" or nTypeTag == "TAutoType" then
		return tltOper.pindex_field(visitor, vPrefixType[1], vKeyType)

	elseif nTypeTag == "TUnion" then
		return false, "TODO index TUnion not implement"
	else
		return false, "TODO index valid typetag="..tostring(nTypeTag)
	end
end

function tltOper._index_get(visitor, vPrefixType, vKeyType)
	local nOkay, nField = tltOper.pindex_field(visitor, vPrefixType, vKeyType)
	if not nOkay then
		visitor:log_error(nField)
		return tltype.Any()
	else
		if not nField then
			visitor:log_warning("index a nil field")
			return tltype.Nil()
		else
			return nField[2]
		end
	end
end

-- TODO think which one is better ... -- no return
function tltOper._index_set(visitor, vPrefixType, vKeyType, vValueType, vLeftDeco)
	local nRightType = tltype.Nil()
	if not vValueType then
		visitor:log_warning("set assign missing")
	else
		nRightType = tltype.general(vValueType)
	end
	local nPrefixType = visitor:link_refer_type(vPrefixType)
	local nOkay, nLeftField = tltOper.pindex_field(visitor, nPrefixType, vKeyType)
	if not nOkay then
		visitor:log_error(nLeftField)
		return
	end
	if nPrefixType.sub_tag == "TTableAuto" and (not nLeftField) then
		assert(nPrefixType[1].tag == "TTable", "TTableAuto not TTable")
		if vLeftDeco then
			tltable.insert(nPrefixType[1], tltable.NilableField(vKeyType, vLeftDeco))
			if nRightType.tag == "TAutoLink" then
				visitor:cast_auto(vLeftDeco, nRightType)
			else
				if not tltRelation.contain(vLeftDeco, nRightType) then
					visitor:log_error("index insert outtype for deco & right", vLeftDeco.tag , nRightType.tag)
				end
			end
		else
			--local seri = require "typedlua/seri"
			--print("before:", seri(nPrefixType))
			tltable.insert(nPrefixType[1], tltable.NilableField(vKeyType, nRightType))
			--print("after", seri(nPrefixType))
		end
	else
		local nLeftType = tltype.Nil()
		if nLeftField then
			nLeftType = nLeftField[2]
		end
		if vLeftDeco then
			if not tltRelation.contain(nLeftType, vLeftDeco) then
				visitor:log_error("index set outtype for left & deco", nLeftType.tag, vLeftDeco.tag)
			end
			if not tltRelation.contain(vLeftDeco, nRightType) then
				visitor:log_error("index set outtype for deco & right", vLeftDeco.tag, nRightType.tag)
			end
		else
			if not tltRelation.contain(nLeftType, nRightType) then
				visitor:log_error("index set outtype for left & right", nLeftType.tag, nRightType.tag)
			end
		end
	end
end

-- set -- return assign
function tltOper._set_assign(visitor, vLeftType, vRightType, vLeftDeco)
	if not vRightType then
		vRightType = tltype.Nil()
		visitor:log_warning("set assign missing")
	else
		vRightType = tltype.general(vRightType)
	end
	if vRightType.tag == "TAutoLink" then
		print("set assign thinking cast detail...")
		if vLeftDeco then
			visitor:cast_auto(vLeftDeco, vRightType)
		else
			visitor:cast_auto(vLeftType, vRightType)
		end
	else
		if vLeftDeco then
			if not tltRelation.sub(vRightType, vLeftDeco) then
				visitor:log_error(
					tltype.tostring(vRightType), "can't be assigned to decotype:",
					tltype.tostring(vLeftDeco))
			end
		else
			if not tltRelation.sub(vRightType, vLeftType) then
				visitor:log_error(
					tltype.tostring(vRightType), "can't be assigned to type:",
					tltype.tostring(vLeftType))
			end
		end
	end
end

-- local -- return assign
function tltOper._init_assign(visitor, vRightType, vLeftDeco)
	if not vRightType then
		vRightType = tltype.Nil()
		visitor:log_warning("init assign missing")
	else
		vRightType = tltype.general(vRightType)
	end
	if vLeftDeco then
		if vRightType.tag == "TAutoLink" then
			visitor:cast_auto(vLeftDeco, vRightType)
		else
			if not tltRelation.sub(vRightType, vLeftDeco) then
				visitor:log_error(
					tltype.tostring(vRightType), "can't be assigned to ",
					tltype.tostring(vLeftDeco))
			end
		end
		return vLeftDeco
	else
		return vRightType
	end
end

-- logic operator

function tltOper._not(visitor, vType)
	visitor:log_warning("_not TODO")
	return tltype.Boolean()
end

function tltOper._and(visitor, vLeftType, vRightType)
	visitor:log_warning("_and TODO")
	return vRightType
end

function tltOper._or(visitor, vLeftType, vRightType)
	visitor:log_warning("_or TODO")
	return vLeftType
end

-- # operator

function tltOper.__len(visitor, vType)
	-- TODO
	-- visitor:check(vWrapper, dosth)
	return tltype.Integer()
end

-- mathematic operator

function tltOper.__unm(visitor, vType)
	tltOper.assert_type(visitor, vType, tltype.Number())
	return tltype.Number()
end

function tltOper.__add(visitor, vLeftType, vRightType)
	tltOper.assert_type(visitor, vLeftType, tltype.Number())
	tltOper.assert_type(visitor, vRightType, tltype.Number())
	return tltype.Number()
end

function tltOper.__sub(visitor, vLeftType, vRightType)
	tltOper.assert_type(visitor, vLeftType, tltype.Number())
	tltOper.assert_type(visitor, vRightType, tltype.Number())
	return tltype.Number()
end

function tltOper.__mul(visitor, vLeftType, vRightType)
	tltOper.assert_type(visitor, vLeftType, tltype.Number())
	tltOper.assert_type(visitor, vRightType, tltype.Number())
	return tltype.Number()
end

function tltOper.__div(visitor, vLeftType, vRightType)
	tltOper.assert_type(visitor, vLeftType, tltype.Number())
	tltOper.assert_type(visitor, vRightType, tltype.Number())
	return tltype.Number()
end

function tltOper.__idiv(visitor, vLeftType, vRightType)
	tltOper.assert_type(visitor, vLeftType, tltype.Number())
	tltOper.assert_type(visitor, vRightType, tltype.Number())
	return tltype.Integer()
end

function tltOper.__mod(visitor, vLeftType, vRightType)
	tltOper.assert_type(visitor, vLeftType, tltype.Number())
	tltOper.assert_type(visitor, vRightType, tltype.Number())
	return tltype.Number()
end

function tltOper.__pow(visitor, vLeftType, vRightType)
	tltOper.assert_type(visitor, vLeftType, tltype.Number())
	tltOper.assert_type(visitor, vRightType, tltype.Number())
	return tltype.Number()
end

function tltOper.__concat(visitor, vLeftType, vRightType)
	tltOper.assert_type(visitor, vLeftType, tltype.String())
	tltOper.assert_type(visitor, vRightType, tltype.String())
	return tltype.String()
end

-- bitwise operator

function tltOper.__band(visitor, vLeftType, vRightType)
	tltOper.assert_type(visitor, vLeftType, tltype.Integer())
	tltOper.assert_type(visitor, vRightType, tltype.Integer())
	return tltype.Integer()
end

function tltOper.__bor(visitor, vLeftType, vRightType)
	tltOper.assert_type(visitor, vLeftType, tltype.Integer())
	tltOper.assert_type(visitor, vRightType, tltype.Integer())
	return tltype.Integer()
end

function tltOper.__bxor(visitor, vLeftType, vRightType)
	tltOper.assert_type(visitor, vLeftType, tltype.Integer())
	tltOper.assert_type(visitor, vRightType, tltype.Integer())
	return tltype.Integer()
end

function tltOper.__bnot(visitor, vType)
	tltOper.assert_type(visitor, vType, tltype.Integer())
	return tltype.Integer()
end

function tltOper.__shl(visitor, vLeftType, vRightType)
	tltOper.assert_type(visitor, vLeftType, tltype.Integer())
	tltOper.assert_type(visitor, vRightType, tltype.Integer())
	return tltype.Integer()
end

function tltOper.__shr(visitor, vLeft, vRight)
	tltOper.assert_type(visitor, vLeft, tltype.Integer())
	tltOper.assert_type(visitor, vRight, tltype.Integer())
	return tltype.Integer()
end

-- equivalence comparison operators

function tltOper.__eq(visitor, vLeftType, vRightType)
	visitor:log_warning("__eq oper TODO")
	return tltype.Boolean()
end

function tltOper.__lt(visitor, vLeftType, vRightType)
	tltOper.assert_type(visitor, vLeftType, tltype.Number())
	tltOper.assert_type(visitor, vRightType, tltype.Number())
	return tltype.Boolean()
end

function tltOper.__le(visitor, vLeftType, vRightType)
	tltOper.assert_type(visitor, vLeftType, tltype.Number())
	tltOper.assert_type(visitor, vRightType, tltype.Number())
	return tltype.Boolean()
end

-- equivalence comparison operators not meta

function tltOper._ne(visitor, vLeftType, vRightType)
	visitor:log_warning("_ne  oper TODO")
	return tltype.Boolean()
end

function tltOper._ge(visitor, vLeftType, vRightType)
	return tltOper.__le(visitor, vRightType, vLeftType)
end

function tltOper._gt(visitor, vLeftType, vRightType)
	return tltOper.__lt(visitor, vRightType, vLeftType)
end

function tltOper._fornum(visitor, vType)
	tltOper.assert_type(visitor, vType, tltype.Number())
end

return tltOper
