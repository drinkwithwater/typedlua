
local tltype = require "typedlua/tltype"
local tltable = require "typedlua/tltable"
local tltAuto = require "typedlua/tltAuto"
local tlt_G= require "typedlua/tltGlobal/g"

local mGlobalTable = tltAuto.AutoTable()

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

for nStr, nValue in pairs(tlt_G) do
	local nKey = tltype.Literal(nStr)
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
	local nValue = tltable.StaticTable(tltable.Field(Any, Any))
	local nField = tltable.Field(nKey, nValue)
	tltable.insert(mGlobalTable, nField)
end

return mGlobalTable
