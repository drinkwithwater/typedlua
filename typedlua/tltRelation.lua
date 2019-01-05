local tltype = require "typedlua/tltype"
local seri = require "typedlua/seri"
local tltRelation = {}

-- The first element in node are equal.
local eq1 = function(vLeft, vRight)
	return vLeft[1] == vRight[1]
end

local CONTAIN_PART = 2
local CONTAIN_FULL = 1
local CONTAIN_NIL = false
tltRelation.CONTAIN_PART = CONTAIN_PART
tltRelation.CONTAIN_FULL = CONTAIN_FULL
tltRelation.CONTAIN_NIL = CONTAIN_NIL

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
	TAny={
	},
	TLiteral={
		TLiteral=function(vLiteral, vSubLiteral)
			if (vLiteral[1] == vSubLiteral[1]) then
				return 1
			else
				return false
			end
		end,
		TBase=false,
		TGlobalVariable=false,
		TTable=false,
		TUnion=unionNil,
		TNil=false,
		TFunction=false,
	},
	TBase={
		TLiteral=function(vBase, vSubLiteral)
			local nLeftDetail = vBase[1]
			local nRightDetail = tltype.toBaseDetail(vSubLiteral[1])
			if nLeftDetail == nRightDetail then
				return CONTAIN_FULL
			elseif nLeftDetail == "number" and nRightDetail == "integer" then
				return CONTAIN_FULL
			elseif nLeftDetail == "integer" and nRightDetail == "number" then
				return CONTAIN_PART
			else
				return CONTAIN_NIL
			end
		end,
		TBase=function(vBase, vSubBase)
			local nBaseDetail = vBase[1]
			local nSubBaseDetail = vSubBase[1]
			if nBaseDetail == nSubBaseDetail then
				return CONTAIN_FULL
			elseif nBaseDetail == "number" and nSubBaseDetail == "integer" then
				return CONTAIN_FULL
			elseif nBaseDetail == "integer" and nSubBaseDetail == "number" then
				return CONTAIN_PART
			else
				return CONTAIN_NIL
			end
		end,
		TGlobalVariable=false,
		TTable=false,
		TUnion=unionNil,
		TNil=false,
		TFunction=false,
	},
	TGlobalVariable={
		TLiteral=false,
		TBase=false,
		TGlobalVariable=eq1,
		TTable=false,
		TUnion=unionNil,
		TNil=false,
		TFunction=false,
	},
	TTable={
		TLiteral=false,
		TBase=false,
		TGlobalVariable=false,
		TTable=function(vLeftTable, vRightTable)
			if vLeftTable.sub_tag == "TOpenTable" then
				if vRightTable.sub_tag == "TOpenTable" then
					if vLeftTable == vRightTable then
						print("TODO opentable relation:equal if ref same obj???")
						return CONTAIN_FULL
					else
						return CONTAIN_NIL
					end
				else
					return CONTAIN_NIL
				end
			elseif vLeftTable.sub_tag == "TCloseTable" then
				local nLeftNotnilFieldDict = {}
				for k, nField in ipairs(vLeftTable) do
					if nField.sub_tag == "TNotnilField" then
						nLeftNotnilFieldDict[k] = nField
					end
				end
				local nPartContain = false
				local nLeftRecordDict = vLeftTable.record_dict
				for nRightIndex, nRightField in ipairs(vRightTable) do
					local nLeftRecordIndex = nil
					local nRightFieldKeyType = nRightField[1]
					if nRightFieldKeyType.tag == "TLiteral" then
						nLeftRecordIndex = nLeftRecordDict[nRightFieldKeyType[1]]
					end
					if nLeftRecordIndex then
						nLeftNotnilFieldDict[nLeftRecordIndex] = nil
						-- if has mapped left record, compare record field
						local nLeftField = vLeftTable[nLeftRecordIndex]
						local nContainResult = tltRelation.contain(nLeftField[2], nRightField[2])
						if not nContainResult then
							return CONTAIN_NIL
						elseif nContainResult == CONTAIN_PART then
							nPartContain = true
						elseif nContainResult == CONTAIN_FULL then
							if nLeftField.sub_tag == "TNotnilField"
								and nRightField.sub_tag == "TNilableField" then
								nPartContain = true
							end
						end
					else
						local nHashContainRight = false
						-- if left do not has mapped left record, compare hash field
						for k, nLeftHashIndex in ipairs(vLeftTable.hash_list) do
							local nLeftField = vLeftTable[nLeftHashIndex]
							local nKeyContainResult = tltRelation.contain(nLeftField[1], nRightField[1])
							local nValueContainResult = tltRelation.contain(nLeftField[2], nRightField[2])
							if nKeyContainResult == CONTAIN_FULL then
								if not nValueContainResult then
									return CONTAIN_NIL
								elseif nValueContainResult == CONTAIN_FULL then
									nHashContainRight = true
									break
								elseif nValueContainReulst == CONTAIN_PART then
									nPartContain = true
									nHashContainRight = true
									break
								end
							elseif nKeyContainResult == CONTAIN_PART then
								if not nValueContainResult then
									return CONTAIN_NIL
								else
									nPartContain = true
									nHashContainRight = true
									break
								end
							else
								-- continue
							end
						end
						if not nHashContainRight then
							return CONTAIN_NIL
						end
					end
				end
				-- some notnil record field not existed in righttable
				local nNotMappedAll = false
				for k,v in pairs(nLeftNotnilFieldDict) do
					nNotMappedAll = true
					break
				end
				if nNotMappedAll then
					return CONTAIN_NIL
				else
					if nPartContain then
						return CONTAIN_PART
					else
						return CONTAIN_FULL
					end
				end
			else
				error("unexception table type")
				return false
			end
		end,
		TUnion=unionNil,
		TNil=false,
		TFunction=false,
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
		end,
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
		TFunction=false,
	},
	TFunction={
		TFunction=function(vFunctionType, vFunctionType)
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

return tltRelation
