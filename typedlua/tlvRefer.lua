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
		tleIdent.begin_scope(visitor.file_env, stm)
	end,
	While=function(visitor, stm)
		tleIdent.begin_scope(visitor.file_env, stm)
	end,
	Repeat=function(visitor, stm)
		tleIdent.begin_scope(visitor.file_env, stm)
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
		tleIdent.begin_scope(visitor.file_env, stm)
		visitor.define_pos = true
		node_visit(visitor, stm[1])
		visitor.define_pos = false
		node_visit(visitor, block_node)
		tleIdent.end_scope(visitor.file_env)
	end,
	Forin=function(visitor, stm, node_visit)
		node_visit(visitor, stm[2])

		tleIdent.begin_scope(visitor.file_env, stm)
		visitor.define_pos = true
		node_visit(visitor, stm[1])
		visitor.define_pos = false
		node_visit(visitor, stm[3])
		tleIdent.end_scope(visitor.file_env)
	end,
	Function = function(visitor, func, node_visit)
		tleIdent.begin_scope(visitor.file_env, func)
		visitor.define_pos = true
		node_visit(visitor, func[1])
		visitor.define_pos = false
		if func[3] then
			node_visit(visitor, func[3])
		else
			node_visit(visitor, func[2])
		end
		tleIdent.end_scope(visitor.file_env)
	end,
	Block=function(visitor, stm, node_visit, self_visit)
		local stack = visitor.stack
		local if_stm = stack[#stack - 1]
		if if_stm and if_stm.tag == "If" then
			tleIdent.begin_scope(visitor.file_env, stm)
			self_visit(visitor, stm)
			tleIdent.end_scope(visitor.file_env)
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
			node.refer = tleIdent.ident_define(visitor.file_env, node)
		else
			-- TODO for ... in global
			error("... TODO in chunk scope")
			node.refer = assert(tleIdent.ident_refer(visitor.file_env, node))
		end
	end,
	Id=function(visitor, node)
		if visitor.define_pos then
			node.refer = tleIdent.ident_define(visitor.file_env, node)
		else
			local refer = tleIdent.ident_refer(visitor.file_env, node)
			if refer then
				node.refer = refer
			else
				-- unrefered ident converse to global
				node.tag = "Index"

				-- ident
				local e1 = tlast.ident(node.pos, "_ENV")
				e1.l, e1.c = node.l, node.c
				e1.refer = tleIdent.ident_refer(visitor.file_env, e1)
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
		tleIdent.end_scope(visitor.file_env)
	end,
	While=function(visitor, stm)
		tleIdent.end_scope(visitor.file_env)
	end,
	Repeat=function(visitor, stm)
		tleIdent.end_scope(visitor.file_env)
	end,
}


function tlvRefer.refer(vFileEnv)
	local visitor = {
		file_env = vFileEnv,
		before = visitor_before,
		override = visitor_override,
		after = visitor_after,
	}
	tleIdent.begin_scope(vFileEnv, vFileEnv.ast)
	tlvisitor.visit_raw(vFileEnv.ast, visitor)
	tleIdent.end_scope(vFileEnv)

	return vFileEnv
end

return tlvRefer
