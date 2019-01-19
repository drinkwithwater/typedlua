--[[
This module implements Ident Node's reference
]]
local tleIdent = require "typedlua.tleIdent"
local tlast = require "typedlua.tlast"
local tlvisitor = require "typedlua.tlvisitor"
local tlutils = require "typedlua.tlutils"
local tlvRefer = {}

local visitor_before = {
	Do=function(visitor, stm)
		tleIdent.begin_scope(visitor.ident_tree, stm)
	end,
	While=function(visitor, stm)
		tleIdent.begin_scope(visitor.ident_tree, stm)
	end,
	Repeat=function(visitor, stm)
		tleIdent.begin_scope(visitor.ident_tree, stm)
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
		tleIdent.begin_scope(visitor.ident_tree, stm)
		visitor.define_pos = true
		node_visit(visitor, stm[1])
		visitor.define_pos = false
		node_visit(visitor, block_node)
		tleIdent.end_scope(visitor.ident_tree)
	end,
	Forin=function(visitor, stm, node_visit)
		node_visit(visitor, stm[2])

		tleIdent.begin_scope(visitor.ident_tree, stm)
		visitor.define_pos = true
		node_visit(visitor, stm[1])
		visitor.define_pos = false
		node_visit(visitor, stm[3])
		tleIdent.end_scope(visitor.ident_tree)
	end,
	Function = function(visitor, func, node_visit)
		tleIdent.begin_scope(visitor.ident_tree, func)
		visitor.define_pos = true
		node_visit(visitor, func[1])
		visitor.define_pos = false
		if func[3] then
			node_visit(visitor, func[3])
		else
			node_visit(visitor, func[2])
		end
		tleIdent.end_scope(visitor.ident_tree)
	end,
	Block=function(visitor, stm, node_visit, self_visit)
		local stack = visitor.stack
		local if_stm = stack[#stack - 1]
		if if_stm and if_stm.tag == "If" then
			tleIdent.begin_scope(visitor.ident_tree, stm)
			self_visit(visitor, stm)
			tleIdent.end_scope(visitor.ident_tree)
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
			node.refer = tleIdent.ident_define(visitor.ident_tree, node)
		else
			-- TODO for ... in global
			node.refer = assert(tleIdent.ident_refer(visitor.ident_tree, node))
		end
	end,
	Id=function(visitor, node)
		if visitor.define_pos then
			node.refer = tleIdent.ident_define(visitor.ident_tree, node)
		else
			local refer = tleIdent.ident_refer(visitor.ident_tree, node)
			if refer then
				node.refer = refer
			else
				-- unrefered ident converse to global
				node.tag = "Index"

				-- ident
				local e1 = tlast.ident(node.pos, "_ENV")
				e1.l, e1.c = node.l, node.c
				e1.refer = tleIdent.ident_refer(visitor.ident_tree, e1)
				node[1] = e1

				-- key
				local e2 = tlast.exprString(node.pos, node[1])
				e2.l, e2.c = node.l, node.c
				node[2] = e2
			end
		end
	end,
}

local visitor_after = {
	Do=function(visitor, stm)
		tleIdent.end_scope(visitor.ident_tree)
	end,
	While=function(visitor, stm)
		tleIdent.end_scope(visitor.ident_tree)
	end,
	Repeat=function(visitor, stm)
		tleIdent.end_scope(visitor.ident_tree)
	end,
}


function tlvRefer.refer(vGlobalEnv, ast)
	local nIdentTree = tleIdent.new_tree(vGlobalEnv, ast)
	local visitor = {
		ident_tree = nIdentTree,
		before = visitor_before,
		override = visitor_override,
		after = visitor_after,
	}
	-- TODO set type
	local env_node = tlast.ident(0, "_ENV")
	env_node.l=0
	env_node.c=0
	env_node.refer = tleIdent.ident_define(nIdentTree, env_node)
	tleIdent.begin_scope(nIdentTree, ast)
	tlvisitor.visit_raw(ast, visitor)
	tleIdent.end_scope(nIdentTree)

	return nIdentTree
end

return tlvRefer
