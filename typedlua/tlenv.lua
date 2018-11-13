--[[
This module implements some env setting
]]

local tlenv = {}

function tlenv.GlobalEnv(vSubject, vFileName, vAst)
	local nGlobalEnv = tlenv.FileEnv(vSubject, vFileName, vAst)
	nGlobalEnv.file_env_dict = {}
	nGlobalEnv.interface_dict = {}
	return nGlobalEnv
end

function tlenv.FileEnv(vSubject, vFileName, vAst)
	local env = {
		ast = vAst,
		ident_tree = nil,
		subject = vSubject,
		filename = vFileName,
		unique_table_list = {},
	}
	return env
end

return tlenv
