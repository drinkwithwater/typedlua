--[[
This module implements Ident define & refer for Lua.
]]

local seri = require "typedlua.seri"
local tlutils = require "typedlua.tlutils"
local tlident = {}

--[[@
interface IdentDefine
	tag:"IdentDefine"
	node:Node			-- astnode
	[1]:string			-- name
	[2]:integer			-- refer index
end
]]

function tlident.new_ident_define(ident, index)
	if ident.tag == "Id" then
		return { tag = "IdentDefine", node=ident, ident[1], index}
	elseif ident.tag == "Dots" then
		return { tag = "IdentDefine", node=ident, "...", index}
	else
		error("ident type error:"..tostring(ident.tag))
	end
end

--[[@
interface IdentTable
	tag:"IdentTable"
	node:AstNode
	parent:IdentTable?
	[integer]:IdentDefine|IdentTable
	record_dict:{string:integer}
end
]]
function tlident.new_table(parent, stm)
	local obj = {
		tag = "IdentTable",
		node = stm,
		parent = parent,
		record_dict = parent and setmetatable({}, {
			__index=parent.record_dict
		}) or {},
	}
	return obj
end

--[[@
interface IdentTree
	tag:"IdentTree"
	cur_table:IdentTable?
	root_table:IdentTable?
	record_dict:{string:integer}
	[integer]:IdentDefine|IdentTree
end
]]

--@(IdentTree, AstStm)
function tlident.new_tree(ast)
	local cur_table  = tlident.new_table(nil, ast)
	local obj = {
		tag = "IdentTree",
		cur_table = cur_table,
		root_table = cur_table,
	}
	return obj
end

--@(IdentTree, AstStm)
function tlident.begin_scope(tree, stm)
	local new_table = tlident.new_table(tree.cur_table, stm)
	tree.cur_table[#tree.cur_table + 1] = new_table
	tree.cur_table = new_table
end

function tlident.end_scope(tree)
	assert(tree.cur_table.parent)
	local parent = tree.cur_table.parent
	tree.cur_table.parent = nil
	tree.cur_table = parent
end

function tlident.ident_define(tree, ident)
	local new_index = #tree + 1
	local new_ident_define = tlident.new_ident_define(ident, new_index)
	tree[new_index] = new_ident_define
	tree.cur_table[#tree.cur_table + 1] = new_ident_define
	tree.cur_table.record_dict[new_ident_define[1]] = new_index
	return new_index
end

function tlident.ident_refer(tree, ident)
	local name
	if ident.tag == "Id" then
		name = ident[1]
	elseif ident.tag == "Dots" then
		name = "..."
	else
		error("tlident refer error tag"..tostring(ident.tag))
	end
	-- local refer_index = assert(tree.cur_table.record_dict[name], string.format("ident_refer fail, %s,%s", ident.l, ident.c))
	local refer_index = tree.cur_table.record_dict[name]
	return refer_index
end

function tlident.dump(tree)
	return tlutils.dumpLambda(tree.root_table, function(child)
		if child.tag == "IdentTable" then
			return child.node, "", nil
		else
			return child.node, nil, table.concat(child, ",")
		end
	end)
end

return tlident
