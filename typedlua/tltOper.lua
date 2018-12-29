
local tltype = require "typedlua/tltype"
local tltRelation = require "typedlua/tltRelation"
local tltable = require "typedlua/tltable"
local tltOper = {}

local function check_type(visitor, vWrapper, vType)
	if not tltRelation.sub(vWrapper.type, vType) then
		visitor:log_error(vWrapper, vWrapper.type.tag, "can't not be", vType.tag)
	end
end

function tltOper._index_get(visitor, vPrefixWrapper, vKeyWrapper)
	local nType1 = vPrefixWrapper.type
	local nType2 = vKeyWrapper.type
	if nType1.tag == "TTable" then
		nField = tltable.index_field(nType1, nType2)
	else
		-- TODO check node is Table
		visitor:log_error(node, "index for non-table type not implement...")
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
function tltOper._index_set(visitor, vPrefixWrapper, vKeyWrapper, vValueWrapper)
	local nPrefixType = vPrefixWrapper.type
	local nKeyType = vKeyWrapper.type
	local nValueType = vValueWrapper.type
	if nPrefixType.tag == "TTable" then
		if nPrefixType.sub_tag == "TOpenTable" then
			local nField = tltable.index_field(nPrefixType, nKeyType)
			if not nField then
				tltable.insert(nPrefixType, tltable.NilableField(
					nVarNode[2].type,
					tltRelation.general(nExprNode.type)
				))
			else
				if not tltRelation.sub(nValueType, nField[2]) then
					visitor:log_error(vPrefixWrapper, "table index set fail:", nValueType.tag, nField[2].tag)
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
function tltOper._set_assign(visitor, vNameWrapper, vExprWrapper)
	local nRightType = nil
	if not vExprWrapper then
		nRightType = tltype.Nil()
		visitor:log_error(vNameWrapper, vNameWrapper.tag, "set assign missing")
	else
		nRightType = vExprWrapper.type
	end
	local nLeftDeco = vNameWrapper.left_deco
	if nLeftDeco then
		if not tltRelation.sub(nRighType, nLeftDeco) then
			visitor:log_error(vNameWrapper, nRightType.tag, "can't be assigned to "..nLeftDeco.tag)
		end
		return {
			type = nLeftDeco
		}
	else
		return {
			type = nRightType
		}
	end
end

-- local -- return assign
function tltOper._init_assign(visitor, vNameWrapper, vExprWrapper)
	local nRightType = nil
	if not vExprWrapper then
		nRightType = tltype.Nil()
		visitor:log_error(vNameWrapper, vNameWrapper.tag, "local assign missing")
	else
		nRightType = vExprWrapper.type
	end
	local nLeftDeco = vNameWrapper.left_deco
	if nLeftDeco then
		if not tltRelation.sub(nRightType, nLeftDeco) then
			visitor:log_error(vNameWrapper, nRightType.tag, "can't be assigned to "..nLeftDeco.tag)
		end
		return {
			type = nLeftDeco
		}
	else
		return {
			type = nRightType
		}
	end
end

function tltOper._call(visitor, vFuncWrapper, ...)
	visitor:log_warning("_call TODO")
	error("TODO")
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
