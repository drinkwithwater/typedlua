--[[
This file implements Interface parsing before type checker
--!cz
]]

local tlst = require "typedlua.tlst"
local tlvisitor = require "typedlua.tlvisitor"
local tltype = require "typedlua.tltype"
local tlutils = require "typedlua.tlutils"

local tlparser = require "typedlua.tlparser"
local tldparser = require "typedlua.tldparser"

local seri = require "typedlua.seri"
local tldefine = {}

local unpack = table.unpack
local defineerror = function(env, node, msg)
  local tag = node.tag
  local l, c = node.l or 0, node.c or 0
  local error_msg = { tag = tag, filename = env.filename, msg = msg, l = l, c = c }
  for i, v in ipairs(env.messages) do
    if l < v.l or (l == v.l and c < v.c) then
      table.insert(env.messages, i, error_msg)
      return
    end
  end
  table.insert(env.messages, error_msg)
end

local visitor_before = {
	Interface = function(visitor, stm)
		local name, t, is_local = stm[1], stm[2], stm.is_local
		if is_local then
			return
		end
		visitor.definePosition = stm.pos
	end,
	TVariable = function(visitor, t)
		if visitor.definePosition then
			tltype.setGlobalVariable(t, visitor.env, visitor.definePosition, defineerror)
		end
	end,
	-- TODO
	TSelf = function(visitor, t)
		local pos = visitor.definePosition
		if not pos then
			-- not in interface scope
			return
		end
		local env = visitor.env
		local stack = visitor.stack
		local checkFunction = false
		local errorMsg = nil
		for i=#stack, 1, -1 do
			local curNode = stack[i]
			if curNode.tag == "Interface" then
				break
			elseif curNode.tag == "TFunction" then
				if checkFunction then
					errorMsg = "self type appearing in deep function scope"
					break
				else
					checkFunction = true
					local inputNode = curNode[1]
					local outputNode = curNode[2]
					local subNode = stack[i + 1]
					if inputNode == subNode then
						if t ~= inputNode[1] then
							errorMsg = "self type appearing in a place that is not a first parameter or a return type inside type"
							break
						end
					end
				end
			end
		end
		if errorMsg then
			defineerror(env, t, errorMsg)
		end
	end,
}

local visitor_after = {
	Interface = function(visitor, stm)
		local name, t, is_local = stm[1], stm[2], stm.is_local
		if stm.is_local then
			return
		end
		if visitor.env.interface[name] then
			-- local bold_token = "'%s'"
			local msg = "attempt to redeclare interface '%s'"
			msg = string.format(msg, name)
			defineerror(visitor.env, stm, msg)
		else
			t.name = name
			visitor.env.interface[name] = t
		end
		visitor.definePosition = false
	end,
}

function tldefine.create_visitor(env)
	local visitor = {
		env = env,
		before = visitor_before,
		after = visitor_after,
		override = {},
		definePosition = false,
	}

	return visitor
end

function tldefine.defineAll(global_env)
	local ast = global_env.ast
	local visitor = tldefine.create_visitor(global_env)
	tlvisitor.visit(ast, visitor)
	for name, loadedInfo in pairs(global_env.loadedInfo) do
		tlvisitor.visit(loadedInfo.ast, visitor)
	end
	return visitor
end

return tldefine