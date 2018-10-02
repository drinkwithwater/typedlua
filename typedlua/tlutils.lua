
local tlnode = require "typedlua.tlnode"

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

return tlutils
