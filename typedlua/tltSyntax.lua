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

local function chainl1 (pat, sep)
  return lpeg.Cf(pat * lpeg.Cg(sep * pat)^0, tlast.exprBinaryOp)
end

local function exprFunction(...)
  local func = tlast.exprFunction(...)
  func.comment = table.concat(tllexer.comments, "\n")
  tllexer.comments = {}
  return func
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
                lpeg.V("TableType");
                -- TODO lpeg.V("VariableType");
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
  TupleType = tllexer.symb("(") * (lpeg.V("Type") * (tllexer.symb(",") * lpeg.V("Type"))^0)^-1 * tllexer.symb(")") / tltype.Tuple;
  FunctionType = lpeg.V("TupleType") * tllexer.symb("->") * lpeg.V("TupleType") / tltype.Function +
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
  TableType = tllexer.symb("{") * lpeg.V("TableTypeBody") * tllexer.symb("}") / tltable.Table;


  -- VariableType = tllexer.token(tllexer.Name, "Type") / tltype.Variable;

  -----------------------
  -- interface ?? TODO --
  -----------------------
  Id = lpeg.Cp() * tllexer.token(tllexer.Name, "Name") / tlast.ident;
  IdList = lpeg.Cp() * lpeg.V("Id") * (tllexer.symb(",") * lpeg.V("Id"))^0 / tlast.namelist;
  IdDec = lpeg.V("IdList") * tllexer.symb(":") * lpeg.V("Type") / tltable.fieldlist;
  IdDecList = ((lpeg.V("IdDec") * tllexer.Skip)^1 + lpeg.Cc(nil)) / tltable.Table;
  TypeDec = tllexer.token(tllexer.Name, "Name") * lpeg.V("IdDecList") * tllexer.kw("end");
  Interface = lpeg.Cp() * tllexer.kw("interface") * lpeg.V("TypeDec") /
              tlast.statInterface +
              lpeg.Cp() * tllexer.kw("typealias") *
              tllexer.token(tllexer.Name, "Name") * tllexer.symb("=") * lpeg.V("Type") /
              tlast.statInterface;
  LocalInterface = tllexer.kw("local") * lpeg.V("Interface") / tlast.statLocalTypeDec;
  TypeDecStat = lpeg.V("Interface") + lpeg.V("LocalInterface");


  -----------
  -- other --
  -----------
  Userdata = lpeg.Cp() * tllexer.kw("userdata") * lpeg.V("TypeDec") /
             tlast.statUserdata;
  TypedId = lpeg.Cp() * tllexer.token(tllexer.Name, "Name") *
            tllexer.symb(":") * lpeg.V("Type") / tlast.ident;


}

local mTestPattern = lpeg.P { "Sth";
	Test = lpeg.Cmt(lpeg.Cp()*lpeg.space, function() return false end);
	Sth = lpeg.V("Test");
}

-----------------
-- create deco --
-----------------
local mDecoPattern = lpeg.P(tlutils.table_concat(mBaseSyntax, { "TypeDeco";
  TypeDeco = (tllexer.Skip * lpeg.V("Type") * (tllexer.symb(",") * lpeg.V("Type"))^0 ) * -1 / function(...) return {...} end + tllexer.report_error();
}))

------------------
-- create chunk --
------------------
local mChunkPattern = lpeg.P(tlutils.table_concat(mBaseSyntax, { "TypeChunk";
  TypeChunk = tllexer.Skip * lpeg.V("TypeStatList") * -1 + tllexer.report_error();
  -- stat
  TypeStat = lpeg.V("TypedId") + lpeg.V("Interface") + lpeg.V("Userdata");
  TypeStatList = lpeg.V("TypeStat")^1 / function (...) return {...} end;
}))

local tltSyntax = {}

function tltSyntax.parse_deco(vSubject, vFileName)
  local nContext = tllexer.create_context(vSubject, vFileName)
  lpeg.setmaxstack(1000)
  return lpeg.match(mDecoPattern, vSubject, nil, nContext)
end

function tltSyntax.parse_chunk(vSubject, vFileName)
  local nContext = tllexer.create_context(vSubject, vFileName)
  lpeg.setmaxstack(1000)
  return lpeg.match(mChunkPattern, vSubject, nil, nContext)
end

function tltSyntax.parse_test(vSubject, vFileName)
  local nContext = tllexer.create_context(vSubject, vFileName)
  lpeg.setmaxstack(1000)
  return lpeg.match(mTestPattern, vSubject, nil, nContext)
end

return tltSyntax
