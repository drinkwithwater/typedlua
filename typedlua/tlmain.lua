
local tldefine = require "typedlua/tldefine"
local tlparser = require "typedlua/tlparser"
local tlutils = require "typedlua/tlutils"
local tltype = require "typedlua/tltype"
local tlchecker = require "typedlua/tlchecker"
local tlmain = {}

function tlmain.main(subject, filename, strict, integer, color)
	-- TODO maybe no integer for 5.2 or 5.1
	tltype.integer = true
	local ast, error_msg = tlparser.parse(subject, filename, strict, integer)
	if not ast then
		print(error_msg)
		return
	end

	local context = {
		subject = subject,
		filename = filename,
		strict = strict,
		integer = integer,
		color = color,
		ast = ast,
		loaded = {},
		interface = {},
		messages = {},
	}

	local result = tldefine.define(context)
	for name, _ in pairs(result.requireSet) do
		tlmain.define_require(context, name)
	end

	for k,v in pairs(context.interface) do
		print(k, tlutils.dumptype(v))
	end
	print(tlutils.dumpast(context.ast))

	local msgs, env = tlchecker.check(context)


	print(tlchecker.error_msgs(msgs,false,false,false))

	return ast
end

function tlmain.define_require(context, arg)
	arg = string.gsub(arg, '%.', '/')
	local loaded = context.loaded
	local interface = context.interface
	if not loaded[arg] then
		print("requiring:", arg)
		local path = package.path
		local filename, errormsg  = assert(tlutils.searchpath(arg, path))
		local subject = tlutils.getcontents(filename)
		local ast, error_msg = assert(tlparser.parse(subject, fileName, context.strict, context.integer))
		local subContext = {
			subject = subject,
			filename = filename,
			ast = ast,

			strict = context.strict,
			integer = context.integer,
			color = context.color,

			interface = interface,
		}
		print("finish requiring:", arg)
		local result = tldefine.define(subContext)
		loaded[arg] = true
		for arg, _ in pairs(result.requireSet) do
			tlmain.define_require(context, arg)
		end
	end
end

return tlmain
