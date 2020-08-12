///
module aslike;

import std.traits;
import std.string : join, format;
import std.exception : enforce;

private mixin template LikeContent(T, string exattr="")
{
    private template dlgName(alias fn) { enum dlgName = "__dlg_" ~ fn.mangleof; }
    private template fnAttr(alias fn)
    { enum fnAttr = [__traits(getFunctionAttributes, fn)].join(" "); }

    static foreach (m; [__traits(allMembers, T)])
        static if (__traits(isVirtualFunction, __traits(getMember, T, m)))
            static foreach (fn; __traits(getOverloads, T, m))
                mixin(format!("private %1$s delegate(%2$s) %3$s %4$s;\n" ~
                              "%6$s %1$s %5$s (%2$s args) %3$s { return %4$s(args); }")
                              ("ReturnType!fn", "Parameters!fn", fnAttr!fn, dlgName!fn, m, exattr));

}

///
struct Like(T) if (is(T == interface)) { mixin LikeContent!T; }
///
class LikeObj(T) : T { mixin LikeContent!(T, "final override"); }
///
class LikeObjCtx(T, S) : LikeObj!T { S __context; }

///
T toObj(T)(auto ref const Like!T th) @property
{
    auto ret = new LikeObj!T;
    static foreach (m; [__traits(allMembers, Like!T)])
        static if (isDelegate!(__traits(getMember, Like!T, m)))
            mixin ("ret."~m~" = th."~m~";");
    return ret;
}

///
void fillLikeDelegates(T, bool nullCheck=true, R, X)(ref R dst, auto ref X src)
    if (is(T == interface) && (is(R : LikeObj!T) || is(R == Like!T)))
{
    static if (nullCheck && (is(X == interface) || is(X == class)))
        enforce(src !is null, "object is null");
    
    static foreach (m; [__traits(allMembers, T)])
        static if (__traits(isVirtualFunction, __traits(getMember, T, m)))
            static foreach (fn; __traits(getOverloads, T, m))
                mixin("dst." ~ dst.dlgName!fn ~ " = &src."~m~";");
}

///
Like!T as(T, bool nullCheck=true, X)(ref X obj) if (is(T == interface))
{
    Like!T ret;
    fillLikeDelegates!(T,nullCheck)(ret, obj);
    return ret;
}

///
T asObj(T, bool nullCheck=true, X)(ref X obj) if (is(T == interface))
{
    auto ret = new LikeObj!T;
    fillLikeDelegates!(T,nullCheck)(ret, obj);
    return ret;
}

///
T asObjCtx(T, bool nullCheck=true, X)(auto ref X obj) if (is(T == interface))
{
    auto ret = new LikeObjCtx!(T, X);
    ret.__context = obj; // copy context
    fillLikeDelegates!(T,nullCheck)(ret, ret.__context);
    return ret;
}

version(unittest)
{
    interface ConstFoo
    {
    @safe:
    nothrow const:
        int one();
        int one(int x);
        int two();

    }

    interface Foo : ConstFoo
    {
    @safe:
        void okda();
    }

    int useFoo(Like!Foo obj) @safe
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

    auto bar = Bar(2, 4);
    assert(useFoo(bar.as!Foo) == 213);
    assert(k == 3);
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

    auto bar = new Bar;
    assert(useFoo(bar.as!Foo) == 208);
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

version(unittest)
{
    int useFooObj(Foo obj) @safe
    {
        obj.okda();
        return obj.one() + obj.two() + obj.one(100);
    }

    int useConstFoo(const Like!ConstFoo obj) @safe
    { return obj.one() + obj.two() + obj.one(1000); }

    int useConstFooObj(const ConstFoo obj) @safe
    { return obj.one() + obj.two() + obj.one(1000); }
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

    auto bar1 = Bar(2, 4);
    assert(useFooObj(bar1.asObj!Foo) == 213);
    assert(k == 3);
    assert(useFooObj(bar1.as!Foo.toObj) == 213);

    assert(useConstFooObj(bar1.asObj!Foo) == 2013);
    assert(useConstFooObj(bar1.as!Foo.toObj) == 2013);

    const bar2 = Bar(1, 2);
    assert(useConstFoo(bar2.as!ConstFoo) == 1008);
    assert(useConstFooObj(bar2.as!ConstFoo.toObj) == 1008);
}