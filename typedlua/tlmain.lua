

local tlparser = require "typedlua/tlparser"

-- visitor
local tlvRequire = require "typedlua/tlvRequire"

local tlvDefine = require "typedlua/tlvDefine"
local tlvRefer = require "typedlua/tlvRefer"

local tlvBreadth = require "typedlua/tlvBreadth"
local tlchecker = require "typedlua/tlchecker"

-- utils
local tlident = require "typedlua/tlident"
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

	tlvRequire.requireAll(global_env)

	tlvDefine.defineAll(global_env)

	for k,v in pairs(global_env.interface) do
		print(k, tlutils.dumptype(v))
	end
	print(tlutils.dumpast(global_env.ast))

	print("==========================================tlvRefer=======================")

	local identTree = tlvRefer.refer(ast)
	-- print(seri(identTree))
	print(tlident.dump(identTree))

	-- tlvBreadth.visit(ast, identTree)
	--[[local msgs, env = tlchecker.check(global_env)

	print(tlchecker.error_msgs(msgs,true,false,false))]]

	return ast
end

return tlmain
