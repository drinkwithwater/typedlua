
local tlvisitor = require "typedlua/tlvisitor"
local tlvTemplate = {}

local visitor_block = {
	Block={
		before=function(visitor, node)
		end,
		after=function(visitor, node)
		end
	}
}

local visitor_stm = {
	Do={
	},
	Set={
	},
	While={
	},
	Repeat={
	},
	If={
	},
	Fornum={
	},
	Forin={
	},
	Local={
	},
	Localrec={
	},
	Goto={
	},
	Label={
	},
	Return={
	},
	Break={
	},
	Call={
	},
	Invoke={
	},
	Interface={
	},
}

local visitor_exp = {
	Nil={},
	Dots={},
	True={},
	False={},
	Number={},
	String={},

	Function = {},
	Table = {},
	Op = {},
	Paren = {},
	Call = {},
	Invoke = {},
	Id = {},
	Index = {},
}

local visitor_list = {
	ExpList={},
	Return={},
	ParList={},
	VarList={},
	NameList={},
}

local visitor_object_dict = tlvisitor.concat(visitor_block, visitor_stm, visitor_exp, visitor_list)

function tlvTemplate.visit(vFileEnv)
	local visitor = {
		object_dict = visitor_object_dict,
		buffer_list = {},
		env = vFileEnv,
	}

	tlvisitor.visit_obj(vFileEnv.ast, visitor)
end

return tlgen
