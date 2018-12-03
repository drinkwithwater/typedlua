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

-- expr check type
local function check_type(visitor, node, t)
	if not tltRelation.sub(node.type, t) then
		log_error(visitor, node, node.type.tag, "can't not be", t.tag)
	end
end

local function oper_merge(visitor, vNode, vWrapper)
	if vNode.type then
		log_error(visitor, vNode, "add type but node.type existed", vNode.type.tag, vWrapper.type.tag)
	else
		vNode.type = vWrapper.type
	end
	vNode.index_field = vWrapper.index_field
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

local visitor_override = {
	Block=function(visitor, node, visit_node, self_visit)
		local pre_node = visitor.stack[#visitor.stack - 1]
		if pre_node and pre_node.tag == "Function" then
			visitor.func_block_list[#visitor.func_block_list + 1] = node
		else
			self_visit(visitor, node)
		end
	end
}

local visitor_binary = {
	add=function(visitor, vNode)
		local nWrapper = tltOper.__add(visitor, vNode[2], vNode[3])
		oper_merge(visitor, vNode, nWrapper)
	end,
	sub=function(visitor, vNode)
		local nWrapper = tltOper.__sub(visitor, vNode[2], vNode[3])
		oper_merge(visitor, vNode, nWrapper)
	end,
	mul=function(visitor, vNode)
		local nWrapper = tltOper.__mul(visitor, vNode[2], vNode[3])
		oper_merge(visitor, vNode, nWrapper)
	end,
	idiv=function(visitor, vNode)
		local nWrapper = tltOper.__idiv(visitor, vNode[2], vNode[3])
		oper_merge(visitor, vNode, nWrapper)
	end,
	div=function(visitor, vNode)
		local nWrapper = tltOper.__div(visitor, vNode[2], vNode[3])
		oper_merge(visitor, vNode, nWrapper)
	end,
	mod=function(visitor, vNode)
		local nWrapper = tltOper.__mod(visitor, vNode[2], vNode[3])
		oper_merge(visitor, vNode, nWrapper)
	end,
	pow=function(visitor, vNode)
		local nWrapper = tltOper.__pow(visitor, vNode[2], vNode[3])
		oper_merge(visitor, vNode, nWrapper)
	end,

	concat=function(visitor, vNode)
		local nWrapper = tltOper.__concat(visitor, vNode[2], vNode[3])
		oper_merge(visitor, vNode, nWrapper)
	end,
	["and"]=function(visitor, vNode)
		local nWrapper = tltOper._and(visitor, vNode[2], vNode[3])
		oper_merge(visitor, vNode, nWrapper)
	end,
	["or"]=function(visitor, vNode)
		local nWrapper = tltOper._or(visitor, vNode[2], vNode[3])
		oper_merge(visitor, vNode, nWrapper)
	end,
	eq=function(visitor, vNode)
		local nWrapper = tltOper.__eq(visitor, vNode[2], vNode[3])
		oper_merge(visitor, vNode, nWrapper)
	end,
	lt=function(visitor, vNode)
		local nWrapper = tltOper.__lt(visitor, vNode[2], vNode[3])
		oper_merge(visitor, vNode, nWrapper)
	end,
	le=function(visitor, vNode)
		local nWrapper = tltOper.__le(visitor, vNode[2], vNode[3])
		oper_merge(visitor, vNode, nWrapper)
	end,
	ne=function(visitor, vNode)
		local nWrapper = tltOper._ne(visitor, vNode[2], vNode[3])
		oper_merge(visitor, vNode, nWrapper)
	end,
	gt=function(visitor, vNode)
		local nWrapper = tltOper._gt(visitor, vNode[3], vNode[2])
		oper_merge(visitor, vNode, nWrapper)
	end,
	ge=function(visitor, vNode)
		local nWrapper = tltOper._ge(visitor, vNode[3], vNode[2])
		oper_merge(visitor, vNode, nWrapper)
	end,

	band=function(visitor, vNode)
		local nWrapper = tltOper.__band(visitor, vNode[2], vNode[3])
		oper_merge(visitor, vNode, nWrapper)
	end,
	bor=function(visitor, vNode)
		local nWrapper = tltOper.__bor(visitor, vNode[2], vNode[3])
		oper_merge(visitor, vNode, nWrapper)
	end,
	bxor=function(visitor, vNode)
		local nWrapper = tltOper.__bxor(visitor, vNode[2], vNode[3])
		oper_merge(visitor, vNode, nWrapper)
	end,
	shl=function(visitor, vNode)
		local nWrapper = tltOper.__shl(visitor, vNode[2], vNode[3])
		oper_merge(visitor, vNode, nWrapper)
	end,
	shr=function(visitor, vNode)
		local nWrapper = tltOper.__shr(visitor, vNode[2], vNode[3])
		oper_merge(visitor, vNode, nWrapper)
	end,
}

local visitor_unary = {
	["not"] = function(visitor, vNode)
		local nWrapper = tltOper._not(visitor, vNode[2])
		oper_merge(visitor, vNode, nWrapper)
	end,
	bnot=function(visitor, vNode)
		local nWrapper = tltOper.__bnot(visitor, vNode[2])
		oper_merge(visitor, vNode, nWrapper)
	end,
	unm=function(visitor, vNode)
		local nWrapper = tltOper.__unm(visitor, vNode[2])
		oper_merge(visitor, vNode, nWrapper)
	end,
	len=function(visitor, vNode)
		local nWrapper = tltOper.__len(visitor, vNode[2])
		oper_merge(visitor, vNode, nWrapper)
	end,
}

local visitor_exp = {
	Nil=function(visitor, node)
		add_type(visitor, node, tltype.Nil())
	end,
	True=function(visitor, node)
		add_type(visitor, node, tltype.Literal(true))
	end,
	False=function(visitor, node)
		add_type(visitor, node, tltype.Literal(false))
	end,
	Number=function(visitor, node)
		add_type(visitor, node, tltype.Literal(node[1]))
	end,
	String=function(visitor, node)
		add_type(visitor, node, tltype.Literal(node[1]))
	end,
	Table=function(visitor, node)
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
		local nUniqueTable = tltable.UniqueTable(table.unpack(l))
		local nNewIndex = #visitor.env.unique_table_list + 1
		visitor.env.unique_table_list[nNewIndex] = nUniqueTable

		add_type(visitor, node, nUniqueTable)
	end,
	Op=function(visitor, vNode)
		local nOP = node[1]
		if #node == 3 then
			local nOper = tltOper["__"..nOP] or tltOper["_"..nOP]
			local nWrapper = nOper(visitor, vNode[2], vNode[3])
			oper_merge(vNode, nWrapper)
		elseif #node == 2 then
			local nOper = tltOper["__"..nOP] or tltOper["_"..nOP]
			local nWrapper = nOper(visitor, vNode[2])
			oper_merge(vNode, nWrapper)
		end
	end,
	Call=function(visitor, node)
		print("func call TODO")
	end,
	Invoke=function(visitor, node)
		print("func invoke TODO")
	end,
	Index=function(visitor, node)
		local nField = nil
		local nType1, nType2 = node[1].type, node[2].type
		if nType1.tag == "TUniqueTable" then
			nField = tltable.index_unique(nType1, nType2)
		elseif nType1.tag == "TTable" then
			nField = tltable.index_generic(nType1, nType2)
		else
			-- TODO check node is Table
			log_error(visitor, node, "index for non-table type not implement...")
			nField = tltable.Field(nType2, tltype.Nil())
		end
		if nField.tag == "TNil" then
			add_type(visitor, node, nField)
		else
			add_type(visitor, node, nField[2])
		end
	end,
	Id=function(visitor, node)
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
}

local visitor_stm = {
	Set=function(visitor, node)
		local nExprList = node[2]
		local nVarList = node[1]
		for i, nVarNode in ipairs(nVarList) do
			local nExprNode = nExprList[i]
			if nVarNode.tag == "Index" then
				if nVarNode.type.tag == "TNil" then
					tltable.insert(nVarNode[1].type, tltable.Field(nVarNode[2].type, nExprNode.type))
				else
					log_error(visitor, nVarNode, "type assign type TODO:", nVarNode.type.tag, nExprNode.tag)
					--[[
					if not tltRelation.sub(nExprNode.type, nVarNode.type) then
						log_error(visitor, nVarNode, "assign type failed:", nVarNode.type.tag, nExprNode.tag)
					end
					]]
				end
			elseif nVarNode.tag == "Id" then
				if not tltRelation.sub(nExprNode.type, nVarNode.type) then
					log_error(visitor, nVarNode, "assign type failed:", nVarNode.type.tag, nExprNode.type.tag)
				end
				-- TODO assign to Id
			else
				error("assign to node:tag="..tostring(node.tag))
			end
		end
	end,
	Localrec=function(visitor, node)
	end,
	Fornum=function(visitor, node)
		node[1].type = tltype.Number()
	end,
	Local=function(visitor, node)
		local identTree = visitor.env.ident_tree
		local nNameList = node[1]
		local nExprList = node[2]
		for i, nNameNode in ipairs(nNameList) do
			local nExprNode = nExprList[i]
			local nRightType = nExprNode and nExprNode.type or Nil
			local nLeftDeco = nNameNode.left_deco
			if nLeftDeco then
				if not tltRelation.sub(nRightType, nLeftDeco) then
					log_error(visitor, nNameNode, nRightType.tag.." can't be assigned to "..nLeftDeco.tag)
				end
				nNameNode.type = nLeftDeco
			else
				nNameNode.type = nRightType
			end
		end
	end,
}

local visitor_after = tlvisitor.concat(visitor_stm, visitor_exp)

function tlvBreadth.visit_block(block, visitor)
	local block_list = {}
	visitor.func_block_list = block_list
	tlvisitor.visit(block, visitor)
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
		func_block_list = {},
		env = vFileEnv,
		log_error = log_error,
		log_warning = log_warning,
	}

	tlvBreadth.visit_block(vFileEnv.ast, visitor)
end

return tlvBreadth
