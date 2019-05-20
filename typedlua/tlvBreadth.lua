--[[
This module implements a type checker,
use a way similar to BFS to visit each function block recursively.

in the case like:
"""
local t = {}

function t.dosth()
	t.data = "jlfkdsfjds"
end

t.data = 321

t.dosth()

"""
We can't get the right type of t.data if we visit block in "function t.dosth" before we visit "t.data = 321".
So I use a breadth-first way to solve this problem: finishing visiting all the statement outside each function's block before visiting a function's block.
]]
local tlvisitor = require "typedlua/tlvisitor"
local tlutils = require "typedlua/tlutils"
local tltype = require "typedlua/tltype"
local tltAuto = require "typedlua/tltAuto"
local tltRelation = require "typedlua/tltRelation"
local tltable = require "typedlua/tltable"
local tltOper = require "typedlua/tltOper"
local tlvBreadth = {}
local tlenv = require "typedlua/tlenv"

local Nil = tltype.Nil()
local Boolean = tltype.Boolean()
local Number = tltype.Number()
local String = tltype.String()

local visitor_meta = {}

-- TODO use duck type....
function visitor_meta.oper_auto_call(visitor, vType, vArgTuple)
	local nFunctionType = visitor:link_type(vType)
	assert(nFunctionType.sub_tag == "TAutoFunction")
	if nFunctionType.auto_solving_state == tltAuto.AUTO_SOLVING_START then
		visitor:log_error("function auto solving loop...")
		return tltype.Tuple(tltype.Any())
	else
		-- maybe function is not visited, because node was breadth-first visited.
		-- so visit without breadth
		if nFunctionType.auto_solving_state == tltAuto.AUTO_SOLVING_IDLE then
			local nScope = visitor.env.scope_list[nFunctionType.own_region_refer]
			tlvBreadth.visit_region(visitor.env, nScope.node)
		end
		return tlenv.function_call(visitor.env, visitor.region_stack[#visitor.region_stack], nFunctionType)
	end
end

function visitor_meta.cast_auto(visitor, vLeftType, vAutoLink)
	local nRegionRefer = visitor.region_stack[#visitor.region_stack]
	if vAutoLink.link_region_refer ~= nRegionRefer then
		visitor:log_error("can't finish auto from out region")
		return false
	end
	local nRegion = visitor.env.region_list[nRegionRefer]
	local nRightType = nRegion.auto_stack[vAutoLink.link_index]
	if vLeftType.tag == "TTable" and nRightType.tag == "TTable" and nRightType.sub_tag == "TAutoTable" then
		for i, nField in ipairs(nRightType) do
			if nField[2].tag == "TAutoLink" then
				assert(nField[1].tag == "TLiteral")
				local nLeftField = tltable.index_field(vLeftType, nField[1])
				if not nLeftField then
					visitor:log_error("finish auto fail for field", tltype.tostring(nField[1]))
					return false
				end
				if not visitor:cast_auto(nLeftField[2], nField[2]) then
					visitor:log_error("recursive finish auto fail for field", tltype.tostring(nField[1]))
					return false
				end
				nField[2] = nLeftField[2]
			end
		end
		if not tltRelation.contain(vLeftType, nRightType) then
			visitor:log_error("finish auto fail for relation")
			return false
		end
		nRegion.auto_stack[vAutoLink.link_index] = vLeftType
		return true
	elseif vLeftType.tag == "TFunction" and nRightType.tag == "TFunction" and nRightType.sub_tag == "TAutoFunction" then
		if nRightType.auto_solving_state == tltAuto.AUTO_SOLVING_IDLE then
			nRegion.auto_stack[vAutoLink.link_index] = vLeftType
			return true
		else
			visitor:log_error("finish auto fail because function is not idle")
			return false
		end
	else
		visitor:log_error("cast_auto type unexception", vLeftType.tag, nRightType.tag, nRightType.sub_tag)
	end
end

function visitor_meta.link_type(visitor, vAutoLink)
	if vAutoLink.tag ~= "TAutoLink" then
		return vAutoLink
	end
	local nRegionRefer = visitor.region_stack[#visitor.region_stack]
	local nRegion = visitor.env.region_list[nRegionRefer]
	while nRegion.region_refer ~= vAutoLink.link_region_refer do
		nRegion = visitor.env.region_list[nRegion.parent_refer]
	end
	return nRegion.auto_stack[vAutoLink.link_index]
end


function visitor_meta.log_error (visitor, ...)
	local filename = visitor.env.filename
	local node = visitor.stack[#visitor.stack]
	local head = string.format("%s:%d:%d:[ERROR]", filename, node.l, node.c)
	print(head, ...)
end

function visitor_meta.log_warning(visitor, ...)
	local filename = visitor.env.filename
	local node = visitor.stack[#visitor.stack]
	local head = string.format("%s:%d:%d:[WARNING]", filename, node.l, node.c)
	print(head, ...)
end

-- expr add type, check right_deco
local function add_type(visitor, node, t)
	--[[ do nothing...
	local nRightDeco = node.right_deco
	if nRightDeco then
		if not tltRelation.sub(t, nRightDeco) then
			log_error(visitor, node, t.tag, "is not", nRightDeco.tag)
		end
	end]]
	if node.type then
		visitor:log_error("add type but node.type existed", node.type.tag, t.tag)
	else
		node.type = t
	end
end

local visitor_stm = {
	Forin={
		override=function(visitor, vForinNode, vNodeVisit, vSelfVisit)
			vNodeVisit(visitor, vForinNode[2])
			local nNextTableInitTuple = tltOper._reforge_tuple(visitor, vForinNode[2])
			-- next, {}, nil
			local nFunctionType = nNextTableInitTuple[1]
			local nArgTypeList = tltype.Tuple()
			for i = 2, #nNextTableInitTuple do
				nArgTypeList[i-1] = nNextTableInitTuple[i]
			end
			error("for in caller TODO")
			local nForinTuple = tltOper._call(visitor, nFunctionType, nArgTypeList)
			vNodeVisit(visitor, vForinNode[1])
			for i, nNameNode in ipairs(vForinNode[1]) do
				local nRightType = nForinTuple[i]
				nNameNode.type = tltOper._init_assign(visitor, nRightType, nNameNode.deco_type)
			end
			vNodeVisit(visitor, vForinNode[3])
		end
	},
	Fornum={
		override=function(visitor, node, visit_node, self_visit)
			for i = 1, #node - 1 do
				local nSubNode = node[i]
				visit_node(visitor, nSubNode)
			end
			-- oper subNode 1
			local nNameNode = node[1]
			nNameNode.type = tltOper._init_assign(visitor, tltype.Number())

			-- oper subNode 2, 3,..., #node-1
			for i = 2, #node - 1 do
				local nSubNode = node[i]
				tltOper._fornum(visitor, nSubNode, nSubNode.type)
			end
			visit_node(visitor, node[#node])
		end,
	},
	Set={
		after=function(visitor, node)
			local nVarList = node[1]
			local nTupleType = tltOper._reforge_tuple(visitor, node[2])
			for i, nVarNode in ipairs(nVarList) do
				local nRightType = tltype.tuple_index(nTupleType, i)
				if nVarNode.tag == "Index" then
					tltOper._index_set(visitor, nVarNode[1].type, nVarNode[2].type, nRightType, nVarNode.deco_type)
				elseif nVarNode.tag == "Id" then
					tltOper._set_assign(visitor, nVarNode.type, nRightType, nVarNode.deco_type)
					-- local nIdent = visitor.env.ident_list[nVarNode.ident_refer]
					-- TODO merge namenode??????????????????
					-- oper_merge(visitor, nIdent, nWrapper)
				else
					error("assign to node:tag="..tostring(node.tag))
				end
			end
		end,
	},
	Localrec={
		after=function(visitor, vLocalrecNode)
			local nNameNode = vLocalrecNode[1][1]
			local nExprNode = vLocalrecNode[2][1]

			nNameNode.type = tltOper._init_assign(visitor, nExprNode.type, nNameNode.deco_type)
		end,
	},
	Local={
		after=function(visitor, node)
			local nNameList = node[1]
			local nTupleType = tltOper._reforge_tuple(visitor, node[2])
			for i, nNameNode in ipairs(nNameList) do
				local nRightType = tltype.tuple_index(nTupleType, i)
				nNameNode.type = tltOper._init_assign(visitor, nRightType, nNameNode.deco_type)
			end
		end,
	},
	Return={
		after=function(visitor, node)
			-- TODO case for none return block
			local nTupleType = tltOper._reforge_tuple(visitor, node[1])
			for i=#visitor.stack, 1, -1 do
				local nPreNode = visitor.stack[i]
				if nPreNode.tag == "Function" then
					tltOper._return(visitor, nPreNode, nTupleType)
					return
				end
			end
			print("file return TODO")
		end
	}
}

local visitor_exp = {
	-- literal
	Nil={
		before=function(visitor, node)
			add_type(visitor, node, tltype.Nil())
		end,
	},
	True={
		before=function(visitor, node)
			add_type(visitor, node, tltype.Literal(true))
		end,
	},
	False={
		before=function(visitor, node)
			add_type(visitor, node, tltype.Literal(false))
		end,
	},
	Number={
		before=function(visitor, node)
			add_type(visitor, node, tltype.Literal(node[1]))
		end,
	},
	String={
		before=function(visitor, node)
			add_type(visitor, node, tltype.Literal(node[1]))
		end,
	},

	Function={
		before=function(visitor, vFunctionNode)
			visitor.region_stack[#visitor.region_stack + 1] = assert(vFunctionNode.region_refer)
		end,
		override=function(visitor, vFunctionNode, visit_node, self_visit)
			-- if #stack == 1 then visit function in an isolating stack
			if #visitor.stack == 1 then
				local nFunctionType = visitor:link_type(vFunctionNode.type)
				-- deco input parameter
				local nInputTuple = nFunctionType[1]
				if nInputTuple then
					local nParList = vFunctionNode[1]
					for k, nIdentNode in ipairs(nParList) do
						if nIdentNode.tag == "Dots" then
							local nDecoTuple = tltype.tuple_sub(nInputTuple, k)
							if nDecoTuple.sub_tag ~= "TVarTuple" then
								if #nDecoTuple <= 0 then
									visitor:log_error("dots empty ...")
								else
									visitor:log_warning("dots but not vartuple ...")
								end
							end
							nIdentNode.deco_type = nDecoTuple
						elseif nIdentNode.tag == "Id" then
							local nDecoType = tltype.tuple_index(nInputTuple, k)
							if not nDecoType then
								nDecoType = tltype.Any()
								visitor:log_error("arguments length and deco inputtuple not match")
							end
							nIdentNode.deco_type = nDecoType
						else
							visitor:log_error("unexcept branch when function deco parlist")
						end
					end
				else
					-- add any for default
					local nTypeList = {}
					local nParList = vFunctionNode[1]
					local nHasDots = false
					for k, nIdentNode in ipairs(nParList) do
						-- TODO fill default with duck type
						nIdentNode.deco_type = tltype.Any()
						nTypeList[k] = tltype.Any()
						if nIdentNode.tag == "Dots" then
							assert(k == #nParList)
							nIdentNode.deco_type = tltype.VarTuple(tltype.Any())
							nHasDots = true
						end
					end
					if nHasDots then
						nFunctionType[1]= tltype.VarTuple(table.unpack(nTypeList))
					else
						nFunctionType[1]= tltype.Tuple(table.unpack(nTypeList))
					end
				end
				-- breadth visit
				if nFunctionType.sub_tag == "TAutoFunction"
					and nFunctionType.auto_solving_state == tltAuto.AUTO_SOLVING_IDLE then
					-- if auto function and idle, change state and visit
					nFunctionType.auto_solving_state = tltAuto.AUTO_SOLVING_START
					self_visit(visitor, vFunctionNode)
					-- TODO solving all auto type in this region when function visit end
					nFunctionType.auto_solving_state = tltAuto.AUTO_SOLVING_FINISH
				else
					-- assert not looping
					assert(nFunctionType.auto_solving_state ~= tltAuto.AUTO_SOLVING_START)
					-- if not auto function or auto finish
					self_visit(visitor, vFunctionNode)
				end
			-- if #stack > 1 then visit function in parent's stack
			-- create AutoFunction right now but visit when it's called or by breadth
			else
				-- auto deco for parameter
				local nOwnRegionRefer = vFunctionNode.region_refer
				local nAutoFunction = tltAuto.AutoFunction(nOwnRegionRefer)
				local nParentRefer = visitor.env.region_list[nOwnRegionRefer].parent_refer
				local nAutoLink = tlenv.region_push_auto(visitor.env, nParentRefer, nAutoFunction)
				vFunctionNode.type = nAutoLink
				visitor.breadth_region_node_list[#visitor.breadth_region_node_list + 1] = vFunctionNode
			end
		end,
		after=function(visitor, vFunctionNode)
			visitor.region_stack[#visitor.region_stack] = nil
		end,
	},
	Table={
		after=function(visitor, vTableNode)
			local nFieldList = {}
			local nArrayTypeList = {}
			local nArrayField = false
			for i, nSubNode in ipairs(vTableNode) do
				if nSubNode.tag == "Pair" then
					nFieldList[#nFieldList + 1] = tltable.Field(nSubNode[1].type, nSubNode[2].type)
				elseif nSubNode.tag == "Dots" then
					if i < #vTableNode then
						nArrayTypeList[#nArrayTypeList + 1] = tltype.first(nSubNode.type)
						visitor:log_warning("Dots isn't last element in table constructor")
					else
						local nDotsTuple = nSubNode.type
						if nDotsTuple.sub_tag == "TVarTuple" then
							for j=1, #nDotsTuple - 1 do
								nArrayTypeList[#nArrayTypeList + 1] = nDotsTuple[j]
							end
							nArrayField = tltable.Field(tltype.Integer(), nDotsTuple[#nDotsTuple])
						else
							for i, nType in ipairs(nDotsTuple) do
								nArrayTypeList[#nArrayTypeList + 1] = nType
							end
						end
					end
				else
					nArrayTypeList[#nArrayTypeList + 1] = nSubNode.type
				end
			end

			if not nArrayField then
				for i, nType in ipairs(nArrayTypeList) do
					nFieldList[#nFieldList + 1] = tltable.Field(tltype.Literal(i), nType)
				end
			else
				for i, nType in pairs(nArrayTypeList) do
					if not tltRelation.contain(nArrayField[2], nType) then
						visitor:log_error("table contain array field but type conflict")
					end
					if nType.tag == "TNil" then
						visitor:log_error("table contain array field but mixed nil value")
					end
				end
				nFieldList[#nFieldList + 1] = nArrayField
			end

			local nRegionRefer = visitor.region_stack[#visitor.region_stack]

			-- if not deco type, ident is unique table
			local nAutoTable = tltAuto.AutoTable(table.unpack(nFieldList))
			local nAutoLink = tlenv.region_push_auto(visitor.env, nRegionRefer, nAutoTable)

			add_type(visitor, vTableNode, nAutoLink)

		end,
	},
	Op={
		after=function(visitor, vNode)
			local nOP = vNode[1]
			if #vNode== 3 then
				local nOper = tltOper["__"..nOP] or tltOper["_"..nOP]
				vNode.type = nOper(visitor, vNode[2].type, vNode[3].type)
			elseif #vNode == 2 then
				local nOper = tltOper["__"..nOP] or tltOper["_"..nOP]
				vNode.type = nOper(visitor, vNode[2].type)
			else
				error("exception branch")
			end
		end,
	},
	Paren={
		after=function(visitor, vNode)
			vNode.type = tltype.first(vNode[1].type)
		end,
	},
	Id={
		before=function(visitor, node)
			local ident = visitor.env.ident_list[node.ident_refer]
			if node == ident.node then
				-- ident set itself
				if node.deco_type then
					node.type = node.deco_type
				end
			else
				-- ident get
				node.type = ident.node.type
			end
		end
	},
	Index={
		after=function(visitor, vIndexNode)
			local nParentNode = visitor.stack[#visitor.stack - 1]
			if nParentNode and nParentNode.tag == "VarList" then
				-- set index
				-- pass
			else
				vIndexNode.type = tltOper._index_get(visitor, vIndexNode[1].type, vIndexNode[2].type)
			end
		end,
	},
	-- exp may be tuple: call, invoke, dots
	Call={
		after=function(visitor, vCallNode)
			-- auto parsing, parsing function when it's called
			local nTuple = tltOper._reforge_tuple(visitor, vCallNode[2])
			local nReturnTuple = tltOper._call(visitor, vCallNode[1].type, nTuple)
			local nParentNode = visitor.stack[#visitor.stack - 1]
			if nParentNode and (nParentNode.tag == "ExpList" or nParentNode.tag == "Pair") then
				-- maybe tuple
				vCallNode.type = nReturnTuple
			else
				vCallNode.type = tltype.first(nReturnTuple)
			end
		end
	},
	Invoke={
		after=function(visitor, node)
			error("func invoke TODO")
		end
	},
	Dots={
		after=function(visitor, vDotsNode)
			local nParentNode = visitor.stack[#visitor.stack - 1]
			local nIdent = visitor.env.ident_list[vDotsNode.ident_refer]
			if nIdent.node == vDotsNode then
				-- dot define
				if vDotsNode.deco_type then
					vDotsNode.type = vDotsNode.deco_type
				end
				assert(vDotsNode.type.tag == "TTuple")
			else
				if nParentNode and (nParentNode.tag == "ExpList" or nParentNode.tag == "Table") then
					vDotsNode.type = nIdent.node.type
				else
					vDotsNode.type = tltype.first(nIdent.node.type)
				end
			end
		end
	},
	Chunk={
		before=function(visitor, vChunkNode)
			visitor.region_stack[#visitor.region_stack + 1] = assert(vChunkNode.region_refer)
		end,
		after=function(visitor, node)
			visitor.region_stack[#visitor.region_stack] = nil
		end
	},
}


local visitor_object_dict = tlvisitor.concat(visitor_stm, visitor_exp)

function tlvBreadth.visit_region(vFileEnv, vRegionNode)
	assert(vRegionNode.tag == "Function" or vRegionNode.tag == "Chunk")
	if vRegionNode.breadth_visited then
		return
	end
	vRegionNode.breadth_visited = true
	local visitor = setmetatable({
		object_dict = visitor_object_dict,
		region_stack = {tlenv.G_SCOPE_REFER},
		breadth_region_node_list = {},
		env = vFileEnv,
	}, {
		__index=visitor_meta,
	})
	local nRegionNodeList = visitor.breadth_region_node_list
	tlvisitor.visit_obj(vRegionNode, visitor)
	for _, nSubRegionNode in ipairs(nRegionNodeList) do
		-- TODO don't implement function first
		-- visitor.region_stack[#visitor.region_stack + 1] = nSubRegionNode.region_refer
		tlvBreadth.visit_region(vFileEnv, nSubRegionNode)
		-- visitor.region_stack[#visitor.region_stack] = nil
	end
end

function tlvBreadth.visit(vFileEnv)
	tlvBreadth.visit_region(vFileEnv, vFileEnv.ast)
	--[[
	local seri = require "typedlua.seri"
	for k, nScope in ipairs(vFileEnv.scope_list) do
		if nScope.sub_tag == "Region" then
			print(k, seri(nScope.auto_stack))
		end
	end]]
end

return tlvBreadth
