--[[
This module implements a type checker,
use a way similar to BFS to visit each function block recursively.

in the case like:
"""
local t = {}

function t.dosth()
	t.data = "jlfkdsfjds"
end

t.data = 321

t.dosth()

"""
We can't get the right type of t.data if we visit block in "function t.dosth" before we visit "t.data = 321".
So I use a breadth-first way to solve this problem: finishing visiting all the statement outside each function's block before visiting a function's block.
]]
local tlvisitor = require "typedlua/tlvisitor"
local tlutils = require "typedlua/tlutils"
local tltype = require "typedlua/tltype"
local tltAuto = require "typedlua/tltAuto"
local tltRelation = require "typedlua/tltRelation"
local tltable = require "typedlua/tltable"
local tltOper = require "typedlua/tltOper"
local tlenv = require "typedlua/tlenv"

local Nil = tltype.Nil()
local Boolean = tltype.Boolean()
local Number = tltype.Number()
local String = tltype.String()

local visitor_meta = {}

local tlvBreadth = {}

-- TODO use duck type....
function visitor_meta.oper_auto_call(visitor, vType, vArgTuple)
	local nFunctionType = visitor:link_refer_type(vType)
	assert(nFunctionType.sub_tag == "TFunctionAuto")
	if nFunctionType.auto_solving_state == tltAuto.AUTO_SOLVING_START then
		visitor:log_error("function auto solving loop...")
		return tltype.VarTuple(tltype.Any())
	else
		-- maybe function is not visited, because node was breadth-first visited.
		-- so visit without breadth
		if nFunctionType.auto_solving_state == tltAuto.AUTO_SOLVING_IDLE then
			local nScope = visitor.env.scope_list[nFunctionType.own_region_refer]
			tlvBreadth.visit_region(visitor.env, nScope.node)
		end
		return tlenv.function_call(visitor.env, visitor.region_stack[#visitor.region_stack], nFunctionType)
	end
end

function visitor_meta.cast_auto(visitor, vLeftType, vAutoLink)
	local nRegionRefer = visitor.region_stack[#visitor.region_stack]
	if vAutoLink.link_region_refer ~= nRegionRefer then
		visitor:log_error("can't finish auto from out region")
		return false
	end
	local nRegion = visitor.env.region_list[nRegionRefer]
	local nRightType = nRegion.auto_stack[vAutoLink.link_index]
	local nLeftType = visitor:link_refer_type(vLeftType)
	if nRightType.tag == "TAutoType" and nRightType.sub_tag == "TTableAuto" then
		local nLeftTableType
		if nLeftType.tag == "TTable" then
			nLeftTableType = nLeftType
		elseif nLeftType.tag == "TDefineType" and nLeftType[1].tag == "TTable" then
			nLeftTableType = nLeftType[1]
		else
			visitor:log_error("cast_auto type unexception type when table, info TODO")
			return false
		end
		-- 1. check sub autolink field
		for i, nField in ipairs(nRightType[1]) do
			if nField[2].tag == "TAutoLink" then
				assert(nField[1].tag == "TLiteral", "auto link in unliteral field")
				local nLeftField = tltable.index_field(nLeftTableType, nField[1])
				if not nLeftField then
					visitor:log_error("finish auto fail for field", tltype.tostring(nField[1]))
					return false
				end
				if not visitor:cast_auto(nLeftField[2], nField[2]) then
					visitor:log_error("recursive finish auto fail for field", tltype.tostring(nField[1]))
					return false
				end
			end
		end
		print("TODO check other field")
	elseif nRightType.tag == "TAutoType" and nRightType.sub_tag == "TFunctionAuto" then
		local nLeftFunctionType
		if nLeftType.tag == "TFunction" then
			nLeftTableType = nLeftType
		elseif nLeftType.tag == "TDefineType" and nLeftType[1].tag == "TFunction" then
			nLeftTableType = nLeftType[1]
		else
			visitor:log_error("cast_auto type unexception type when function, info TODO")
			return false
		end
		if nRightType.auto_solving_state ~= tltAuto.AUTO_SOLVING_IDLE then
			visitor:log_error("finish auto fail because function is not idle")
			return false
		end
	else
		visitor:log_error("cast_auto type unexception", nLeftType.tag, nRightType.tag, nRightType.sub_tag)
		return false
	end
	nRightType[2] = nRightType[1]
	nRightType[1] = vLeftType
	nRightType.sub_tag = "TCastAuto"
	return true
end

function visitor_meta.link_refer_type(visitor, vType)
	if vType.tag == "TDefineRefer" then
		return visitor.env.define_dict[vType.name]
	elseif vType.tag == "TAutoLink" then
		local nRegionRefer = visitor.region_stack[#visitor.region_stack]
		local nRegion = visitor.env.region_list[nRegionRefer]
		while nRegion.region_refer ~= vType.link_region_refer do
			nRegion = visitor.env.region_list[nRegion.parent_refer]
		end
		local nAutoType = nRegion.auto_stack[vType.link_index]
		if nAutoType.sub_tag == "TCastAuto" then
			return visitor:link_refer_type(nAutoType[1])
		else
			return nAutoType
		end
	else
		return vType
	end
end

function visitor_meta.log_error (visitor, ...)
	local filename = visitor.env.filename
	local node = visitor.stack[#visitor.stack]
	local head = string.format("%s:%d:%d:[ERROR]", filename, node.l, node.c)
	print(head, ...)
end

function visitor_meta.log_warning(visitor, ...)
	local filename = visitor.env.filename
	local node = visitor.stack[#visitor.stack]
	local head = string.format("%s:%d:%d:[WARNING]", filename, node.l, node.c)
	print(head, ...)
end

function visitor_meta.log_wany(visitor, ...)
	local filename = visitor.env.filename
	local node = visitor.stack[#visitor.stack]
	local head = string.format("%s:%d:%d:[WANY]", filename, node.l, node.c)
	print(head, ...)
end

-- expr add type, check right_deco
local function add_type(visitor, node, t)
	--[[ do nothing...
	local nRightDeco = node.right_deco
	if nRightDeco then
		if not tltRelation.sub(t, nRightDeco) then
			log_error(visitor, node, t.tag, "is not", nRightDeco.tag)
		end
	end]]
	if node.type then
		visitor:log_error("add type but node.type existed", node.type.tag, t.tag)
	else
		node.type = t
	end
end

local visitor_stm = {
	Forin={
		override=function(visitor, vForinNode, vNodeVisit, vSelfVisit)
			vNodeVisit(visitor, vForinNode[2])
			local nNextTableInitTuple = tltOper._reforge_tuple(visitor, vForinNode[2])
			-- next, {}, nil
			local nFunctionType = tltype.tuple_index(nNextTableInitTuple, 1)
			local nArgTuple = tltype.tuple_sub(nNextTableInitTuple, 2)
			local nForinTuple = tltOper._call(visitor, nFunctionType, nArgTuple)
			vNodeVisit(visitor, vForinNode[1])
			for i, nNameNode in ipairs(vForinNode[1]) do
				local nRightType = tltype.tuple_index(nForinTuple, i)
				nNameNode.type = tltOper._init_assign(visitor, nRightType) --, nNameNode.deco_type)
			end
			vNodeVisit(visitor, vForinNode[3])
		end
	},
	Fornum={
		override=function(visitor, node, visit_node, self_visit)
			for i = 1, #node - 1 do
				local nSubNode = node[i]
				visit_node(visitor, nSubNode)
			end
			-- oper subNode 1
			local nNameNode = node[1]
			nNameNode.type = tltOper._init_assign(visitor, tltype.Number())

			-- oper subNode 2, 3,..., #node-1
			for i = 2, #node - 1 do
				local nSubNode = node[i]
				tltOper._fornum(visitor, nSubNode, nSubNode.type)
			end
			visit_node(visitor, node[#node])
		end,
	},
	Set={
		after=function(visitor, node)
			local nVarList = node[1]
			local nTupleType = tltOper._reforge_tuple(visitor, node[2])
			for i, nVarNode in ipairs(nVarList) do
				local nRightType = tltype.tuple_index(nTupleType, i)
				if nVarNode.tag == "Index" then
					tltOper._index_set(visitor, nVarNode[1].type, nVarNode[2].type, nRightType, nVarNode.deco_type)
				elseif nVarNode.tag == "Id" then
					tltOper._set_assign(visitor, nVarNode.type, nRightType, nVarNode.deco_type)
					-- local nIdent = visitor.env.ident_list[nVarNode.ident_refer]
					-- TODO merge namenode??????????????????
					-- oper_merge(visitor, nIdent, nWrapper)
				else
					error("assign to node:tag="..tostring(node.tag))
				end
			end
		end,
	},
	Localrec={
		after=function(visitor, vLocalrecNode)
			local nNameNode = vLocalrecNode[1][1]
			local nExprNode = vLocalrecNode[2][1]

			nNameNode.type = tltOper._init_assign(visitor, nExprNode.type, nNameNode.deco_type)
		end,
	},
	Local={
		after=function(visitor, node)
			local nNameList = node[1]
			local nTupleType = tltOper._reforge_tuple(visitor, node[2])
			for i, nNameNode in ipairs(nNameList) do
				local nRightType = tltype.tuple_index(nTupleType, i)
				nNameNode.type = tltOper._init_assign(visitor, nRightType, nNameNode.deco_type)
			end
		end,
	},
	Return={
		after=function(visitor, node)
			-- TODO case for none return block
			local nTupleType = tltOper._reforge_tuple(visitor, node[1])
			for i=#visitor.stack, 1, -1 do
				local nPreNode = visitor.stack[i]
				if nPreNode.tag == "Function" then
					tltOper._return(visitor, nPreNode, nTupleType)
					return
				end
			end
			print("file return TODO")
		end
	}
}

local visitor_exp = {
	-- literal
	Nil={
		before=function(visitor, node)
			add_type(visitor, node, tltype.Nil())
		end,
	},
	True={
		before=function(visitor, node)
			add_type(visitor, node, tltype.Literal(true))
		end,
	},
	False={
		before=function(visitor, node)
			add_type(visitor, node, tltype.Literal(false))
		end,
	},
	Number={
		before=function(visitor, node)
			add_type(visitor, node, tltype.Literal(node[1]))
		end,
	},
	String={
		before=function(visitor, node)
			add_type(visitor, node, tltype.Literal(node[1]))
		end,
	},

	Function={
		before=function(visitor, vFunctionNode)
			visitor.region_stack[#visitor.region_stack + 1] = assert(vFunctionNode.region_refer)
		end,
		override=function(visitor, vFunctionNode, visit_node, self_visit)
			-- if #stack == 1 then visit function in an isolating stack
			if #visitor.stack == 1 then
				local nFunctionType = vFunctionNode.type
				nFunctionType = visitor:link_refer_type(nFunctionType)
				-- breadth visit
				if nFunctionType.sub_tag == "TFunctionAuto" then
					assert(nFunctionType.auto_solving_state == tltAuto.AUTO_SOLVING_IDLE)
					-- add any for default
					local nTypeList = {}
					local nParList = vFunctionNode[1]
					local nHasDots = false
					for k, nIdentNode in ipairs(nParList) do
						-- TODO fill default with duck type
						nIdentNode.deco_type = tltype.Any()
						nTypeList[k] = tltype.Any()
						if nIdentNode.tag == "Dots" then
							assert(k == #nParList)
							nIdentNode.deco_type = tltype.VarTuple(tltype.Any())
							nHasDots = true
						end
					end
					if nHasDots then
						nFunctionType[1][1] = tltype.VarTuple(table.unpack(nTypeList))
					else
						nFunctionType[1][1] = tltype.Tuple(table.unpack(nTypeList))
					end
					-- if auto function and idle, change state and visit
					nFunctionType.auto_solving_state = tltAuto.AUTO_SOLVING_START
					self_visit(visitor, vFunctionNode)
					-- TODO solving all auto type in this region when function visit end
					nFunctionType.auto_solving_state = tltAuto.AUTO_SOLVING_FINISH
				else
					if nFunctionType.tag == "TDefineType" then
						nFunctionType = nFunctionType[1]
					end
					assert(nFunctionType.tag == "TFunction", "function but not function type")
					-- deco input parameter
					local nInputTuple = nFunctionType[1]
					local nParList = vFunctionNode[1]
					for k, nIdentNode in ipairs(nParList) do
						if nIdentNode.tag == "Dots" then
							local nDecoTuple = tltype.tuple_sub(nInputTuple, k)
							if nDecoTuple.sub_tag ~= "TVarTuple" then
								if #nDecoTuple <= 0 then
									visitor:log_error("dots empty ...")
								else
									visitor:log_warning("dots but not vartuple ...")
								end
							end
							nIdentNode.deco_type = nDecoTuple
						elseif nIdentNode.tag == "Id" then
							local nDecoType = tltype.tuple_index(nInputTuple, k)
							if not nDecoType then
								nDecoType = tltype.Any()
								visitor:log_error("arguments length and deco inputtuple not match")
							end
							nIdentNode.deco_type = nDecoType
						else
							visitor:log_error("unexcept branch when function deco parlist")
						end
					end
					-- if not auto function or auto finish
					self_visit(visitor, vFunctionNode)
				end
			-- if #stack > 1 then visit function in parent's stack
			-- create FunctionAuto right now but visit when it's called or by breadth
			else
				-- auto deco for parameter
				local nOwnRegionRefer = vFunctionNode.region_refer
				local nFunctionAuto = tltAuto.FunctionAuto(nOwnRegionRefer)
				local nParentRefer = visitor.env.region_list[nOwnRegionRefer].parent_refer
				local nAutoLink = tlenv.region_push_auto(visitor.env, nParentRefer, nFunctionAuto)
				-- if static, cast when assign
				vFunctionNode.type = nAutoLink
				visitor.breadth_region_node_list[#visitor.breadth_region_node_list + 1] = vFunctionNode
			end
		end,
		after=function(visitor, vFunctionNode)
			visitor.region_stack[#visitor.region_stack] = nil
		end,
	},
	Table={
		after=function(visitor, vTableNode)
			local nRecordFieldDict = {} -- {key=var1}
			local nHashFieldList = {} -- {[var1]=var2}
			local nArrayTypeList = {} -- {1,2,3}
			for i, nSubNode in ipairs(vTableNode) do
				if nSubNode.tag == "Pair" then
					local nKeyType = nSubNode[1].type
					local nField = tltable.Field(nKeyType, nSubNode[2].type)
					if nKeyType.tag == "TLiteral" then
						if nRecordFieldDict[nKeyType[1]] then
							visitor:log_warning("same record key in table constructor")
						end
						nRecordFieldDict[nKeyType[1]] = nField
					else
						nHashFieldList[#nHashFieldList + 1] = nField
					end
				elseif nSubNode.tag == "Dots" or nSubNode.tag == "Call" or nSubNode.tag == "Invoke" then
					if i < #vTableNode then
						if nSubNode.type.tag == "TTuple" then
							nArrayTypeList[#nArrayTypeList + 1] = tltype.first(nSubNode.type)
							visitor:log_warning("TTuple isn't last element in table constructor")
						else
							nArrayTypeList[#nArrayTypeList + 1] = nSubNode.type
						end
					else
						local nFinalTuple = nSubNode.type
						assert(nFinalTuple.tag == "TTuple")
						if nFinalTuple.sub_tag == "TVarTuple" then
							for j=1, #nFinalTuple - 1 do
								nArrayTypeList[#nArrayTypeList + 1] = nFinalTuple[j]
							end
							nHashFieldList[#nHashFieldList + 1] =
									tltable.Field(tltype.Integer(), nFinalTuple[#nFinalTuple])
						else
							for i, nType in ipairs(nFinalTuple) do
								nArrayTypeList[#nArrayTypeList + 1] = nType
							end
						end
					end
				else
					nArrayTypeList[#nArrayTypeList + 1] = nSubNode.type
				end
			end

			local nFieldList = {}
			local nTableConstructor = tltable.TableConstructor()
			if #nHashFieldList == 0 then
				-- insert record field
				for nRecordKey, nRecordField in pairs(nRecordFieldDict) do
					if nArrayTypeList[nRecordKey] then
						visitor:log_error("table constructor confliction in record key")
					else
						tltable.insert(nTableConstructor, nRecordField)
					end
				end
				-- insert array record field
				for i, nType in ipairs(nArrayTypeList) do
					local nField = tltable.Field(tltype.Literal(i), nType)
					tltable.insert(nTableConstructor, nField)
				end
			else
				-- insert hash field
				for i, nHashField in ipairs(nHashFieldList) do
					if tltable.index_field(nTableConstructor, nHashField[1]) then
						visitor:log_error("table construct confliction in hash key")
					else
						tltable.insert(nTableConstructor, nHashField)
					end
				end
				-- insert record field
				for nRecordKey, nRecordField in pairs(nRecordFieldDict) do
					local nFindField = tltable.index_field(nTableConstructor, nRecordField[1])
					if nFindField then
						visitor:log_error("table construct confliction between hash key and record key")
					elseif nArrayTypeList[nRecordKey] then
						visitor:log_error("table construct confliction between record key and array key")
					else
						tltable.insert(nTableConstructor, nRecordField)
					end
				end
				-- insert array record field
				if #nArrayTypeList > 0 and tltable.index_field(nTableConstructor, tltype.Literal(1)) then
					visitor:log_error("table construct confliction between hash key and array key")
				else
					for i, nType in ipairs(nArrayTypeList) do
						local nField = tltable.Field(tltype.Literal(i), nType)
						tltable.insert(nTableConstructor, nField)
					end
				end
			end

			local nRegionRefer = visitor.region_stack[#visitor.region_stack]
			local nTableAuto = tltAuto.TableAuto(nTableConstructor)
			local nAutoLink = tlenv.region_push_auto(visitor.env, nRegionRefer, nTableAuto)

			add_type(visitor, vTableNode, nAutoLink)

		end,
	},
	Op={
		after=function(visitor, vNode)
			local nOP = vNode[1]
			if #vNode== 3 then
				local nOper = tltOper["__"..nOP] or tltOper["_"..nOP]
				vNode.type = nOper(visitor, vNode[2].type, vNode[3].type)
			elseif #vNode == 2 then
				local nOper = tltOper["__"..nOP] or tltOper["_"..nOP]
				vNode.type = nOper(visitor, vNode[2].type)
			else
				error("exception branch")
			end
		end,
	},
	Paren={
		after=function(visitor, vNode)
			vNode.type = tltype.first(vNode[1].type)
		end,
	},
	Id={
		before=function(visitor, node)
			local ident = visitor.env.ident_list[node.ident_refer]
			if node == ident.node then
				-- ident set itself
				if node.deco_type then
					node.type = node.deco_type
				end
			else
				-- ident get
				node.type = ident.node.type
			end
		end
	},
	Index={
		after=function(visitor, vIndexNode)
			local nParentNode = visitor.stack[#visitor.stack - 1]
			if nParentNode and nParentNode.tag == "VarList" then
				-- set index
				-- pass
			else
				vIndexNode.type = tltOper._index_get(visitor, vIndexNode[1].type, vIndexNode[2].type)
			end
		end,
	},
	-- exp may be tuple: call, invoke, dots
	Call={
		after=function(visitor, vCallNode)
			-- auto parsing, parsing function when it's called
			local nTuple = tltOper._reforge_tuple(visitor, vCallNode[2])
			local nReturnTuple = tltOper._call(visitor, vCallNode[1].type, nTuple)
			local nParentNode = visitor.stack[#visitor.stack - 1]
			if nParentNode and (nParentNode.tag == "ExpList" or nParentNode.tag == "Pair") then
				-- will reforge tuple
				vCallNode.type = nReturnTuple
			elseif nParentNode and (nParentNode.tag == "Block" or nParentNode.tag == "Chunk") then
				-- just ignore tuple
				vCallNode.type = nReturnTuple
			else
				-- will not be tuple
				vCallNode.type = tltype.first(nReturnTuple)
			end
		end
	},
	Invoke={
		after=function(visitor, node)
			error("func invoke TODO")
		end
	},
	Dots={
		after=function(visitor, vDotsNode)
			local nParentNode = visitor.stack[#visitor.stack - 1]
			local nIdent = visitor.env.ident_list[vDotsNode.ident_refer]
			if nIdent.node == vDotsNode then
				-- dot define
				if vDotsNode.deco_type then
					vDotsNode.type = vDotsNode.deco_type
				end
				assert(vDotsNode.type.tag == "TTuple")
			else
				if nParentNode and (nParentNode.tag == "ExpList" or nParentNode.tag == "Table") then
					vDotsNode.type = nIdent.node.type
				else
					vDotsNode.type = tltype.first(nIdent.node.type)
				end
			end
		end
	},
	Chunk={
		before=function(visitor, vChunkNode)
			visitor.region_stack[#visitor.region_stack + 1] = assert(vChunkNode.region_refer)
		end,
		after=function(visitor, node)
			visitor.region_stack[#visitor.region_stack] = nil
		end
	},
}


local visitor_object_dict = tlvisitor.concat(visitor_stm, visitor_exp)

function tlvBreadth.visit_region(vFileEnv, vRegionNode)
	assert(vRegionNode.tag == "Function" or vRegionNode.tag == "Chunk")
	if vRegionNode.breadth_visited then
		return
	end
	vRegionNode.breadth_visited = true
	local visitor = setmetatable({
		object_dict = visitor_object_dict,
		region_stack = {tlenv.G_SCOPE_REFER},
		breadth_region_node_list = {},
		env = vFileEnv,
	}, {
		__index=visitor_meta,
	})
	local nRegionNodeList = visitor.breadth_region_node_list
	tlvisitor.visit_obj(vRegionNode, visitor)
	for _, nSubRegionNode in ipairs(nRegionNodeList) do
		-- TODO don't implement function first
		-- visitor.region_stack[#visitor.region_stack + 1] = nSubRegionNode.region_refer
		tlvBreadth.visit_region(vFileEnv, nSubRegionNode)
		-- visitor.region_stack[#visitor.region_stack] = nil
	end
end

function tlvBreadth.visit(vFileEnv)
	tlvBreadth.visit_region(vFileEnv, vFileEnv.ast)
	--[[
	local seri = require "typedlua.seri"
	for k, nScope in ipairs(vFileEnv.scope_list) do
		if nScope.sub_tag == "Region" then
			print(k, seri(nScope.auto_stack))
		end
	end]]
end

return tlvBreadth
