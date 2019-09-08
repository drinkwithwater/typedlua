
local tltype = require "typedlua.tltype"
local tltRelation = require "typedlua.tltRelation"

local tleUnion = {}

function tleUnion.UnionType(...)
	return {tag = "TUnionType", ...}
end

-- called when tag=local
function tleUnion.create_union_deduce(vFileEnv, vUnionType)
	local nNewRefer = #vFileEnv.union_deduce_list + 1
	local nValidTypeDict = {}
	for i=1, #vUnionType do
		nValidTypeDict[i] = vUnionType[i]
	end
	local nUnionState = {
		tag = "TUnionDeduce",
		deduce_refer = nNewRefer,
		tree_refer = nil,
		valid_type_dict = nValidTypeDict,
		deduce_list = nil,
	}
	vFileEnv.union_deduce_list[nNewRefer] = nUnionState
	return nUnionState
end

-- for ident refer, TODO
function tleUnion.create_extern_union_deduce(vFileEnv, vUnionDeduce, vCaseIndexSet)
	local nValidTypeDict = nil
	if vCaseIndexSet then
		nValidTypeDict = {}
		for nIndex, _ in pairs(vCaseIndexSet) do
			nValidTypeDict[nIndex] = vUnionDeduce.valid_type_dict[nIndex]
		end
	end
	return setmetatable({
		sub_tag = "TExternUnionDeduce",
		valid_type_dict = nValidTypeDict,
	}, {
		__index=vUnionDeduce,
	})
end

function tleUnion.create_deduce_tree(vFileEnv, vRootDeduceUnion)
	local nNewRefer = #vFileEnv.union_deduce_tree_list + 1
	local nTree = {
		tag = "TDeduceTree",
		root_deduce_refer = nil,
		tree_refer = nNewRefer,
		extern_union_deduce_dict = {},
	}
	vFileEnv.union_deduce_tree_list[tree_refer] = nTree
	return nTree
end

function tleUnion.deduce_next(vIndexSet, vDeduceList)
	local nUnionReferToIndexSet = {}
	local nIndex, _b1 = next(vIndexSet)
	if nIndex then
		for nUnionRefer, nNextIndexSet in pairs(vDeduceList[nIndex]) do
			local nCopyIndexSet = {}
			for nNextIndex, _ in pairs(nNextIndexSet) do
				nCopyIndexSet[nNextIndex] = true
			end
			nUnionReferToIndexSet[nUnionRefer] = nCopyIndexSet
		end
		while true do
			nIndex, _b1 = next(vIndexSet, nIndex)
			if not nIndex then
				break
			end
			local nNextUnionReferToIndexSet = vDeduceList[nIndex]
			for nUnionRefer, nIndexSet in pairs(nUnionReferToIndexSet) do
				local nNextIndexSet = nNextUnionReferToIndexSet[nUnionRefer]
				if not nNextIndexSet then
					nUnionReferToIndexSet[nUnionRefer] = nil
				else
					for nNextIndex, _b2 in pairs(nNextIndexSet) do
						nIndexSet[nNextIndex] = true
					end
				end
			end
		end
		if not next(nUnionReferToIndexSet) then
			return nil
		else
			return nUnionReferToIndexSet
		end
	else
		-- mDeduceList[nIndex] = vIndexSet
		-- then mUnionType[nIndex] deduce empty case
		return nil
	end
end

-- {[refer1]->{index1_1,index1_2}, [refer2]={index2_1,index2_2}} and {[vRightUnionRefer]=vRightIndexSet}
function tleUnion.deduce_and(vLeftReferToIndexSet, vRightUnionRefer, vRightIndexSet)
	local nLeftIndexSet = vLeftReferToIndexSet[vRightUnionRefer]
	if not nLeftIndexSet then
		vLeftReferToIndexSet[vRightUnionRefer] = vRightIndexSet
	else
		for nLeftIndex, _ in pairs(nLeftIndexSet) do
			if not vRightIndexSet[nLeftIndex] then
				nLeftIndexSet[nLeftIndex] = nil
			end
		end
	end
end

