--[[
This module implements Typed Lua parser
]]


local lpeg = require "lpeg"
lpeg.locale(lpeg)

local seri = require "typedlua/seri"
local tlast = require "typedlua.tlast"
local tllexer = require "typedlua.tllexer"
local tltype = require "typedlua.tltype"
local tltable = require "typedlua.tltable"

local function chainl1 (pat, sep)
  return lpeg.Cf(pat * lpeg.Cg(sep * pat)^0, tlast.exprBinaryOp)
end

local function exprFunction(...)
  local func = tlast.exprFunction(...)
  func.comment = table.concat(tllexer.comments, "\n")
  tllexer.comments = {}
  return func
end

local tlparser = {}

local G = lpeg.P { "TypedLua";
  TypedLua = tllexer.Shebang^-1 * tllexer.Skip * lpeg.V("Chunk") * -1 +
             tllexer.report_error();
  -- type language
  Type = lpeg.V("NilableType");
  NilableType = lpeg.V("UnionType") * (tllexer.decosymb("?") * lpeg.Cc(true))^-1 /
                tltype.UnionNil;
  UnionType = lpeg.V("PrimaryType") * (lpeg.Cg(tllexer.decosymb("|") * lpeg.V("PrimaryType"))^0) /
              tltype.Union;
  PrimaryType = lpeg.V("LiteralType") +
                lpeg.V("BaseType") +
                lpeg.V("NilType") +
                lpeg.V("AnyType") +
                lpeg.V("FunctionType") +
                lpeg.V("TableType") +
                lpeg.V("VariableType");
  LiteralType = ((tllexer.decotoken("false", "Type") * lpeg.Cc(false)) +
                (tllexer.decotoken("true", "Type") * lpeg.Cc(true)) +
                tllexer.decotoken(tllexer.Number, "Type") +
                tllexer.decotoken(tllexer.String, "Type")) /
                tltype.Literal;
  BaseType = tllexer.decotoken("boolean", "Type") / tltype.Boolean +
             tllexer.decotoken("number", "Type") / tltype.Number +
             tllexer.decotoken("string", "Type") / tltype.String +
             tllexer.decotoken("integer", "Type") * lpeg.Carg(3) / tltype.Integer;
  NilType = tllexer.decotoken("nil", "Type") / tltype.Nil;
  AnyType = tllexer.decotoken("any", "Type") / tltype.Any;

  -- function type only use tuple
  TupleType = tllexer.decosymb("(") * (lpeg.V("Type") * (tllexer.decosymb(",") * lpeg.V("Type"))^0)^-1 * tllexer.decosymb(")") / tltype.Tuple;
  FunctionType = lpeg.V("TupleType") * tllexer.decosymb("->") * lpeg.V("TupleType") / tltype.Function +
				 lpeg.V("TupleType") * tllexer.decosymb("->") * tllexer.decokw("auto") / tltype.AutoFunction;

  TableType = tllexer.decosymb("{") * lpeg.V("TableTypeBody") * tllexer.decosymb("}") / tltable.Table;
  TableTypeBody = lpeg.V("RecordType") +
                  lpeg.V("HashType") +
                  lpeg.V("ArrayType") +
                  lpeg.Cc(nil);
  RecordType = lpeg.V("RecordField") * (tllexer.decosymb(",") * lpeg.V("RecordField"))^0 *
               (tllexer.decosymb(",") * (lpeg.V("HashType") + lpeg.V("ArrayType")))^-1;
  RecordField = tllexer.decosymb("[") * lpeg.V("LiteralType") * tllexer.decosymb("]") *
				tllexer.decosymb("=") * lpeg.V("Type") / tltable.Field;
  HashType = tllexer.decosymb("[") * lpeg.V("KeyType") * tllexer.decosymb("]") *
			 tllexer.decosymb("=") * lpeg.V("FieldType") / tltable.Field;
  ArrayType = lpeg.V("FieldType") / tltable.ArrayField;
  KeyType = lpeg.V("BaseType") + lpeg.V("AnyType");
  FieldType = lpeg.V("Type") * lpeg.Cc(tltype.Nil()) / tltype.Union;
  VariableType = tllexer.decotoken(tllexer.Name, "Type") / tltype.Variable;

  -- interface ?? TODO
  TypeDecId = (tllexer.kw("const") * lpeg.V("Id") / tlast.setConst) +
              lpeg.V("Id");
  IdList = lpeg.Cp() * lpeg.V("TypeDecId") * (tllexer.symb(",") * lpeg.V("TypeDecId"))^0 /
           tlast.namelist;
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

  -- deco
  --[[GlobalDefine = lpeg.Cp() * tllexer.kw("global") * lpeg.V("NameList") *
                lpeg.Ct(lpeg.Cc()) / tlast.statLocal;]]
  DecoDefineStat = tllexer.symb("--[[@") * lpeg.V("TypeDecStat")^0 * tllexer.symb("]]");
  DecoName = tllexer.decosymb("--@") * lpeg.V("Type") * (tllexer.decosymb(",") * lpeg.V("Type"))^0 * lpeg.P("\n") * tllexer.DecoSkip / tlast.decoList;
  DecoFunc = tllexer.decosymb("--@") * lpeg.V("FunctionType") * lpeg.P("\n") * tllexer.DecoSkip;

  -- parser
  Chunk = lpeg.V("Block") / tlast.chunk;
  StatList = (tllexer.symb(";") + lpeg.V("Stat"))^0;
  Var = lpeg.V("Id");
  Id = lpeg.Cp() * tllexer.token(tllexer.Name, "Name") / tlast.ident;
  FunctionDef = tllexer.kw("function") * lpeg.V("FuncBody");
  FieldSep = tllexer.symb(",") + tllexer.symb(";");
  Field = lpeg.Cp() *
          ((tllexer.symb("[") * lpeg.V("Expr") * tllexer.symb("]")) +
          (lpeg.Cp() * tllexer.token(tllexer.Name, "Name") / tlast.exprString)) *
          tllexer.symb("=") * lpeg.V("Expr") / tlast.fieldPair +
          lpeg.V("Expr");
  TField = (tllexer.kw("const") * lpeg.V("Field") / tlast.setConst) +
           lpeg.V("Field");
  FieldList = (lpeg.V("TField") * (lpeg.V("FieldSep") * lpeg.V("TField"))^0 *
              lpeg.V("FieldSep")^-1)^-1;
  Constructor = lpeg.Cp() * tllexer.symb("{") * lpeg.V("FieldList") * tllexer.symb("}") / tlast.exprTable;
  NameList = lpeg.Cp() * lpeg.V("Id") * (tllexer.symb(",") * lpeg.V("Id"))^0 /
             tlast.namelist;
  ExpList = lpeg.Cp() * lpeg.V("Expr") * (tllexer.symb(",") * lpeg.V("Expr"))^0 /
            tlast.explist;
  FuncArgs = tllexer.symb("(") *
             (lpeg.V("Expr") * (tllexer.symb(",") * lpeg.V("Expr"))^0)^-1 *
             tllexer.symb(")") +
             lpeg.V("Constructor") +
             lpeg.Cp() * tllexer.token(tllexer.String, "String") / tlast.exprString;
  OrOp = tllexer.kw("or") / "or";
  AndOp = tllexer.kw("and") / "and";
  RelOp = tllexer.symb("~=") / "ne" +
          tllexer.symb("==") / "eq" +
          tllexer.symb("<=") / "le" +
          tllexer.symb(">=") / "ge" +
          tllexer.symb("<") / "lt" +
          tllexer.symb(">") / "gt";
  BOrOp = tllexer.symb("|") / "bor";
  BXorOp = tllexer.symb("~") / "bxor";
  BAndOp = tllexer.symb("&") / "band";
  ShiftOp = tllexer.symb("<<") / "shl" +
            tllexer.symb(">>") / "shr";
  ConOp = tllexer.symb("..") / "concat";
  AddOp = tllexer.symb("+") / "add" +
          tllexer.symb("-") / "sub";
  MulOp = tllexer.symb("*") / "mul" +
          tllexer.symb("//") / "idiv" +
          tllexer.symb("/") / "div" +
          tllexer.symb("%") / "mod";
  UnOp = tllexer.kw("not") / "not" +
         tllexer.symb("-") / "unm" +
         tllexer.symb("~") / "bnot" +
         tllexer.symb("#") / "len";
  PowOp = tllexer.symb("^") / "pow";
  Expr = lpeg.V("SubExpr_1");
  SubExpr_1 = chainl1(lpeg.V("SubExpr_2"), lpeg.V("OrOp"));
  SubExpr_2 = chainl1(lpeg.V("SubExpr_3"), lpeg.V("AndOp"));
  SubExpr_3 = chainl1(lpeg.V("SubExpr_4"), lpeg.V("RelOp"));
  SubExpr_4 = chainl1(lpeg.V("SubExpr_5"), lpeg.V("BOrOp"));
  SubExpr_5 = chainl1(lpeg.V("SubExpr_6"), lpeg.V("BXorOp"));
  SubExpr_6 = chainl1(lpeg.V("SubExpr_7"), lpeg.V("BAndOp"));
  SubExpr_7 = chainl1(lpeg.V("SubExpr_8"), lpeg.V("ShiftOp"));
  SubExpr_8 = lpeg.V("SubExpr_9") * lpeg.V("ConOp") * lpeg.V("SubExpr_8") /
              tlast.exprBinaryOp +
              lpeg.V("SubExpr_9");
  SubExpr_9 = chainl1(lpeg.V("SubExpr_10"), lpeg.V("AddOp"));
  SubExpr_10 = chainl1(lpeg.V("SubExpr_11"), lpeg.V("MulOp"));
  SubExpr_11 = lpeg.V("UnOp") * lpeg.V("SubExpr_11") / tlast.exprUnaryOp +
               lpeg.V("SubExpr_12");
  SubExpr_12 = lpeg.V("SimpleExp") * (lpeg.V("PowOp") * lpeg.V("SubExpr_11"))^-1 /
               tlast.exprBinaryOp;
  SimpleExp = lpeg.Cp() * tllexer.token(tllexer.Number, "Number") / tlast.exprNumber +
              lpeg.Cp() * tllexer.token(tllexer.String, "String") / tlast.exprString +
              lpeg.Cp() * tllexer.kw("nil") / tlast.exprNil +
              lpeg.Cp() * tllexer.kw("false") / tlast.exprFalse +
              lpeg.Cp() * tllexer.kw("true") / tlast.exprTrue +
              lpeg.Cp() * tllexer.symb("...") / tlast.exprDots +
              lpeg.V("FunctionDef") +
              lpeg.V("Constructor") +
              lpeg.V("SuffixedExp");
  SuffixedExp = lpeg.Cf(lpeg.V("PrimaryExp") * (
                (lpeg.Cp() * tllexer.symb(".") *
                  (lpeg.Cp() * tllexer.token(tllexer.Name, "Name") / tlast.exprString)) /
                  tlast.exprIndex +
                (lpeg.Cp() * tllexer.symb("[") * lpeg.V("Expr") * tllexer.symb("]")) /
                tlast.exprIndex +
                (lpeg.Cp() * lpeg.Cg(tllexer.symb(":") *
                   (lpeg.Cp() * tllexer.token(tllexer.Name, "Name") / tlast.exprString) *
                   lpeg.V("FuncArgs"))) / tlast.invoke +
                (lpeg.Cp() * lpeg.V("FuncArgs")) / tlast.call)^0, tlast.exprSuffixed);
  PrimaryExp = lpeg.V("Var") +
               lpeg.Cp() * tllexer.symb("(") * lpeg.V("Expr") * tllexer.symb(")") / tlast.exprParen;
  Block = lpeg.Cp() * lpeg.V("StatList") * lpeg.V("RetStat")^-1 / tlast.block;
  IfStat = lpeg.Cp() * tllexer.kw("if") * lpeg.V("Expr") * tllexer.kw("then") * lpeg.V("Block") *
           (tllexer.kw("elseif") * lpeg.V("Expr") * tllexer.kw("then") * lpeg.V("Block"))^0 *
           (tllexer.kw("else") * lpeg.V("Block"))^-1 *
           tllexer.kw("end") / tlast.statIf;
  WhileStat = lpeg.Cp() * tllexer.kw("while") * lpeg.V("Expr") *
              tllexer.kw("do") * lpeg.V("Block") * tllexer.kw("end") / tlast.statWhile;
  DoStat = tllexer.kw("do") * lpeg.V("Block") * tllexer.kw("end") / tlast.statDo;
  ForBody = tllexer.kw("do") * lpeg.V("Block");
  ForNum = lpeg.Cp() *
           lpeg.V("Id") * tllexer.symb("=") * lpeg.V("Expr") * tllexer.symb(",") *
           lpeg.V("Expr") * (tllexer.symb(",") * lpeg.V("Expr"))^-1 *
           lpeg.V("ForBody") / tlast.statFornum;
  ForGen = lpeg.Cp() * lpeg.V("NameList") * tllexer.kw("in") *
           lpeg.V("ExpList") * lpeg.V("ForBody") / tlast.statForin;
  ForStat = tllexer.kw("for") * (lpeg.V("ForNum") + lpeg.V("ForGen")) * tllexer.kw("end");
  RepeatStat = lpeg.Cp() * tllexer.kw("repeat") * lpeg.V("Block") *
               tllexer.kw("until") * lpeg.V("Expr") / tlast.statRepeat;
  FuncName = lpeg.Cf(lpeg.V("Id") * (tllexer.symb(".") *
             (lpeg.Cp() * tllexer.token(tllexer.Name, "Name") / tlast.exprString))^0, tlast.funcName) *
             (tllexer.symb(":") * (lpeg.Cp() * tllexer.token(tllexer.Name, "Name") /
             tlast.exprString) *
               lpeg.Cc(true))^-1 /
             tlast.funcName;
  ParDots = lpeg.Cp() * tllexer.symb("...") / tlast.identDots;
  ParList = lpeg.Cp() * lpeg.V("NameList") * (tllexer.symb(",") * lpeg.V("ParDots"))^-1 / tlast.parList2 +
            lpeg.Cp() * lpeg.V("ParDots") / tlast.parList1 +
            lpeg.Cp() / tlast.parList0;
  FuncBody = lpeg.Cp() * tllexer.symb("(") * lpeg.V("ParList") * tllexer.symb(")") *
             lpeg.V("Block") * tllexer.kw("end") / exprFunction;


  -- stat , normal set func & assign
  FuncStat = lpeg.Cp() * (tllexer.kw("const") * lpeg.Cc(true) + lpeg.Cc(false)) *
             tllexer.kw("function") * lpeg.V("FuncName") * lpeg.V("FuncBody") /
             tlast.statFuncSet;
  AssignStat = lpeg.Cmt(lpeg.V("LVar")*(tllexer.symb(",") * lpeg.V("LVar"))^0 * tllexer.symb("=") * lpeg.V("ExpList"), function(s, i, ...) return tlast.statSet(...) end);

  -- stat with deco
  SetStat = lpeg.V("FuncStat") + lpeg.V("AssignStat") +
	  (lpeg.Cp() * lpeg.V("DecoName") * lpeg.V("AssignStat")/tlast.statDecoAssign) +
	  (lpeg.Cp() * lpeg.V("DecoFunc") * lpeg.V("FuncStat")/tlast.statDecoFunc);

  -- stat , normal local func & assign
  LocalFunc = lpeg.Cp() * tllexer.kw("local") * tllexer.kw("function") *
              lpeg.V("Id") * lpeg.V("FuncBody") / tlast.statLocalrec;
  LocalAssign = lpeg.Cp() * tllexer.kw("local") * lpeg.V("NameList") *
                ((tllexer.symb("=") * lpeg.V("ExpList")) + lpeg.Ct(lpeg.Cc())) / tlast.statLocal;

  -- stat with deco
  LocalStat = lpeg.V("LocalFunc") + lpeg.V("LocalAssign") +
	  (lpeg.Cp() * lpeg.V("DecoName") * lpeg.V("LocalAssign")/tlast.statDecoAssign) +
	  (lpeg.Cp() * lpeg.V("DecoFunc") * lpeg.V("LocalFunc")/tlast.statDecoFunc);

  LabelStat = lpeg.Cp() * tllexer.symb("::") * tllexer.token(tllexer.Name, "Name") * tllexer.symb("::") / tlast.statLabel;
  BreakStat = lpeg.Cp() * tllexer.kw("break") / tlast.statBreak;
  GoToStat = lpeg.Cp() * tllexer.kw("goto") * tllexer.token(tllexer.Name, "Name") / tlast.statGoto;
  RetStat = lpeg.Cp() * tllexer.kw("return") *
            (lpeg.V("Expr") * (tllexer.symb(",") * lpeg.V("Expr"))^0)^-1 *
            tllexer.symb(";")^-1 / tlast.statReturn;

  LVar = (tllexer.kw("const") * lpeg.V("SuffixedExp") / tlast.setConst) +
         lpeg.V("SuffixedExp");

  ApplyStat = lpeg.Cmt(lpeg.V("SuffixedExp") * (lpeg.Cc(tlast.statApply)),
             function (s, i, s1, f, ...) return f(s1, ...) end);

  Stat = lpeg.V("DecoDefineStat") + lpeg.V("TypeDecStat") +
		 lpeg.V("LocalStat") + lpeg.V("SetStat") +

		 lpeg.V("IfStat") + lpeg.V("WhileStat") + lpeg.V("DoStat") + lpeg.V("ForStat") +
         lpeg.V("RepeatStat") +
         lpeg.V("LabelStat") + lpeg.V("BreakStat") + lpeg.V("GoToStat") +
         lpeg.V("ApplyStat");
}

local function fixup_lin_col(subject, node, counter)
  counter = counter or {
	  curLine = 0,
	  startPos = 0,
	  finishPos = 1,
  }
  if node and node.pos then
	  while counter.finishPos < node.pos do
		  counter.startPos = counter.finishPos
		  counter.finishPos = subject:find("\n", counter.finishPos + 1)
		  counter.curLine = counter.curLine + 1
	  end
	  node.l = counter.curLine
	  node.c = node.pos - counter.startPos
  end
  for _, child in ipairs(node) do
    if type(child) == "table" then
		fixup_lin_col(subject, child, counter)
    end
  end
end

function tlparser.parse (subject, filename, strict, integer)
  local errorinfo = { subject = subject, filename = filename }
  lpeg.setmaxstack(1000)
  if integer and _VERSION ~= "Lua 5.3" then integer = false end
  local ast, error_msg = lpeg.match(G, subject, nil, errorinfo, strict, integer)
  if not ast then return ast, error_msg end

  fixup_lin_col(subject, ast)
  return ast, error_msg
end

return tlparser
