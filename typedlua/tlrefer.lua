
local tluv = require "typedlua.tluv"
local tlast = require "typedlua.tlast"
local tlvisitor = require "typedlua.tlvisitor"
local tlutils = require "typedlua.tlutils"
local tlrefer = {}

local visitor_before = {
	Do=function(visitor, stm)
		tluv.begin_scope(visitor.uvtree, stm)
	end,
	While=function(visitor, stm)
		tluv.begin_scope(visitor.uvtree, stm)
	end,
	Repeat=function(visitor, stm)
		tluv.begin_scope(visitor.uvtree, stm)
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
		tluv.begin_scope(visitor.uvtree, stm)
		visitor.define_pos = true
		node_visit(visitor, stm[1])
		visitor.define_pos = false
		node_visit(visitor, block_node)
		tluv.end_scope(visitor.uvtree)
	end,
	Forin=function(visitor, stm, node_visit)
		node_visit(visitor, stm[2])

		tluv.begin_scope(visitor.uvtree, stm)
		visitor.define_pos = true
		node_visit(visitor, stm[1])
		visitor.define_pos = false
		node_visit(visitor, stm[3])
		tluv.end_scope(visitor.uvtree)
	end,
	Function = function(visitor, func, node_visit)
		tluv.begin_scope(visitor.uvtree, func)
		visitor.define_pos = true
		node_visit(visitor, func[1])
		visitor.define_pos = false
		if func[3] then
			node_visit(visitor, func[3])
		else
			node_visit(visitor, func[2])
		end
		tluv.end_scope(visitor.uvtree)
	end,
	Block=function(visitor, stm, node_visit, self_visit)
		local stack = visitor.stack
		local if_stm = stack[#stack - 1]
		if if_stm and if_stm.tag == "If" then
			tluv.begin_scope(visitor.uvtree, stm)
			self_visit(visitor, stm)
			tluv.end_scope(visitor.uvtree)
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
			tluv.ident_define(visitor.uvtree, node)
		else
			tluv.ident_refer(visitor.uvtree, node)
		end
	end,
	Id=function(visitor, node)
		if visitor.define_pos then
			tluv.ident_define(visitor.uvtree, node)
		else
			tluv.ident_refer(visitor.uvtree, node)
		end
	end,
}

local visitor_after = {
	Do=function(visitor, stm)
		tluv.end_scope(visitor.uvtree)
	end,
	While=function(visitor, stm)
		tluv.end_scope(visitor.uvtree)
	end,
	Repeat=function(visitor, stm)
		tluv.end_scope(visitor.uvtree)
	end,
}


function tlrefer.refer(ast)
	local uvtree = tluv.new_tree(ast)
	local visitor = {
		uvtree = uvtree,
		before = visitor_before,
		override = visitor_override,
		after = visitor_after,
	}
	-- TODO set type
	local env_node = tlast.ident(0, "_ENV")
	env_node.l=0
	env_node.c=0
	tluv.ident_define(uvtree, env_node)
	tluv.begin_scope(uvtree, ast)
	tlvisitor.visit(ast, visitor)
	tluv.end_scope(uvtree)

	return uvtree
end

return tlrefer
