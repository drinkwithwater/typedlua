

local tlparser = require "typedlua/tlparser"

-- visitor
local tlvRequire = require "typedlua/tlvRequire"

local tlvDefine = require "typedlua/tlvDefine"
local tlvRefer = require "typedlua/tlvRefer"

local tlvBreadth = require "typedlua/tlvBreadth"

-- utils
local tleIdent = require "typedlua/tleIdent"
local seri = require "typedlua/seri"
local tlutils = require "typedlua/tlutils"
local tltype = require "typedlua/tltype"
local tlenv = require "typedlua/tlenv"
local tlmain = {}

function tlmain.main(subject, filename, strict, integer, color)
	-- TODO maybe no integer for 5.2 or 5.1
	tltype.integer = true
	local ast, error_msg = tlparser.parse(subject, filename, strict, integer)
	if not ast then
		print(error_msg)
		return
	end

	local global_env = tlenv.GlobalEnv(subject, filename, ast)
	-- print(tlutils.dumpast(global_env.ast))

	print("==========================================tlvRequire=======================")
	tlvRequire.requireAll(global_env)

	print("==========================================tlvDefine=======================")
	tlvDefine.defineAll(global_env)

	--[[for k,v in pairs(global_env.interface_dict) do
		print(k, tlutils.dumptype(v))
	end]]
	print(tlutils.dumpast(global_env.ast))

	print("==========================================tlvRefer=======================")

	local identTree = tlvRefer.refer(global_env, ast)
	--print(seri(identTree))
	print(tleIdent.dump(identTree))

	global_env.ident_tree = identTree

	print("==========================================tlvBreadth=======================")
	tlvBreadth.visit(global_env)

	print(tlutils.dumpLambda(global_env.ast, function(node)
		if node.type then
			return node, "", node.type.tag
		else
			return node, "", nil
		end
	end):gsub("[()]"," "))
	--[[local msgs, env = tlchecker.check(global_env)

	print(tlchecker.error_msgs(msgs,true,false,false))]]

	return ast
end

return tlmain
