
local tlvisitor = require "typedlua/tlvisitor"
local tlutils = require "typedlua/tlutils"
local tltype = require "typedlua/tltype"
local tlbreadth = {}

local Value = tltype.Value()
local Any = tltype.Any()
local Nil = tltype.Nil()
local Self = tltype.Self()
local Boolean = tltype.Boolean()
local Number = tltype.Number()
local String = tltype.String()
local Integer = tltype.Integer(false)

local function typeerror(env, node, ...)
	error(...)
end

local function typeassert(node, value, msg)
	if not value then
		error(string.format("(%s,%s) %s", node.l, node.c, msg))
	else
		return value
	end
end

local function set_type(node, t)
	if node.right_deco then
		if not tltype.subtype(t, node.right_deco) then
			typeerror(nil, node, "typeerror")
		end
		node.type = right_deco
	end
	node.type = t
end

local visitor_override = {
	Function = function(visitor, node)
		visitor.func_block_list[#visitor.func_block_list + 1] = node[3] or node[2]
	end
}

local visitor_arith = function(visitor, node)
end
local visitor_bitwise = function(visitor, node)
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
	end,

	eq=function(visitor, node)
	end,

	lt=function(visitor, node)
	end,
	le=function(visitor, node)
	end,

	["and"]=function(visitor, node)
	end,
	["or"]=function(visitor, node)
	end,
	band=visitor_bitwise,
	bor=visitor_bitwise,
	bxor=visitor_bitwise,
	shl=visitor_bitwise,
	shr=visitor_bitwise,
}

local visitor_exp = {
	Nil=function(visitor, node)
		set_type(node, Nil)
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
		local t = tltype.Table(table.unpack(l))
		t.unique = true
		if node.right_deco then
			assert(tltype.subtype(t, node.right_deco))
			node.type = node.right_deco
		else
			t.tag = "TUniqueTable"
			node.type = t
		end
	end,
	Op=function(visitor, node)
	end,
	Call=function(visitor, node)
	end,
	Invoke=function(visitor, node)
	end,
	Index=function(visitor, node)
		local n_field = tltype.indexfield(node[1].type, node[2].type)
		if tltype.isNil(n_field) then
			node.type = n_field
		else
			node.type = n_field[2]
		end
	end,
	Id=function(visitor, node)
		node.type = visitor.identTree[node.tlrefer].node.type
	end
}

local function visitor_setsub(visitor, lhs, exp)
end

local visitor_stm = {
	Set=function(visitor, node)
		for i, lhs in ipairs(node[1]) do
		end
	end,
	Localrec=function(visitor, node)
	end,
	Local=function(visitor, node)
		local identTree = visitor.identTree
		local name_list = node[1]
		local exp_list = node[2]
		for i, name in ipairs(name_list) do
			local exp = exp_list[i]
			local right_type = exp and exp.type or Nil
			if name.left_deco and right_type then
				assert(tltype.subtype(right_type, name.left_deco))
				name.type = left_deco
			else
				name.type = right_type
			end
		end
	end,
}

local visitor_after = tlvisitor.concat(visitor_stm, visitor_exp)

function tlbreadth.visit_block(block, visitor)
	tlvisitor.visit(block, visitor)
	local func_block_list = visitor.func_block_list
	visitor.func_block_list = {}
	for _, sub_block in pairs(func_block_list) do
		tlbreadth.visit_block(sub_block, visitor)
	end
end

function tlbreadth.visit(ast, identTree)
	local visitor = {
		override = visitor_override,
		after = visitor_after,
		identTree = identTree,
		func_block_list = {},
		unique_table_list = {},
	}

	tlvisitor.visit(ast, visitor)
	local func_block_list = visitor.func_block_list
	visitor.func_block_list = {}
	for _, sub_block in pairs(func_block_list) do
		tlbreadth.visit_block(sub_block, visitor)
	end
end

return tlbreadth
