
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
	local nFunctionType = vFunctionNode.type
	if not nFunctionType[2] then
		-- auto set type
		nFunctionType[2] = vTupleType
	else
		print("TODO check type")
		-- check type
	end
end

function tltOper._reforge_tuple(visitor, vExpListWrapper)
	local nTupleType = tltype.Tuple()
	local nLength = #vExpListWrapper
	-- #vExpListWrapper == 0 return {}
	if nLength <= 0 then
		return nTupleType
	end
	local nLastType = vExpListWrapper[nLength].type
	-- #vExpListWrapper >=1 merge and return
	for i = 1, nLength - 1 do
		nTupleType[i] = tltype.first(vExpListWrapper[i].type)
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

function tltOper._call(visitor, vCallNode, vFunctionType, vArgTypeList)
	if vFunctionType.tag == "TFunction" then
		print("TODO tltOper._call check args")
		return vFunctionType[2]
	else
		visitor:log_error(vCallNode, tltype.tostring(vFunctionType), "is not function type")
		return tltype.Tuple(tltype.Nil())
	end
end

function tltOper._index_get(visitor, vIndexNode, vPrefixWrapper, vKeyWrapper)
	local nType1 = vPrefixWrapper.type
	local nType2 = vKeyWrapper.type
	local nField = nil
	if nType1.tag == "TTable" then
		nField = tltable.index_field(nType1, nType2)
	else
		-- TODO check node is Table
		visitor:log_error(vPrefixWrapper, "index for non-table type not implement...")
	end
	local nReType = nil
	if not nField then
		nReType = tltype.Nil()
	else
		nReType = nField[2]
	end
	vIndexNode.type = nReType
end

-- TODO think which one is better ... -- no return
function tltOper._index_set(visitor, vPrefixNode, vKeyType, vValueType, vLeftDeco)
	local nPrefixType = vPrefixNode.type
	if nPrefixType.tag == "TTable" then
		if nPrefixType.sub_tag == "TOpenTable" then
			local nField = tltable.index_field(nPrefixType, vKeyType)
			if not nField then
				tltable.insert(nPrefixType, tltable.NilableField(
					vKeyType,
					tltype.general(vValueType)
				))
			else
				if not tltRelation.sub(vValueType, nField[2]) then
					visitor:log_error(vPrefixNode,
						tltype.tostring(vValueType), "set index",
						tltype.tostring(nField[2]), "failed")
				end
			end
		else
			-- TODO
		end
	else
		-- TODO check node is Table
		visitor:log_error(vPrefixNode, "index for non-table type not implement...")
	end
end

-- set -- return assign
function tltOper._set_assign(visitor, vNameWrapper, vRightType, vLeftDeco)
	if not vRightType then
		vRightType = tltype.Nil()
		visitor:log_warning(vNameWrapper, "set assign missing")
	else
		vRightType = tltype.general(vRightType)
	end
	if vLeftDeco then
		if not tltRelation.sub(vRightType, vLeftDeco) then
			visitor:log_error(vNameWrapper,
				tltype.tostring(vRightType), "can't be assigned to decotype:",
				tltype.tostring(vLeftDeco))
		end
		-- return { type = vLeftDeco }
	else
		local nLeftType = vNameWrapper.type
		if not tltRelation.sub(vRightType, nLeftType) then
			visitor:log_error(vNameWrapper,
				tltype.tostring(vRightType), "can't be assigned to type:",
				tltype.tostring(nLeftType))
		end
		-- return { type = vRightType }
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
		if not tltRelation.sub(vRightType, vLeftDeco) then
			visitor:log_error(vNameNode,
				tltype.tostring(vRightType), "can't be assigned to ",
				tltype.tostring(vLeftDeco))
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
