--[[
This module implements some env setting
]]

local tlast = require "typedlua/tlast"
local tltype = require "typedlua/tltype"
local tltAuto = require "typedlua/tltAuto"
local tltable = require "typedlua/tltable"
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
	local nNode = tlast.ident(0, "_G")
	nNode.l=0
	nNode.c=0
	-- nNode.type = tltPrime
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

	-- put _G as auto type
	nNode.type = tlenv.region_push_auto(nGlobalEnv, tlenv.G_REGION_REFER, tltPrime)


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
	nRegion.auto_stack  = {}
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

function tlenv.region_push_auto(vFileEnv, vRegionRefer, vAutoType)
	local nRegion = vFileEnv.region_list[vRegionRefer]
	local nNewIndex = #nRegion.auto_stack + 1
	nRegion.auto_stack[nNewIndex] = vAutoType
	vAutoType.def_region_refer = vRegionRefer
	vAutoType.def_index = nNewIndex
	vAutoType.run_region_refer = vRegionRefer
	vAutoType.run_index = nNewIndex
	return tltAuto.AutoLink(vRegionRefer, nNewIndex)
end

function tlenv.function_call(vFileEnv, vRunRegionRefer, vFunctionType)
	local nRunRegion = vFileEnv.region_list[vRunRegionRefer]
	local nFunctionOwnRegion = vFileEnv.region_list[vFunctionType.own_region_refer]
	local nClosureIndex = #nRunRegion.auto_stack + 1
	local nClosure = {
		tag = "TClosure",
		own_region_refer = vFunctionType.own_region_refer,
		def_region_refer = vRunRegionRefer,
		def_index = nClosureIndex,
		run_region_refer = vRunRegionRefer,
		run_index = nClosureIndex,
		length = #nFunctionOwnRegion.auto_stack,
		caller_auto_link = tltAuto.AutoLink(vFunctionType.run_region_refer, vFunctionType.run_index),
	}
	nRunRegion.auto_stack[nClosureIndex] = nClosure
	for i, nAutoType in ipairs(nFunctionOwnRegion.auto_stack) do
		local nNewIndex = #nRunRegion.auto_stack + 1
		local nCopyType = nil
		if nAutoType.tag == "TFunction" then
			nCopyType = tlenv.closure_copy_function(vFileEnv, nClosure, nAutoType)
		elseif nAutoType.tag == "TTable" then
			nCopyType = tlenv.closure_copy_table(vFileEnv, nClosure, nAutoType)
		elseif nAutoType.tag == "TClosure" then
			nCopyType = {
				tag = "TClosure",
				def_region_refer = vRunRegionRefer,
				def_index = nNewIndex,
				length = nAutoType.length,
				caller_auto_link = tlenv.closure_relink(vFileEnv, nClosure, nAutoType.caller_auto_link),
			}
		end
		nRunRegion.auto_stack[nNewIndex] = nCopyType
		nCopyType.run_region_refer = vRunRegionRefer
		nCopyType.run_index = nNewIndex
	end
	if vFunctionType[2] then
		local nOutputTuple = tltype.Tuple()
		for i, nType in ipairs(vFunctionType[2]) do
			if nType.tag == "TAutoLink" then
				nOutputTuple[i] = tlenv.closure_relink(vFileEnv, nClosure, nType)
			else
				nOutputTuple[i] = nType
			end
		end
		return nOutputTuple
	else
		return tltype.Tuple()
	end
end

function tlenv.closure_copy_table(vFileEnv, vClosure, vAutoTable)
	local nCopyTable = tltAuto.AutoTable()
	nCopyTable.auto_solving_state = tltAuto.AUTO_SOLVING_IDLE
	nCopyTable.def_region_refer = vAutoTable.def_region_refer
	nCopyTable.def_index  = vAutoTable.def_index
	for i, nField in ipairs(vAutoTable) do
		local nFieldKey = nField[1]
		local nFieldValue = nField[2]
		if nFieldValue.tag == "TAutoLink" then
			nFieldValue = tlenv.closure_relink(vFileEnv, vClosure, nFieldValue)
		end
		nCopyTable.record_dict[nFieldKey[1]] = i
		nCopyTable[i] = tltable.Field(nFieldKey, nFieldValue)
	end
	return nCopyTable
end

function tlenv.closure_copy_function(vFileEnv, vClosure, vAutoFunction)
	local nCopyFunction = tltAuto.AutoFunction(vAutoFunction.own_region_refer, vAutoFunction[1])
	nCopyFunction.auto_solving_state = tltAuto.AUTO_SOLVING_FINISH
	nCopyFunction.def_region_refer = vAutoFunction.def_region_refer
	nCopyFunction.def_index = vAutoFunction.def_index
	-- input is static type...
	nCopyFunction[1] = vAutoFunction[1]
	if not vAutoFunction[2] then
		print("auto function nil return...")
	else
		local nOutputTuple = tltype.Tuple()
		for i, nType in ipairs(vAutoFunction[2]) do
			if nType.tag == "TAutoLink" and nType.link_region_refer ~= vAutoFunction.own_region_refer then
				nOutputTuple[i] = tlenv.closure_relink(vFileEnv, vClosure, nType)
			else
				nOutputTuple[i] = nType
			end
		end
		nCopyFunction[2] = nOutputTuple
	end
	return nCopyFunction
end

-- change link from link-stack to link-closure-from-stack
function tlenv.closure_relink(vFileEnv, vClosure, vAutoLink)
	assert(vAutoLink.tag == "TAutoLink", "closure_relink called with unexcept type:"..tostring(vAutoLink.tag))
	local nClosure = vClosure
	while (nClosure ~= nil) and (nClosure.own_region_refer ~= vAutoLink.link_region_refer) do
		local nCallerLink = nClosure.caller_auto_link
		local nCallerType = vFileEnv.region_list[nCallerLink.link_region_refer].auto_stack[nCallerLink.link_index]
		nClosure = tlenv.type_find_closure(vFileEnv, nCallerType)
	end
	local nLinkedType = nil
	if not nClosure then
		nLinkedType = vFileEnv.region_list[vAutoLink.link_region_refer].auto_stack[vAutoLink.link_index]
		-- return tltAuto.AutoLink(vAutoLink.link_region_refer, vAutoLink.link_index)
	else
		nLinkedType = tlenv.closure_index_type(vFileEnv, nClosure, vAutoLink.link_index)
		-- return tltAuto.AutoLink(nLinkedType.run_region_refer, nLinkedType.run_index)
	end
	if tltAuto.is_auto_type(nLinkedType) then
		return tltAuto.AutoLink(nLinkedType.run_region_refer, nLinkedType.run_index)
	else
		return nLinkedType
	end
end

function tlenv.closure_index_type(vFileEnv, vClosure, vIndex)
	return vFileEnv.region_list[vClosure.run_region_refer].auto_stack[vClosure.run_index + vIndex]
end

function tlenv.type_find_closure(vFileEnv, vType)
	local nClosureIndex = vType.run_index - vType.def_index
	if nClosureIndex > 0 then
		return vFileEnv.region_list[vType.run_region_refer].auto_stack[nClosureIndex]
	else
		return nil
	end
end

return tlenv
