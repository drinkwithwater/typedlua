
local tltype = require "typedlua.tltype"
local tltRelation = require "typedlua.tltRelation"

local tltable = {}

function tltable.OpenTable(...)
  local nTableType = { tag = "TTable", sub_tag="TOpenTable", record_dict={}, hash_list={}}
  local nRecordDict = nTableType.record_dict
  local nHashList = nTableType.hash_list
  for i=1, select("#", ...) do
	  local nField = select(i, ...)
	  local nFieldKey = nField[1]
	  local nFieldValue = nField[2]
	  if nFieldKey.tag == "TLiteral" then
		  assert(not nRecordDict[nFieldKey[1]], "TLiteral key use twice")
		  nRecordDict[nFieldKey[1]] = i
		  nTableType[i] = tltable.Field(nFieldKey, tltype.general(nFieldValue))
	  else
		  nHashList[#nHashList + 1] = i
		  nTableType[i] = tltable.Field(nFieldKey, tltype.general(nFieldValue))
	  end
  end
  return nTableType
end

function tltable.CloseTable(...)
  local nTableType = { tag = "TTable", sub_tag="TCloseTable", record_dict={}, hash_list={}, ... }
  local nRecordDict = nTableType.record_dict
  local nHashList = nTableType.hash_list
  for i, nField in ipairs(nTableType) do
	  local nFieldKey = nField[1]
	  if nFieldKey.tag == "TLiteral" then
		  assert(not nRecordDict[nFieldKey[1]], "TLiteral key use twice")
		  nRecordDict[nFieldKey[1]] = i
	  else
		  nHashList[#nHashList + 1] = i
	  end
  end
  return nTableType
end

function tltable.insert(vTableType, vFieldType)
	local nNewIndex = #vTableType + 1
	local nFieldKey = vFieldType[1]
	  if nFieldKey.tag == "TLiteral" then
		assert(not vTableType.record_dict[nFieldKey[1]], "TLiteral key use twice")
		vTableType.record_dict[nFieldKey[1]] = nNewIndex
	else
		table.insert(vTableType.hash_list, nNewIndex)
	end
	vTableType[nNewIndex] = vFieldType
end

function tltable.index_field(vTableType, vKeyType)
	if vKeyType.tag == "TLiteral" then
		local j = vTableType.record_dict[vKeyType[1]]
		if j then
			return vTableType[j]
		end
	end
	for _, j in ipairs(vTableType.hash_list) do
		if tltRelation.sub(vKeyType, vTableType[j][1]) then
			return vTableType[j]
		end
	end
	return nil
end

function tltable.Field(vKeyType, vValueType)
	return {tag = "TField", [1] = vKeyType, [2] = vValueType}
end

function tltable.NilableField(vKeyType, vValueType)
	return {tag = "TField", sub_tag = "TNilableField", [1] = vKeyType, [2] = vValueType}
end

return tltable
