local tltype = require "typedlua/tltype"
local tlrelation = {}

-- The first element in node are equal.
local eq0 = function(vLeft, vRight)
	return vLeft == vRight
end
-- The first element in node are equal.
local eq1 = function(vLeft, vRight)
	return vLeft[1] == vRight[1]
end

local SubRelation = {
	TLiteral={
		TLiteral=function(vLeftLiteral, vRightLiteral)
			return (vLeftLiteral[1] == vRightLiteral[1])
		end,
		TBase=function(vLeftLiteral, vRightBase)
			local nLeft = vLeftLiteral[1]
			local nRight = vRightBase[1]
			if nRight == "integer" then
				if type(nLeft) == "number" then
					return nLeft % 1 == 0
				else
					return false
				end
			else
				return type(nLeft) == nRight
			end
		end,
		TGlobalVariable=false,
		TTable=false,
		TUniqueTable=false,
	},
	TBase={
		TLiteral=false,
		TBase=function(vLeftBase, vRightBase)
			return (vLeftBase[1] == vRightBase[1]) or
			(vLeftBase[1] == "integer" and vRightBase[1] == "number")
		end,
		TGlobalVariable=false,
		TTable=false,
		TUniqueTable=false,
	},
	TGlobalVariable={
		TLiteral=false,
		TBase=false,
		TGlobalVariable=eq1,
		TTable=false,
		TUniqueTable=false,
	},
	TTable={
		TLiteral=false,
		TBase=false,
		TGlobalVariable=false,
		TTable=false,
		TUniqueTable=false,
	},
	TUniqueTable={
		TLiteral=false,
		TBase=false,
		TGlobalVariable=false,
		TTable=false,
		TUniqueTable=eq0,
	},
}

for nType, nRelation in pairs(SubRelation) do
	setmetatable(nRelation, {
		__index=function(t,k,v)
			print(nType,k)
			error("TODO... not implement")
		end
	})
end

function tlrelation.sub(vLeft, vRight)
	local nSub = SubRelation[vLeft.tag][vRight.tag]
	if nSub then
		return nSub(vLeft, vRight)
	else
		return false
	end
end

function tlrelation.general(vType)
	if vType.tag == "TLiteral" then
		return tltype.Base(type(vType[1]))
	end
end

return tlrelation


--[[
local List = {
	TVoid = {
		TVoid=VoidVoid,
		TUnionlist=toUnionlist,
		TTuple=toTuple,
		TVararg=toVararg,
	},
	TPrim = { },

	TTuple = { },
	TVararg = { },

	TLiteral = { },
	TBase = { },
	TNil = { },

	TValue = { },
	TAny = { },

	TUnion = {},

	TFunction = { },

	TTable = { },

	TVariable = { },

	TGlobalVariable = {},

	TUniqueTable = {},

	-- not compatible type
	-- TUnionlist = { },
	-- TSelf = { },
	-- TRecursive = {},
	-- TProj = { },
}
]]
