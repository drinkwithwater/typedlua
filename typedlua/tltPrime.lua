
local tltype = require "typedlua/tltype"
local tltable = require "typedlua/tltable"

local mGlobalTable = tltable.OpenTable()

local Any = tltype.Any()

local functionKeys = {
	"xpcall",
	"print",
	"pairs",
	"setmetatable",
	"tonumber",
	"rawequal",
	"tostring",
	"rawlen",
	"rawget",
	"getmetatable",
	"assert",
	"error",
	"dofile",
	"select",
	"load",
	"rawset",
	"ipairs",
	"loadfile",
	"next",
	"pcall",
	"require",
	"type",
	"collectgarbage",
}

for k, nStr in pairs(functionKeys) do
	local nKey = tltype.Literal(nStr)
	local nValue = tltype.Function(tltype.Tuple(Any), tltype.Tuple(Any))
	local nField = tltable.Field(nKey, nValue)
	tltable.insert(mGlobalTable, nField)
end

local tableKeys = {
	"math",
	"arg",
	"string",
	"coroutine",
	"_G",
	"os",
	"io",
	"table",
	"package",
	"utf8",
	"debug",
}

for k, nStr in pairs(tableKeys) do
	local nKey = tltype.Literal(nStr)
	local nValue = tltable.CloseTable(tltable.Field(Any, Any))
	local nField = tltable.Field(Any, Any)
	tltable.insert(mGlobalTable, nField)
end

return mGlobalTable
