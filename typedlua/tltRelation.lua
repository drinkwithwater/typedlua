local seri = require "typedlua/seri"
local tltRelation = {}

--@(any)->(string)
function tltRelation.to_base_detail(vValue)
	local nValueType = type(vValue)
	if type(vValue) == "number" then
		if vValue % 1 == 0 then
			return "integer"
		end
	end
	return nValueType
end

local CONTAIN_PART = 2
local CONTAIN_FULL = 1
local CONTAIN_NIL = false
tltRelation.CONTAIN_PART = CONTAIN_PART
tltRelation.CONTAIN_FULL = CONTAIN_FULL
tltRelation.CONTAIN_NIL = CONTAIN_NIL

local function containFull()
	return CONTAIN_FULL
end

local function containPart()
	return CONTAIN_PART
end

local function containNil()
	return CONTAIN_NIL
end

-- The first element in node are equal.
local eq1 = function(vLeft, vRight)
	if vLeft[1] == vRight[1] then
		return CONTAIN_FULL
	else
		return CONTAIN_NIL
	end
end

local function singleContainAny()
	return CONTAIN_PART
end

local function singleContainUnion(vType, vUnion)
	if #vUnion < 2 then
		error("union 1 item...")
	end
	for i, nSubType in ipairs(vUnion) do
		local nContainResult = tltRelation.contain(vType, nSubType)
		if nContainResult then
			-- singletype can only contain part uniontype
			return CONTAIN_PART
		end
	end
	return CONTAIN_NIL
end

local function setDefault(vTable, vDefaultFunction)
	return setmetatable(vTable, {
		__index=function(vT, vSubTypeTag)
			rawset(vT, vSubTypeTag, vDefaultFunction)
			return vDefaultFunction
		end
	})
end

local TypeContainDict = {
	TAny=setDefault({}, containFull),
	TLiteral=setDefault({
		TLiteral=function(vLiteral, vSubLiteral)
			if (vLiteral[1] == vSubLiteral[1]) then
				return CONTAIN_FULL
			else
				return CONTAIN_NIL
			end
		end,
		TBase=function(vLiteral, vBase)
			local nRightDetail = vBase[1]
			local nLeftDetail = tltRelation.to_base_detail(vLiteral[1])
			if nLeftDetail == nRightDetail then
				return CONTAIN_PART
			elseif nLeftDetail == "number" and nRightDetail == "integer" then
				return CONTAIN_PART
			elseif nLeftDetail == "integer" and nRightDetail == "number" then
				return CONTAIN_PART
			else
				return CONTAIN_NIL
			end
		end,
		TUnionType			= singleContainUnion,
		TAny			= singleContainAny,
	}, containNil),
	TBase=setDefault({
		TLiteral=function(vBase, vSubLiteral)
			local nLeftDetail = vBase[1]
			local nRightDetail = tltRelation.to_base_detail(vSubLiteral[1])
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
		TUnionType			= singleContainUnion,
		TAny			= singleContainAny,
	}, containNil),
	--[[
	--global variable TODO
	TGlobalVariable=setDefault({
		TGlobalVariable	= eq1,
		TUnionType			= singleContainUnion,
		TAny			= singleContainAny,
	}, containNil),]]
	TTable=setDefault({
		TTable=function(vLeftTable, vRightTable)
			if vLeftTable.sub_tag == "TAnyTable" then
				return CONTAIN_FULL
			elseif vRightTable.sub_tag == "TAnyTable" then
				return CONTAIN_PART
			elseif vLeftTable.sub_tag == "TStaticTable" and vRightTable.sub_tag == "TStaticTable" then
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
								elseif nValueContainResult == CONTAIN_PART then
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
				return CONTAIN_NIL
			end
		end,
		TUnionType			= singleContainUnion,
		TAny			= singleContainAny,
	}, containNil),
	TUnionType=setDefault({
		TUnionType=function(vUnion, vSubUnion)
			local nContainPart = false
			for k, nSubUnionItem in ipairs(vSubUnion) do
				local nContainResult = tltRelation.contain(vUnion, nSubUnionItem)
				if not nContainResult then
					return CONTAIN_NIL
				elseif nContainResult == CONTAIN_PART then
					nContainPart = true
				end
			end
			if nContainPart then
				return CONTAIN_PART
			else
				return CONTAIN_FULL
			end
		end,
		TAny=singleContainAny,
		TAutoLink		= containNil,
	},function(vUnion, vSubType)
			for k, nUnionItem in ipairs(vUnion) do
				local nContainResult = tltRelation.contain(nUnionItem, vSubType)
				if nContainResult then
					return nContainResult
				end
			end
			return CONTAIN_NIL
	end),
	TNil=setDefault({
		TNil			= containFull,
		TUnionType			= singleContainUnion,
		TAny			= singleContainAny,
	}, containNil),
	TFunction=setDefault({
		TFunction=function(vLeftFuncType, vRightFuncType)
			print("function relation TODO")
			if vLeftFuncType == vRightFuncType then
				return CONTAIN_FULL
			else
				return CONTAIN_NIL
			end
		end,
		TUnionType			= singleContainUnion,
		TAny			= singleContainAny,
	}, containNil),
	TUnionState=setDefault({
	}, containNil),
	TDefineType=setDefault({
		TDefineType=function(vLeftDefine, vRightDefine)
			if vLeftDefine.name == vRightDefine.name then
				return CONTAIN_FULL
			else
				return CONTAIN_NIL
			end
		end,
		TUnionType			= singleContainUnion,
		TAny			= singleContainAny,
	}, containNil),
	TDefineRefer=setDefault({
		TDefineRefer=function(vLeftDefineRefer, vRightDefineRefer)
			if vLeftDefineRefer.name == vRightDefineRefer.name then
				return CONTAIN_FULL
			else
				return CONTAIN_NIL
			end
		end,
		TUnionType			= singleContainUnion,
		TAny			= singleContainAny,
	}, containNil),
	TAutoLink=setDefault({}, function()
		error("TODO AutoLink relation ...........")
		return CONTAIN_FULL
	end),
}

for nType, nRelation in pairs(TypeContainDict) do
	if not getmetatable(nRelation) then
		setmetatable(nRelation, {
			__index=function(t,k,v)
				print(nType,k)
				error("TODO... contain not implement")
			end
		})
	end
end

--@(any, any)->(any)
function tltRelation.contain(vLeft, vRight)
	local nContain = TypeContainDict[vLeft.tag][vRight.tag]
	if nContain then
		return nContain(vLeft, vRight)
	else
		return CONTAIN_NIL
	end
end

--@(any, any)->(any)
function tltRelation.sub(vLeft, vRight)
	local nContain = TypeContainDict[vRight.tag][vLeft.tag]
	if nContain then
		return nContain(vRight, vLeft)
	else
		return CONTAIN_NIL
	end
end

return tltRelation
