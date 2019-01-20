--[[
This module implements some env setting
]]

local tleIdent = require "typedlua/tleIdent"
local tlast = require "typedlua/tlast"
local tlenv = {}

function tlenv.GlobalEnv(vMainFileName)
	-- function & chunk ?
	-- open table ?
	-- ident ?
	-- tlenv.FileEnv(vSubject, vFileName, vAst)
	local _GNode= tlast.ident(0, "_G")
	_GNode.l=0
	_GNode.c=0
	_GNode.refer = 1 -- tleIdent.ident_define(nIdentTree, env_node)
	local _GIdent= tleIdent.new_ident(_GNode, 1)

	local nGlobalEnv = {
		main_filename = vMainFileName,
		file_env_dict = {},
		interface_dict = {},
		region_list = {},
		env_stack = {},
		cur_env = nil,
		_G_node= _GNode,
		_G_ident = _GIdent,
	}
	return nGlobalEnv
end

function tlenv.FileEnv(vSubject, vFileName, vAst)
	local env = {
		ast = vAst,
		subject = vSubject,
		filename = vFileName,
		unique_table_list = {},
		region_list = nil,



		-- ident
		ident_tree = nil,
		cur_ident_table = nil,
		root_ident_table = nil,
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


	-- create ident list
	nFileEnv.ident_list = {vGlobalEnv._G_node}

	-- create root ident table
	local nRootIdentTable = tleIdent.new_table(nil, vAst)
	nFileEnv.cur_ident_table = nRootIdentTable
	nFileEnv.root_ident_table = nRootIdentTable

	-- put _G into root ident table
	nRootIdentTable[1] = vGlobalEnv._G_ident
	nRootIdentTable.record_dict["_G"] = 1
	nRootIdentTable.record_dict["_ENV"] = 1

end

function tlenv.end_file(vGlobalEnv)
	local nLastIndex = #vGlobalEnv.env_stack
	vGlobalEnv.env_stack[nLastIndex] = nil
	vGlobalEnv.cur_env = vGlobalEnv.env_stack[nLastIndex - 1]
end

function tlenv.begin_scope()
end

function tlenv.end_scope()
end

return tlenv
