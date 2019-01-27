
local tltype = require "typedlua/tltype"
local tltRelation = require "typedlua/tltRelation"
local tltable = require "typedlua/tltable"
local tlutils = require "typedlua/tlutils"
local tltOper = {}

local function check_type(visitor, vWrapper, vType)
	if not tltRelation.sub(vWrapper.type, vType) then
		visitor:log_error(vWrapper, tltype.tostring(vWrapper.type), "can't not belong", tltype.tostring(vType))
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

function tltOper._call(visitor, vCalleeWrapper, vTypeList)
	local nFunctionType = vCalleeWrapper.type
	if nFunctionType.tag == "TFunction" then
		print("TODO tltOper._call check args")
		return {
			type=nFunctionType[2]
		}
	else
		visitor:log_error(vCalleeWrapper, tltype.tostring(nFunctionType), "is not function type")
		return {
			type=tltype.Nil()
		}
	end
end

function tltOper._index_get(visitor, vPrefixWrapper, vKeyWrapper)
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
	return {
		type = nReType,
	}
end

-- TODO think which one is better ... -- no return
function tltOper._index_set(visitor, vPrefixWrapper, vKeyWrapper, vValueType, vLeftDeco)
	local nPrefixType = vPrefixWrapper.type
	local nKeyType = vKeyWrapper.type
	if nPrefixType.tag == "TTable" then
		if nPrefixType.sub_tag == "TOpenTable" then
			local nField = tltable.index_field(nPrefixType, nKeyType)
			if not nField then
				tltable.insert(nPrefixType, tltable.NilableField(
					nKeyType,
					tltype.general(vValueType)
				))
			else
				if not tltRelation.sub(vValueType, nField[2]) then
					visitor:log_error(vPrefixWrapper,
						tltype.tostring(vValueType), "set index",
						tltype.tostring(nField[2]), "failed")
				end
			end
		else
			-- TODO
		end
	else
		-- TODO check node is Table
		visitor:log_error(vPrefixWrapper, "index for non-table type not implement...")
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
		return {
			type = vLeftDeco
		}
	else
		local nLeftType = vNameWrapper.type
		if not tltRelation.sub(vRightType, nLeftType) then
			visitor:log_error(vNameWrapper,
				tltype.tostring(vRightType), "can't be assigned to type:",
				tltype.tostring(nLeftType))
		end
		return {
			type = vRightType
		}
	end
end

-- local -- return assign
function tltOper._init_assign(visitor, vNameWrapper, vRightType, vLeftDeco)
	if not vRightType then
		vRightType = tltype.Nil()
		visitor:log_warning(vNameWrapper, "init assign missing")
	else
		vRightType = tltype.general(vRightType)
	end
	if vLeftDeco then
		if not tltRelation.sub(vRightType, vLeftDeco) then
			visitor:log_error(vNameWrapper,
				tltype.tostring(vRightType), "can't be assigned to ",
				tltype.tostring(vLeftDeco))
		end
		return {
			type = vLeftDeco
		}
	else
		return {
			type = vRightType
		}
	end
end

-- logic operator

function tltOper._not(visitor, vWrapper)
	visitor:log_warning(vWrapper, "_not TODO")
	return {
		type=tltype.Boolean()
	}
end

function tltOper._and(visitor, vLeft, vRight)
	visitor:log_warning(vLeft, "_and TODO")
	return {
		type=vRight.type
	}
end

function tltOper._or(visitor, vLeft, vRight)
	visitor:log_warning(vLeft, "_and TODO")
	return {
		type=vLeft.type
	}
end

-- # operator

function tltOper.__len(visitor, vWrapper)
	-- visitor:check(vWrapper, dosth)
	return {
		type=tltype.Integer()
	}
end

-- mathematic operator

function tltOper.__unm(visitor, vWrapper)
	check_type(visitor, vWrapper, tltype.Number())
	return {
		type=tltype.Number()
	}
end

function tltOper.__add(visitor, vLeft, vRight)
	check_type(visitor, vLeft, tltype.Number())
	check_type(visitor, vRight, tltype.Number())
	return {
		type=tltype.Number()
	}
