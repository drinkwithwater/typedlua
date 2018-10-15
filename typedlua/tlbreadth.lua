
local tlvisitor = require "typedlua/tlvisitor"
local tltype = require "typedlua/tltype"
local tlbreadth = {}

local function typeerror(env, node, ...)
	error(...)
end

local function set_type(node, t)
	if node.right_deco then
		if not tltype.subtype(t, node.right_deco) then
			typeerror(nil, node, "typeerror")
		end
	end
	node.type = t
end

local visitor_override = {
	Function = function(visitor, node)
		visitor.func_block_list[#visitor.func_block_list + 1] = node[3] or node[2]
	end
}

local visitor_after = {
	String=function(visitor, node)
		set_type(node, tltype.Literal(node[1]))
	end,
	Number=function(visitor, node)
		set_type(node, tltype.Literal(node[1]))
	end,
	Set=function(visitor, node)
	end,
	Localrec=function(visitor, node)
	end,
	Local=function(visitor, node)
	end,
}

function tlbreadth.visit_block(block, visitor)
	tlvisitor.visit(block, visitor)
	local func_block_list = visitor.func_block_list
	visitor.func_block_list = {}
	for _, sub_block in pairs(func_block_list) do
		tlbreadth.visit_block(sub_block, visitor)
	end
end

function tlbreadth.visit(ast, uvtree)
	local visitor = {
		override = visitor_override,
		after = visitor_after,
		uvtree = uvtree,
		func_block_list = {},
	}

	tlvisitor.visit(ast, visitor)
	local func_block_list = visitor.func_block_list
	visitor.func_block_list = {}
	for _, sub_block in pairs(func_block_list) do
		tlbreadth.visit_block(sub_block, visitor)
	end
end

return tlbreadth
