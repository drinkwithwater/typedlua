
local tltAuto = {}

tltAuto.AUTO_SOLVING_IDLE = 1
tltAuto.AUTO_SOLVING_START = 2
tltAuto.AUTO_SOLVING_FINISH = 3


function tltAuto.AutoLink(vRegionRefer, vIndex)
	return {
		tag="TAutoLink",
		link_region_refer=vRegionRefer,
		link_index=vIndex
	}
end

-- TODO
function tltAuto.PlaceHolder()
	return {tag="TPlaceHolder"}
end

function tltAuto.AutoFunction(vRegionRefer, vInputTuple)
  return {
	  tag = "TFunction", sub_tag = "TAutoFunction",
	  auto_solving_state = tltAuto.AUTO_SOLVING_IDLE,
	  own_region_refer = vRegionRefer,
	  run_region_refer = nil,
	  run_index = nil,
	  def_region_refer = nil,
	  def_index = nil,
	  [1] = vInputTuple,
  }
end

function tltAuto.AutoTable(...)
	-- TODO check part contain type in keyset
  local nTableType = {
	  tag = "TTable", sub_tag="TAutoTable",
	  auto_solving_state = tltAuto.AUTO_SOLVING_IDLE,
	  record_dict={},
	  hash_list={},
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

function tltAuto.is_auto_type(vType)
	if vType.sub_tag == "TAutoTable" or vType.sub_tag == "TAutoFunction" then
		return true
	else
		return false
	end
end

return tltAuto