end

function tltOper.__sub(visitor, vLeft, vRight)
	check_type(visitor, vLeft, tltype.Number())
	check_type(visitor, vRight, tltype.Number())
	return {
		type=tltype.Number()
	}
end

function tltOper.__mul(visitor, vLeft, vRight)
	check_type(visitor, vLeft, tltype.Number())
	check_type(visitor, vRight, tltype.Number())
	return {
		type=tltype.Number()
	}
end

function tltOper.__div(visitor, vLeft, vRight)
	check_type(visitor, vLeft, tltype.Number())
	check_type(visitor, vRight, tltype.Number())
	return {
		type=tltype.Number()
	}
end

function tltOper.__idiv(visitor, vLeft, vRight)
	check_type(visitor, vLeft, tltype.Number())
	check_type(visitor, vRight, tltype.Number())
	return {
		type=tltype.Integer()
	}
end

function tltOper.__mod(visitor, vLeft, vRight)
	check_type(visitor, vLeft, tltype.Number())
	check_type(visitor, vRight, tltype.Number())
	return {
		type=tltype.Number()
	}
end

function tltOper.__pow(visitor, vLeft, vRight)
	check_type(visitor, vLeft, tltype.Number())
	check_type(visitor, vRight, tltype.Number())
	return {
		type=tltype.Number()
	}
end

function tltOper.__concat(visitor, vLeft, vRight)
	check_type(visitor, vLeft, tltype.String())
	check_type(visitor, vRight, tltype.String())
	return {
		type=tltype.String()
	}
end

-- bitwise operator

function tltOper.__band(visitor, vLeft, vRight)
	check_type(visitor, vLeft, tltype.Integer())
	check_type(visitor, vRight, tltype.Integer())
	return {
		type=tltype.Integer()
	}
end

function tltOper.__bor(visitor, vLeft, vRight)
	check_type(visitor, vLeft, tltype.Integer())
	check_type(visitor, vRight, tltype.Integer())
	return {
		type=tltype.Integer()
	}
end

function tltOper.__bxor(visitor, vLeft, vRight)
	check_type(visitor, vLeft, tltype.Integer())
	check_type(visitor, vRight, tltype.Integer())
	return {
		type=tltype.Integer()
	}
end

function tltOper.__bnot(visitor, vWrapper)
	check_type(visitor, vWrapper, tltype.Integer())
	return {
		type=tltype.Integer()
	}
end

function tltOper.__shl(visitor, vLeft, vRight)
	check_type(visitor, vLeft, tltype.Integer())
	check_type(visitor, vRight, tltype.Integer())
	return {
		type=tltype.Integer()
	}
end

function tltOper.__shr(visitor, vLeft, vRight)
	check_type(visitor, vLeft, tltype.Integer())
	check_type(visitor, vRight, tltype.Integer())
	return {
		type=tltype.Integer()
	}
end

-- equivalence comparison operators

function tltOper.__eq(visitor, vLeft, vRight)
	visitor:log_warning("__eq oper TODO")
	return {
		type=tltype.Boolean()
	}
end

function tltOper.__lt(visitor, vLeft, vRight)
	check_type(visitor, vLeft, tltype.Number())
	check_type(visitor, vRight, tltype.Number())
	return {
		type=tltype.Boolean()
	}
end

function tltOper.__le(visitor, vLeft, vRight)
	check_type(visitor, vLeft, tltype.Number())
	check_type(visitor, vRight, tltype.Number())
	return {
		type=tltype.Boolean()
	}
end

-- equivalence comparison operators not meta

function tltOper._ne(visitor, vLeft, vRight)
	visitor:log_warning("_ne  oper TODO")
	return {
		type=tltype.Boolean()
	}
end

function tltOper._ge(visitor, vLeft, vRight)
	return tltOper.__le(visitor, vRight, vLeft)
end

function tltOper._gt(visitor, vLeft, vRight)
	return tltOper.__lt(visitor, vRight, vLeft)
end

function tltOper._assert(visitor, vNode, vType)
	check_type(visitor, vNode, vType)
	return {
		type=vType,
	}
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
