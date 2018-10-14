

-- visitor
local tlparser = require "typedlua/tlparser"
local tlrequire = require "typedlua/tlrequire"

local tldefine = require "typedlua/tldefine"
local tlrefer = require "typedlua/tlrefer"

local tlchecker = require "typedlua/tlchecker"

-- utils
local tluv = require "typedlua/tluv"
local seri = require "typedlua/seri"
local tlutils = require "typedlua/tlutils"
local tltype = require "typedlua/tltype"
local tlst = require "typedlua/tlst"
local tlmain = {}

function tlmain.main(subject, filename, strict, integer, color)
	-- TODO maybe no integer for 5.2 or 5.1
	tltype.integer = true
	local ast, error_msg = tlparser.parse(subject, filename, strict, integer)
	if not ast then
		print(error_msg)
		return
	end

	local global_env = tlst.new_global_env(subject, filename, strict, color)
	global_env.ast = ast

	tlrequire.requireAll(global_env)

	tldefine.defineAll(global_env)

	for k,v in pairs(global_env.interface) do
		print(k, tlutils.dumptype(v))
	end
	print(tlutils.dumpast(global_env.ast))

	print("==========================================tlrefer=======================")

	local uvtree = tlrefer.refer(ast)
	-- print(seri(uvtree))
	print(tluv.dump(uvtree))
	-- local msgs, env = tlchecker.check(global_env)

	-- print(tlchecker.error_msgs(msgs,false,false,false))

	return ast
end

return tlmain
