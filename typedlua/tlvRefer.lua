--[[
This module add ident_refer & scope_refer & region_refer to some node.
]]
local tlenv = require "typedlua.tlenv"
local tlast = require "typedlua.tlast"
local tlvisitor = require "typedlua.tlvisitor"
local tlutils = require "typedlua.tlutils"
local tlvRefer = {}

local visitor_before = {
	Do=function(visitor, stm)
		tlvRefer.scope_begin(visitor, stm)
	end,
	While=function(visitor, stm)
		tlvRefer.scope_begin(visitor, stm)
	end,
	Repeat=function(visitor, stm)
		tlvRefer.scope_begin(visitor, stm)
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
		tlvRefer.scope_begin(visitor, stm)
		visitor.define_pos = true
		node_visit(visitor, stm[1])
		visitor.define_pos = false
		node_visit(visitor, block_node)
		tlvRefer.scope_end(visitor)
	end,
	Forin=function(visitor, stm, node_visit)
		node_visit(visitor, stm[2])

		tlvRefer.scope_begin(visitor, stm)
		visitor.define_pos = true
		node_visit(visitor, stm[1])
		visitor.define_pos = false
		node_visit(visitor, stm[3])
		tlvRefer.scope_end(visitor)
	end,
	Function=function(visitor, func, node_visit)
		tlvRefer.scope_begin(visitor, func)
		visitor.define_pos = true
		node_visit(visitor, func[1])
		visitor.define_pos = false
		if func[3] then
			node_visit(visitor, func[3])
		else
			node_visit(visitor, func[2])
		end
		tlvRefer.scope_end(visitor)
	end,
	Block=function(visitor, stm, node_visit, self_visit)
		local stack = visitor.stack
		local if_stm = stack[#stack - 1]
		if if_stm and if_stm.tag == "If" then
			tlvRefer.scope_begin(visitor, stm)
			local nCurScope = visitor.scope_stack[#visitor.scope_stack]
			stm.self_scope_refer = nCurScope.scope_refer
			self_visit(visitor, stm)
			tlvRefer.scope_end(visitor)
		else
			local nCurScope = visitor.scope_stack[#visitor.scope_stack]
			stm.self_scope_refer = nCurScope.scope_refer
			self_visit(visitor, stm)
		end
	end,
	Local=function(visitor, stm, node_visit)
		node_visit(visitor, stm[2])
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
			tlvRefer.ident_define(visitor, node)
		else
			tlvRefer.ident_use(visitor, node)
		end
	end,
	Id=function(visitor, node)
		if visitor.define_pos then
			tlvRefer.ident_define(visitor, node)
		else
			tlvRefer.ident_use(visitor, node)
		end
	end,
	Chunk=function(visitor, chunk, node_visit, self_visit)
		tlvRefer.scope_begin(visitor, chunk)
		self_visit(visitor, chunk)
		tlvRefer.scope_end(visitor)
	end
}

local visitor_after = {
	Do=function(visitor, stm)
		tlvRefer.scope_end(visitor)
	end,
	While=function(visitor, stm)
		tlvRefer.scope_end(visitor)
	end,
	Repeat=function(visitor, stm)
		tlvRefer.scope_end(visitor)
	end,
}

local before_default = function(visitor, vNode)
	local nCurScope = visitor.scope_stack[#visitor.scope_stack]
	local nCurRegion = visitor.region_stack[#visitor.region_stack]
	vNode.parent_region_refer = assert(nCurRegion.region_refer)
	vNode.parent_scope_refer = assert(nCurScope.scope_refer)
end

function tlvRefer.scope_begin(visitor, vNode)
	local nCurScope = visitor.scope_stack[#visitor.scope_stack]
	local nCurRegion = visitor.region_stack[#visitor.region_stack]
	local nNextScope = nil
	-- if function or chunk then create region
	if vNode.tag == "Function" or vNode.tag == "Chunk" then
		nNextScope = tlenv.create_region(visitor.file_env, nCurRegion, nCurScope, vNode)
		table.insert(visitor.region_stack, nNextScope)
	-- else create scope
	else
		nNextScope = tlenv.create_scope(visitor.file_env, nCurScope, vNode)
	end
	vNode.self_scope_refer = nNextScope.scope_refer
	table.insert(visitor.scope_stack, nNextScope)
	return nNextScope
end

function tlvRefer.scope_end(visitor)
	local nScope = table.remove(visitor.scope_stack)
	if nScope.sub_tag == "Region" then
		table.remove(visitor.region_stack)
	end
end

function tlvRefer.ident_define(visitor, vIdentNode)
	-- create and set ident_refer
	local nCurScope = visitor.scope_stack[#visitor.scope_stack]
	local nNewIdent = tlenv.create_ident(visitor.file_env, nCurScope, vIdentNode)
	vIdentNode.ident_refer = nNewIdent.ident_refer
	vIdentNode.is_define = true
end

function tlvRefer.ident_use(visitor, vIdentNode)
	local nCurScope = visitor.scope_stack[#visitor.scope_stack]
	if vIdentNode.tag == "Id" then
		local nName = vIdentNode[1]
		local nIdentRefer = nCurScope.record_dict[nName]
		if nIdentRefer then
			vIdentNode.ident_refer = nIdentRefer
			vIdentNode.is_define = false
		else
			vIdentNode.ident_refer = tlenv.G_IDENT_REFER
			vIdentNode.is_define = false
			-- unrefered ident converse to global
			--vIdentNode.tag = "Index"

			-- ident
			--local e1 = tlast.ident(vIdentNode.pos, "_ENV")
			--e1.l, e1.c = vIdentNode.l, vIdentNode.c
			--e1.ident_refer = tlenv.G_IDENT_REFER
			--e1.self_scope_refer = tlenv.G_SCOPE_REFER

			-- key
			--local e2 = tlast.exprString(vIdentNode.pos, vIdentNode[1])
			--e2.l, e2.c = vIdentNode.l, vIdentNode.c

			--vIdentNode[1] = e1
			--vIdentNode[2] = e2
		end
	elseif vIdentNode.tag == "Dots" then
		local nName = "..."
		vIdentNode.ident_refer = assert(nCurScope.record_dict[nName], "dot no refer")
	else
		error("ident refer error tag"..tostring(vIdentNode.tag))
	end
end

function tlvRefer.refer(vFileEnv)
	local visitor = {
		file_env = vFileEnv,

		before_dict = visitor_before,
		override_dict = visitor_override,
		after_dict = visitor_after,
		before_default = before_default,

		scope_stack = {
			vFileEnv.root_scope
		},
		region_stack = {
			vFileEnv.root_scope
		},

		define_pos=false,
	}
	local nAst = vFileEnv.info.ast
	tlvisitor.visit_raw(nAst, visitor)
	return vFileEnv
end

return tlvRefer
