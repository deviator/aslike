# ASLIKE

[![Build Status](https://travis-ci.org/deviator/aslike.svg?branch=master)](https://travis-ci.org/deviator/aslike)
[![codecov](https://codecov.io/gh/deviator/aslike/branch/master/graph/badge.svg)](https://codecov.io/gh/deviator/aslike)
[![Dub](https://img.shields.io/dub/v/aslike.svg)](http://code.dlang.org/packages/aslike)
[![Downloads](https://img.shields.io/dub/dt/aslike.svg)](http://code.dlang.org/packages/aslike)
[![License](https://img.shields.io/dub/l/aslike.svg)](http://code.dlang.org/packages/aslike)

This lib can be helpful if you want to declare function or method what must get
some object as argument, and it object must contains all methods what you want,
and if you don't want use classic OOP and/or want use structs. If you use classic
OOP and your functions and/or methods already gets interface as argument you
can wrap structs to auto-implement objects.

## API

`struct Like(T) if (is(T == interface))` -- wrapper for `T`, it have
methods and private delegate fields matches all methods from `T`.

`class LikeObj(T) : T` -- wrapper for `T`, as `Like!T`, but class.

`class LikeObjCtx(T, S) : LikeObj!T` -- wrapper for `T`, as `LikeObj!T`,
but with `S __context` field (usable for short lifetime structs).

`Like!T as(T, bool nullCheck=true, X)(ref X obj) if (is(T == interface))` --
wrap object `obj` into `Like!T` if it possible (fill all delegate fields
in returned `Like!T` with methods pointers from `obj`). If `X` is class or
interface and if `nullCheck` is true enforce `obj` is not `null`.

`T asObj(T, bool nullCheck=true, X)(ref X obj) if (is(T == interface))` --
wrap object `obj` into `LikeObj!T` if it possible.

`T asObjCtx(T, bool nullCheck=true, X)(auto ref X obj) if (is(T == interface))` --
copy `obj` into private field of `LikeObjCtx!(T, X)` and wrap this field,
instead of original `obj`.

`T toObj(T)(auto ref const Like!T th) @property` -- make new wrapper object
(`LikeObj!T` -- without saving `th`) and fill delegates from `th` delegates.

`void fillLikeDelegates(T, bool nullCheck=true, R, X)(ref R dst, auto ref X src)
    if (is(T == interface) && (is(R : LikeObj!T) || is(R == Like!T)))` --
function for filling delegate fields, if you want manual allocate `Like` objects.

## Examples

Overridable method with any compatible type: [example](example/struct.d)

Cache virtual methods table lookup for improving multiple call
methods performance: [cache example](example/cache.d)

Use struct when method or function gets interface instance as argument:
[wrap to object example](example/wrapobj.d)

## Notes

`Like!T` struct and `LikeObj!T` class have reference symantics respect to
wrapped object.

Be careful when wrap objects allocated on stack: when program exit from scope,
reference to object saved in delegates will be broken.
