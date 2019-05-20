
local tltype = require "typedlua.tltype"
local tltRelation = require "typedlua.tltRelation"

local tltable = {}


function tltable.AnyTable()
	return {tag = "TTable", sub_tag = "TAnyTable", record_dict = {}, hash_list = {}}
end

function tltable.StaticTable(...)
	-- TODO check part contain type in keyset
  local nTableType = { tag = "TTable", sub_tag="TStaticTable", record_dict={}, hash_list={}, ... }
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

function tltable.next_return(vTableType)
	print("next TODO... merge in union")
	for i, nField in ipairs(vTableType) do
		return tltype.Tuple(nField[1], nField[2])
	end
end

function tltable.inext_return(vTableType)
	print("inext TODO... merge in union")
	for i, nField in ipairs(vTableType) do
		local nKeyType = nField[1]
		if nKeyType.tag == "TBase" and nKeyType[1] == "integer" then
			return tltype.Tuple(nField[1], nField[2])
		elseif nKeyType.tag == "TLiteral" and type(nKeyType[1]=="number") then
			return tltype.Tuple(nField[1], nField[2])
		end
	end
end

function tltable.Field(vKeyType, vValueType)
	if vKeyType.tag == "TLiteral" then
		return {tag = "TField", sub_tag = "TNotnilField", [1] = vKeyType, [2] = vValueType}
	else
		return {tag = "TField", sub_tag = "THashField", [1] = vKeyType, [2] = vValueType}
	end
end

function tltable.ArrayField(vValueType)
	return tltable.Field(tltype.Integer(i), vValueType)
end

function tltable.NilableField(vKeyType, vValueType)
	return {tag = "TField", sub_tag = "TNilableField", [1] = vKeyType, [2] = vValueType}
end

function tltable.fieldlist(idlist, t)
  local l = {}
  for _, v in ipairs(idlist) do
    table.insert(l, tltable.Field(tltype.Literal(v[1]), t))
  end
  return table.unpack(l)
end


return tltable
