
local tlvisitor = require "typedlua/tlvisitor"
local tlvGenerator = {}

local function push(vNode, vBuffer)
	local vList = vNode.buffer
	if vBuffer then
		if type(vBuffer) == "string" then
			table.insert(vList, vBuffer)
		elseif type(vBuffer) == "table" then
			for i=1, #vBuffer do
				table.insert(vList, vBuffer[i])
			end
		else
			error("type error when buffer push"..type(vBuffer))
		end
	else
		print(vNode.tag)
	end
end

local visitor_block = {
	Block={
		before=function(visitor, node)
			node.buffer = {}
		end,
		after=function(visitor, node)
			for k, nSubNode in ipairs(node) do
				push(node, nSubNode.buffer)
			end
		end
	}
}

local visitor_stm = {
	Do={
		before=function(visitor, node)
			node.buffer = {" do "}
		end,
		after=function(visitor, node)
			push(node, node[1].buffer)
			push(node, " end ")
		end
	},
	Set={
		before=function(visitor, node)
			node.buffer = {" local "}
		end,
		after=function(visitor, node)
			push(node, node[1].buffer)
			push(node, " = ")
			push(node, node[2].buffer)
		end
	},
	While={
		before=function(visitor, node)
			node.buffer = {" while "}
		end,
		after=function(visitor, node)
			push(node, node[1].buffer)
			push(node, " do ")
			push(node, node[2].buffer)
			push(node, " end ")
		end
	},
	Repeat={
		before=function(visitor, node)
		end,
		after=function(visitor, node)
		end,
	}
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
	ExpList={}
	Return={},
	ParList={},
	VarList={},
	NameList={},
}

local visitor_object_dict = tlvisitor.concat(visitor_block, visitor_stm, visitor_exp, visitor_list)

function tlvGenerator.visit(vFileEnv)
	local visitor = {
		object_dict = visitor_object_dict,
		buffer_list = {},
		env = vFileEnv,
	}

	tlvisitor.visit_obj(vFileEnv.ast, visitor)
end

return tlgen
