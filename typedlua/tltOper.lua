
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
	local nFunctionType = visitor:link_type(vFunctionNode.type)
	if not nFunctionType[2] then
		-- auto set type
		nFunctionType[2] = vTupleType
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
		nNewTuple[i] = visitor:link_type(nType)
	end
	return nNewTuple
end

function tltOper._call(visitor, vCallerType, vArgTuple)
	local nFunctionType = visitor:link_type(vCallerType)
	if nFunctionType.tag == "TFunction" then
		local nInputTuple = tltOper._relink_tuple(visitor, vArgTuple)
		print("TODO tltOper._call check and cast args")
		if nFunctionType.sub_tag == "TAutoFunction" then
			return visitor:oper_auto_call(vCallerType, nInputTuple)
		elseif nFunctionType.sub_tag == "TNativeFunction" then
			return nFunctionType.caller(visitor, nInputTuple)
		elseif nFunctionType.sub_tag == "TStaticFunction" then
			return nFunctionType[2]
		elseif nFunctionType.sub_tag == "TAnyFunction" then
			return tltype.VarTuple(tltype.Any())
		else
			visitor:log_error("function sub_tag exception", nFunctionType.sub_tag)
		end
	elseif nFunctionType.tag == "TAny" then
		visitor:log_warning("call any")
		return tltype.VarTuple(tltype.Any())
	else
		visitor:log_error(tltype.tostring(nFunctionType), "is not function type")
		return tltype.Tuple(tltype.Nil())
	end
end

function tltOper._index_get(visitor, vPrefixType, vKeyType)
	vPrefixType = visitor:link_type(vPrefixType)
	local nField = nil
	if vPrefixType.tag == "TTable" then
		nField = tltable.index_field(vPrefixType, vKeyType)
	elseif vPrefixType.tag == "TAny" then
		visitor:log_warning("index any")
		nField = tltable.Field(tltype.Any(), tltype.Any())
	else
		-- TODO check node is Table
		visitor:log_error("index for non-table type not implement...")
	end
	local nReType = nil
	if not nField then
		nReType = tltype.Nil()
	else
		nReType = nField[2]
	end
	return nReType
end

-- TODO think which one is better ... -- no return
function tltOper._index_set(visitor, vPrefixType, vKeyType, vValueType, vLeftDeco)
	if not vValueType then
		vValueType = tltype.Nil()
		visitor:log_warning("set assign missing")
	else
		vValueType = tltype.general(vValueType)
	end
	vPrefixType = visitor:link_type(vPrefixType)
	if vPrefixType.tag == "TTable" then
		local nField = tltable.index_field(vPrefixType, vKeyType)
		if (not nField) and (not vLeftDeco) then
			if vPrefixType.sub_tag == "TAutoTable" then
				tltable.insert(vPrefixType, tltable.NilableField(
					vKeyType, vValueType
				))
			else
				visitor:log_error("non-auto table set in empty field", tltype.tostring(nField[2]))
			end
		elseif nField and nField.tag == "TAutoLink" then
			assert(vPrefixType.sub_tag == "TAutoTable")
			visitor:log_error("autolink field can't be set")
		else
			local nCastType = nil
			if nField then
				nCastType = nField[2]
				if vLeftDeco then
					if not tltRelation.contain(nField[2], vLeftDeco) then
						visitor:log_error(
							tltype.tostring(nField[2]), "field not contain deco",
							tltype.tostring(vLeftDeco))
					end
				end
			elseif vLeftDeco and (not nField) then
				nCastType = vLeftDeco
				tltable.insert(vPrefixType, tltable.NilableField(vKeyType, vLeftDeco))
			else
				error("error branch when index_set")
			end
			if nCastType and vValueType.tag == "TAutoLink" then
				visitor:cast_auto(nCastType, vValueType)
			else
				if not tltRelation.contain(nCastType, vValueType) then
					visitor:log_error(
						tltype.tostring(vValueType), "index set",
						tltype.tostring(nField[2]), "failed")
				end
			end
		end
	elseif vPrefixType.tag == "TAny" then
		visitor:log_warning("set index for any")
	else
		-- TODO deal case for non-table
		visitor:log_error("index for non-table type not implement...", vPrefixType.tag)
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

tltOper.wrapper = setmetatable({},{
	__index=function(t,k)
		local nFunc = tltype[k]
		return function(...)
			local nType = nFunc(...)
			local nWrapper = setmetatable({}, {
				__index={type=nType},
				__newindex=function()
					error("wrapper can't be modified")
				end
			})
			return nWrapper
		end
	end
})

return tltOper
