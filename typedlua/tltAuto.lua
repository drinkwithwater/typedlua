
local tltable = require "typedlua/tltable"
local tltype = require "typedlua/tltype"
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

function tltAuto.FunctionAuto(vRegionRefer, vFunctionConstructor)
	return {
		tag = "TAutoType", sub_tag = "TFunctionAuto",
		auto_solving_state = tltAuto.AUTO_SOLVING_IDLE,
		own_region_refer = vRegionRefer,
		run_region_refer = nil,
		run_index = nil,
		def_region_refer = nil,
		def_index = nil,
		[1] = vFunctionConstructor or tltype.FunctionConstructor(),
	}
end

function tltAuto.TableAuto(vTableConstructor)
	return {
		tag = "TAutoType", sub_tag = "TTableAuto",
		auto_solving_state = tltAuto.AUTO_SOLVING_IDLE,
		run_region_refer = nil,
		run_index = nil,
		def_region_refer = nil,
		def_index = nil,
		[1] = vTableConstructor or tltable.TableConstructor(),
	}
end

return tltAuto
