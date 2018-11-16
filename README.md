# Typed Lua

Typed Lua is a typed superset of Lua that compiles to plain Lua.
It provides optional type annotations, compile-time type checking, and
class-based object oriented programming through the definition of classes,
interfaces, and modules.

This is a repository forked from [andremm/typedlua](https://github.com/andremm/typedlua).

# Motivation

This forking intends to improve the typed system and some code in Typedlua.

## Benefit

1. Syntax define and parser based on LPeg.
2. Ast's node and link's implement using lua table.
3. Some basic design and logic in a type system. (As I'm a newbie in PL...)

## Not Good

1. Unionlist, Union, Variable, Recursive...
2. The code in tlvisitor.lua is hard to reuse.
3. The complexity of tltype.subtype.
4. Much if-else branches which may be a little slow are used in many place.

## Problem

1. Support for multi .lua file.
2. Type checking order if there's function block.

# TODO

Many things TODO...

# License

Released under the MIT License (MIT)

Copyright (c) 2013 Andre Murbach Maidl

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
