/+ dub.sdl:
    dependency "aslike" path=".."
 +/

import std.stdio;

import aslike;

interface Foo
{
const:
    int func1();
    int func2(int, int);
}

int bar(Foo foo, int a, int b) { return foo.func1() * foo.func2(a, b); }

struct FooImpl
{
    int v;
const:
    int func1() { return v; }
    int func2(int a, int b) { return a + b; }
}

void main()
{
    auto foo = FooImpl(10);
    writeln(bar(foo.asObj!Foo, 2, 3));
    // Don't use asObj for structs with short lifetime
    //writeln(bar(FooImpl(10).asObj!Foo, 2, 3));

    // Use asObjCtx
    writeln(bar(FooImpl(10).asObjCtx!Foo, 2, 3));
}
