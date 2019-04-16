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

local function log_error (visitor, node, ...)
	local filename = visitor.env.filename
	local head = string.format("%s:%d:%d:[ERROR]", filename, node.l, node.c)
	print(head, ...)
end

local function log_warning(visitor, node, ...)
	local filename = visitor.env.filename
	local head = string.format("%s:%d:%d:[WARNING]", filename, node.l, node.c)
	print(head, ...)
end

local function oper_merge(visitor, vNode, vWrapper)
	local nFirstType = tltype.first(vWrapper.type)

	if vNode.type then
		-- log_error(visitor, vNode, "add type but node.type existed", vNode.type.tag, vWrapper.type.tag)
		vNode.type = nFirstType
	else
		vNode.type = nFirstType
	end
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
		log_error(visitor, node, "add type but node.type existed", node.type.tag, t.tag)
	else
		node.type = t
	end
end

local function link_type(visitor, vAutoLink)
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
			local nForinTuple = tltOper._call(visitor, vForinNode[2], nFunctionType, nArgTypeList)
			vNodeVisit(visitor, vForinNode[1])
			for i, nNameNode in ipairs(vForinNode[1]) do
				local nRightType = nForinTuple[i]
				tltOper._init_assign(visitor, nNameNode, nRightType, nNameNode.left_deco)
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
			tltOper._init_assign(visitor, nNameNode, tltype.Number())

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
			local nTypeList = tltOper._reforge_tuple(visitor, node[2])
			for i, nVarNode in ipairs(nVarList) do
				local nRightType = nTypeList[i]
				if nVarNode.tag == "Index" then
					tltOper._index_set(visitor, nVarNode[1], nVarNode[1].type, nVarNode[2].type, nRightType, nVarNode.left_deco)
				elseif nVarNode.tag == "Id" then
					tltOper._set_assign(visitor, nVarNode, nVarNode.type, nRightType, nVarNode.left_deco)
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

			tltOper._init_assign(visitor, nNameNode, nExprNode.type, nNameNode.left_deco)
		end,
	},
	Local={
		after=function(visitor, node)
			local nNameList = node[1]
			local nTypeList = tltOper._reforge_tuple(visitor, node[2])
			for i, nNameNode in ipairs(nNameList) do
				local nRightType = nTypeList[i]
				tltOper._init_assign(visitor, nNameNode, nRightType, nNameNode.left_deco)
			end
		end,
	},
	Return={
		after=function(visitor, node)
			-- TODO case for none return block
			local nTypeList = tltOper._reforge_tuple(visitor, node[1])
			for i=#visitor.stack, 1, -1 do
				local nPreNode = visitor.stack[i]
				if nPreNode.tag == "Function" then
					tltOper._return(visitor, nPreNode, nTypeList)
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
			-- if #stack == 1 then visit function in a seperate stack
			if #visitor.stack == 1 then
				local nSolvingState = vFunctionNode.type.auto_solving_state
				if not nSolvingState then
					-- if not auto function
					self_visit(visitor, vFunctionNode)
				elseif nSolvingState == tltAuto.AUTO_SOLVING_IDLE then
					-- if auto function, change state and visit
					vFunctionNode.type.auto_solving_state = tltAuto.AUTO_SOLVING_ACTIVE
					self_visit(visitor, vFunctionNode)
					-- TODO solving all auto type in this region when function visit end
					vFunctionNode.type.auto_solving_state = tltAuto.AUTO_SOLVING_FINISH
				elseif nSolvingState == tltAuto.AUTO_SOLVING_FINISH then
					-- if auto solving finish, do nothing
				else
					visitor:log_error(vFunctionNode, "auto_solving_state unexception!!!", nSolvingState)
				end
			-- if #stack > 1 then visit function in parent's stack
			-- create AutoFunction right now but visit when it's called
			else
				-- TODO thing visitor argments list in which step?
				-- don't visit block
				if vFunctionNode.right_deco then
					vFunctionNode.type = vFunctionNode.right_deco
					return
				end

				print("TODO:auto function deco for lambda")
				-- auto deco for parameter
				local nTypeList = {}
				local nParList = vFunctionNode[1]
				for k, nIdentNode in ipairs(nParList) do
					nIdentNode.left_deco = tltype.Any()
					nTypeList[k] = tltype.Any()
					if nIdentNode.tag == "Dots" then
						print("TODO:auto type for dots")
					end
				end
				local nOwnRegionRefer = vFunctionNode.region_refer
				local nAutoFunction = tltAuto.AutoFunction(nOwnRegionRefer, tltype.Tuple(table.unpack(nTypeList)))
				local nParentRefer = visitor.env.region_list[nOwnRegionRefer].parent_refer
				local nStackIndex = tlenv.region_push_auto(visitor.env, nParentRefer, nAutoFunction)
				local nAutoLink = tltAuto.AutoLink(nParentRefer, nStackIndex)
				vFunctionNode.type = nAutoLink
				visitor.breadth_region_node_list[#visitor.breadth_region_node_list + 1] = vFunctionNode
			end
		end,
		after=function(visitor, vFunctionNode)
			visitor.region_stack[#visitor.region_stack] = nil
		end,
	},
	Table={
		after=function(visitor, node)
			local nList = {}
			for i, nSubNode in ipairs(node) do
				if nSubNode.tag == "Pair" then
					nList[#nList + 1] = tltable.Field(nSubNode[1].type, tltype.general(nSubNode[2].type))
				elseif nSubNode.tag == "Dots" then
					print("TODO:Dots in table constructor...")
				else
					nList[#nList + 1] = tltable.Field(tltype.Literal(i), tltype.general(nSubNode.type))
				end
			end

			local nRegionRefer = visitor.region_stack[#visitor.region_stack]

			-- if not deco type, ident is unique table
			local nAutoTable = tltAuto.AutoTable(table.unpack(nList))
			local nStackIndex = tlenv.region_push_auto(visitor.env, nRegionRefer, nAutoTable)

			local nAutoLink = tltAuto.AutoLink(nRegionRefer, nStackIndex)
			add_type(visitor, node, nAutoLink)

			-- local nAuto = tlenv.create_auto(visitor.env, nRegionRefer, node, nAutoTable)

			-- TODO..... 20190301

		end,
	},
	Op={
		after=function(visitor, vNode)
			local nOP = vNode[1]
			if #vNode== 3 then
				local nOper = tltOper["__"..nOP] or tltOper["_"..nOP]
				vNode.type = nOper(visitor, vNode, vNode[2].type, vNode[3].type)
			elseif #vNode == 2 then
				local nOper = tltOper["__"..nOP] or tltOper["_"..nOP]
				vNode.type = nOper(visitor, vNode, vNode[2].type)
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
				if node.left_deco then
					node.type = node.left_deco
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
				vIndexNode.type = tltOper._index_get(visitor, vIndexNode, vIndexNode[1].type, vIndexNode[2].type)
			end
		end,
	},
	-- exp may be tuple: call, invoke, dots
	Call={
		after=function(visitor, vCallNode)
			-- auto parsing, parsing function when it's called
			local nFunctionType = visitor:link_type(vCallNode[1].type)
			local nReturnTuple = nil
			if nFunctionType.auto_solving_state == tltAuto.AUTO_SOLVING_ACTIVE then
				visitor:log_error(vCallNode, "function auto solving loop...")
				nReturnTuple = tltype.Tuple(tltype.Any())
			else
				-- maybe function is not visited, because node was breadth-first visited.
				-- so visit without breadth
				if nFunctionType.auto_solving_state == tltAuto.AUTO_SOLVING_IDLE then
					local nScope = visitor.env.scope_list[nFunctionType.own_region_refer]
					tlvBreadth.visit_region(visitor.env, nScope.node)
				end
				if nFunctionType.sub_tag == "TAutoFunction" then

					nReturnTuple = tlenv.function_call(visitor.env, visitor.region_stack[#visitor.region_stack], nFunctionType)
				else
					print("TODO: thinking how to redesign tltOper.lua")
					local nTypeList = tltOper._reforge_tuple(visitor, vCallNode[2])
					nReturnTuple = tltOper._call(visitor, vCallNode, vCallNode[1].type, nTypeList)
				end
			end
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
				if vDotsNode.left_deco then
					vDotsNode.type = vDotsNode.left_deco
				end
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
	local visitor = {
		object_dict = visitor_object_dict,
		region_stack = {tlenv.G_SCOPE_REFER},
		breadth_region_node_list = {},
		env = vFileEnv,
		log_error = log_error,
		log_warning = log_warning,
		link_type = link_type,
	}
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
end

return tlvBreadth
