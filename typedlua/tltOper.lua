
local tltype = require "typedlua/tltype"
local tltRelation = require "typedlua/tltRelation"
local tltable = require "typedlua/tltable"
local tlutils = require "typedlua/tlutils"
local tltOper = {}

local function check_type(visitor, vAnchorNode, vType, vMustType)
	if not tltRelation.sub(vType, vMustType) then
		visitor:log_error(vAnchorNode, tltype.tostring(vType), "can't belong to", tltype.tostring(vMustType))
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
	local nTupleType = tltype.Tuple()
	local nLength = #vExpListNode
	-- #vExpListNode == 0 return {}
	if nLength <= 0 then
		return nTupleType
	end
	local nLastType = vExpListNode[nLength].type
	-- #vExpListNode >=1 merge and return
	for i = 1, nLength - 1 do
		nTupleType[i] = tltype.first(vExpListNode[i].type)
	end

	-- if type1,type2,...,type3,type4 return {type1,type2,...,type3,type4}
	if nLastType.tag ~= "TTuple" then
		nTupleType[nLength] = nLastType
		return nTupleType
	end

	-- if type1,type2,...,type3,tuple return {type1,type2,...,type3,table.unpack(tuple)}
	for i=1, #nLastType do
		nTupleType[nLength + i - 1] = nLastType[i]
	end

	return nTupleType
end

function tltOper._call(visitor, vCallNode, vCallerType, vArgTuple)
	local nFunctionType = visitor:link_type(vCallerType)
	if nFunctionType.tag == "TFunction" then
		print("TODO tltOper._call check args")
		if nFunctionType.sub_tag == "TAutoFunction" then
			return visitor:oper_call(vCallerType, vArgTuple)
		else
			return nFunctionType[2]
		end
	else
		visitor:log_error(vCallNode, tltype.tostring(nFunctionType), "is not function type")
		return tltype.Tuple(tltype.Nil())
	end
end

function tltOper._index_get(visitor, vIndexNode, vPrefixType, vKeyType)
	vPrefixType = visitor:link_type(vPrefixType)
	local nField = nil
	if vPrefixType.tag == "TTable" then
		nField = tltable.index_field(vPrefixType, vKeyType)
	else
		-- TODO check node is Table
		visitor:log_error(vIndexNode, "index for non-table type not implement...")
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
function tltOper._index_set(visitor, vPrefixNode, vPrefixType, vKeyType, vValueType, vLeftDeco)
	vPrefixType = visitor:link_type(vPrefixType)
	if vPrefixType.tag == "TTable" then
		local nField = tltable.index_field(vPrefixType, vKeyType)
		if not nField then
			if vPrefixType.sub_tag == "TAutoTable" then
				tltable.insert(vPrefixType, tltable.NilableField(
					vKeyType,
					tltype.general(vValueType)
				))
			else
				visitor:log_error(vPrefixNode, "non-auto table set in empty field", tltype.tostring(nField[2]))
			end
		else
			if vValueType.tag == "TAutoLink" then
				visitor:cast_auto(nField[2], vValueType)
			else
				if not tltRelation.contain(nField[2], vValueType) then
					visitor:log_error(vPrefixNode,
						tltype.tostring(vValueType), "index set",
						tltype.tostring(nField[2]), "failed")
				end
			end
		end
	else
		-- TODO check node is Table
		visitor:log_error(vPrefixNode, "index for non-table type not implement...")
	end
end

-- set -- return assign
function tltOper._set_assign(visitor, vNameNode, vLeftType, vRightType, vLeftDeco)
	if not vRightType then
		vRightType = tltype.Nil()
		visitor:log_warning(vNameNode, "set assign missing")
	else
		vRightType = tltype.general(vRightType)
	end
	if vRightType.tag == "TAutoLink" then
		if vLeftDeco then
			visitor:cast_auto(vLeftDeco, vRightType)
		else
			visitor:cast_auto(vLeftType, vRightType)
		end
	else
		if vLeftDeco then
			if not tltRelation.sub(vRightType, vLeftDeco) then
				visitor:log_error(vNameNode,
					tltype.tostring(vRightType), "can't be assigned to decotype:",
					tltype.tostring(vLeftDeco))
			end
		else
			if not tltRelation.sub(vRightType, vLeftType) then
				visitor:log_error(vNameNode,
					tltype.tostring(vRightType), "can't be assigned to type:",
					tltype.tostring(vLeftType))
			end
		end
	end
end

-- local -- return assign
function tltOper._init_assign(visitor, vNameNode, vRightType, vLeftDeco)
	if not vRightType then
		vRightType = tltype.Nil()
		visitor:log_warning(vNameNode, "init assign missing")
	else
		vRightType = tltype.general(vRightType)
	end
	if vLeftDeco then
		if vRightType.tag == "TAutoLink" then
			visitor:cast_auto(vLeftDeco, vRightType)
		else
			if not tltRelation.sub(vRightType, vLeftDeco) then
				visitor:log_error(vNameNode,
					tltype.tostring(vRightType), "can't be assigned to ",
					tltype.tostring(vLeftDeco))
			end
		end
		vNameNode.type=vLeftDeco
	else
		vNameNode.type=vRightType
	end
end

-- logic operator

function tltOper._not(visitor, vNode, vType)
	visitor:log_warning(vNode, "_not TODO")
	return tltype.Boolean()
