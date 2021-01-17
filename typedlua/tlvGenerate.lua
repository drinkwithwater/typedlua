
local tlvisitor = require "typedlua/tlvisitor"
local tlvGen = {}
local seri = require "typedlua/seri"

function tlvGen:indent()
	table.insert(self.buffer_list, string.rep("\t", self.indent_count - 1))
end

function tlvGen:print(obj)
	if type(obj) == "table" then
		tlvisitor.visit_node(obj, self)
	else
		table.insert(self.buffer_list, obj)
	end
end

local visitor_block = {
	Block={
		before=function(visitor, node)
			visitor.indent_count = visitor.indent_count + 1
		end,
		override=function(visitor, node)
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
			visitor:indent()
			visitor:print("do\n")
		end,
		after=function(visitor, node)
			visitor:indent()
			visitor:print("end")
		end
	},
	Set={
		override=function(visitor, node)
			visitor:print(node[1])
			visitor:print("=")
			visitor:print(node[2])
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
			visitor:print("for ")
			visitor:print(node[1])
			visitor:print(" = ")
			visitor:print(node[2])
			visitor:print(", ")
			visitor:print(node[3])
			if #node == 4 then
				visitor:print(" do\n")
				visitor:print(node[4])
			elseif #node == 5 then
				visitor:print(", ")
				visitor:print(node[4])
				visitor:print(" do\n")
				visitor:print(node[5])
			else
				error("fornum length error")
			end
			visitor:indent()
			visitor:print("end")
		end
	},
	Forin={
		override=function(visitor, node)
			visitor:print("for ")
			visitor:print(node[1])
			visitor:print(" in ")
			visitor:print(node[2])
			visitor:print(" do\n")
			visitor:print(node[3])
			visitor:indent()
			visitor:print("end")
		end
	},
	Local={
		override=function(visitor, node)
			visitor:print("local ")
			visitor:print(node[1])
			if #node[2]>0 then
				visitor:print(" = ")
				visitor:print(node[2])
			end
		end
	},
	Localrec={
		override=function(visitor, node)
			visitor:print("local function ")
			visitor:print(node[1])
			visitor:print("(")
			visitor:print(node[2][1])
			visitor:print(")")
			visitor:print(node[2][2])
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
			visitor:print(node[1])
			visitor:print("(")
			visitor:print(node[2])
			visitor:print(")")
		end
	},
	Invoke={
		override=function(visitor, node)
			visitor:print(node[1])
			visitor:print(":")
			visitor:print(node[2])
			visitor:print("(")
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
			visitor:print("function (")
			visitor:print(node[1])
			visitor:print(")\n")
			visitor:print(node[2])
			visitor:indent()
			visitor:print("end")
		end
	},
	Table = {
		override=function(visitor, node)
			visitor:print("{")
			for i=1, #node do
				if node[i].tag == "Pair" then
					visitor:print("[")
					visitor:print(node[i][1])
					visitor:print("]=")
					visitor:print(node[i][2])
				else
					visitor:print(node[i])
				end
				visitor:print(i < #node and "," or "")
			end
			visitor:print("}")
		end,
	},
	Op = {
		override=function(visitor, node)
			local t = {["or"]=1,["not"]=1,["and"]=1}
			if t[node[1]] then
				if node[1] == "not" then
					visitor:print("not ")
					visitor:print(node[2])
				else
					visitor:print(node[2])
					visitor:print(" "..node[1].." ")
					visitor:print(node[3])
				end
			else
				visitor:print(node[1])
				visitor:print("(")
				visitor:print(node[2])
				if #node == 3 then
					visitor:print(",")
					visitor:print(node[3])
				end
				visitor:print(")")
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
			visitor:print(node[1])
		end
	},
	Index = {
		override=function(visitor, node)
			visitor:print(node[1])
			visitor:print("[")
			visitor:print(node[2])
			visitor:print("]")
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

function tlvGen.visit(vFileEnv)
	local visitor = setmetatable({
		object_dict = visitor_object_dict,
		buffer_list = {},
		env = vFileEnv,
		indent_count = 0,
	}, {
		__index=tlvGen
	})

	tlvisitor.visit_obj(vFileEnv.info.ast, visitor)
	print(table.concat(visitor.buffer_list))
end

return tlvGen
