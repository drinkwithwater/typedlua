local tlnode = {}

--[[
interface Tag
	tostring:()->(string)
end

interface NodeClass
	addDeriveList:({string})->()
	bindFunction:(any)->(any)
end

]]

local NodeMeta = {}

function tlnode.createNodeClass(tag)
end

local TAG = {
	"Set",
	"While",
	"Repeat",
	"If",
	"Fornum",
	"Forin",
	"Local",
	"Locarec",
	"Goto",
	"Label",
	"Return",
	"Break",

	"Dots",
	"True",
	"False",
	"Number",
	"String",
	"Function",
	"Table",
	"Op",
	"Paren",

	"Call",
	"Invoke",

	"Index",
	"Id",
}

local TYPE_TAG = {
	"TLiteral",
	"TBase",
	"TNil",
	"TValue",
	"TAny",
	"TSelf",
	"TUnion",
	"TFunction",
	"TTable",
	"TVariable",
	"TRecursive",
	"TVoid",
	"TUnionlist",
	"TTuple",
	"TVararg",
}

local NODE = {
	"block",
	"stat",
	"expr",
	"apply",
	"lhs",

	"literal",
	"base",

	"type",
	"field",
}

local typeSet = {}

for k,v in pairs(TYPE_TAG) do
	typeSet[v] = true
end

function tlnode.isType(tag)
	return typeSet[tag] == true
end


return tlnode
