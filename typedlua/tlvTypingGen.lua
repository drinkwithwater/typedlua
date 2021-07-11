
local tlvisitor = require "typedlua/tlvisitor"
local tlenv = require "typedlua/tlenv"
local tlvGen = {}
local seri = require "typedlua/seri"

function tlvGen:indent()
	table.insert(self.buffer_list, string.rep("\t", self.indent_count - 1))
end

function tlvGen:print(...)
	for i=1, select("#", ...) do
		local obj = select(i, ...)
		if type(obj) == "table" then
			tlvisitor.visit_node(obj, self)
		else
			table.insert(self.buffer_list, obj)
		end
	end
end

function tlvGen:printn(c, n)
	for i=1, n do
		self:print(c..i)
		if i < n then
			self:print(",")
		end
	end
end

function tlvGen:get_ident_scope_refer(vIdentNode)
	return self.env.ident_list[vIdentNode.ident_refer].scope_refer
end

local visitor_block = {
	Block={
		before=function(visitor, node)
			visitor.indent_count = visitor.indent_count + 1
		end,
		override=function(visitor, node)
			visitor:indent()
			visitor:print("local s"..node.self_scope_refer.."={}\n")
			local parent = visitor.stack[#visitor.stack - 1]
			if node.is_fornum_block then
				visitor:indent()
				visitor:print("SYMBOL_INIT(")
				visitor:print(parent[1], ", fornum_i)")
				visitor:print("\n")
			elseif node.is_forin_block then
				for i=1, #parent[1] do
					visitor:indent()
					visitor:print(parent[1][i])
					visitor:print("=yueHook:symbol_new(forin_a"..i..")\n")
				end
			end
			for i=1, #node do
				visitor:indent()
				visitor:print(node[i])
				visitor:print("\n")
			end
		end,
		after=function(visitor, node)
			visitor.indent_count = visitor.indent_count - 1
		end
	}
}

local visitor_stm = {
	Do={
		before=function(visitor, node)
			visitor:print("do\n")
		end,
		after=function(visitor, node)
			visitor:indent()
			visitor:print("end")
		end
	},
	Set={
		override=function(visitor, node)
			visitor:print("local ")
			visitor:printn("set_a", #node[1])
			visitor:print("=")
			visitor:print(node[2])
			visitor:print("\n")
			for i=1, #node[1] do
				visitor:indent()
				local var = node[1][i]
				if var.tag == "Id" then
					var.is_set = true
					visitor:print("SYMBOL_SET(")
					visitor:print(var)
					visitor:print(", ")
				elseif var.tag == "Index" then
					visitor:print("META_SET(")
					visitor:print(var[1])
					visitor:print(", ")
					visitor:print(var[2])
					visitor:print(", ")
				end
				if i == #node[1] then
					visitor:print("set_a", i, ")")
				else
					visitor:print("set_a", i, ")\n")
				end
			end
		end
	},
	While={
		override=function(visitor, node)
			visitor:indent()
			visitor:print("while ")
			visitor:print(node[1])
			visitor:print(" do\n")
			visitor:print(node[2])
			visitor:indent()
			visitor:print("end\n")
		end,
	},
	Repeat={
		override=function(visitor, node)
			visitor:indent()
			visitor:print("repeat")
			visitor:print(node[1])
			visitor:indent()
			visitor:print("until(")
			visitor:print(node[2])
			visitor:print(")\n")
		end,
	},
	If={
		override=function(visitor, node)
			visitor:print("if ")
			visitor:print(node[1])
			visitor:print(" then\n")
			visitor:print(node[2])
			for i=3,#node-1,2 do
				visitor:indent()
				visitor:print("elseif ")
				visitor:print(node[i])
				visitor:print(" then\n")
				visitor:print(node[i+1])
			end
			if #node >= 3 and #node % 2 == 1 then
				visitor:indent()
				visitor:print("else\n")
				visitor:print(node[#node])
			end
			visitor:indent()
			visitor:print("end")
		end
	},
	Fornum={
		override=function(visitor, node)
			local blockNode
			if #node == 4 then
				visitor:print("local fornum_r1, fornum_r2 = ")
				visitor:print(node[2], ", ", node[3], "\n")
				blockNode = node[4]
				visitor:print("for fornum_i=fornum_r1, fornum_r2 do\n")
			elseif #node == 5 then
				visitor:print("local fornum_r1, fornum_r2, fornum_r3 =")
				visitor:print(node[2], ", ", node[3], ", ", node[4], "\n")
				blockNode = node[5]
				visitor:print("for fornum_i=fornum_r1, fornum_r2, fornum_r3 do\n")
			end
			blockNode.is_fornum_block = true
			visitor:print(blockNode)
			visitor:indent()
			visitor:print("end")
		end
	},
	Forin={
		override=function(visitor, node)
			--visitor:print("for ")
			--visitor:print(node[1])
			--visitor:print(" in ")
			visitor:print("do\n")
			visitor:indent()
			visitor:print("\tlocal ")
			visitor:printn("forin_a", #node[1])
			visitor:print("=", node[2], "\n")
			visitor:indent()
			node[3].is_forin_block = true
			visitor:print(node[3])
			visitor:indent()
			visitor:print("end")
		end
	},
	Local={
		override=function(visitor, node)
			--visitor:print("local ")
			visitor:print("local ")
			visitor:printn("local_a", #node[1])
			if #node[2]>0 then
				visitor:print("=")
				visitor:print(node[2])
			end
			visitor:print("\n")
			for i=1, #node[1] do
				visitor:indent()
				visitor:print("SYMBOL_INIT(")
				visitor:print(node[1][i], ", ")
				visitor:printn("local_a", #node[1])
				visitor:print(")\n")
			end
		end
	},
	Localrec={
		override=function(visitor, node)
			visitor:print("local function ")
			visitor:print(node[1])
			visitor:print("(")
			visitor:print(node[2][1][1])
			visitor:print(")")
			visitor:print(node[2][1][2])
			visitor:print("\n")
			visitor:indent()
			visitor:print("end")
		end,
	},
	Goto={
		before=function()
			print("goto TODO")
		end
	},
	Label={
		before=function()
			print("label TODO")
		end
	},
	Return={
		before=function(visitor, node)
			visitor:print("return ")
		end,
	},
	Break={
		before=function(visitor, node)
			visitor:print("break")
		end,
	},
	Call={
		override=function(visitor, node)
			visitor:print("META_CALL(")
			visitor:print(node[1])
			visitor:print(",")
			visitor:print(node[2])
			visitor:print(")")
		end
	},
	Invoke={
		override=function(visitor, node)
			visitor:print("META_HOOK(")
			visitor:print(node[1])
			visitor:print(",")
			visitor:print(node[2])
			visitor:print(",")
			visitor:print(node[3])
			visitor:print(")")
		end
	},
}

local visitor_exp = {
	Nil={
		before=function(visitor, node)
			visitor:print("nil")
		end
	},
	Dots={
		before=function(visitor, node)
			visitor:print("...")
		end
	},
	True={
		before=function(visitor, node)
			visitor:print("true")
		end
	},
	False={
		before=function(visitor, node)
			visitor:print("false")
		end
	},
	Number={
		before=function(visitor, node)
			visitor:print(tostring(node[1]))
		end
	},
	String={
		before=function(visitor, node)
			local s = string.gsub(node[1], '\\', '\\\\')
			s = string.gsub(s, '"', '\\"')
			if node[1]:match("\n") then
				visitor:print('[[' .. s .. ']]')
			else
				visitor:print('"' .. s .. '"')
			end
		end
	},
	Function = {
		override=function(visitor, node)
			visitor:print("function(")
			visitor:print(node[1])
			visitor:print(")\n")
			visitor:print(node[2])
			visitor:indent()
			visitor:print("end")
		end
	},
	Table = {
		override=function(visitor, node)
			visitor:print("TABLE_NEW({")
			for i=1, #node do
				if node[i].tag == "Pair" then
					visitor:print("[", node[i][1], "]=", node[i][2])
				else
					visitor:print(node[i])
				end
				visitor:print(i < #node and "," or "")
			end
			visitor:print("})")
		end,
	},
	Op = {
		override=function(visitor, node)
			local t = {["or"]=1,["not"]=1,["and"]=1}
			if t[node[1]] then
				if node[1] == "not" then
					visitor:print("LOGIC_NOT(", node[2], ")")
				else
					visitor:print("LOGIC_", node[1]:upper(), "(", node[2], ",", node[3], ")")
				end
			else
				if #node == 2 then
					visitor:print("META_UOP(\"", node[1], "\",", node[2], ")")
				else
					visitor:print("META_BOP(\"", node[1], "\",", node[2], ",", node[3], ")")
				end
			end
		end
	},
	Paren = {
		before=function(visitor, node)
			visitor:print("(")
		end,
		after=function(visitor, node)
			visitor:print(")")
		end,
	},
	--Call = {},
	--Invoke = {},
	Id = {
		before=function(visitor, node)
			local preNode = visitor.stack[#visitor.stack-1]
			if preNode.tag == "ParList" then
				visitor:print(node[1])
			else
				if node.is_define or node.is_set then
					visitor:print("s"..visitor:get_ident_scope_refer(node)..", \""..node[1], "\"")
				else
					visitor:print("SYMBOL_GET(s"..visitor:get_ident_scope_refer(node)..", \""..node[1], "\")")
				end
			end
			--visitor:print(node[1])
		end
	},
	Index = {
		override=function(visitor, node)
			visitor:print("META_GET(")
			visitor:print(node[1])
			visitor:print(",")
			visitor:print(node[2])
			visitor:print(")")
		end
	},
}

local visitor_list = {
	ExpList={
		override=function(visitor, node)
			for i=1,#node do
				visitor:print(node[i])
				visitor:print(i < #node and "," or "")
			end
		end
	},
	ParList={
		override=function(visitor, node)
			for i=1, #node do
				visitor:print(node[i])
				visitor:print(i < #node and "," or "")
			end
		end
	},
	VarList={
		override=function(visitor, node)
			for i=1, #node do
				visitor:print(node[i])
				visitor:print(i < #node and "," or "")
			end
		end
	},
	NameList={
		override=function(visitor, node)
			for i=1,#node do
				visitor:print(node[i])
				visitor:print(i < #node and "," or "")
			end
		end
	},
}

local visitor_object_dict = tlvisitor.concat(visitor_block, visitor_stm, visitor_exp, visitor_list)

local hook = require "typedlua.yue.Hook"
function tlvGen.visit(vFileEnv)
	local pre_codes = {
		'local yueRuntime = (require "typedlua.yue.Runtime").new()\n',
		"local yueHook = yueRuntime.mHook\n",
		"local s"..tlenv.G_SCOPE_REFER.."=_G\n",
	}
	for funcName, v in pairs(hook) do
		pre_codes[#pre_codes + 1] = "local function " .. funcName:upper() .. "(...) return yueHook:"..funcName.."(...) end "
	end
	pre_codes[#pre_codes + 1] = "\n----------------------------\n"
	local visitor = setmetatable({
		object_dict = visitor_object_dict,
		buffer_list = pre_codes,
		env = vFileEnv,
		indent_count = 0,
	}, {
		__index=tlvGen
	})

	tlvisitor.visit_obj(vFileEnv.info.ast, visitor)
	print(table.concat(visitor.buffer_list))
end

return tlvGen
