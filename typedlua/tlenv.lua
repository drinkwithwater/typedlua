--[[
This module implements some env setting
]]

local tlast = require "typedlua/tlast"
local tltPrime = require "typedlua/tltPrime"
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
	local nNode= tlast.ident(0, "_G")
	nNode.l=0
	nNode.c=0
	nNode.type = tltPrime
	nNode.ident_refer = tlenv.G_IDENT_REFER

	local nGlobalEnv = {
		main_filename = vMainFileName,
		file_env_dict = {},
		interface_dict = {},
		env_stack = {},
		cur_env = nil,
		_G_node = nil,
		_G_ident = nil,
		scope_list = {},
		ident_list = {},
		auto_list = {},
		closure_list = {},
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

function tlenv.FileEnv(vSubject, vFileName, vAst)
	local env = {
		ast = vAst,
		subject = vSubject,
		filename = vFileName,

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
	-- if vCurScope then
		-- vCurScope[#vCurScope + 1] = nNextScope
	-- end
	return nNextScope
end

function tlenv.create_region(vFileEnv, vParentRegion, vCurScope, vNode)
	local nRegion = tlenv.create_scope(vFileEnv, vCurScope, vNode)
	nRegion.sub_tag = "Region"
	nRegion.region_refer = nRegion.scope_refer
	nRegion.upvalue_list = {}
	nRegion.invalue_list = {}
	nRegion.child_refer_list = {}
	if nRegion.region_refer ~= tlenv.G_REGION_REFER then
		vParentRegion.child_refer_list[#vParentRegion.child_refer_list + 1] = nRegion.region_refer
		nRegion.parent_refer = vParentRegion.region_refer
	else
		nRegion.parent_refer = false
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

function tlenv.dump(vFileEnv)
	return tlutils.dumpLambda(vFileEnv.root_scope, function(child)
		if child.tag == "Scope" then
			return child.node, "", nil
		else
			return child.node, nil, table.concat(child, ",")
		end
	end)
end

function tlenv.region_push_invalue(vFileEnv, vRegionRefer, vAutoType)
	local nRegion = vFileEnv.region_list[vRegionRefer]
	local nNewIndex = #nRegion.invalue_list + 1
	nRegion.invalue_list[nNewIndex] = vAutoType
	return nNewIndex
end

function tlenv.region_index(vFileEnv, vRegionRefer, vTypeRefer)
	if vTypeRefer.sub_tag == "TAutoTypeReferUp" then
	end
end

function tlenv.create_closure(vFileEnv, vRunRegionRefer, vDefineRegionRefer)
	local nDefineRegion = vFileEnv.region_list[nDefineRegionRefer]
	local nRunRegion = vFileEnv.region_list[nRunRegionRefer]
	local nClosure = {
		tag = "TClosure",
		run_region_refer = nRunRegionRefer,
		run_index = #nRunRegion.invalue_list + 1,
		length = #nDefineRegion.invalue_list,
	}
	nRunRegion.invalue_list[nClosure.index] = nClosure
	for i, nInvalue in ipairs(nDefineRegion.invalue_list) do
		if nInvalue.tag == "TFunction" then
			-- TODO
		elseif nInvalue.tag == "TTable" then
			-- TODO
		end
	end
end

--[[
function tlenv.create_closure(vFileEnv, vRegionRefer, vParentRefer)
	local nNewIndex = #vFileEnv.closure_list + 1
	local nClosure = {
		refer = nNewIndex,
		parent_refer = vParentRefer,
		region_refer = vRegionRefer,
	}
	vFileEnv.closure_list[nNewIndex] = nClosure
	return nClosure
end
]]

return tlenv
