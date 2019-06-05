

local tlparser = require "typedlua/tlparser"

-- visitor
local tlvRequire = require "typedlua/tlvRequire"

local tlvDefine = require "typedlua/tlvDefine"
local tlvRefer = require "typedlua/tlvRefer"

local tlvBreadth = require "typedlua/tlvBreadth"

-- utils
local seri = require "typedlua/seri"
local tlutils = require "typedlua/tlutils"
local tltype = require "typedlua/tltype"
local tlenv = require "typedlua/tlenv"
local tlmain = {}

function tlmain.main(subject, filename, strict, integer, color)
	-- TODO maybe no integer for 5.2 or 5.1
	tltype.integer = true
	local nContext, error_msg = tlparser.parse(subject, filename, strict, integer)
	if not nContext then
		print(error_msg)
		return
	end
	local ast = nContext.ast

	print(seri(nContext.define_list))

	local nGlobalEnv = tlenv.GlobalEnv(filename)
	tlenv.begin_file(nGlobalEnv, subject, filename, ast)

	-- print(tlutils.dumpast(global_env.ast))

	-- print("==========================================tlvRequire=======================")
	-- tlvRequire.requireAll(global_env)

	-- print("==========================================tlvDefine=======================")
	-- tlvDefine.defineAll(global_env)

	--[[for k,v in pairs(global_env.interface_dict) do
		print(k, tlutils.dumptype(v))
	end]]
	local nFileEnv = nGlobalEnv.cur_env

	print("==========================================tlvRefer=======================")

	tlvRefer.refer(nFileEnv)
	print(tlutils.dumpast(nFileEnv.ast))
	--print(seri(identTree))
	print(tlenv.dump(nFileEnv))

	print("==========================================tlvBreadth=======================")
	tlvBreadth.visit(nFileEnv)

	--[[print(tlutils.dumpLambda(nFileEnv.ast, function(node)
		if node.type then
			return node, "", node.type.tag
		else
			return node, "", nil
		end
	end):gsub("[()]"," "))
	--[[local msgs, env = tlchecker.check(global_env)

	print(tlchecker.error_msgs(msgs,true,false,false))]]

	tlenv.end_file(nFileEnv)
	return ast
end

return tlmain