end

function tltOper._and(visitor, vNode, vLeftType, vRightType)
	visitor:log_warning(vNode, "_and TODO")
	return vRightType
end

function tltOper._or(visitor, vNode, vLeftType, vRightType)
	visitor:log_warning(vNode, "_or TODO")
	return vLeftType
end

-- # operator

function tltOper.__len(visitor, vNode, vType)
	-- TODO
	-- visitor:check(vWrapper, dosth)
	return tltype.Integer()
end

-- mathematic operator

function tltOper.__unm(visitor, vNode, vType)
	check_type(visitor, vNode, vType, tltype.Number())
	return tltype.Number()
end

function tltOper.__add(visitor, vNode, vLeftType, vRightType)
	check_type(visitor, vNode, vLeftType, tltype.Number())
	check_type(visitor, vNode, vRightType, tltype.Number())
	return tltype.Number()
end

function tltOper.__sub(visitor, vNode, vLeftType, vRightType)
	check_type(visitor, vNode, vLeftType, tltype.Number())
	check_type(visitor, vNode, vRightType, tltype.Number())
	return tltype.Number()
end

function tltOper.__mul(visitor, vNode, vLeftType, vRightType)
	check_type(visitor, vNode, vLeftType, tltype.Number())
	check_type(visitor, vNode, vRightType, tltype.Number())
	return tltype.Number()
end

function tltOper.__div(visitor, vNode, vLeftType, vRightType)
	check_type(visitor, vNode, vLeftType, tltype.Number())
	check_type(visitor, vNode, vRightType, tltype.Number())
	return tltype.Number()
end

function tltOper.__idiv(visitor, vNode, vLeftType, vRightType)
	check_type(visitor, vNode, vLeftType, tltype.Number())
	check_type(visitor, vNode, vRightType, tltype.Number())
	return tltype.Integer()
end

function tltOper.__mod(visitor, vNode, vLeftType, vRightType)
	check_type(visitor, vNode, vLeftType, tltype.Number())
	check_type(visitor, vNode, vRightType, tltype.Number())
	return tltype.Number()
end

function tltOper.__pow(visitor, vNode, vLeftType, vRightType)
	check_type(visitor, vNode, vLeftType, tltype.Number())
	check_type(visitor, vNode, vRightType, tltype.Number())
	return tltype.Number()
end

function tltOper.__concat(visitor, vNode, vLeftType, vRightType)
	check_type(visitor, vNode, vLeftType, tltype.String())
	check_type(visitor, vNode, vRightType, tltype.String())
	return tltype.String()
end

-- bitwise operator

function tltOper.__band(visitor, vNode, vLeftType, vRightType)
	check_type(visitor, vNode, vLeftType, tltype.Integer())
	check_type(visitor, vNode, vRightType, tltype.Integer())
	return tltype.Integer()
end

function tltOper.__bor(visitor, vNode, vLeftType, vRightType)
	check_type(visitor, vNode, vLeftType, tltype.Integer())
	check_type(visitor, vNode, vRightType, tltype.Integer())
	return tltype.Integer()
end

function tltOper.__bxor(visitor, vNode, vLeftType, vRightType)
	check_type(visitor, vNode, vLeftType, tltype.Integer())
	check_type(visitor, vNode, vRightType, tltype.Integer())
	return tltype.Integer()
end

function tltOper.__bnot(visitor, vNode, vType)
	check_type(visitor, vNode, vType, tltype.Integer())
	return tltype.Integer()
end

function tltOper.__shl(visitor, vNode, vLeftType, vRightType)
	check_type(visitor, vNode, vLeftType, tltype.Integer())
	check_type(visitor, vNode, vRightType, tltype.Integer())
	return tltype.Integer()
end

function tltOper.__shr(visitor, vNode, vLeft, vRight)
	check_type(visitor, vNode, vLeft, tltype.Integer())
	check_type(visitor, vNode, vRight, tltype.Integer())
	return tltype.Integer()
end

-- equivalence comparison operators

function tltOper.__eq(visitor, vNode, vLeftType, vRightType)
	visitor:log_warning(vNode, "__eq oper TODO")
	return tltype.Boolean()
end

function tltOper.__lt(visitor, vNode, vLeftType, vRightType)
	check_type(visitor, vNode, vLeftType, tltype.Number())
	check_type(visitor, vNode, vRightType, tltype.Number())
	return tltype.Boolean()
end

function tltOper.__le(visitor, vNode, vLeftType, vRightType)
	check_type(visitor, vNode, vLeftType, tltype.Number())
	check_type(visitor, vNode, vRightType, tltype.Number())
	return tltype.Boolean()
end

-- equivalence comparison operators not meta

function tltOper._ne(visitor, vNode, vLeftType, vRightType)
	visitor:log_warning(vNode, "_ne  oper TODO")
	return tltype.Boolean()
end

function tltOper._ge(visitor, vNode, vLeftType, vRightType)
	return tltOper.__le(visitor, vNode, vRightType, vLeftType)
end

function tltOper._gt(visitor, vNode, vLeftType, vRightType)
	return tltOper.__lt(visitor, vNode, vRightType, vLeftType)
end

function tltOper._fornum(visitor, vNode, vType)
	check_type(visitor, vNode, vType, tltype.Number())
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
