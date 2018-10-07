
local tlnode = require "typedlua.tlnode"
local tlvisitor = require "typedlua.tlvisitor"

local tlutils = {}

local function lineno (s, i)
	if i == 1 then return 1, 1 end
	local rest, num = s:sub(1,i):gsub("[^\n]*\n", "")
	local r = #rest
	return 1 + num, r ~= 0 and r or 1
end

function tlutils.logat(env, pos, msg)

  local l, c = lineno(env.subject, pos)
  print(string.format("%s:%s:%s:%s", env.filename, l, c, tostring(msg)))
end

-- dump ast node
local function dumpNode(env, astNode, bufferList, preLine)
	local line, offset = preLine, nil
	if tlnode.isType(astNode.tag) then
		bufferList[#bufferList + 1] = "["
		bufferList[#bufferList + 1] = astNode.tag
		bufferList[#bufferList + 1] = "]"
		return line
	end
	if astNode.pos then
		line, offset = lineno(env.subject, astNode.pos)
		if line ~= preLine then
			bufferList[#bufferList + 1] = "\n"
			bufferList[#bufferList + 1] = line
			bufferList[#bufferList + 1] = ":"
			bufferList[#bufferList + 1] = string.rep(" ", offset)
		end
	end
	bufferList[#bufferList + 1] = astNode.tag
	bufferList[#bufferList + 1] = "{"
	for k, v in ipairs(astNode) do
		if type(v) == "table" then
			line = dumpNode(env, v, bufferList, line)
		else
			bufferList[#bufferList + 1] = "("
			bufferList[#bufferList + 1] = v
			bufferList[#bufferList + 1] = ")"
		end
	end
	bufferList[#bufferList + 1] = "}"
	return line
end

function tlutils.dumpast(env, astNode)
	local bufferList = {}
	dumpNode(env, astNode, bufferList, 0)
	return table.concat(bufferList)
end

-- dump type
local function type_tag(visitor, node, append)
	append = (append and append.."\n") or "\n"
	local word = string.rep("\t", visitor.indent).."`"..node.tag.." "..append
	table.insert(visitor.bufferList, word)
end

local function type_scope_begin(visitor, node, append)
	append = (append and " "..append.." " ) or " "
	local word = string.rep("\t", visitor.indent).."`"..node.tag..append.."{\n"
	table.insert(visitor.bufferList, word)
	visitor.indent = visitor.indent + 1
end

local function type_scope_end(visitor, node)
	visitor.indent = visitor.indent - 1
	local word = string.rep("\t", visitor.indent).."}\n"
	table.insert(visitor.bufferList, word)
end

local visitor_before = {
	TLiteral = function(visitor, node)
		type_tag(visitor, node, tostring(node[1]))
	end,
	TBase = function(visitor, node)
		type_tag(visitor, node, node[1])
	end,
	TNil = type_tag,
	TValue = type_tag,
	TAny = type_tag,
	TSelf = type_tag,
	TVoid = type_tag,

	TVariable = function(visitor, node)
		type_tag(visitor, node, node[1])
	end,
	TGlobalVariable = function(visitor, node)
		type_tag(visitor, node, node[1])
	end,

	TUnion = type_scope_begin,
	TUnionlist = type_scope_begin,
	TFunction = type_scope_begin,
	TTable = type_scope_begin,
	TTuple = type_scope_begin,
	TVararg = type_scope_begin,
	TField = type_scope_begin,
	TRecursive = function(visitor, node)
		type_scope_begin(visitor, node, node[1])
	end,
}

local visitor_after = {
	TUnion = type_scope_end,
	TUnionlist = type_scope_end,
	TFunction = type_scope_end,
	TTable = type_scope_end,
	TTuple = type_scope_end,
	TVararg = type_scope_end,
	TRecursive = type_scope_end,
	TField = type_scope_end,
}

function tlutils.dumptype(env, typeNode)
	local visitor = {
		before = visitor_before,
		after = visitor_after,
		override = {},
		indent = 0,
		bufferList = {},
	}
	tlvisitor.visit_type(typeNode, visitor)
	return table.concat(visitor.bufferList, "")
end

function tlutils.searchpath(name, path)
  if package.searchpath then
    return package.searchpath(name, path)
  else
    local error_msg = ""
    name = string.gsub(name, '%.', '/')
    for tldpath in string.gmatch(path, "([^;]*);") do
      tldpath = string.gsub(tldpath, "?", name)
      local f = io.open(tldpath, "r")
      if f then
        f:close()
        return tldpath
      else
        error_msg = error_msg .. string.format("no file '%s'\n", tldpath)
      end
    end
    return nil, error_msg
  end
end

function tlutils.getcontents(fileName)
  local file = assert(io.open(fileName, "r"))
  local contents = file:read("*a")
  file:close()
  return contents
end

return tlutils
