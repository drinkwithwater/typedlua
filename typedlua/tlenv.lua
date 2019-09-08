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
		define_dict = {},
		_G_node = nil,
		_G_ident = nil,
		scope_list = {},
		ident_list = {},
		auto_list = {},
		closure_list = {},
		union_deduce_tree_list = {},
		union_deduce_list = {}
	}

	nGlobalEnv.region_list = nGlobalEnv.scope_list

	-- create and set root scope
	local nRootScope = tlenv.create_region(nGlobalEnv, nil, nil, nNode)

	-- create and bind ident
	local nIdent = tlenv.create_ident(nGlobalEnv, nRootScope, nNode)
	nRootScope.record_dict["_G"] = tlenv.G_IDENT_REFER
	nRootScope.record_dict["_ENV"] = tlenv.G_IDENT_REFER

	-- put _G as auto type
	local nGlobalAuto = tltAuto.TableAuto(tltPrime)
	nNode.type = tlenv.region_push_auto(nGlobalEnv, tlenv.G_REGION_REFER, nGlobalAuto)


	nGlobalEnv.root_scope = nRootScope
	nGlobalEnv._G_node = nNode
	nGlobalEnv._G_ident = nIdent


	return nGlobalEnv
end

function tlenv.FileEnv(vSubject, vFileName)
	local env = {
		subject = vSubject,
		filename = vFileName,
		define_dict = {},
		define_link_list = {},
		ast = nil,
		split_info_list = nil,

		-- region
		scope_list = nil,

		-- ident
		ident_list = nil,

		root_scope = nil,
	}
	return env
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
		caller_auto_link = tltAuto.AutoLink(vFunctionType.run_region_refer, vFunctionType.run_index),
	}
	nRunRegion.auto_stack[nClosureIndex] = nClosure
	for i, nAutoType in ipairs(nFunctionOwnRegion.auto_stack) do
		local nNewIndex = #nRunRegion.auto_stack + 1
		local nCopyType = nil
		if nAutoType.tag == "TAutoType" then
			if nAutoType.sub_tag == "TFunctionAuto" then
				nCopyType = tlenv.closure_copy_function(vFileEnv, nClosure, nAutoType)
			elseif nAutoType.sub_tag == "TTableAuto" then
				nCopyType = tlenv.closure_copy_table(vFileEnv, nClosure, nAutoType)
			else
				error("unexception auto sub type"..tostring(nAutoType.sub_tag))
			end
		elseif nAutoType.tag == "TClosure" then
			nCopyType = {
				tag = "TClosure",
				def_region_refer = vRunRegionRefer,
				def_index = nNewIndex,
				caller_auto_link = tlenv.closure_relink(vFileEnv, nClosure, nAutoType.caller_auto_link),
			}
		end
		nRunRegion.auto_stack[nNewIndex] = nCopyType
		nCopyType.run_region_refer = vRunRegionRefer
		nCopyType.run_index = nNewIndex
	end
	if vFunctionType[1][2] then
		local nOutputTuple = tltype.Tuple()
		for i, nType in ipairs(vFunctionType[1][2]) do
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

function tlenv.closure_copy_table(vFileEnv, vClosure, vTableAuto)
	if vTableAuto.sub_tag ~= "TTableAuto" then
		return vTableAuto
	end
	local nFieldList = {}
	for i, nField in ipairs(vTableAuto[1]) do
		local nFieldKey = nField[1]
		local nFieldValue = nField[2]
		if nFieldValue.tag == "TAutoLink" then
			nFieldValue = tlenv.closure_relink(vFileEnv, vClosure, nFieldValue)
		end
		nFieldList[i] = tltable.Field(nFieldKey, nFieldValue)
	end
	local nTableAuto = tltAuto.TableAuto(tltable.TableConstructor(table.unpack(nFieldList)))
	nTableAuto.auto_solving_state = tltAuto.AUTO_SOLVING_FINISH
	nTableAuto.def_region_refer = vTableAuto.def_region_refer
	nTableAuto.def_index  = vTableAuto.def_index
	return nTableAuto
end

function tlenv.closure_copy_function(vFileEnv, vClosure, vFunctionAuto)
	if vFunctionAuto.sub_tag ~= "TFunctionAuto" then
		return vFunctionAuto
	end
	-- input is static type...
	local nInputTuple, nOutputTuple = vFunctionAuto[1][1], vFunctionAuto[1][2]
	if not nOutputTuple then
		print("auto function nil return...")
	else
		nOutputTuple = tltype.Tuple()
		for i, nType in ipairs(vFunctionAuto[1][2]) do
			if nType.tag == "TAutoLink" and nType.link_region_refer ~= vFunctionAuto.own_region_refer then
				nOutputTuple[i] = tlenv.closure_relink(vFileEnv, vClosure, nType)
			else
				nOutputTuple[i] = nType
			end
		end
	end
	local nCopyAuto = tltAuto.FunctionAuto(
		vFunctionAuto.own_region_refer,
		tltype.FunctionConstructor(nInputTuple, nOutputTuple))
	nCopyAuto.auto_solving_state = tltAuto.AUTO_SOLVING_FINISH
	nCopyAuto.def_region_refer = vFunctionAuto.def_region_refer
	nCopyAuto.def_index = vFunctionAuto.def_index
	return nCopyAuto
end

-- change link from link-stack to link-closure-from-stack
-- used place:
-- 1. copy table, table field;
-- 2. copy function, function return;
-- 3. copy closure, closure caller;
-- 4. function call, return;
function tlenv.closure_relink(vFileEnv, vClosure, vAutoLink)
	assert(vAutoLink.tag == "TAutoLink", "closure_relink called with unexcept type:"..tostring(vAutoLink.tag))
	local nClosure = vClosure
	while nClosure and (nClosure.own_region_refer ~= vAutoLink.link_region_refer) do
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
	if nLinkedType.tag == "TAutoType" then
		if nLinkedType.sub_tag == "TCastAuto" then
			return nLinkedType[1]
		else
			return tltAuto.AutoLink(nLinkedType.run_region_refer, nLinkedType.run_index)
		end
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
