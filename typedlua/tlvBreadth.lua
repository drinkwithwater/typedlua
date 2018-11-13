
local tlvisitor = require "typedlua/tlvisitor"
local tlutils = require "typedlua/tlutils"
local tltype = require "typedlua/tltype"
local tltable = require "typedlua/tltable"
local tlvBreadth = {}

local Value = tltype.Value()
local Any = tltype.Any()
local Nil = tltype.Nil()
local Self = tltype.Self()
local Boolean = tltype.Boolean()
local Number = tltype.Number()
local String = tltype.String()

-- expr set type, check right_deco
local function set_type(node, t)
	if node.right_deco then
		--[[ TODO
		if not tltype.subtype(t, node.right_deco) then
			typeerror(nil, node, "typeerror")
		end]]
		-- node.type = right_deco
	end
	node.type = t
end

-- assign or local
local function assign_type(node, t)
	if node.left_deco then
		-- TODO
	end
	node.type = t
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

-- +-*/
local visitor_arith = function(visitor, node)
	-- TODO
	set_type(node, tltype.Number())
end
-- &|~>><<
local visitor_bitwise = function(visitor, node)
	set_type(node, tltype.Integer())
end
-- >= <= > < == ~=
local visitor_compare = function(visitor, node)
	set_type(node, tltype.Boolean())
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
		set_type(node, tltype.String())
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
		set_type(node, tltype.Boolean())
	end,
	bnot=function(visitor, node)
		set_type(node, tltype.Integer())
	end,
	unm=function(visitor, node)
		set_type(node, node[2].type)
	end,
	len=function(visitor, node)
		set_type(node, tltype.Integer())
	end,
}

local visitor_exp = {
	Nil=function(visitor, node)
		set_type(node, tltype.Nil())
	end,
	True=function(visitor, node)
		set_type(node, tltype.Literal(true))
	end,
	False=function(visitor, node)
		set_type(node, tltype.Literal(false))
	end,
	Number=function(visitor, node)
		set_type(node, tltype.Literal(node[1]))
	end,
	String=function(visitor, node)
		set_type(node, tltype.Literal(node[1]))
	end,
	Table=function(visitor, node)
		local l = {}
		local i = 1
		for k, field in ipairs(node) do
			if field.tag == "Pair" then
				l[#l + 1] = tltype.Field(false, field[1].type, field[2].type)
			else
				l[#l + 1] = tltype.Field(false, tltype.Literal(i), field.type)
			end
		end

		-- if not deco type, ident is unique table
		local nUniqueTable = tltable.UniqueTable(table.unpack(l))
		local nNewIndex = #visitor.env.unique_table_list + 1
		visitor.env.unique_table_list[nNewIndex] = nUniqueTable

		set_type(node, nUniqueTable)
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
		local nField = tltable.index(node[1].type, node[2].type)
		if tltype.isNil(nField) then
			set_type(node, nField)
		else
			set_type(node, nField[2])
		end
	end,
	Id=function(visitor, node)
		local seri = require "typedlua.seri"
		local ident = visitor.env.ident_tree[node.tlvRefer]
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
		for i, lhs in ipairs(node[1]) do
		end
	end,
	Localrec=function(visitor, node)
	end,
	Fornum=function(visitor, node)
		node[1].type = tltype.Number()
	end,
	Local=function(visitor, node)
		local identTree = visitor.env.ident_tree
		local name_list = node[1]
		local exp_list = node[2]
		for i, name in ipairs(name_list) do
			local exp = exp_list[i]
			local right_type = exp and exp.type or Nil
			if name.left_deco and right_type then
				-- TODO assert(tltype.subtype(right_type, name.left_deco))
			else
				name.type = right_type
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
		tlvBreadth.visit_block(sub_block, visitor)
	end
end

function tlvBreadth.visit(vFileEnv)
	local visitor = {
		override = visitor_override,
		after = visitor_after,
		func_block_list = {},
		env = vFileEnv,
	}

	tlvBreadth.visit_block(vFileEnv.ast, visitor)
end

return tlvBreadth
