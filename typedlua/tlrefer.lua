
local tlident = require "typedlua.tlident"
local tlast = require "typedlua.tlast"
local tlvisitor = require "typedlua.tlvisitor"
local tlutils = require "typedlua.tlutils"
local tlrefer = {}

local visitor_before = {
	Do=function(visitor, stm)
		tlident.begin_scope(visitor.identTree, stm)
	end,
	While=function(visitor, stm)
		tlident.begin_scope(visitor.identTree, stm)
	end,
	Repeat=function(visitor, stm)
		tlident.begin_scope(visitor.identTree, stm)
	end,
}

local visitor_override = {
	Fornum=function(visitor, stm, node_visit)
		local block_node = nil
		node_visit(visitor, stm[2])
		node_visit(visitor, stm[3])
		if stm[5] then
			node_visit(visitor, stm[4])
			block_node = stm[5]
		else
			block_node = stm[4]
		end
		tlident.begin_scope(visitor.identTree, stm)
		visitor.define_pos = true
		node_visit(visitor, stm[1])
		visitor.define_pos = false
		node_visit(visitor, block_node)
		tlident.end_scope(visitor.identTree)
	end,
	Forin=function(visitor, stm, node_visit)
		node_visit(visitor, stm[2])

		tlident.begin_scope(visitor.identTree, stm)
		visitor.define_pos = true
		node_visit(visitor, stm[1])
		visitor.define_pos = false
		node_visit(visitor, stm[3])
		tlident.end_scope(visitor.identTree)
	end,
	Function = function(visitor, func, node_visit)
		tlident.begin_scope(visitor.identTree, func)
		visitor.define_pos = true
		node_visit(visitor, func[1])
		visitor.define_pos = false
		if func[3] then
			node_visit(visitor, func[3])
		else
			node_visit(visitor, func[2])
		end
		tlident.end_scope(visitor.identTree)
	end,
	Block=function(visitor, stm, node_visit, self_visit)
		local stack = visitor.stack
		local if_stm = stack[#stack - 1]
		if if_stm and if_stm.tag == "If" then
			tlident.begin_scope(visitor.identTree, stm)
			self_visit(visitor, stm)
			tlident.end_scope(visitor.identTree)
		else
			self_visit(visitor, stm)
		end
	end,
	Local=function(visitor, stm, node_visit)
		if #stm[2] > 0 then
			node_visit(visitor, stm[2])
		end
		visitor.define_pos = true
		node_visit(visitor, stm[1])
		visitor.define_pos = false
	end,
	Localrec=function(visitor, stm, node_visit)
		visitor.define_pos = true
		node_visit(visitor, stm[1][1])
		visitor.define_pos = false
		node_visit(visitor, stm[2][1])
	end,
	Dots=function(visitor, node)
		if visitor.define_pos then
			node.tlrefer = tlident.ident_define(visitor.identTree, node)
		else
			node.tlrefer = tlident.ident_refer(visitor.identTree, node)
		end
	end,
	Id=function(visitor, node)
		if visitor.define_pos then
			node.tlrefer = tlident.ident_define(visitor.identTree, node)
		else
			node.tlrefer = tlident.ident_refer(visitor.identTree, node)
		end
	end,
}

local visitor_after = {
	Do=function(visitor, stm)
		tlident.end_scope(visitor.identTree)
	end,
	While=function(visitor, stm)
		tlident.end_scope(visitor.identTree)
	end,
	Repeat=function(visitor, stm)
		tlident.end_scope(visitor.identTree)
	end,
}


function tlrefer.refer(ast)
	local identTree = tlident.new_tree(ast)
	local visitor = {
		identTree = identTree,
		before = visitor_before,
		override = visitor_override,
		after = visitor_after,
	}
	-- TODO set type
	local env_node = tlast.ident(0, "_ENV")
	env_node.l=0
	env_node.c=0
	env_node.tlrefer = tlident.ident_define(identTree, env_node)
	tlident.begin_scope(identTree, ast)
	tlvisitor.visit(ast, visitor)
	tlident.end_scope(identTree)

	return identTree
end

return tlrefer
