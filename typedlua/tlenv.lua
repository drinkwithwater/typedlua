--[[
This module implements some env setting
]]

local tlast = require "typedlua/tlast"
local tltype = require "typedlua/tltype"
local tlutils = require "typedlua/tlutils"
local tlenv = {}

tlenv.G_IDENT_REFER = 1
tlenv.G_SCOPE_REFER = 1
tlenv.G_REGION_REFER = 1

function tlenv.GlobalEnv(vMainFileName)
	-- function & chunk ?
	-- auto table ?
	-- ident ?

	-- TODO add what node ???
	local nNode = tlast.ident(0, "_G")
	nNode.l=0
	nNode.c=0
	-- nNode.type = tltPrime
	nNode.ident_refer = tlenv.G_IDENT_REFER

	local nGlobalEnv = {
		main_filename = vMainFileName,
		file_env_dict = {},
		_G_node = nil,
		_G_ident = nil,

		define_dict = {},
		scope_list = {},
		region_list = nil, -- region_list = scope_list
		ident_list = {},
	}

	nGlobalEnv.region_list = nGlobalEnv.scope_list

	-- create and set root scope
	local nRootScope = tlenv.create_region(nGlobalEnv, nil, nil, nNode)

	-- create and bind ident
	local nIdent = tlenv.create_ident(nGlobalEnv, nRootScope, nNode)
	nRootScope.record_dict["_G"] = tlenv.G_IDENT_REFER
	nRootScope.record_dict["_ENV"] = tlenv.G_IDENT_REFER


	nGlobalEnv.root_scope = nRootScope
	nGlobalEnv._G_node = nNode
	nGlobalEnv._G_ident = nIdent


	return nGlobalEnv
end

function tlenv.FileEnv(vSubject, vFileName)
	local nEnv = {

		info = {
			subject = vSubject,
			file_name = vFileName,
			split_info_list = nil,
			ast = nil,
		},

		cursor = {
			cur_node = nil,
			cur_scope = nil,
			cur_region = nil,
		},


		-- meta in global
		root_scope = nil,
		define_dict = nil,
		scope_list = nil,
		region_list = nil,
		ident_list = nil,

	}
	return nEnv
end

function tlenv.create_file_env(vGlobalEnv, vSubject, vFileName)
	local nFileEnv = tlenv.FileEnv(vSubject, vFileName)
	-- bind globalenv with fileenv
	setmetatable(nFileEnv, {__index=vGlobalEnv})
	vGlobalEnv.file_env_dict[vFileName] = nFileEnv
	return nFileEnv
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
		parent_scope_refer = vCurScope and vCurScope.scope_refer,
	}
	vFileEnv.scope_list[nNewIndex] = nNextScope
	-- if vCurScope then
		-- vCurScope[#vCurScope + 1] = nNextScope
	-- end
	return nNextScope
end

function tlenv.create_region(vFileEnv, vParentRegion, vCurScope, vNode)
	local nRegion = tlenv.create_scope(vFileEnv, vCurScope, vNode)
	nRegion.sub_tag = "Region"
	nRegion.region_refer = nRegion.scope_refer
	nRegion.auto_stack  = {}
	nRegion.child_refer_list = {}
	if nRegion.region_refer ~= tlenv.G_REGION_REFER then
		vParentRegion.child_refer_list[#vParentRegion.child_refer_list + 1] = nRegion.region_refer
		nRegion.parent_region_refer = vParentRegion.region_refer
	else
		nRegion.parent_region_refer = false
	end
	return nRegion
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

--@(FileEnv, integer, integer, AstNode)
function tlenv.update_cursor(vFileEnv, vRegionRefer, vScopeRefer, vAstNode)
	local nCursor = vFileEnv.cursor
	nCursor.cur_scope = vFileEnv.scope_list[vScopeRefer]
	nCursor.cur_region = vFileEnv.region_list[vRegionRefer]
	nCursor.cur_node = vAstNode
end

function tlenv.reset_cursor(vFileEnv)
	local nCursor = vFileEnv.cursor
	nCursor.cur_scope = vFileEnv.scope_list[tlenv.G_SCOPE_REFER]
	nCursor.cur_region = vFileEnv.region_list[tlenv.G_REGION_REFER]
	nCursor.cur_node = vFileEnv._G_node
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
