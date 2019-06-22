
local tltype = require "typedlua.tltype"
local tltRelation = require "typedlua.tltRelation"

local tltable = {}

--[[@

interface TTuple
	tag=string
	sub_tag=string
	[integer]=Type
end

interface Type
	tag=string
	sub_tag=string
end

interface TField
	tag=string
	sub_tag=string
	[1]=Type
	[2]=Type
end

interface TTable
	tag=string
	sub_tag=string
	record_dict={[string]=integer}
	hash_list={[integer]=integer}
	[integer]=TField
end

]]

--@()->(TTable)
function tltable.AnyTable()
	return {tag = "TTable", sub_tag = "TAnyTable", record_dict = {}, hash_list = {}}
end

--@(TField*)->(TTable)
function tltable.TableConstructor(...)
	-- TODO check part contain type in keyset
  local nTableType = { tag = "TTable", sub_tag = "TUnknownTable", record_dict={}, hash_list={}, ... }
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

--@(TField*)->(TTable)
function tltable.StaticTable(...)
	local nStaticTable = tltable.TableConstructor(...)
	nStaticTable.sub_tag = "TStaticTable"
	return nStaticTable
end

--@(Type, TField)->(TTable)
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

--@(TTable, Type)->(TField)
function tltable.index_field(vTableType, vKeyType)
	if vTableType.sub_tag == "TAnyTable" then
		return tltable.Field(tltype.Any(), tltype.Any())
	end
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

--@(TTable)->(TTuple)
function tltable.next_return(vTableType)
	print("next TODO... merge in union")
	for i, nField in ipairs(vTableType) do
		return tltype.Tuple(nField[1], nField[2])
	end
end

--@(TTable)->(TTuple)
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

--@(Type, Type)->(TTable)
function tltable.Field(vKeyType, vValueType)
	if vKeyType.tag == "TLiteral" then
		return {tag = "TField", sub_tag = "TNotnilField", [1] = vKeyType, [2] = vValueType}
	else
		return {tag = "TField", sub_tag = "THashField", [1] = vKeyType, [2] = vValueType}
	end
end

--@(Type)->(TField)
function tltable.ArrayField(vValueType)
	return tltable.Field(tltype.Integer(), vValueType)
end

--@(Type, Type)->(TField)
function tltable.NilableField(vKeyType, vValueType)
	return {tag = "TField", sub_tag = "TNilableField", [1] = vKeyType, [2] = vValueType}
end

return tltable
