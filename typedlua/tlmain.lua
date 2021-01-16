

local tlparser = require "typedlua/tlparser"

-- visitor

local tlvRefer = require "typedlua/tlvRefer"

local tlvBreadth = require "typedlua/tlvBreadth"

-- utils
local seri = require "typedlua/seri"
local tlutils = require "typedlua/tlutils"
local tltype = require "typedlua/tltype"
local tlenv = require "typedlua/tlenv"
local tlmain = {}

function tlmain.main(subject, filename, strict, integer, color)
	local nGlobalEnv = tlenv.GlobalEnv(filename)
	local nFileEnv = tlenv.create_file_env(nGlobalEnv, subject, filename)

	local nContext, error_msg = tlparser.parse(nFileEnv)
	if not nContext then
		print(error_msg)
		return
	end

	-- print("define_dict:", seri(nContext.env.define_dict))

	-- print(tlutils.dumpast(global_env.info.ast))

	-- print("==========================================tlvRequire=======================")
	-- tlvRequire.requireAll(global_env)

	-- print("==========================================tlvDefine=======================")
	-- tlvDefine.defineAll(global_env)

	--[[for k,v in pairs(global_env.interface_dict) do
		print(k, tlutils.dumptype(v))
	end]]

	print("==========================================tlvRefer=======================")

	tlvRefer.refer(nFileEnv)
	print(tlutils.seri(nFileEnv.info.ast))
	--print(seri(identTree))
	--print(tlenv.dump(nFileEnv))

	--print("==========================================tlvBreadth=======================")
	--tlvBreadth.visit(nFileEnv)

	--[[print(tlutils.dumpLambda(nFileEnv.info.ast, function(node)
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
