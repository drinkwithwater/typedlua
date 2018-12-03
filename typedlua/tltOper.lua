
local tltype = require "typedlua/tltype"
local tltRelation = require "typedlua/tltRelation"
local tltOper = {}

local function check_type(visitor, vWrapper, vType)
	if not tltRelation.sub(vWrapper.type, vType) then
		visitor:log_error(vWrapper, vWrapper.type.tag, "can't not be", vType.tag)
	end
end

function tltOper._index_get(visitor, vPrefixWrapper, vKeyWrapper)
	local nType1 = vPrefixWrapper.type
	local nType2 = vKeyWrapper.type
	local nReField = nil
	local nReType = nil
	if nType1.tag == "TUniqueTable" then
		nField = tltable.index_unique(nType1, nType2)
	elseif nType1.tag == "TTable" then
		nField = tltable.index_generic(nType1, nType2)
	else
		-- TODO check node is Table
		log_error(visitor, node, "index for non-table type not implement...")
		nReType = tltype.Nil()
	end
	if nField.tag == "TNil" then
		nReType = nField
	else
		nReType = nField[2]
	end
	return {
		index_field = nReField,
		type = nReType,
	}
end

function tltOper._index_set(visitor, vPrefixWrapper, vValueWrapper)
end

function tltOper._assign(visitor, vVarWrapper, vExprWrapper)
end

function tltOper._call(visitor, vFuncWrapper, ...)
	visitor:log_warning("_call TODO")
	error("TODO")
end

-- logic operator

function tltOper._not(visitor, vWrapper)
	visitor:log_warning("_not TODO")
	return {
		type=tltype.Boolean()
	}
end

function tltOper._and(visitor, vLeft, vRight)
	visitor:log_warning("_and TODO")
	return {
		type=vRight.type
	}
end

function tltOper._or(visitor, vLeft, vRight)
	visitor:log_warning("_and TODO")
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

return tltOper
