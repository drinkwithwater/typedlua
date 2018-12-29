local tltype = require "typedlua/tltype"
local seri = require "typedlua/seri"
local tltRelation = {}

-- The first element in node are equal.
local eq1 = function(vLeft, vRight)
	return vLeft[1] == vRight[1]
end

local function unionNil(vType, vUnion)
	if #vUnion < 2 then
		error("union 1 item...")
	elseif #vUnion > 2 then
		return false
	end
	local nSubType = nil
	if vUnion[1].tag == "TNil" then
		nSubType = vUnion[2]
	elseif vUnion[2].tag == "TNil" then
		nSubType = vUnion[1]
	else
		return false
	end
	if tltRelation.contain(vType, nSubType) then
		return true, true
	end
	return false
end

local TypeContainDict = {
	TLiteral={
		TLiteral=function(vLiteral, vSubLiteral)
			return (vLiteral[1] == vSubLiteral[1])
		end,
		TBase=false,
		TGlobalVariable=false,
		TTable=false,
		TUnion=unionNil,
		TNil=false,
	},
	TBase={
		TLiteral=function(vBase, vSubLiteral)
			local nLeft = vSubLiteral[1]
			local nRight = vBase[1]
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
		TBase=function(vBase, vSubBase)
			return (vBase[1] == vSubBase[1]) or
			(vSubBase[1] == "integer" and vBase[1] == "number")
		end,
		TGlobalVariable=false,
		TTable=false,
		TUnion=unionNil,
		TNil=false,
	},
	TGlobalVariable={
		TLiteral=false,
		TBase=false,
		TGlobalVariable=eq1,
		TTable=false,
		TUnion=unionNil,
		TNil=false,
	},
	TTable={
		TLiteral=false,
		TBase=false,
		TGlobalVariable=false,
		TTable=function(vLeftTable, vRightTable)
			if vLeftTable.sub_tag == "TOpenTable" and vRightTable.sub_tag == "TOpenTable" then
				if vLeftTable == vRightTable then
					return true, true
				else
					return false
				end
			end
			if vLeftTable.sub_tag ~= "TOpenTable" and vRightTable.sub_tag == "TOpenTable" then
				local nWarning = true
				local nLeftRecordDict = vLeftTable.record_dict
				for nRightKey, nRightRecordIndex in pairs(vRightTable.record_dict) do
					local nLeftRecordIndex = nLeftRecordDict[nRightKey]
					local nRightField = vRightTable[nRightRecordIndex]
					if nLeftRecordIndex then
						-- if has left record, compare record field
						local nLeftField = vLeftTable[nLeftRecordIndex]
						local nContainResult, nFieldWarning = tltRelation.contain(nLeftField[2], nRightField[2])
						if not nContainResult then
							return false
						elseif nFieldWarning then
							nWarning = true
						end
					else
						-- if left do not has left record, compare hash field
						local nContain = true
						for k, nLeftHashIndex in ipairs(vLeftTable.hash_list) do
							local nLeftField = vLeftTable[nLeftHashIndex]
							if tltRelation.contain(nLeftField[1], nRightField[1]) then
								local nContainResult, nFieldWarning = tltRelation.contain(nLeftField[2], nRightField[2])
								if not nContainResult then
									return false
								else
									nContain = true
									if nFieldWarning then
										nWarning = true
									end
								end
							end
						end
						if not nContain then
							return false
						end
					end
				end
				if nWarning then
					return true, true
				else
					return true
				end
			end
		end,
		TUnion=unionNil,
		TNil=false,
	},
	TUnion=setmetatable({
		TUnion=function(vUnion, vSubUnion)
			local nWarning = false
			for k, nSubUnionItem in ipairs(vSubUnion) do
				local nContainResult, nItemWarning = tltRelation.contain(vUnion, nSubUnionItem)
				if not nContainResult then
					return false
				elseif nItemWarning then
					nWarning = true
				end
			end
			if nWarning then
				return true, true
			else
				return true
			end
		end,
		},{
		__index=function(t, vSubTypeTag)
			local nContain = function(vUnion, vSubType)
				local nWarning = false
				for k, nUnionItem in ipairs(vUnion) do
					local nContainResult, nItemWarning = tltRelation.contain(nUnionItem, vSubType)
					if nContainResult then
						if not nItemWarning then
							return true
						else
							nWarning = true
						end
					end
				end
				if nWarning then
					return true, true
				else
					return false
				end
			end
			rawset(t, vSubTypeTag, nContain)
			return nContain
		end
	}),
	TNil={
		TLiteral=false,
		TBase=false,
		TGlobalVariable=false,
		TTable=false,
		TUnion=false,
		TNil=function()
			return true
		end,
	}
}

for nType, nRelation in pairs(TypeContainDict) do
	if not getmetatable(nRelation) then
		setmetatable(nRelation, {
			__index=function(t,k,v)
				print(nType,k)
				error("TODO... not implement")
			end
		})
	end
end

function tltRelation.contain(vLeft, vRight)
	local nContain = TypeContainDict[vLeft.tag][vRight.tag]
	if nContain then
		return nContain(vLeft, vRight)
	else
		return false
	end
end

function tltRelation.sub(vLeft, vRight)
	local nContain = TypeContainDict[vRight.tag][vLeft.tag]
	if nContain then
		return nContain(vRight, vLeft)
	else
		return false
	end
end

function tltRelation.general(vType)
	if vType.tag == "TLiteral" then
		return tltype.Base(type(vType[1]))
	else
		return vType
	end
end

return tltRelation


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

	-- not compatible type
	-- TUnionlist = { },
	-- TSelf = { },
	-- TRecursive = {},
	-- TProj = { },
}
]]
