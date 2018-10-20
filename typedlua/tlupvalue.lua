--[[
This module implements Upvalue index for Lua.
]]

local seri = require "typedlua.seri"
local tlupvalue = {}

--[[@
interface UVTable
	tag:"UpValue"
	[1]:string			-- name
	[2]:integer			-- index
end
]]

function tlupvalue.new_upvalue(ident, index)
	if ident.tag == "Id" then
		return { tag = "UpValue", node=ident, ident[1], index}
	elseif ident.tag == "Dots" then
		return { tag = "UpValue", node=ident, "...", index}
	else
		error("ident type error:"..tostring(ident.tag))
	end
end

--[[@
interface UVTable
	tag:"UVTable"
	node:AstNode
	parent:UVTable?
	[integer]:UpValue|UVTable
	record_dict:{string:integer}
end
]]
function tlupvalue.new_table(parent, stm)
	local obj = {
		tag = "UVTable",
		node = stm,
		parent = parent,
		record_dict = parent and setmetatable({}, {
			__index=parent.record_dict
		}) or {},
	}
	return obj
end

--[[@
interface UVTree
	tag:"UVTree"
	cur_table:UVTable?
	root_table:UVTable?
	record_dict:{string:integer}
	[integer]:UpValue|UVTree
end
]]

--@(UVTree, AstStm)
function tlupvalue.new_tree(ast)
	local cur_table  = tlupvalue.new_table(nil, ast)
	local obj = {
		tag = "UVTree",
		cur_table = cur_table,
		root_table = cur_table,
	}
	return obj
end

--@(UVTree, AstStm)
function tlupvalue.begin_scope(tree, stm)
	local new_table = tlupvalue.new_table(tree.cur_table, stm)
	tree.cur_table[#tree.cur_table + 1] = new_table
	tree.cur_table = new_table
end

function tlupvalue.end_scope(tree)
	assert(tree.cur_table.parent)
	local parent = tree.cur_table.parent
	tree.cur_table.parent = nil
	tree.cur_table = parent
end

function tlupvalue.ident_define(tree, ident)
	local new_index = #tree + 1
	local new_upvalue = tlupvalue.new_upvalue(ident, new_index)
	tree[new_index] = new_upvalue
	tree.cur_table[#tree.cur_table + 1] = new_upvalue
	tree.cur_table.record_dict[new_upvalue[1]] = new_index
	return new_index
end

function tlupvalue.ident_refer(tree, ident)
	local name
	if ident.tag == "Id" then
		name = ident[1]
	elseif ident.tag == "Dots" then
		name = "..."
	else
		error("tlupvalue refer error tag"..tostring(ident.tag))
	end
	local refer_uv_index = assert(tree.cur_table.record_dict[name], string.format("ident_refer fail, %s,%s", ident.l, ident.c))
	return refer_uv_index
end

--@(UVTable|UpValue, {integer:string}, integer) -> string
function tlupvalue.iteruv(uv, buffer_list, pre_line)
	local line, offset = pre_line, nil
	local astNode = uv.node
	if astNode.pos then
		line, offset = astNode.l, astNode.c
		if line ~= pre_line then
			buffer_list[#buffer_list + 1] = "\n"
			buffer_list[#buffer_list + 1] = line
			buffer_list[#buffer_list + 1] = ":"
			buffer_list[#buffer_list + 1] = string.rep(" ", offset)
		end
	end
	if uv.tag == "UVTable" then
		buffer_list[#buffer_list + 1] = "{"
		for k, v in ipairs(uv) do
			if type(v) == "table" then
				line = tlupvalue.iteruv(v, buffer_list, line)
			else
				buffer_list[#buffer_list + 1] = "("
				buffer_list[#buffer_list + 1] = v
				buffer_list[#buffer_list + 1] = ")"
			end
		end
		buffer_list[#buffer_list + 1] = "}"
	else
		buffer_list[#buffer_list + 1] = "("
		buffer_list[#buffer_list + 1] = table.concat(uv, ",")
		buffer_list[#buffer_list + 1] = ")"
	end
	return line
end

function tlupvalue.dump(tree)
	local bufferList = {}
	tlupvalue.iteruv(tree.root_table, bufferList, -1)
	return table.concat(bufferList)
end

return tlupvalue
