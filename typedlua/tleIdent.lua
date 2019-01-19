--[[
This module implements Ident define & refer for Lua.
]]

local seri = require "typedlua.seri"
local tlutils = require "typedlua.tlutils"
local tleIdent = {}

--[[@
interface IdentDefine
	tag:"IdentDefine"
	node:Node			-- astnode
	[1]:string			-- name
	[2]:integer			-- refer index
end
]]

function tleIdent.new_ident(vIdent, vIndex)
	if vIdent.tag == "Id" then
		return { tag = "IdentDefine", node=vIdent, vIdent[1], vIndex}
	elseif vIdent.tag == "Dots" then
		return { tag = "IdentDefine", node=vIdent, "...", vIndex}
	else
		error("ident type error:"..tostring(vIdent.tag))
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
function tleIdent.new_table(vParent, vStmNode)
	local nObj = {
		tag = "IdentTable",
		node = vStmNode,
		parent = vParent,
		record_dict = vParent and setmetatable({}, {
			__index=vParent.record_dict
		}) or {},
	}
	return nObj
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
function tleIdent.new_tree(vFileEnv, vAst)
	local nCurTable = tleIdent.new_table(nil, vAst)
	local nObj = {
		tag = "IdentTree",
		cur_table = nCurTable,
		root_table = nCurTable,
	}
	return nObj
end

--@(IdentTree, AstStm)
function tleIdent.begin_scope(vTree, vStmNode)
	local new_table = tleIdent.new_table(vTree.cur_table, vStmNode)
	vTree.cur_table[#vTree.cur_table + 1] = new_table
	vTree.cur_table = new_table
end

function tleIdent.end_scope(vTree)
	assert(vTree.cur_table.parent)
	local nParent = vTree.cur_table.parent
	vTree.cur_table.parent = nil
	vTree.cur_table = nParent
end

function tleIdent.ident_define(vTree, vIdent)
	local nNewIndex = #vTree + 1
	local nNewIdent = tleIdent.new_ident(vIdent, nNewIndex)
	vTree[nNewIndex] = nNewIdent
	vTree.cur_table[#vTree.cur_table + 1] = nNewIdent
	vTree.cur_table.record_dict[nNewIdent[1]] = nNewIndex
	return nNewIndex
end

function tleIdent.ident_refer(vTree, vIdent)
	local nName
	if vIdent.tag == "Id" then
		nName = vIdent[1]
	elseif vIdent.tag == "Dots" then
		nName = "..."
	else
		error("tleIdent refer error tag"..tostring(vIdent.tag))
	end
	-- local refer_index = assert(tree.cur_table.record_dict[name], string.format("ident_refer fail, %s,%s", ident.l, ident.c))
	local nReferIndex = vTree.cur_table.record_dict[nName]
	return nReferIndex
end

function tleIdent.dump(vTree)
	return tlutils.dumpLambda(vTree.root_table, function(child)
		if child.tag == "IdentTable" then
			return child.node, "", nil
		else
			return child.node, nil, table.concat(child, ",")
		end
	end)
end

return tleIdent
