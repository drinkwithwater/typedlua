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

--@(FileEnv, AstStm)
function tleIdent.begin_scope(vFileEnv, vStmNode)
	local nNewTable = tleIdent.new_table(vFileEnv.cur_ident_table, vStmNode)
	vFileEnv.cur_ident_table[#vFileEnv.cur_ident_table + 1] = nNewTable
	vFileEnv.cur_ident_table = nNewTable
end

function tleIdent.end_scope(vFileEnv)
	assert(vFileEnv.cur_ident_table.parent)
	local nParent = vFileEnv.cur_ident_table.parent
	vFileEnv.cur_ident_table.parent = nil
	vFileEnv.cur_ident_table = nParent
end

function tleIdent.ident_define(vFileEnv, vIdent)
	local nIdentList = vFileEnv.ident_list
	local nNewIndex = #nIdentList + 1
	local nNewIdent = tleIdent.new_ident(vIdent, nNewIndex)
	nIdentList[nNewIndex] = nNewIdent
	vFileEnv.cur_ident_table[#vFileEnv.cur_ident_table + 1] = nNewIdent
	vFileEnv.cur_ident_table.record_dict[nNewIdent[1]] = nNewIndex
	return nNewIndex
end

function tleIdent.ident_refer(vFileEnv, vIdent)
	local nName
	if vIdent.tag == "Id" then
		nName = vIdent[1]
	elseif vIdent.tag == "Dots" then
		nName = "..."
	else
		error("tleIdent refer error tag"..tostring(vIdent.tag))
	end
	-- local refer_index = assert(tree.cur_table.record_dict[name], string.format("ident_refer fail, %s,%s", ident.l, ident.c))
	local nReferIndex = vFileEnv.cur_ident_table.record_dict[nName]
	return nReferIndex
end

function tleIdent.dump(vFileEnv)
	return tlutils.dumpLambda(vFileEnv.root_ident_table, function(child)
		if child.tag == "IdentTable" then
			return child.node, "", nil
		else
			return child.node, nil, table.concat(child, ",")
		end
	end)
end

return tleIdent