function tleUnion.__eq(vFileEnv, vLeftType, vRightType)
	if (vLeftType.tag == "TUnionDeduce") and (vRightType.tag ~= "TUnionDeduce") then
		local nLeftUnionDeduce = vLeftType
		local nTrueDeduceIndexSet = {}
		local nFalseDeduceIndexSet = {}
		for nIndex, nType in pairs(nLeftUnionDeduce.valid_type_dict) do
			if tltRelation.contain(nType, vRightType) then
				print("think if vRightType is union ???")
				nTrueDeduceIndexSet[nIndex] = true
				if nType.tag ~= "TLiteral" or vRightType.tag ~= "TLiteral" then
					nFalseDeduceIndexSet[nIndex] = true
				end
			else
				nFalseDeduceIndexSet[nIndex] = true
			end
		end
		-- if state is local variable's then deduce one distance
		if nLeftUnionDeduce.sub_tag == "TExternUnionDeduce" then
			local nUnionType = tleUnion.UnionType()
			local nDeduceList = {}
			if next(nTrueDeduceIndexSet) then
				nUnionType[1] = tltype.Literal(true)
				nDeduceList[1] = {
					[nLeftUnionDeduce.deduce_refer] = nTrueDeduceIndexSet
				}
			end
			if next(nFalseDeduceIndexSet) then
				nUnionType[#nUnionType + 1] = tltype.Literal(false)
				nDeduceList[#nDeduceList + 1] = {
					[nLeftUnionDeduce.deduce_refer] = nFalseDeduceIndexSet
				}
			end
			local nResultUnionDeduce = tleUnion.create_union_deduce(vFileEnv, nUnionType)
			nResultUnionDeduce.deduce_list = nDeduceList
			return nResultUnionDeduce
		else
			local nUnionType = tleUnion.UnionType()
			local nDeduceList = {}
			if next(nTrueDeduceIndexSet) then
				local nUnionReferToIndexSet = tleUnion.deduce_next(nTrueDeduceIndexSet, nLeftUnionDeduce.deduce_list)
				if nUnionReferToIndexSet then
					nUnionType[1] = tltype.Literal(true)
					nDeduceList[1] = nUnionReferToIndexSet
				end
			end
			if next(nFalseDeduceIndexSet) then
				local nUnionReferToIndexSet = tleUnion.deduce_next(nFalseDeduceIndexSet, nLeftUnionDeduce.deduce_list)
				if nUnionReferToIndexSet then
					nUnionType[#nUnionType + 1] = tltype.Literal(false)
					nDeduceList[#nDeduceList + 1] = nUnionReferToIndexSet
				end
			end
			local nResultUnionDeduce = tleUnion.create_deduce_union(vFileEnv, nUnionType)
			nResultUnionDeduce.deduce_list = nDeduceList
			return nResultUnionDeduce
		end
	else
		print("TODO __eq union other case", vLeftType.tag, vRightType.tag)
	end
end

function tleUnion._or(vLeftType, vRightType)
end

-- called when tag=assign
function tleUnion.reset_union_state()
end

-- called when tag=ifexp / whileexp
function tleUnion.gen_control()
end

-- put for if while block
function tleUnion.control_scope_begin(vFileEnv, vScopeRefer, vUnionRefer, vControl)
end

function tleUnion.control_scope_end(vFileEnv, vScopeRefer)
	-- TODO clean union in parent
end

function tleUnion.UnionTODO(...)
	local nTypeList = {...}
	local nUnionType = {tag = "TUnionType"}
	for i, nType in ipairs(nTypeList) do
		local nRightList = nType
		if nType.tag ~= "TUnionType" then
			nRightList = {nType}
		end
		for j, nRightType in ipairs(nRightList) do
			local nFullContain = false
			local nFullBelong = false
			for k, nLeftType in ipairs(nUnionType) do
				-- right in left, do nothing
				local nLeftContainRight = tltRelation.contain(nLeftType, nRightType)
				if nLeftContainRight == tltRelation.CONTAIN_FULL then
					nFullContain = true
				end
				-- left in right, replace left with right
				local nRightContainLeft = tltRelation.contain(nRightType, nLeftType)
				if nRightContainLeft == tltRelation.CONTAIN_FULL then
					nFullBelong = k
				end
				if nLeftContainRight == tltRelation.CONTAIN_PART
					and nRightContainLeft == tltRelation.CONTAIN_PART then
					print("union type in unimplement case")
				end
			end
			if not nFullContain then
				if nFullBelong then
					nUnionType[nFullBelong] = nRightType
				else
					nUnionType[#nUnionType + 1] = nRightType
				end
			end
		end
	end
	return nUnionType
end

function tleUnion.UnionNil (vType, vIsUnionNil)
	if vIsUnionNil then
		if vType.tag == "TUnionType" then
			vType[#vType + 1] = tltype.Nil()
			return vType
		else
			return tleUnion.UnionType(vType, tltype.Nil())
		end
	else
		return vType
	end
end

return tleUnion
