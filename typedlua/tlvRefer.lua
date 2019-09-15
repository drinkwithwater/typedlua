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
			self_visit(visitor, stm)
			tlvRefer.scope_end(visitor)
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

	-- some node about open must contain region_refer
	-- TODO write here or in tlvBreadth ?????
	Call=function(visitor, vNode)
		vNode.region_refer = assert(tlvRefer.get_region_refer(visitor), "region refer not found")
	end,
	Table=function(visitor, vNode)
		vNode.region_refer = assert(tlvRefer.get_region_refer(visitor), "region refer not found")
	end,
}

function tlvRefer.scope_begin(visitor, vNode)
	local nCurScope = visitor.scope_stack[#visitor.scope_stack]
	local nNextScope = nil
	-- if function or chunk then create region
	-- else create scope
	if vNode.tag == "Function" or vNode.tag == "Chunk" then
		local nParentRegion = nil
		for i=#visitor.scope_stack, 1, -1 do
			local nScope = visitor.scope_stack[i]
			if nScope.sub_tag == "Region" then
				nParentRegion = nScope
				break
			end
		end
		nNextScope = tlenv.create_region(visitor.file_env, nParentRegion, nCurScope, vNode)
		vNode.region_refer = nNextScope.scope_refer
	else
		nNextScope = tlenv.create_scope(visitor.file_env, nCurScope, vNode)
	end
	table.insert(visitor.scope_stack, nNextScope)
	vNode.scope_refer = nNextScope.scope_refer
	return nNextScope
end

function tlvRefer.scope_end(visitor)
	table.remove(visitor.scope_stack)
end

function tlvRefer.get_region_refer(visitor)
	for i=#visitor.scope_stack, 1, -1 do
		local nScopeNode = visitor.scope_stack[i].node
		if nScopeNode.tag == "Function" or nScopeNode.tag == "Chunk" then
			return nScopeNode.region_refer
		end
	end
	error("out side region...")
end

function tlvRefer.ident_define(visitor, vIdentNode)
	-- create and set ident_refer
	local nCurScope = visitor.scope_stack[#visitor.scope_stack]
	local nNewIdent = tlenv.create_ident(visitor.file_env, nCurScope, vIdentNode)
	vIdentNode.ident_refer = nNewIdent.ident_refer
end

function tlvRefer.ident_use(visitor, vIdentNode)
	local nCurScope = visitor.scope_stack[#visitor.scope_stack]
	if vIdentNode.tag == "Id" then
		local nName = vIdentNode[1]
		local nIdentRefer = nCurScope.record_dict[nName]
		if nIdentRefer then
			vIdentNode.ident_refer = nIdentRefer
		else
			-- unrefered ident converse to global
			vIdentNode.tag = "Index"

			-- ident
			local e1 = tlast.ident(vIdentNode.pos, "_ENV")
			e1.l, e1.c = vIdentNode.l, vIdentNode.c
			e1.ident_refer = tlenv.G_IDENT_REFER

			-- key
			local e2 = tlast.exprString(vIdentNode.pos, vIdentNode[1])
			e2.l, e2.c = vIdentNode.l, vIdentNode.c

			vIdentNode[1] = e1
			vIdentNode[2] = e2
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
		scope_stack = {
			vFileEnv.root_scope
		},
		define_pos=false,
	}
	local nAst = vFileEnv.info.ast
	tlvisitor.visit_raw(nAst, visitor)
	return vFileEnv
end

return tlvRefer
