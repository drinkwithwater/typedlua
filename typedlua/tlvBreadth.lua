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

-- + - * / // % ^
local visitor_arith = function(visitor, node)
	-- TODO
	add_type(visitor, node, tltype.Number())
	check_type(visitor, node[2], tltype.Number())
	check_type(visitor, node[3], tltype.Number())
end
-- &|~>><<
local visitor_bitwise = function(visitor, node)
	add_type(visitor, node, tltype.Integer())
	check_type(visitor, node[2], tltype.Integer())
	check_type(visitor, node[3], tltype.Integer())
end
-- >= <= > < == ~=
local visitor_compare = function(visitor, node)
	add_type(visitor, node, tltype.Boolean())
	check_type(visitor, node[2], tltype.Number())
	check_type(visitor, node[3], tltype.Number())
end

local visitor_binary = {
	add=visitor_arith,
	sub=visitor_arith,
	mul=visitor_arith,
	idiv=visitor_arith,
	div=visitor_arith,
	mod=visitor_arith,
	pow=visitor_arith,

	concat=function(visitor, node)
		add_type(visitor, node, tltype.String())
		check_type(visitor, node[2], tltype.String())
		check_type(visitor, node[3], tltype.String())
	end,
	["and"]=function(visitor, node)
		print("and TODO")
	end,
	["or"]=function(visitor, node)
		print("or TODO")
	end,

	eq=visitor_compare,
	lt=visitor_compare,
	le=visitor_compare,
	ne=visitor_compare,
	gt=visitor_compare,
	ge=visitor_compare,

	band=visitor_bitwise,
	bor=visitor_bitwise,
	bxor=visitor_bitwise,
	shl=visitor_bitwise,
	shr=visitor_bitwise,
}

local visitor_unary = {
	["not"] = function(visitor, node)
		add_type(visitor, node, tltype.Boolean())
	end,
	bnot=function(visitor, node)
		add_type(visitor, node, tltype.Integer())
		check_type(visitor, node[2], tltype.Integer())
	end,
	unm=function(visitor, node)
		add_type(visitor, node, tltype.Number())
		check_type(visitor, node[2], tltype.Number())
	end,
	len=function(visitor, node)
		add_type(visitor, node, tltype.Integer())
		check_type(visitor, node[2], tltype.String())
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
	Op=function(visitor, node)
		local nOP = node[1]
		local nFunc = nil
		if #node == 3 then
			nFunc = visitor_binary[nOP]
		elseif #node == 2 then
			nFunc = visitor_unary[nOP]
		end
		nFunc(visitor, node)
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
