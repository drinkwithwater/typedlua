--[[
This module implements some env setting
]]

local tlast = require "typedlua/tlast"
local tlenv = {}
local tlutils = require "typedlua/tlutils"

tlenv.G_REFER = 1

function tlenv.GlobalEnv(vMainFileName)
	-- function & chunk ?
	-- open table ?
	-- ident ?


	-- TODO add what node ???
	local nNode= tlast.ident(0, "_G")
	nNode.l=0
	nNode.c=0
	nNode.ident_refer = tlenv.G_REFER

	local nGlobalEnv = {
		main_filename = vMainFileName,
		file_env_dict = {},
		interface_dict = {},
		env_stack = {},
		cur_env = nil,
		_G_node = nil,
		_G_ident = nil,
		scope_list = {},
		ident_list = {}
	}

	-- create and set root scope
	local nRootScope = tlenv.create_scope(nGlobalEnv, nil, nNode)

	-- create and bind ident
	local nIdent = tlenv.create_ident(nGlobalEnv, nRootScope, nNode)
	nRootScope.record_dict["_G"] = tlenv.G_REFER
	nRootScope.record_dict["_ENV"] = tlenv.G_REFER

	nGlobalEnv.root_scope = nRootScope
	nGlobalEnv._G_node = nNode
	nGlobalEnv._G_ident = nIdent


	return nGlobalEnv
end

function tlenv.FileEnv(vSubject, vFileName, vAst)
	local env = {
		ast = vAst,
		subject = vSubject,
		filename = vFileName,
		unique_table_list = {},

		-- region
		scope_list = nil,

		-- ident
		ident_list = nil,

		root_scope = nil,
	}
	return env
end

function tlenv.begin_file(vGlobalEnv, vSubject, vFileName, vAst)
	local nFileEnv = tlenv.FileEnv(vSubject, vFileName, vAst)

	-- bind globalenv with fileenv
	setmetatable(nFileEnv, {__index=vGlobalEnv})
	vGlobalEnv.env_stack[#vGlobalEnv.env_stack + 1] = nFileEnv
	vGlobalEnv.file_env_dict[vFileName] = nFileEnv
	vGlobalEnv.cur_env = nFileEnv

end

function tlenv.end_file(vGlobalEnv)
	local nLastIndex = #vGlobalEnv.env_stack
	vGlobalEnv.env_stack[nLastIndex] = nil
	vGlobalEnv.cur_env = vGlobalEnv.env_stack[nLastIndex - 1]
end

function tlenv.create_scope(vFileEnv, vCurScope, vNode)
	local nNewIndex = #vFileEnv.scope_list + 1
	local nNextScope = {
		tag = "Scope",
		node = vNode,
		record_dict = vCurScope and setmetatable({}, {
			__index=vCurScope.record_dict
		}) or {},
		scope_refer = nNewIndex,
	}
	vFileEnv.scope_list[nNewIndex] = nNextScope
	if vCurScope then
		vCurScope[#vCurScope + 1] = nNextScope
	end
	return nNextScope
end

function tlenv.create_ident(vFileEnv, vCurScope, vIdentNode)
	local nNewIndex = #vFileEnv.ident_list + 1
	local nName
	if vIdentNode.tag == "Id" then
		nName = vIdentNode[1]
	elseif vIdentNode.tag == "Dots" then
		nName = "..."
	else
		error("ident type error:"..tostring(vIdentNode.tag))
	end
	local nIdent = {
		tag = "IdentDefine",
		node=vIdentNode,
		ident_refer=nNewIndex,
		nName,
		nNewIndex,
	}
	vFileEnv.ident_list[nNewIndex] = nIdent
	vCurScope.record_dict[nIdent[1]] = nNewIndex
	vCurScope[#vCurScope + 1] = nIdent
	return nIdent
end

function tlenv.dump(vFileEnv)
	return tlutils.dumpLambda(vFileEnv.root_scope, function(child)
		if child.tag == "Scope" then
			return child.node, "", nil
		else
			return child.node, nil, table.concat(child, ",")
		end
	end)
end


return tlenv
