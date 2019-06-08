--[[
This module implements Typed Lua parser
]]


local lpeg = require "lpeg"
lpeg.locale(lpeg)

local tlast = require "typedlua.tlast"
local tllexer = require "typedlua.tllexer"
local tltype = require "typedlua.tltype"
local tltAuto = require "typedlua.tltAuto"
local tltable = require "typedlua.tltable"
local tlutils = require "typedlua.tlutils"

local tltSyntax = {}

function tltSyntax.ast_include(vPos, vFileName)
	return {tag="Include", pos=vPos, vFileName}
end

function tltSyntax.ast_define_type(vPos, vName, vType)
	local nDefineType = tltype.Define(vName, vType)
	nDefineType.pos = vPos
	return nDefineType
end

function tltSyntax.ast_link_define_type(vPos, vContext, vName)
	local nDefineLink = tltype.DefineLink(vName)
	nDefineLink.pos = vPos

	-- record in env
	local nList = vContext.env.define_link_list
	nList[#nList + 1] = nDefineLink
	return nDefineLink
end

local mBaseSyntax = {
  -- type language
  Type = lpeg.V("NilableType");
  NilableType = lpeg.V("UnionType") * (tllexer.symb("?") * lpeg.Cc(true))^-1 /
                tltype.UnionNil;
  UnionType = lpeg.V("PrimaryType") * (lpeg.Cg(tllexer.symb("|") * lpeg.V("PrimaryType"))^0) /
              tltype.Union;

  PrimaryType = lpeg.V("LiteralType") +
                lpeg.V("BaseType") +
                lpeg.V("NilType") +
                lpeg.V("AnyType") +
                lpeg.V("FunctionType") +
                lpeg.V("TableType") +
                lpeg.V("DefineType");
  LiteralType = ((tllexer.token("false", "Type") * lpeg.Cc(false)) +
                (tllexer.token("true", "Type") * lpeg.Cc(true)) +
                tllexer.token(tllexer.Number, "Type") +
                tllexer.token(tllexer.String, "Type")) /
                tltype.Literal;
  BaseType = tllexer.token("boolean", "Type") / tltype.Boolean +
             tllexer.token("number", "Type") / tltype.Number +
             tllexer.token("string", "Type") / tltype.String +
             tllexer.token("integer", "Type") / tltype.Integer;
  NilType = tllexer.token("nil", "Type") / tltype.Nil;
  AnyType = tllexer.token("any", "Type") / tltype.Any;

  -------------------
  -- function type --
  -------------------
  -- function type only use tuple
  TupleType = tllexer.symb("(") * (lpeg.V("Type") * (tllexer.symb(",") * lpeg.V("Type"))^0)^-1 * tllexer.symb(")") / tltype.Tuple + tllexer.symb("(") * lpeg.V("Type") * (tllexer.symb(",") * lpeg.V("Type"))^0 * tllexer.symb("*") * tllexer.symb(")") / tltype.VarTuple;
  FunctionType = lpeg.V("TupleType") * tllexer.symb("->") * lpeg.V("TupleType") / tltype.StaticFunction +
				 lpeg.V("TupleType") * tllexer.symb("->") * tllexer.kw("auto") / tltAuto.AutoFunction;

  ----------------
  -- table type --
  ----------------
  KeyType = lpeg.V("BaseType") + lpeg.V("AnyType");
  RecordField = tllexer.symb("[") * lpeg.V("LiteralType") * tllexer.symb("]") *
				tllexer.symb("=") * lpeg.V("Type") / tltable.Field;
  RecordType = lpeg.V("RecordField") * (tllexer.symb(",") * lpeg.V("RecordField"))^0 *
               (tllexer.symb(",") * (lpeg.V("HashType") + lpeg.V("ArrayType")))^-1;
  HashType = tllexer.symb("[") * lpeg.V("KeyType") * tllexer.symb("]") *
			 tllexer.symb("=") * lpeg.V("Type") / tltable.Field;
  ArrayType = lpeg.V("Type") / tltable.ArrayField;
  TableTypeBody = lpeg.V("RecordType") + lpeg.V("HashType") + lpeg.V("ArrayType") + lpeg.Cc(nil);
  TableType = tllexer.symb("{") * lpeg.V("TableTypeBody") * tllexer.symb("}") / tltable.StaticTable;

  ------------------
  -- define  type --
  ------------------
  DefineType = ( lpeg.Cp()*lpeg.Carg(1)*tllexer.token(tllexer.Name, "Type") )/tltSyntax.ast_link_define_type;

  -----------------------
  -- interface ?? TODO --
  -----------------------
  Id = lpeg.Cp() * tllexer.token(tllexer.Name, "Name") / tlast.ident;
  IdList = lpeg.Cp() * lpeg.V("Id") * (tllexer.symb(",") * lpeg.V("Id"))^0 / tlast.namelist;
  IdDec = lpeg.V("IdList") * tllexer.symb(":") * lpeg.V("Type") / tltable.fieldlist;
  IdDecList = ((lpeg.V("IdDec") * tllexer.Skip)^1 + lpeg.Cc(nil)) / tltable.StaticTable;
  TypeDec = tllexer.token(tllexer.Name, "Name") * lpeg.V("IdDecList") * tllexer.kw("end");
  Interface = lpeg.Cp() * tllexer.kw("interface") * lpeg.V("TypeDec") /
              tltSyntax.ast_define_type+
              lpeg.Cp() * tllexer.kw("typealias") *
              tllexer.token(tllexer.Name, "Name") * tllexer.symb("=") * lpeg.V("Type") /
              tltSyntax.ast_define_type;
  LocalInterface = tllexer.kw("local") * lpeg.V("Interface") / tlast.statLocalTypeDec;
  TypeDecStat = lpeg.V("Interface") + lpeg.V("LocalInterface");


  -----------
  -- other --
  -----------
  Userdata = lpeg.Cp() * tllexer.kw("userdata") * lpeg.V("TypeDec") /
             tltSyntax.ast_define_type;
  TypedId = lpeg.Cp() * tllexer.token(tllexer.Name, "Name") *
            tllexer.symb(":") * lpeg.V("Type") / tlast.ident;


}

local mTestPattern = lpeg.P { "Sth";
	Test = tllexer.token("fdsfds", "fds") ^0 + tllexer.syntax_error();
	Sth = lpeg.V("Test");
}

-----------------
-- create deco --
-----------------
local mDecoPattern = lpeg.P(tlutils.table_concat(mBaseSyntax, { "TypeDeco";
  TypeDeco = (tllexer.Skip * lpeg.V("Type") * (tllexer.symb(",") * lpeg.V("Type"))^0 ) * -1 / function(...) return {...} end + tllexer.syntax_error();
}))

------------------
-- create chunk --
------------------
local mChunkPattern = lpeg.P(tlutils.table_concat(mBaseSyntax, { "TypeChunk";
  TypeChunk = tllexer.Skip * lpeg.V("TypeStatList") * -1 + tllexer.syntax_error();
  -- stat
  TypeStat = lpeg.V("TypedId") + lpeg.V("Interface") + lpeg.V("Userdata");
  TypeStatList = lpeg.V("TypeStat")^1 / function (...) return {...} end;
}))

function tltSyntax.capture_deco(vAllSubject, vNextPos, vContext, vStartPos, vDecoSubject)
	local nSubContext = tllexer.create_context(vContext.env)
	local nDecoList = lpeg.match(mDecoPattern, vDecoSubject, nil, nSubContext)
	if nDecoList then
		return true, nDecoList
	else
		vContext.ffp = vStartPos + nSubContext.ffp - 1
		vContext.sub_context = nSubContext
		return false
	end
end

function tltSyntax.capture_define_chunk(vAllSubject, vNextPos, vContext, vStartPos, vDefineSubject)
	local nFileEnv = vContext.env
	local nSubContext = tllexer.create_context(nFileEnv)
	local nDefineList = lpeg.match(mChunkPattern, vDefineSubject, nil, nSubContext)
	if nDefineList then
		for i, nDefineNode in ipairs(nDefineList) do
			local nFullPos = vStartPos + nDefineNode.pos - 1
			nDefineNode.pos = nFullPos
			nDefineNode.l, nDefineNode.c = tllexer.context_fixup_pos(vContext, nFullPos)
			local nFindInterface = nFileEnv.define_dict[nDefineNode[1]]
			if not nFindInterface then
				nFileEnv.define_dict[nDefineNode[1]] = nDefineNode
			else
				vContext.ffp = vStartPos + nSubContext.ffp - 1
				vContext.sub_context = nSubContext
				nSubContext.semantic_error = "name conflict"
				return false
			end
		end
		return true
	else
		vContext.ffp = vStartPos + nSubContext.ffp - 1
		vContext.sub_context = nSubContext
		return false
	end
end

function tltSyntax.parse_deco(vFileEnv, vSubject)
	error("TODO")
  local nContext = tllexer.create_context(vFileEnv)
  lpeg.setmaxstack(1000)
  return lpeg.match(mDecoPattern, vSubject, nil, nContext)
end

function tltSyntax.parse_define_chunk(vFileEnv, vSubject)
	error("TODO")
  local nContext = tllexer.create_context(vFileEnv)
  lpeg.setmaxstack(1000)
  return lpeg.match(mChunkPattern, vSubject, nil, nContext)
end

function tltSyntax.parse_test(vFileEnv, vSubject)
  local nContext = tllexer.create_context(vFileEnv)
  lpeg.setmaxstack(1000)
  return lpeg.match(mTestPattern, vSubject, nil, nContext)
end

return tltSyntax
