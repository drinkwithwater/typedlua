
local tlutils = require "typedlua/tlutils"
local tlvisitor = require "typedlua/tlvisitor"
local tlparser = require "typedlua/tlparser"

local tlvRequire = {}
local visitor_after = {
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
		table.insert(visitor.requireList, callee[1])
	end,
}

function tlvRequire.requireName(name, global_env)
	local loadedInfo = global_env.loadedInfo
	name = string.gsub(name, '%.', '/')
	if not loadedInfo[name] then
		print("requiring:", name)
		local path = package.path
		local filename, errormsg  = assert(tlutils.searchpath(name, path))
		local subject = tlutils.getcontents(filename)
		local ast, error_msg = assert(tlparser.parse(subject, filename, global_env.strict, global_env.integer))
		loadedInfo[name] = {
			subject = subject,
			filename = filename,
			ast = ast,
		}
		local visitor = {
			after = visitor_after,
			requireList = {},
		}
		tlvisitor.visit(ast, visitor)
		for i, nextName in pairs(visitor.requireList) do
			if not loadedInfo[nextName] then
				tlvRequire.requireName(nextName, global_env)
			end
		end
	end
end

-- require recursive
function tlvRequire.requireAll(global_env)
	local ast = global_env.ast
	local visitor = {
		after = visitor_after,
		requireList = {},
	}
	tlvisitor.visit(ast, visitor)
	for i, nextName in ipairs(visitor.requireList) do
		if not global_env.loadedInfo[nextName] then
			tlvRequire.requireName(nextName, global_env)
		end
	end
end

return tlvRequire
