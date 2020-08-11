///
module aslike;

import std.traits;
import std.string : join;

///
struct Like(T) if (is(T == interface))
{
    private template dlgName(alias fn) { enum dlgName = "__dlg_" ~ fn.mangleof; }
    private template fnAttr(alias fn)
    {
        enum fnAttr = [__traits(getFunctionAttributes, fn)].join(" ");
    }

    static foreach (m; [__traits(allMembers, T)])
    {
        static if (__traits(isVirtualFunction, __traits(getMember, T, m)))
        {
            static foreach (fn; __traits(getOverloads, T, m))
            {
                mixin("private ReturnType!fn delegate(Parameters!fn) " ~ fnAttr!fn ~ " " ~ dlgName!fn ~ ";");
                mixin("ReturnType!fn " ~ m ~ "(Parameters!fn args) " ~ fnAttr!fn ~ " { return " ~ dlgName!fn ~ "(args); }");
            }
        }
    }
}

///
Like!T as(T, X)(auto ref X obj) if (is(T == interface))
{
    Like!T ret;
    
    static foreach (m; [__traits(allMembers, T)])
    {
        static if (__traits(isVirtualFunction, __traits(getMember, T, m)))
        {
            static foreach (fn; __traits(getOverloads, T, m))
            {
                mixin("ret." ~ ret.dlgName!fn ~ " = &obj."~m~";");
            }
        }
    }

    return ret;
}

version(unittest)
{
    interface Foo
    {
    @safe:
        void okda();
    nothrow const:
        int one();
        int one(int x);
        int two();
    }

    static int useFoo(Like!Foo obj) @safe
    {
        obj.okda();
        return obj.one() + obj.two() + obj.one(100);
    }
}

unittest
{
    int k = 1;

    struct Bar
    {
        int a, b;
    @safe:
        void okda() { k = 3; }
    nothrow const:
        int one() { return a * 2 + k; }
        int one(int x) { return a * x; }
        int two() { return a + b; }
    }

    assert(useFoo(Bar(2, 4).as!Foo) == 213);
}

unittest
{
    static class Bar : Foo
    {
        void okda() {}
    override const:
        int one() { return 5; }
        int one(int x) { return x * 2; }
        int two() { return 3; }
    }

    assert(useFoo((new Bar).as!Foo) == 208);
}

unittest
{
    static interface Foo2 { int func() @nogc; }
    static void test(Like!Foo2 obj) @nogc { assert(obj.func() == 42); }

    static class Bar : Foo2
    { override int func() @nogc { return 42; } }

    auto bar = new Bar;

    (() @nogc { test(bar.as!Foo2); })();
}