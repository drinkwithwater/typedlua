--[[
This module implements Typed Lua parser
]]


local lpeg = require "lpeg"
lpeg.locale(lpeg)

local tlast = require "typedlua.tlast"
local tllexer = require "typedlua.tllexer"
local tlutils = require "typedlua.tlutils"

local tltSyntax = {}

function tltSyntax.capture_deco(vAllSubject, vNextPos, vContext, vStartPos, vDecoSubject)
	local nSubContext = tllexer.create_context(vContext.env, vStartPos)
	local nDecoList = false -- lpeg.match(mDecoPattern, vDecoSubject, nil, nSubContext)
	if nDecoList then
		return true, nDecoList
	else
		vContext.ffp = vStartPos + nSubContext.ffp - 1
		vContext.sub_context = nSubContext
		return false
	end
end

function tltSyntax.capture_define_chunk(vAllSubject, vNextPos, vContext, vStartPos, vDefineSubject)
	local nFileEnv = vContext.env
	local nSubContext = tllexer.create_context(nFileEnv, vStartPos)
	local nDefineList = false -- lpeg.match(mChunkPattern, vDefineSubject, nil, nSubContext)
	if nDefineList then
		for i, nDefineNode in ipairs(nDefineList) do
			local nFindInterface = nFileEnv.define_dict[nDefineNode.name]
			if not nFindInterface then
				nFileEnv.define_dict[nDefineNode.name] = nDefineNode
			else
				vContext.ffp = vStartPos + nSubContext.ffp - 1
				vContext.sub_context = nSubContext
				nSubContext.semantic_error = "name conflict"
				return false
			end
		end
		return true
	else
		vContext.ffp = vStartPos + nSubContext.ffp - 1
		vContext.sub_context = nSubContext
		return false
	end
end

function tltSyntax.parse_deco(vFileEnv, vSubject)
	error("TODO")
  local nContext = tllexer.create_context(vFileEnv)
  lpeg.setmaxstack(1000)
  return lpeg.match(mDecoPattern, vSubject, nil, nContext)
end

function tltSyntax.parse_define_chunk(vFileEnv, vSubject)
	error("TODO")
  local nContext = tllexer.create_context(vFileEnv)
  lpeg.setmaxstack(1000)
  return lpeg.match(mChunkPattern, vSubject, nil, nContext)
end

function tltSyntax.parse_test(vFileEnv, vSubject)
  local nContext = tllexer.create_context(vFileEnv)
  lpeg.setmaxstack(1000)
  return lpeg.match(mTestPattern, vSubject, nil, nContext)
end

return tltSyntax
