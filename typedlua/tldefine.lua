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
local defineerror = function(env, tag, msg, pos)
  local function lineno (s, i)
    if i == 1 then return 1, 1 end
    local rest, num = s:sub(1,i):gsub("[^\n]*\n", "")
    local r = #rest
    return 1 + num, r ~= 0 and r or 1
  end

  local l, c = lineno(env.subject, pos)
  local error_msg = { tag = tag, filename = env.filename, msg = msg, l = l, c = c }
  for i, v in ipairs(env.messages) do
    if l < v.l or (l == v.l and c < v.c) then
      table.insert(env.messages, i, error_msg)
      return
    end
  end
  table.insert(env.messages, error_msg)
end

local function get_interface (env, name, pos)
  local t = tlst.get_interface(env, name)
  if not t then
    return tltype.GlobalVariable(env, name, pos, defineerror)
  else
    return t
  end
end

local function visit_require(visitor, arg)
    arg = string.gsub(arg, '%.', '/')
	local env = visitor.env
	if not env.loaded[arg] then
		print("requiring:", arg)
		local path = package.path
		local fileName, errormsg  = assert(tlutils.searchpath(arg, path))
		local subject = tlutils.getcontents(fileName)
		local ast, error_msg = assert(tlparser.parse(subject, fileName, env.strict, env.integer))
		print("finish requiring:", arg)
		tlvisitor.visit(ast, visitor)
		env.loaded[arg] = true
		for name, _ in pairs(visitor.requireSet) do
			visit_require(visitor, name)
		end
	end
end

function tldefine.create_visitor(env)
	local visitor = {
		env=env,
		before = {
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
					defineerror(env, "self", errorMsg, pos)
				end
			end,
		},
		after = {
			-- TODO deal with case if "local sth = require  sth("balabala")"
			Call=function(visitor, stm)
			  local caller = stm[1]
			  if caller.tag ~= "Index" then
				  return
			  end
			  local caller1 = caller[1]
			  local caller2 = caller[2]
			  if caller1.tag ~= "Id" or caller1[1] ~= "_ENV" then
				  return
			  end
			  if caller2.tag ~= "String" or caller2[1] ~= "require" then
				  return
			  end
			  if caller2[1] ~= "require" then
				  return
			  end
			  local callee = stm[2]
			  if callee.tag ~= "String" then
				  return
			  end
			  --
			  -- print("require statement", caller2[1], callee[1])
			  visitor.requireSet[callee[1]] = true
			end,
			Interface = function(visitor, stm)
				local name, t, is_local = stm[1], stm[2], stm.is_local
				if stm.is_local then
					return
				end
				if tlst.get_interface(visitor.env, name) then
					-- local bold_token = "'%s'"
					local msg = "attempt to redeclare interface '%s'"
					msg = string.format(msg, name)
					defineerror(visitor.env, "alias", msg, stm.pos)
				else
					t.name = name
					tlst.set_interface(env, name, t, false)
				end
				visitor.definePosition = false
			end,
		},
		override = {},
		requireSet = {},
		definePosition = false,
	}

	return visitor
end

function tldefine.define(ast, subject, filename, strict, color)
	local env = tlst.new_env(subject, filename, strict, color)
	if integer and _VERSION == "Lua 5.3" then
		env.integer = true
		tltype.integer = true
	end
	local visitor = tldefine.create_visitor(env)
	tlvisitor.visit(ast, visitor)
	for name, _ in pairs(visitor.requireSet) do
		visit_require(visitor, name)
	end
	for k,v in pairs(env.interface) do
		print(k, tlutils.dumptype(v))
		-- print(k, seri(v))
	end
	local error_msg = tldefine.error_msgs(env.messages, false, false, false)
	if error_msg then
		print(error_msg)
	end
end

function tldefine.error_msgs (messages, warnings, color, line_preview)
  assert(type(messages) == "table")
  assert(type(warnings) == "boolean")
  local l = {}
  local msg = color and acolor.bold .. "%s:%d:%d:" .. acolor.reset .. " %s, %s" or "%s:%d:%d: %s, %s"
  local skip_error = { any = true,
    mask = true,
    unused = true,
  }
  local n = 0
  for _, v in ipairs(messages) do
    local tag = v.tag
    if skip_error[tag] then
      if warnings then
        local warning_text = color and acolor.magenta .. "warning" .. acolor.reset or "warning"
        table.insert(l, string.format(msg, v.filename, v.l, v.c, warning_text, v.msg))
        if line_preview then
          table.insert(l, get_source_line(v.filename, v.l))
          table.insert(l, get_source_arrow(v.c, color, true))
        end
      end
    else
      local error_text = color and acolor.red .. "type error" .. acolor.reset or "type error"
      table.insert(l, string.format(msg, v.filename, v.l, v.c, error_text, v.msg))
      if line_preview then
        table.insert(l, get_source_line(v.filename, v.l))
        table.insert(l, get_source_arrow(v.c, color, false))
      end
      n = n + 1
    end
  end
  if #l == 0 then
    return nil, n
  else
    return table.concat(l, "\n"), n
  end
end

return tldefine
