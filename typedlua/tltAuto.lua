
local tltAuto = {}

tltAuto.AUTO_SOLVING_IDLE = 1
tltAuto.AUTO_SOLVING_ACTIVE = 2
tltAuto.AUTO_SOLVING_FINISH = 3


function tltAuto.AutoLink(vRegionRefer, vIndex)
	return {
		tag="TAutoLink",
		link_region_refer=vRegionRefer,
		link_index=vIndex
	}
end

function tltAuto.PlaceHolder()
	return {tag="TPlaceHolder"}
end

function tltAuto.AutoFunction(vRegionRefer, vInputTuple)
  return {
	  tag = "TFunction", sub_tag = "TAutoFunction",
	  auto_solving_state = tltAuto.AUTO_SOLVING_IDLE,
	  region_refer = vRegionRefer,
	  [1] = vInputTuple,
  }
end

function tltAuto.closure_copy_function(vAutoFunction)
	local nCopyFunction = {}
	for k,v in pairs(vAutoFunction) do
		nCopyFunction[k] = v
	end
	return nCopyFunction
end

function tltAuto.AutoTable(...)
	-- TODO check part contain type in keyset
  local nTableType = {
	  tag = "TTable", sub_tag="TAutoTable",
	  auto_solving_state = tltAuto.AUTO_SOLVING_IDLE,
	  record_dict={}, hash_list={},
	  ...
  }
  local nRecordDict = nTableType.record_dict
  local nHashList = nTableType.hash_list
  for i, nField in ipairs(nTableType) do
	  local nFieldKey = nField[1]
	  local nFieldValue = nField[2]
	  if nFieldKey.tag == "TLiteral" then
		  assert(not nRecordDict[nFieldKey[1]], "TLiteral key use twice")
		  nRecordDict[nFieldKey[1]] = i
	  else
		  error("error!!!!!!!!!!!!, auto table cannot has hash field...")
	  end
  end
  return nTableType
end

function tltAuto.closure_copy_table(vAutoTable)
	local nCopyTable = {
		tag = "TTable", sub_tag = "TAutoTable",
		auto_solving_state = tltAuto.AUTO_SOLVING_IDLE,
	}
	error("TODO")
	return nCopyTable
end

return tltAuto
