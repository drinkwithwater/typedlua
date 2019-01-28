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

local visitor_stm = {
	Block={
		override=function(visitor, node, visit_node, self_visit)
			local nParentNode = visitor.stack[#visitor.stack - 1]
			if nParentNode and nParentNode.tag == "Function" and nParentNode.is_full_type then
				visitor.func_block_list[#visitor.func_block_list + 1] = node
				node.region_refer = assert(nParentNode.region_refer)
			else
				self_visit(visitor, node)
			end
		end,
	},
	Fornum={
		override=function(visitor, node, visit_node, self_visit)
			for i = 1, #node - 1 do
				local nSubNode = node[i]
				visit_node(visitor, nSubNode)
			end
			-- oper subNode 1
			local nNameNode = node[1]
			local nWrapper = tltOper._init_assign(visitor, nNameNode, tltype.Number())
			oper_merge(visitor, nNameNode, nWrapper)

			-- oper subNode 2, 3,..., #node-1
			for i = 2, #node - 1 do
				local nSubNode = node[i]
				tltOper._assert(visitor, nSubNode, tltype.Number())
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
					tltOper._index_set(visitor, nVarNode[1], nVarNode[2], nRightType, nVarNode.left_deco)
				elseif nVarNode.tag == "Id" then
					tltOper._set_assign(visitor, nVarNode, nRightType, nVarNode.left_deco)
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

			local nWrapper = tltOper._init_assign(visitor, nNameNode, nExprNode.type, nNameNode.left_deco)
			local nIdent = visitor.env.ident_list[nNameNode.ident_refer]
			oper_merge(visitor, nNameNode, nWrapper)
			-- oper_merge(visitor, nIdent, nWrapper)
		end,
	},
	Local={
		after=function(visitor, node)
			local nNameList = node[1]
			local nTypeList = tltOper._reforge_tuple(visitor, node[2])
			for i, nNameNode in ipairs(nNameList) do
				local nRightType = nTypeList[i]
				local nWrapper = tltOper._init_assign(visitor, nNameNode, nRightType, nNameNode.left_deco)
				local nIdent = visitor.env.ident_list[nNameNode.ident_refer]
				oper_merge(visitor, nNameNode, nWrapper)
				-- oper_merge(visitor, nIdent, nWrapper)
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
			if vFunctionNode.right_deco then
				vFunctionNode.type = vFunctionNode.right_deco
			else
				print("TODO:auto function deco for lambda")
				-- auto deco for parameter
				local nTypeList = {}
				local nParList = vFunctionNode[1]
				for k, nIdentNode in ipairs(nParList) do
					nIdentNode.left_deco = tltype.Any()
					nTypeList[k] = tltype.Any()
				end
				vFunctionNode.type = tltype.Function(tltype.Tuple(table.unpack(nTypeList)))
			end
		end,
		after=function(visitor, vFunctionNode)
			visitor.region_stack[#visitor.region_stack] = nil
		end,
	},
	Table={
		after=function(visitor, node)
			local nList = {}
			for k, nSubNode in ipairs(node) do
				if nSubNode.tag == "Pair" then
					nList[#nList + 1] = tltable.Field(nSubNode[1].type, tltype.general(nSubNode[2].type))
				else
					nList[#nList + 1] = tltable.Field(tltype.Literal(i), tltype.general(nSubNode.type))
				end
			end

			-- if not deco type, ident is unique table
			local nOpenTable = tltable.OpenTable(table.unpack(nList))
			local nNewIndex = #visitor.env.unique_table_list + 1
			visitor.env.unique_table_list[nNewIndex] = nOpenTable

			add_type(visitor, node, nOpenTable)
		end,
	},
	Op={
		after=function(visitor, vNode)
			local nOP = vNode[1]
			if #vNode== 3 then
				local nOper = tltOper["__"..nOP] or tltOper["_"..nOP]
				local nWrapper = nOper(visitor, vNode[2], vNode[3])
				oper_merge(visitor, vNode, nWrapper)
			elseif #vNode == 2 then
				local nOper = tltOper["__"..nOP] or tltOper["_"..nOP]
				local nWrapper = nOper(visitor, vNode[2])
				oper_merge(visitor, vNode, nWrapper)
			else
				error("exception branch")
			end
		end,
	},
	Paren={
		after=function(visitor, vNode)
			oper_merge(visitor, vNode, vNode[1])
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
				local nWrapper = tltOper._index_get(visitor, vIndexNode[1], vIndexNode[2])
				oper_merge(visitor, vIndexNode, nWrapper)
			end
		end,
	},
	-- exp may be tuple: call, invoke, dots
	Call={
		after=function(visitor, vCallNode)
			local nTypeList = tltOper._reforge_tuple(visitor, vCallNode[2])
			local nWrapper = tltOper._call(visitor, vCallNode[1], nTypeList)
			local nParentNode = visitor.stack[#visitor.stack - 1]
			if nParentNode and (nParentNode.tag == "ExpList" or nParentNode.tag == "Pair") then
				-- maybe tuple
				vCallNode.type  = nWrapper.type
			else
				oper_merge(visitor, vCallNode, nWrapper)
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
			if nParentNode and (nParentNode.tag == "ExpList" or nParentNode.tag == "Pair") then
				-- pass
			else
				vDotsNode.type = tltype.first(vDotsNode.type)
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
	}
}

local visitor_object_dict = tlvisitor.concat(visitor_stm, visitor_exp)

function tlvBreadth.visit_block(block, visitor)
	local nBlockList = {}
	visitor.func_block_list = nBlockList
	tlvisitor.visit_obj(block, visitor)
	visitor.func_block_list = nil
	for _, sub_block in pairs(nBlockList) do
		-- TODO don't implement function first
		visitor.region_stack[#visitor.region_stack + 1] = sub_block.region_refer
		tlvBreadth.visit_block(sub_block, visitor)
		visitor.region_stack[#visitor.region_stack] = nil
	end
end

function tlvBreadth.visit(vFileEnv)
	local visitor = {
		object_dict = visitor_object_dict,
		region_stack = {tlenv.G_SCOPE_REFER},
		func_block_list = {},
		env = vFileEnv,
		log_error = log_error,
		log_warning = log_warning,
	}

	tlvBreadth.visit_block(vFileEnv.ast, visitor)
end

return tlvBreadth
