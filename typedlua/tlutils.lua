
local tlnode = require "typedlua.tlnode"

local tlutils = {}

tlutils.seri = require "typedlua/seri"

-- dump ast node
local function dumpNode(obj, bufferList, preLine, lambda)
	local line, offset = preLine, nil
	local astNode, middle, last = lambda(obj)
	if astNode.pos then
		line, offset = astNode.l, astNode.c
		if line ~= preLine then
			bufferList[#bufferList + 1] = "\n"
			bufferList[#bufferList + 1] = line
			bufferList[#bufferList + 1] = ":"
			bufferList[#bufferList + 1] = string.rep(" ", offset)
		end
	end
	if last then
		bufferList[#bufferList + 1] = "("
		bufferList[#bufferList + 1] = last
		bufferList[#bufferList + 1] = ")"
	end
	if not middle then
		return line
	end
	bufferList[#bufferList + 1] = middle
	bufferList[#bufferList + 1] = "{"
	for k, v in ipairs(obj) do
		if type(v) == "table" then
			line = dumpNode(v, bufferList, line, lambda)
		else
			bufferList[#bufferList + 1] = "("
			bufferList[#bufferList + 1] = v
			bufferList[#bufferList + 1] = ")"
		end
	end
	bufferList[#bufferList + 1] = "}"
	return line
end

function tlutils.dumpLambda(root, lambda)
	local bufferList = {}
	dumpNode(root, bufferList, -1, lambda)
	return table.concat(bufferList)
end

function tlutils.dumpast(astNode)
	return tlutils.dumpLambda(astNode, function(node)
		if tlnode.isType(node.tag) then
			return node, nil, node.tag
		else
			return node, node.tag
		end
	end)
end

function tlutils.dumptype(typeNode)
	return tlutils.dumpLambda(typeNode, function(node)
		if tlnode.isType(node.tag) then
			return node, node.tag, nil
		else
			return node, "", nil
		end
	end)
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

local function isprint (x)
  if (x >= 0 and x <= 31) or (x == 127) then return false end
  if x >= 128 then return false end
  return true
end

function tlutils.fixed_string(str)
  local new_str = ""
  for i=1,string.len(str) do
    local char = string.byte(str, i)
    if char == 34 then new_str = new_str .. string.format("\\\"")
    elseif char == 92 then new_str = new_str .. string.format("\\\\")
    elseif char == 7 then new_str = new_str .. string.format("\\a")
    elseif char == 8 then new_str = new_str .. string.format("\\b")
    elseif char == 12 then new_str = new_str .. string.format("\\f")
    elseif char == 10 then new_str = new_str .. string.format("\\n")
    elseif char == 13 then new_str = new_str .. string.format("\\r")
    elseif char == 9 then new_str = new_str .. string.format("\\t")
    elseif char == 11 then new_str = new_str .. string.format("\\v")
    else
      if isprint(char) then
        new_str = new_str .. string.format("%c", char)
      else
        new_str = new_str .. string.format("\\%03d", char)
      end
    end
  end
  return new_str
end

function tlutils.table_concat(...)
	local nDict = {}
	for i=1, select("#", ...) do
		local t = select(i, ...)
		for k,v in pairs(t) do
			if nDict[k] then
				error("concat duplicate")
			end
			nDict[k] = v
		end
	end
	return nDict
end

return tlutils
