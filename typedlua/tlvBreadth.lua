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

local Nil = tltype.Nil()
local Self = tltype.Self()
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
	if vNode.type then
		-- log_error(visitor, vNode, "add type but node.type existed", vNode.type.tag, vWrapper.type.tag)
		vNode.type = vWrapper.type
	else
		vNode.type = vWrapper.type
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
			local pre_node = visitor.stack[#visitor.stack - 1]
			if pre_node and pre_node.tag == "Function" then
				visitor.func_block_list[#visitor.func_block_list + 1] = node
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
			local nNameNode = node[1]
			local nWrapper = tltOper._init_assign(visitor, nNameNode, node[2])
			oper_merge(visitor, nNameNode, nWrapper)
			visit_node(visitor, node[#node])
		end,
	},
	Set={
		after=function(visitor, node)
			local nExprList = node[2]
			local nVarList = node[1]
			for i, nVarNode in ipairs(nVarList) do
				local nExprNode = nExprList[i]
				if nVarNode.tag == "Index" then
					tltOper._index_set(visitor, nVarNode[1], nVarNode[2], nExprNode)
				elseif nVarNode.tag == "Id" then
					local nWrapper = tltOper._set_assign(visitor, nVarNode, nExprNode)
					local nIdent = visitor.env.ident_tree[nVarNode.refer]
					oper_merge(visitor, nIdent, nWrapper)
				else
					error("assign to node:tag="..tostring(node.tag))
				end
			end
		end,
	},
	Localrec={
		after=function(visitor, node)
			print("local function TODO")
		end,
	},
	Local={
		after=function(visitor, node)
			local nNameList = node[1]
			local nExprList = node[2]
			for i, nNameNode in ipairs(nNameList) do
				local nExprNode = nExprList[i]
				local nWrapper = tltOper._init_assign(visitor, nNameNode, nExprNode)
				local nIdent = visitor.env.ident_tree[nNameNode.refer]
				oper_merge(visitor, nNameNode, nWrapper)
				oper_merge(visitor, nIdent, nWrapper)
			end
		end,
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

	--
	Table={
		after=function(visitor, node)
			local l = {}
			local i = 1
			for k, field in ipairs(node) do
				if field.tag == "Pair" then
					l[#l + 1] = tltable.Field(field[1].type, field[2].type)
				else
					l[#l + 1] = tltable.Field(tltype.Literal(i), field.type)
				end
			end

			-- if not deco type, ident is unique table
			local nOpenTable = tltable.OpenTable(table.unpack(l))
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
	Call={
		after=function(visitor, node)
			print("func call TODO")
		end
	},
	Invoke={
		after=function(visitor, node)
			print("func invoke TODO")
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
	Id={
		after=function(visitor, node)
			local ident = visitor.env.ident_tree[node.refer]
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
}

local visitor_object_dict = tlvisitor.concat(visitor_stm, visitor_exp)

function tlvBreadth.visit_block(block, visitor)
	local block_list = {}
	visitor.func_block_list = block_list
	tlvisitor.visit_obj(block, visitor)
	visitor.func_block_list = nil
	for _, sub_block in pairs(block_list) do
		-- TODO don't implement function first
		-- tlvBreadth.visit_block(sub_block, visitor)
	end
end

function tlvBreadth.visit(vFileEnv)
	local visitor = {
		override = visitor_override,
		after = visitor_after,
		before = visitor_before,
		object_dict = visitor_object_dict,
		func_block_list = {},
		env = vFileEnv,
		log_error = log_error,
		log_warning = log_warning,
	}

	tlvBreadth.visit_block(vFileEnv.ast, visitor)
end

return tlvBreadth