///
module aslike;

import std.traits;
import std.string : join, format;
import std.exception : enforce;

///
struct Like(T) if (is(T == interface))
{
    private template dlgName(alias fn) { enum dlgName = "__dlg_" ~ fn.mangleof; }
    private template fnAttr(alias fn)
    { enum fnAttr = [__traits(getFunctionAttributes, fn)].join(" "); }

    static foreach (m; [__traits(allMembers, T)])
        static if (__traits(isVirtualFunction, __traits(getMember, T, m)))
            static foreach (fn; __traits(getOverloads, T, m))
                mixin(format!("private %1$s delegate(%2$s) %3$s %4$s;\n" ~
                              "%1$s %5$s (%2$s args) %3$s { return %4$s(args); }")
                              ("ReturnType!fn", "Parameters!fn", fnAttr!fn, dlgName!fn, m));
}

///
Like!T as(T, bool nullCheck=true, X)(auto ref X obj) if (is(T == interface))
{
    Like!T ret;

    static if (nullCheck && (is(X == interface) || is(X == class)))
        enforce(obj !is null, "object is null");
    
    static foreach (m; [__traits(allMembers, T)])
        static if (__traits(isVirtualFunction, __traits(getMember, T, m)))
            static foreach (fn; __traits(getOverloads, T, m))
                mixin("ret." ~ ret.dlgName!fn ~ " = &obj."~m~";");

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

    static class BarC : Foo2
    { override int func() @nogc { return 42; } }

    auto barC = new BarC;
    (() @nogc { test(barC.as!(Foo2, false)); })();

    static struct BarS
    { int func() @nogc { return 42; } }

    BarS barS;
    (() @nogc { test(barS.as!Foo2); })();

    import std : assertThrown;
    BarC nullBarC;
    assertThrown( nullBarC.as!Foo2 );
}

@safe
unittest
{
    static interface Foo3 { int func() @safe; }
    static void test(Like!Foo3 obj) @safe { assert(obj.func() == 42); }

    static class Bar : Foo3
    { override int func() @nogc { return 42; } }

    auto bar = new Bar;
    (() @safe { test(bar.as!Foo3); })();
}